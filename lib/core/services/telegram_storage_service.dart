import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TelegramUploadResult {
  final String chatId;
  final int messageId;
  final String fileId;
  final String fileUniqueId;
  final String fileName;
  final int fileSize;

  const TelegramUploadResult({
    required this.chatId,
    required this.messageId,
    required this.fileId,
    required this.fileUniqueId,
    required this.fileName,
    required this.fileSize,
  });
}

class TelegramStorageService {
  static const String backendUrl = String.fromEnvironment(
    'TELEGRAM_BACKEND_URL',
    defaultValue: '',
  );

  final SupabaseClient _supabase;
  final dio.Dio _dio;

  TelegramStorageService({
    SupabaseClient? supabase,
    dio.Dio? dioClient,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _dio = dioClient ?? dio.Dio();

  String get _baseUrl {
    final value = backendUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.isEmpty) {
      throw Exception(
        'Telegram Storage backend URL is not configured. '
        'Build the admin dashboard with --dart-define=TELEGRAM_BACKEND_URL=...',
      );
    }
    return value;
  }

  Future<TelegramUploadResult> uploadVideo({
    required PlatformFile file,
    required String lectureId,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Your admin session has expired. Please sign in again.');
    }

    final stream = file.readStream;
    if (stream == null) {
      throw Exception(
        'Unable to stream the selected video. Please select the file again.',
      );
    }

    final form = dio.FormData.fromMap({
      'file': dio.MultipartFile(
        stream,
        file.size,
        filename: file.name,
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/api/upload/video',
      queryParameters: {
        'title': title,
        'lecture_id': lectureId,
      },
      data: form,
      options: dio.Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call((sent / total).clamp(0.0, 1.0));
        }
      },
    );

    final data = response.data;
    if (data == null || data['ok'] != true) {
      throw Exception('Telegram backend returned an invalid upload response.');
    }

    return TelegramUploadResult(
      chatId: data['chat_id']?.toString() ?? '',
      messageId: (data['message_id'] as num?)?.toInt() ?? 0,
      fileId: data['file_id']?.toString() ?? '',
      fileUniqueId: data['file_unique_id']?.toString() ?? '',
      fileName: data['file_name']?.toString() ?? file.name,
      fileSize: (data['file_size'] as num?)?.toInt() ?? file.size,
    );
  }

  Future<void> deleteMessage(int messageId) async {
    if (messageId <= 0) return;

    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      await _dio.delete<void>(
        '$_baseUrl/api/telegram/message/$messageId',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
    } catch (_) {}
  }

  String buildFileUrl(String fileId) {
    if (fileId.trim().isEmpty) {
      throw Exception('Telegram file ID is empty.');
    }
    return 'telegram:${fileId.trim()}';
  }

  String buildProxyUrl(String fileId) {
    if (fileId.trim().isEmpty) {
      throw Exception('Telegram file ID is empty.');
    }
    return '$_baseUrl/api/telegram/file/${Uri.encodeComponent(fileId.trim())}';
  }
}
