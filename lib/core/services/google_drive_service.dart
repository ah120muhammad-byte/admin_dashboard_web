import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

class GoogleDriveUploadResult {
  final String fileId;
  final String name;
  final String webViewLink;

  const GoogleDriveUploadResult({
    required this.fileId,
    required this.name,
    required this.webViewLink,
  });
}

class GoogleDriveService {
  static const String clientId =
      '595177774591-5cpq6vvqgds2h2t7cusi1tjfvosn07jv.apps.googleusercontent.com';
  static const String scope = 'https://www.googleapis.com/auth/drive.file';
  static const int chunkSize = 8 * 1024 * 1024;

  final Dio _dio;
  String? _accessToken;

  GoogleDriveService({Dio? dio}) : _dio = dio ?? Dio();

  Future<String> _getAccessToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken!;
    }

    final google = js_util.getProperty<Object?>(js_util.globalThis, 'google');
    if (google == null) {
      throw Exception(
        'Google OAuth library is not loaded. Please refresh the admin page.',
      );
    }

    final accounts = js_util.getProperty<Object?>(google, 'accounts');
    final oauth2 = accounts == null
        ? null
        : js_util.getProperty<Object?>(accounts, 'oauth2');

    if (oauth2 == null) {
      throw Exception('Google OAuth is unavailable. Please refresh the page.');
    }

    final initTokenClient =
        js_util.getProperty<Object?>(oauth2, 'initTokenClient');
    if (initTokenClient == null) {
      throw Exception('Google OAuth token client is unavailable.');
    }

    final completer = Completer<String>();

    final callback = js.allowInterop((Object response) {
      try {
        final error = js_util.getProperty<Object?>(response, 'error');
        if (error != null) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(error.toString()));
          }
          return;
        }

        final token =
            js_util.getProperty<String?>(response, 'access_token');

        if (token == null || token.isEmpty) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Google did not return an access token.'),
            );
          }
          return;
        }

        _accessToken = token;
        if (!completer.isCompleted) {
          completer.complete(token);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    final config = js_util.jsify(<String, Object?>{
      'client_id': clientId,
      'scope': scope,
      'callback': callback,
    });

    final client = js_util.callMethod<Object?>(
      oauth2,
      'initTokenClient',
      [config],
    );

    if (client == null) {
      throw Exception('Unable to initialize Google OAuth.');
    }

    js_util.callMethod<void>(client, 'requestAccessToken', [
      js_util.jsify({'prompt': ''}),
    ]);

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw Exception('Google authorization timed out.'),
    );
  }

  Future<GoogleDriveUploadResult> uploadVideo(
    PlatformFile file, {
    void Function(double progress)? onProgress,
  }) async {
    final token = await _getAccessToken();
    final total = await file.length();

    if (total == null || total <= 0) {
      throw Exception('Unable to determine the selected video size.');
    }

    final mimeType = _mimeType(file.name);

    final initResponse = await _dio.post<String>(
      'https://www.googleapis.com/upload/drive/v3/files',
      queryParameters: const {'uploadType': 'resumable'},
      data: jsonEncode({
        'name': file.name,
        'mimeType': mimeType,
      }),
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': mimeType,
          'X-Upload-Content-Length': total,
        },
        responseType: ResponseType.plain,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    final sessionUrl = initResponse.headers.value('location');
    if (sessionUrl == null || sessionUrl.isEmpty) {
      throw Exception('Google Drive did not return an upload session.');
    }

    final stream = file.readAsByteStream();
    if (stream == null) {
      throw Exception('Unable to stream the selected video.');
    }

    final buffer = BytesBuilder(copy: false);
    var uploaded = 0;
    Map<String, dynamic>? finalMetadata;

    Future<Map<String, dynamic>> sendChunk(
      Uint8List chunk,
      int start,
    ) async {
      final end = start + chunk.length - 1;

      for (var attempt = 1; attempt <= 4; attempt++) {
        try {
          final response = await _dio.put<dynamic>(
            sessionUrl,
            data: chunk,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Range': 'bytes $start-$end/$total',
                'Content-Type': mimeType,
              },
              responseType: ResponseType.json,
              validateStatus: (status) =>
                  status != null &&
                  (status == 200 || status == 201 || status == 308),
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = response.data;
            if (data is Map) {
              return {
                ...Map<String, dynamic>.from(data),
                'nextOffset': end + 1,
              };
            }
            return {'nextOffset': end + 1};
          }

          final range = response.headers.value('range');
          if (range != null) {
            final match = RegExp(r'bytes=\\d+-(\\d+)').firstMatch(range);
            if (match != null) {
              return {
                'nextOffset': int.parse(match.group(1)!) + 1,
              };
            }
          }

          return {'nextOffset': end + 1};
        } catch (e) {
          if (attempt == 4) rethrow;
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }

      throw Exception('Upload chunk failed.');
    }

    Future<void> uploadBufferedChunk(Uint8List chunk) async {
      var localOffset = 0;

      while (localOffset < chunk.length) {
        final part = Uint8List.sublistView(chunk, localOffset);
        final result = await sendChunk(part, uploaded);
        final nextOffset =
            result['nextOffset'] as int? ?? (uploaded + part.length);

        if (result['id'] != null) {
          finalMetadata = result;
        }

        final accepted = nextOffset - uploaded;
        if (accepted <= 0) {
          throw Exception('Google Drive returned an invalid upload offset.');
        }

        uploaded = nextOffset;
        localOffset += accepted;
        onProgress?.call((uploaded / total).clamp(0.0, 1.0));
      }
    }

    await for (final part in stream) {
      buffer.add(part);

      while (buffer.length >= chunkSize) {
        final bytes = buffer.takeBytes();
        final chunk = Uint8List.fromList(bytes);

        if (chunk.length > chunkSize) {
          await uploadBufferedChunk(
            Uint8List.sublistView(chunk, 0, chunkSize),
          );
          buffer.add(Uint8List.sublistView(chunk, chunkSize));
        } else {
          await uploadBufferedChunk(chunk);
        }
      }
    }

    if (buffer.length > 0) {
      await uploadBufferedChunk(buffer.takeBytes());
    }

    if (uploaded != total) {
      throw Exception(
        'Google Drive upload stopped at $uploaded of $total bytes.',
      );
    }

    final fileId = finalMetadata?['id']?.toString();
    if (fileId == null || fileId.isEmpty) {
      throw Exception('Google Drive uploaded the video but returned no file ID.');
    }

    await _makePublic(fileId, token);

    onProgress?.call(1.0);

    return GoogleDriveUploadResult(
      fileId: fileId,
      name: file.name,
      webViewLink: 'https://drive.google.com/file/d/$fileId/view',
    );
  }

  Future<void> _makePublic(String fileId, String token) async {
    await _dio.post<void>(
      'https://www.googleapis.com/drive/v3/files/$fileId/permissions',
      queryParameters: const {'sendNotificationEmail': 'false'},
      data: const {'type': 'anyone', 'role': 'reader'},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<void> deleteFile(String fileId) async {
    final token = await _getAccessToken();

    await _dio.delete<void>(
      'https://www.googleapis.com/drive/v3/files/$fileId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }

  String _mimeType(String name) {
    final extension =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';

    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'video/mp4';
    }
  }
}
