import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLecture {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final int displayOrder;
  final bool isPublished;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  const AdminLecture({
    required this.id,
    required this.moduleId,
    required this.title,
    this.description,
    required this.displayOrder,
    required this.isPublished,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  factory AdminLecture.fromMap(Map<String, dynamic> map) {
    return AdminLecture(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isPublished: map['is_published'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      publishedAt: map['published_at'] != null
          ? DateTime.tryParse(map['published_at'].toString())
          : null,
    );
  }
}

class LectureModule {
  final String id;
  final String name;

  const LectureModule({
    required this.id,
    required this.name,
  });

  factory LectureModule.fromMap(Map<String, dynamic> map) {
    return LectureModule(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
    );
  }
}

class LectureContentInput {
  final String title;
  final String fileType;
  final Uint8List bytes;
  final String fileName;
  final int displayOrder;

  const LectureContentInput({
    required this.title,
    required this.fileType,
    required this.bytes,
    required this.fileName,
    required this.displayOrder,
  });
}

class LecturesService {
  final SupabaseClient _supabase;

  LecturesService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminLecture>> getLectures() async {
    final response = await _supabase.from('lectures').select(
          'id, module_id, title, description, display_order, is_published, '
          'is_active, created_at, updated_at, published_at',
        ).order('display_order', ascending: true);

    return (response as List)
        .map((item) => AdminLecture.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<LectureModule>> getModules() async {
    final response = await _supabase
        .from('modules')
        .select('id, name')
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => LectureModule.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<String> createLecture({
    required String moduleId,
    required String title,
    String? description,
    required int displayOrder,
  }) async {
    final response = await _supabase.from('lectures').insert({
      'module_id': moduleId,
      'title': title,
      'description': description,
      'display_order': displayOrder,
      'is_published': false,
      'is_active': true,
    }).select('id').single();

    final lectureId = response['id'] as String;

    try {
      await _supabase.functions.invoke(
        'send-broadcast-notification',
        body: {
          'title': 'New Lecture Available',
          'body': 'A new lecture "$title" is now available.',
          'type': 'new_lecture',
          'lectureId': lectureId,
        },
      );
    } catch (_) {}

    return lectureId;
  }

  Future<void> addLectureContent({
    required String lectureId,
    required LectureContentInput content,
  }) async {
    await addLectureFile(
      lectureId: lectureId,
      title: content.title,
      fileType: content.fileType,
      bytes: content.bytes,
      fileName: content.fileName,
      displayOrder: content.displayOrder,
    );
  }

  Future<void> addLectureFile({
    required String lectureId,
    required String title,
    required String fileType,
    required Uint8List bytes,
    required String fileName,
    int? displayOrder,
  }) async {
    final bucket = _bucketForType(fileType);
    final safeFileName = _sanitizeFileName(fileName);
    final storagePath =
        '$lectureId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    try {
      await _supabase.storage.from(bucket).uploadBinary(
        storagePath,
        bytes,
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

    if (response.isNotEmpty) {
      return ((response.first['display_order'] as num?)?.toInt() ?? 0) + 1;
    }
    return 1;
  }

  Future<void> reorderLectures({
    required List<String> lectureIds,
  }) async {
    await Future.wait(
      List.generate(
        lectureIds.length,
        (index) => _supabase
            .from('lectures')
            .update({'display_order': index + 1})
            .eq('id', lectureIds[index]),
      ),
    );
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

  Future<void> replaceLectureFile({
    required String lectureFileId,
    required String lectureId,
    required String fileType,
    required List<int> bytes,
    required String newFileName,
    required String oldFileUrl,
  }) async {
    final bucket = _bucketForType(fileType);
    final oldPath = _extractStoragePath(oldFileUrl, bucket);
    final safeFileName = _sanitizeFileName(newFileName);
    final newPath =
        '$lectureId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';
    final newBytes = Uint8List.fromList(bytes);

    await _supabase.storage.from(bucket).uploadBinary(
      newPath,
      newBytes,
      fileOptions: const FileOptions(upsert: false),
    );

    try {
      await _supabase
          .from('lecture_files')
          .update({'file_url': newPath})
          .eq('id', lectureFileId);
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

  Future<void> updateLecture({
    required String id,
    required String moduleId,
    required String title,
    String? description,
    required int displayOrder,
  }) async {
    await _supabase.from('lectures').update({
      'module_id': moduleId,
      'title': title,
      'description': description,
      'display_order': displayOrder,
    }).eq('id', id);
  }

  Future<void> setActive({
    required String id,
    required bool value,
  }) async {
    await _supabase.from('lectures').update({'is_active': value}).eq('id', id);
  }

  Future<void> setPublished({
    required String id,
    required bool value,
  }) async {
    await _supabase.from('lectures').update({
      'is_published': value,
      'published_at': value ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  Future<void> deleteLecture(String id) async {
    final files = await _supabase
        .from('lecture_files')
        .select('file_type, file_url')
        .eq('lecture_id', id);

    final grouped = <String, List<String>>{};
    for (final raw in files as List) {
      final type = raw['file_type'] as String? ?? '';
      final url = raw['file_url'] as String? ?? '';
      if (type.isEmpty || url.isEmpty) continue;
      final bucket = _bucketForType(type);
      final path = _extractStoragePath(url, bucket);
      if (path.isNotEmpty) {
        grouped.putIfAbsent(bucket, () => <String>[]).add(path);
      }
    }

    for (final entry in grouped.entries) {
      try {
        await _supabase.storage.from(entry.key).remove(entry.value);
      } catch (_) {}
    }

    await _supabase.from('lectures').delete().eq('id', id);
  }

  String _bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';
      case 'audio':
        return 'Lecture audios';
      case 'video':
        return 'lecture videos';
      default:
        throw Exception('Unsupported lecture file type: $type');
    }
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

    return segments.sublist(bucketIndex + 1).map(Uri.decodeComponent).join('/');
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}
