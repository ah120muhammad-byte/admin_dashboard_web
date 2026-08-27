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

  LecturesService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  // ==========================================================================
  // GET LECTURES
  // ==========================================================================

  Future<List<AdminLecture>> getLectures() async {
    final response = await _supabase
        .from('lectures')
        .select(
          'id, module_id, title, description, '
          'pdf_path, audio_path, video_path, '
          'display_order, is_published, is_active, '
          'created_at, updated_at, published_at',
        )
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => AdminLecture.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // GET MODULES
  // ==========================================================================

  Future<List<LectureModule>> getModules() async {
    final response = await _supabase
        .from('modules')
        .select('id, name')
        .eq('is_active', true)
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => LectureModule.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // CREATE LECTURE
  // ==========================================================================

  Future<String> createLecture({
    required String moduleId,
    required String title,
    String? description,
    required int displayOrder,
  }) async {
    final response = await _supabase
        .from('lectures')
        .insert({
          'module_id': moduleId,
          'title': title,
          'description': description,
          'display_order': displayOrder,
          'is_published': false,
          'is_active': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  // ==========================================================================
  // ADD LECTURE CONTENT
  // ==========================================================================

  Future<void> addLectureContent({
    required String lectureId,
    required LectureContentInput content,
  }) async {
    final bucket = _bucketForType(content.fileType);

    final safeFileName = _sanitizeFileName(
      content.fileName,
    );

    final storagePath =
        '$lectureId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    try {
      // Upload to PRIVATE bucket.
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            content.bytes,
            fileOptions: const FileOptions(
              upsert: false,
            ),
          );

      // IMPORTANT:
      // Do NOT use getPublicUrl().
      //
      // Save only the storage path.
      await _supabase.from('lecture_files').insert({
        'lecture_id': lectureId,
        'title': content.title,
        'file_type': content.fileType,
        'file_url': storagePath,
        'display_order': content.displayOrder,
        'is_active': true,
      });
    } catch (e) {
      // If DB insert fails, remove uploaded file.
      try {
        await _supabase.storage
            .from(bucket)
            .remove([storagePath]);
      } catch (_) {}

      rethrow;
    }
  }

  // ==========================================================================
  // BUCKET
  // ==========================================================================

  String _bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';

      case 'audio':
        return 'Lecture audios';

      case 'video':
        return 'lecture videos';

      default:
        throw Exception(
          'Unsupported lecture file type: $type',
        );
    }
  }

  // ==========================================================================
  // SANITIZE FILE NAME
  // ==========================================================================

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
  }

  // ==========================================================================
  // UPDATE LECTURE
  // ==========================================================================

  Future<void> updateLecture({
    required String id,
    required String moduleId,
    required String title,
    String? description,
    required int displayOrder,
  }) async {
    await _supabase
        .from('lectures')
        .update({
          'module_id': moduleId,
          'title': title,
          'description': description,
          'display_order': displayOrder,
        })
        .eq('id', id);
  }

  // ==========================================================================
  // ACTIVE
  // ==========================================================================

  Future<void> setActive({
    required String id,
    required bool value,
  }) async {
    await _supabase
        .from('lectures')
        .update({
          'is_active': value,
        })
        .eq('id', id);
  }

  // ==========================================================================
  // PUBLISHED
  // ==========================================================================

  Future<void> setPublished({
    required String id,
    required bool value,
  }) async {
    await _supabase
        .from('lectures')
        .update({
          'is_published': value,
          'published_at':
              value ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', id);
  }
}