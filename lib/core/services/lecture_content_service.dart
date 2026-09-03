import 'dart:typed_data';

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
    );
  }
}

class LectureContentService {
  final SupabaseClient _supabase;

  LectureContentService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

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
          'id, lecture_id, title, file_type, file_url, display_order, is_active, created_at, updated_at',
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
          'id, lecture_id, title, file_type, file_url, display_order, is_active, created_at, updated_at',
        )
        .eq('lecture_id', lectureId)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => LectureFileItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<String> createFileUrl(LectureFileItem file) async {
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
  }) async {
    final bucket = bucketForType(fileType);
    final safeFileName = _sanitizeFileName(fileName);
    final storagePath =
        '$lectureId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';
    final uploadBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    try {
      await _supabase.storage.from(bucket).uploadBinary(
        storagePath,
        uploadBytes,
        fileOptions: const FileOptions(upsert: false),
      );

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

    // 1. Upload the replacement first. Never overwrite the old object.
    await _supabase.storage.from(bucket).uploadBinary(
      newPath,
      uploadBytes,
      fileOptions: const FileOptions(upsert: false),
    );

    try {
      // 2. Update both the storage pointer and the displayed file name.
      await _supabase
          .from('lecture_files')
          .update({
            'file_url': newPath,
            'title': newTitle,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', file.id);

      // 3. Verify both values using a normal SELECT.
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
      // The database must remain on the old object if anything above fails.
      try {
        await _supabase.storage.from(bucket).remove([newPath]);
      } catch (_) {}
      rethrow;
    }

    // 4. The DB now points to the new object, so it is safe to remove the old
    // object. Cleanup failure must not undo a successful replacement.
    if (oldPath.isNotEmpty && oldPath != newPath) {
      try {
        await _supabase.storage.from(bucket).remove([oldPath]);
      } catch (_) {
        // Keep the replacement valid even if old-file cleanup fails.
      }
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
    final bucket = bucketForType(file.fileType);
    final path = _extractStoragePath(file.fileUrl, bucket);

    if (path.isNotEmpty) {
      await _supabase.storage.from(bucket).remove([path]);
    }

    await _supabase.from('lecture_files').delete().eq('id', file.id);
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
