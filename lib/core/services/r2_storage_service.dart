import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class R2UploadResult {
  final String key;
  final String fileName;
  final int fileSize;
  const R2UploadResult({required this.key, required this.fileName, required this.fileSize});
}

class R2StorageService {
  static const String backendUrl = String.fromEnvironment('TELEGRAM_BACKEND_URL', defaultValue: '');
  final SupabaseClient _supabase;
  final dio.Dio _dio;

  R2StorageService({SupabaseClient? supabase, dio.Dio? dioClient})
      : _supabase = supabase ?? Supabase.instance.client,
        _dio = dioClient ?? dio.Dio();

  String get _baseUrl {
    final value = backendUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.isEmpty) {
      throw Exception('R2 backend URL is not configured. Build with --dart-define=TELEGRAM_BACKEND_URL=...');
    }
    return value;
  }

  Future<Map<String, dynamic>> _post(String path, {Object? data}) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Your admin session has expired. Please sign in again.');

    final response = await _dio.post<Map<String, dynamic>>(
      _baseUrl + path,
      data: data,
      options: dio.Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'application/json',
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
    if (response.data == null) throw Exception('R2 backend returned an empty response.');
    return response.data!;
  }

  Future<R2UploadResult> uploadVideo({
    required PlatformFile file,
    required String lectureId,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    final size = file.size;
    if (size <= 0) throw Exception('The selected video is empty.');

    final init = await _post('/api/r2/multipart/initiate', data: {
      'lecture_id': lectureId,
      'filename': file.name,
      'content_type': _contentType(file.name),
      'file_size': size,
    });

    final key = init['key']?.toString() ?? '';
    final uploadId = init['upload_id']?.toString() ?? '';
    final partSize = (init['part_size'] as num?)?.toInt() ?? 64 * 1024 * 1024;
    if (key.isEmpty || uploadId.isEmpty) throw Exception('R2 backend did not return a valid multipart upload session.');

    final stream = file.readStream;
    if (stream == null) {
      await _abort(key, uploadId);
      throw Exception('Unable to stream the selected video.');
    }

    final parts = <Map<String, dynamic>>[];
    var partNumber = 0;
    var uploadedBytes = 0;

    try {
      await for (final bytes in _splitIntoParts(stream, partSize)) {
        partNumber++;
        if (partNumber > 10000) throw Exception('The video requires more than 10,000 upload parts.');

        final urlData = await _post('/api/r2/multipart/part-url', data: {
          'key': key,
          'upload_id': uploadId,
          'part_number': partNumber,
        });
        final url = urlData['url']?.toString() ?? '';
        if (url.isEmpty) throw Exception('R2 did not return a signed upload URL.');

        String? etag;
        Object? lastError;
        for (var attempt = 1; attempt <= 3; attempt++) {
          try {
            final response = await _dio.put<void>(
              url,
              data: bytes,
              options: dio.Options(
                headers: {
                  'Content-Type': 'application/octet-stream',
                  'Content-Length': bytes.length.toString(),
                },
                validateStatus: (status) => status != null && status >= 200 && status < 300,
              ),
            );
            etag = response.headers.value('etag');
            if (etag == null || etag.isEmpty) throw Exception('R2 did not return an ETag for part $partNumber.');
            break;
          } catch (e) {
            lastError = e;
            if (attempt < 3) await Future<void>.delayed(Duration(seconds: attempt));
          }
        }

        if (etag == null) throw Exception('Failed to upload part $partNumber: $lastError');
        uploadedBytes += bytes.length;
        parts.add({'part_number': partNumber, 'etag': etag});
        onProgress?.call((uploadedBytes / size).clamp(0.0, 1.0));
      }

      if (parts.isEmpty) throw Exception('No video data was uploaded.');
      await _post('/api/r2/multipart/complete', data: {
        'key': key,
        'upload_id': uploadId,
        'parts': parts,
      });
      onProgress?.call(1.0);
      return R2UploadResult(key: key, fileName: file.name, fileSize: size);
    } catch (e) {
      await _abort(key, uploadId);
      rethrow;
    }
  }

  Future<void> _abort(String key, String uploadId) async {
    try {
      await _post('/api/r2/multipart/abort', data: {'key': key, 'upload_id': uploadId});
    } catch (_) {}
  }

  Future<void> deleteObject(String key) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return;
    await _dio.delete<void>(
      '$_baseUrl/api/r2/object',
      queryParameters: {'key': key},
      options: dio.Options(
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
  }

  Future<String> createSignedUrl(String key) async {
    final data = await _post('/api/r2/signed-url', data: {'key': key});
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('R2 backend did not return a signed URL.');
    return url;
  }

  String buildFileUrl(String key) => 'r2:${key.trim()}';

  String keyFromFileUrl(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('r2:') ? trimmed.substring(3).trim() : trimmed;
  }

  String _contentType(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'webm': return 'video/webm';
      case 'mov': return 'video/quicktime';
      case 'm4v': return 'video/x-m4v';
      case 'avi': return 'video/x-msvideo';
      case 'mkv': return 'video/x-matroska';
      default: return 'video/mp4';
    }
  }

  Stream<Uint8List> _splitIntoParts(Stream<List<int>> source, int partSize) async* {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source) {
      var offset = 0;
      while (offset < chunk.length) {
        final remaining = partSize - builder.length;
        final take = (chunk.length - offset) < remaining ? chunk.length - offset : remaining;
        builder.add(chunk.sublist(offset, offset + take));
        offset += take;
        if (builder.length == partSize) yield builder.takeBytes();
      }
    }
    if (builder.length > 0) yield builder.takeBytes();
  }
}
