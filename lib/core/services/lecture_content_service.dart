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

  factory ContentLecture.fromMap(
    Map<String, dynamic> map,
  ) {
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

  factory LectureFileItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return LectureFileItem(
      id: map['id'] as String,
      lectureId: map['lecture_id'] as String,
      title: map['title'] as String? ?? '',
      fileType: map['file_type'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? '',
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(
              map['created_at'].toString(),
            )
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(
              map['updated_at'].toString(),
            )
          : null,
    );
  }
}

class LectureContentService {
  final SupabaseClient _supabase;

  LectureContentService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ?? Supabase.instance.client;

  // ==========================================================================
  // BUCKET
  // ==========================================================================

  String bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';

      case 'audio':
        return 'Lecture audios';

      case 'video':
        return 'lecture videos';

      default:
        throw Exception(
          'Unsupported file type: $type',
        );
    }
  }

  // ==========================================================================
  // GET LECTURES
  // ==========================================================================

  Future<List<ContentLecture>> getLectures() async {
    final response = await _supabase
        .from('lectures')
        .select(
          'id, module_id, title, '
          'description, display_order, '
          'is_published, is_active',
        )
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => ContentLecture.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // GET ALL FILES
  // ==========================================================================

  Future<List<LectureFileItem>> getLectureFiles() async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, lecture_id, title, file_type, '
          'file_url, display_order, is_active, '
          'created_at, updated_at',
        )
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => LectureFileItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // GET FILES FOR ONE LECTURE
  // ==========================================================================

  Future<List<LectureFileItem>> getFilesForLecture(
    String lectureId,
  ) async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, lecture_id, title, file_type, '
          'file_url, display_order, is_active, '
          'created_at, updated_at',
        )
        .eq(
          'lecture_id',
          lectureId,
        )
        .eq(
          'is_active',
          true,
        )
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => LectureFileItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // CREATE SIGNED URL
  // ==========================================================================

  Future<String> createFileUrl(
    LectureFileItem file,
  ) async {
    final bucket = bucketForType(
      file.fileType,
    );

    final path = _extractStoragePath(
      file.fileUrl,
      bucket,
    );

    if (path.isEmpty) {
      throw Exception(
        'Invalid storage path for file: ${file.title}',
      );
    }

    return _supabase.storage
        .from(bucket)
        .createSignedUrl(
          path,
          3600,
        );
  }

  // ==========================================================================
  // EXTRACT STORAGE PATH
  // ==========================================================================

  String _extractStoragePath(
    String value,
    String bucket,
  ) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    // New format:
    //
    // lectureId/file.pdf
    //
    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Old URL format:
    //
    // https://xxx.supabase.co/storage/v1/object/public/Bucket/file.pdf

    final uri = Uri.tryParse(trimmed);

    if (uri == null) {
      return trimmed;
    }

    final segments = uri.pathSegments;

    final bucketIndex = segments.indexWhere(
      (segment) =>
          Uri.decodeComponent(segment) == bucket,
    );

    if (bucketIndex == -1) {
      throw Exception(
        'Bucket "$bucket" was not found in file URL.',
      );
    }

    if (bucketIndex + 1 >= segments.length) {
      return '';
    }

    final pathSegments = segments.sublist(
      bucketIndex + 1,
    );

    return pathSegments
        .map(Uri.decodeComponent)
        .join('/');
  }

  // ==========================================================================
  // DELETE FILE
  // ==========================================================================

  Future<void> deleteLectureFile({
    required LectureFileItem file,
  }) async {
    final bucket = bucketForType(
      file.fileType,
    );

    final path = _extractStoragePath(
      file.fileUrl,
      bucket,
    );

    try {
      if (path.isNotEmpty) {
        await _supabase.storage
            .from(bucket)
            .remove([path]);
      }
    } finally {
      await _supabase
          .from('lecture_files')
          .delete()
          .eq(
            'id',
            file.id,
          );
    }
  }

  // ==========================================================================
  // ACTIVE / INACTIVE
  // ==========================================================================

  Future<void> setFileActive({
    required String id,
    required bool value,
  }) async {
    await _supabase
        .from('lecture_files')
        .update({
          'is_active': value,
        })
        .eq(
          'id',
          id,
        );
  }

  // ==========================================================================
  // UPDATE TITLE
  // ==========================================================================

  Future<void> updateFileTitle({
    required String id,
    required String title,
  }) async {
    await _supabase
        .from('lecture_files')
        .update({
          'title': title,
        })
        .eq(
          'id',
          id,
        );
  }
}