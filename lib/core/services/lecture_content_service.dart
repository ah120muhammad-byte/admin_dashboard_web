import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'google_drive_service.dart';
import 'telegram_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentLecture {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final int displayOrder;
  final bool isPublished;
  final bool isActive;

  const ContentLecture({
    required this.id,
    required this.moduleId,
    required this.title,
    this.description,
    required this.displayOrder,
    required this.isPublished,
    required this.isActive,
  });

  factory ContentLecture.fromMap(Map<String, dynamic> map) {
    return ContentLecture(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isPublished: map['is_published'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class LectureFileItem {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String fileUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String storageProvider;
  final String? telegramChatId;
  final int? telegramMessageId;
  final String? telegramFileId;
  final String? telegramFileUniqueId;
  final int? fileSize;

  const LectureFileItem({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.storageProvider = 'supabase',
    this.telegramChatId,
    this.telegramMessageId,
    this.telegramFileId,
    this.telegramFileUniqueId,
    this.fileSize,
  });

  factory LectureFileItem.fromMap(Map<String, dynamic> map) {
    return LectureFileItem(
      id: map['id'] as String,
      lectureId: map['lecture_id'] as String,
      title: map['title'] as String? ?? '',
      fileType: map['file_type'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? '',
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      storageProvider: map['storage_provider']?.toString() ?? 'supabase',
      telegramChatId: map['telegram_chat_id']?.toString(),
      telegramMessageId: (map['telegram_message_id'] as num?)?.toInt(),
      telegramFileId: map['telegram_file_id']?.toString(),
      telegramFileUniqueId: map['telegram_file_unique_id']?.toString(),
      fileSize: (map['file_size'] as num?)?.toInt(),
    );
  }
}

class LectureContentService {
  final SupabaseClient _supabase;
  final GoogleDriveService _googleDrive;
  final TelegramStorageService _telegram;

  LectureContentService({
    SupabaseClient? supabase,
    GoogleDriveService? googleDrive,
    TelegramStorageService? telegram,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _googleDrive = googleDrive ?? GoogleDriveService(),
        _telegram = telegram ?? TelegramStorageService();

  Future<void> authorizeGoogleDrive() async {
    await _googleDrive.authorize();
  }

  String bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';
      case 'audio':
        return 'Lecture audios';
      case 'video':
        return 'lecture videos';
      default:
        throw Exception('Unsupported file type: $type');
    }
  }

  Future<List<ContentLecture>> getLectures() async {
    final response = await _supabase
        .from('lectures')
        .select(
          'id, module_id, title, description, display_order, is_published, is_active',
        )
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => ContentLecture.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<LectureFileItem>> getLectureFiles() async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, lecture_id, title, file_type, file_url, display_order, is_active, created_at, updated_at, storage_provider, telegram_chat_id, telegram_message_id, telegram_file_id, telegram_file_unique_id, file_size',
        )
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => LectureFileItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<LectureFileItem>> getFilesForLecture(String lectureId) async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, lecture_id, title, file_type, file_url, display_order, is_active, created_at, updated_at, storage_provider, telegram_chat_id, telegram_message_id, telegram_file_id, telegram_file_unique_id, file_size',
        )
        .eq('lecture_id', lectureId)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => LectureFileItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<String> createFileUrl(LectureFileItem file) async {
    if (file.storageProvider == 'telegram' || file.telegramFileId?.isNotEmpty == true || file.fileUrl.startsWith('telegram:')) {
      final fileId = file.telegramFileId ?? _telegramFileIdFromUrl(file.fileUrl);
      return _telegram.buildProxyUrl(fileId);
    }

    if (_isGoogleDriveFile(file.fileUrl)) {
      final fileId = _googleDriveFileId(file.fileUrl);
      if (fileId.isEmpty) {
        throw Exception('Invalid Google Drive file ID for: ${file.title}');
      }
      return 'https://drive.google.com/file/d/$fileId/view';
    }

    final bucket = bucketForType(file.fileType);
    final path = _extractStoragePath(file.fileUrl, bucket);

    if (path.isEmpty) {
      throw Exception('Invalid storage path for file: ${file.title}');
    }

    return _supabase.storage.from(bucket).createSignedUrl(path, 3600);
  }

  String _extractStoragePath(String value, String bucket) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexWhere(
      (segment) => Uri.decodeComponent(segment) == bucket,
    );

    if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) return '';

    return segments
        .sublist(bucketIndex + 1)
        .map(Uri.decodeComponent)
        .join('/');
  }

  Future<void> addLectureFile({
    required String lectureId,
    required String title,
    required String fileType,
    required List<int> bytes,
    required String fileName,
    int? displayOrder,
    void Function(double progress)? onProgress,
  }) async {
    final bucket = bucketForType(fileType);
    final safeFileName = _sanitizeFileName(fileName);
    final storagePath =
        '$lectureId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';
    final uploadBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;
      if (token == null || token.isEmpty) {
        throw Exception('Your admin session has expired. Please sign in again.');
      }

      final headers = <String, dynamic>{
        ..._supabase.headers,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
      };

      await Dio().post<void>(
        '${_supabase.storage.url}/$bucket/${Uri.encodeFull(storagePath)}',
        data: uploadBytes,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          if (total > 0) {
            onProgress?.call((sent / total).clamp(0.0, 1.0));
          }
        },
      );

      onProgress?.call(1.0);

      final order = displayOrder ?? await _nextDisplayOrder(lectureId);

      await _supabase.from('lecture_files').insert({
        'lecture_id': lectureId,
        'title': title,
        'file_type': fileType,
        'file_url': storagePath,
        'display_order': order,
        'is_active': true,
      });
    } catch (e) {
      try {
        await _supabase.storage.from(bucket).remove([storagePath]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> addLectureVideo({
    required String lectureId,
    required String title,
    required PlatformFile file,
    int? displayOrder,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _telegram.uploadVideo(
      file: file,
      lectureId: lectureId,
      title: title,
      onProgress: onProgress,
    );

    final order = displayOrder ?? await _nextDisplayOrder(lectureId);

    try {
      await _supabase.from('lecture_files').insert({
        'lecture_id': lectureId,
        'title': title,
        'file_type': 'video',
        'file_url': _telegram.buildFileUrl(result.fileId),
        'display_order': order,
        'is_active': true,
        'storage_provider': 'telegram',
        'telegram_chat_id': result.chatId,
        'telegram_message_id': result.messageId,
        'telegram_file_id': result.fileId,
        'telegram_file_unique_id': result.fileUniqueId,
        'file_size': result.fileSize,
      });
    } catch (e) {
      await _telegram.deleteMessage(result.messageId);
      rethrow;
    }
  }

  Future<void> replaceLectureVideo({
    required LectureFileItem file,
    required PlatformFile newFile,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _telegram.uploadVideo(
      file: newFile,
      lectureId: file.lectureId,
      title: _titleFromFileName(newFile.name),
      onProgress: onProgress,
    );

    final newTitle = _titleFromFileName(newFile.name);

    try {
      await _supabase.from('lecture_files').update({
        'file_url': _telegram.buildFileUrl(result.fileId),
        'title': newTitle,
        'storage_provider': 'telegram',
        'telegram_chat_id': result.chatId,
        'telegram_message_id': result.messageId,
        'telegram_file_id': result.fileId,
        'telegram_file_unique_id': result.fileUniqueId,
        'file_size': result.fileSize,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', file.id);

      final verification = await _supabase
          .from('lecture_files')
          .select('id, file_url, title, telegram_file_id')
          .eq('id', file.id)
          .maybeSingle();

      if (verification == null ||
          verification['telegram_file_id']?.toString() != result.fileId ||
          verification['title']?.toString() != newTitle) {
        throw Exception(
          'The new Telegram video was uploaded, but the lecture record was not updated correctly.',
        );
      }
    } catch (e) {
      await _telegram.deleteMessage(result.messageId);
      rethrow;
    }

    if (file.telegramMessageId != null) {
      await _telegram.deleteMessage(file.telegramMessageId!);
    }
  }

  Future<int> _nextDisplayOrder(String lectureId) async {
    final response = await _supabase
        .from('lecture_files')
        .select('display_order')
        .eq('lecture_id', lectureId)
        .order('display_order', ascending: false)
        .limit(1);

    final rows = response as List;
    if (rows.isNotEmpty) {
      return ((rows.first['display_order'] as num?)?.toInt() ?? 0) + 1;
    }
    return 1;
  }

  Future<void> reorderLectureFiles({
    required List<String> fileIds,
  }) async {
    await Future.wait(
      List.generate(
        fileIds.length,
        (index) => _supabase
            .from('lecture_files')
            .update({'display_order': index + 1})
            .eq('id', fileIds[index]),
      ),
    );
  }

  /// Replaces the storage object and the displayed title behind an existing
  /// lecture_files row.
  ///
  /// The order is intentionally:
  ///   1. Upload the new object.
  ///   2. Switch the DB row to the new object and its filename-derived title.
  ///   3. Verify the DB row actually contains both new values.
  ///   4. Only then delete the old object.
  Future<void> replaceLectureFile({
    required LectureFileItem file,
    required List<int> bytes,
    required String newFileName,
  }) async {
    final bucket = bucketForType(file.fileType);
    final oldPath = _extractStoragePath(file.fileUrl, bucket);
    final safeFileName = _sanitizeFileName(newFileName);
    final newPath =
        '${file.lectureId}/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';
    final newTitle = _titleFromFileName(newFileName);
    final uploadBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    await _supabase.storage.from(bucket).uploadBinary(
      newPath,
      uploadBytes,
      fileOptions: const FileOptions(upsert: false),
    );

    try {
      await _supabase
          .from('lecture_files')
          .update({
            'file_url': newPath,
            'title': newTitle,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', file.id);

      final verification = await _supabase
          .from('lecture_files')
          .select('id, file_url, title')
          .eq('id', file.id)
          .maybeSingle();

      if (verification == null) {
        throw Exception(
          'The lecture file record could not be found after replacement.',
        );
      }

      final savedPath = verification['file_url']?.toString();
      final savedTitle = verification['title']?.toString();

      if (savedPath != newPath || savedTitle != newTitle) {
        throw Exception(
          'The replacement was uploaded, but the lecture file record was not updated correctly.',
        );
      }
    } catch (e) {
      try {
        await _supabase.storage.from(bucket).remove([newPath]);
      } catch (_) {}
      rethrow;
    }

    if (oldPath.isNotEmpty && oldPath != newPath) {
      try {
        await _supabase.storage.from(bucket).remove([oldPath]);
      } catch (_) {}
    }
  }

  Future<void> updateFileTitle({
    required String id,
    required String title,
  }) async {
    await _supabase.from('lecture_files').update({'title': title}).eq('id', id);
  }

  Future<void> setFileActive({
    required String id,
    required bool value,
  }) async {
    await _supabase
        .from('lecture_files')
        .update({'is_active': value})
        .eq('id', id);
  }

  Future<void> deleteLectureFile({required LectureFileItem file}) async {
    if (file.storageProvider == 'telegram' || file.telegramMessageId != null || file.fileUrl.startsWith('telegram:')) {
      if (file.telegramMessageId != null) {
        await _telegram.deleteMessage(file.telegramMessageId!);
      }
      await _supabase.from('lecture_files').delete().eq('id', file.id);
      return;
    }

    if (_isGoogleDriveFile(file.fileUrl)) {
      final fileId = _googleDriveFileId(file.fileUrl);
      if (fileId.isNotEmpty) {
        await _googleDrive.deleteFile(fileId);
      }
      await _supabase.from('lecture_files').delete().eq('id', file.id);
      return;
    }

    final bucket = bucketForType(file.fileType);
    final path = _extractStoragePath(file.fileUrl, bucket);

    if (path.isNotEmpty) {
      await _supabase.storage.from(bucket).remove([path]);
    }

    await _supabase.from('lecture_files').delete().eq('id', file.id);
  }

  bool _isGoogleDriveFile(String value) {
    return value.trim().toLowerCase().startsWith('gdrive:');
  }

  String _telegramFileIdFromUrl(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('telegram:')) return '';
    return trimmed.substring('telegram:'.length).trim();
  }

  String _telegramFileIdFromUrl(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('telegram:')) return '';
    return trimmed.substring('telegram:'.length).trim();
  }

  String _googleDriveFileId(String value) {
    if (!_isGoogleDriveFile(value)) return '';
    return value.trim().substring('gdrive:'.length).trim();
  }

  String _titleFromFileName(String fileName) {
    final name = fileName.trim();
    if (name.isEmpty) return 'file';
    return name.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}
