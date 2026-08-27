import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// ADMIN EXAM
// ============================================================================

class AdminExam {
  final String id;
  final String lectureId;
  final String title;
  final String? description;
  final int durationMinutes;
  final double passingScore;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminExam({
    required this.id,
    required this.lectureId,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.passingScore,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminExam.fromMap(
    Map<String, dynamic> map,
  ) {
    return AdminExam(
      id: map['id'] as String,
      lectureId: map['lecture_id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      durationMinutes:
          (map['duration_minutes'] as num?)?.toInt() ?? 0,
      passingScore:
          (map['passing_score'] as num?)?.toDouble() ?? 0,
      isActive:
          map['is_active'] as bool? ?? true,
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

// ============================================================================
// EXAM LECTURE
// ============================================================================

class ExamLecture {
  final String id;
  final String moduleId;
  final String title;
  final int displayOrder;
  final bool isActive;
  final bool isPublished;

  const ExamLecture({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.displayOrder,
    required this.isActive,
    required this.isPublished,
  });

  factory ExamLecture.fromMap(
    Map<String, dynamic> map,
  ) {
    return ExamLecture(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      title: map['title'] as String? ?? '',
      displayOrder:
          (map['display_order'] as num?)?.toInt() ?? 0,
      isActive:
          map['is_active'] as bool? ?? true,
      isPublished:
          map['is_published'] as bool? ?? false,
    );
  }
}

// ============================================================================
// EXAMS SERVICE
// ============================================================================

class ExamsService {
  final SupabaseClient _supabase;

  ExamsService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ?? Supabase.instance.client;

  // ==========================================================================
  // GET EXAMS
  // ==========================================================================

  Future<List<AdminExam>> getExams() async {
    final response = await _supabase
        .from('exams')
        .select(
          'id, lecture_id, title, description, '
          'duration_minutes, passing_score, '
          'is_active, created_at, updated_at',
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => AdminExam.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // GET LECTURES
  // ==========================================================================

  Future<List<ExamLecture>> getLectures() async {
    final response = await _supabase
        .from('lectures')
        .select(
          'id, module_id, title, display_order, '
          'is_active, is_published',
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
          (item) => ExamLecture.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // CREATE EXAM
  // ==========================================================================

  Future<String> createExam({
    required String lectureId,
    required String title,
    String? description,
    required int durationMinutes,
    required double passingScore,
  }) async {
    final response = await _supabase
        .from('exams')
        .insert({
          'lecture_id': lectureId,
          'title': title,
          'description': description,
          'duration_minutes': durationMinutes,
          'passing_score': passingScore,
          'is_active': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  // ==========================================================================
  // UPDATE EXAM
  // ==========================================================================

  Future<void> updateExam({
    required String id,
    required String lectureId,
    required String title,
    String? description,
    required int durationMinutes,
    required double passingScore,
  }) async {
    await _supabase
        .from('exams')
        .update({
          'lecture_id': lectureId,
          'title': title,
          'description': description,
          'duration_minutes': durationMinutes,
          'passing_score': passingScore,
        })
        .eq(
          'id',
          id,
        );
  }

  // ==========================================================================
  // ACTIVE / INACTIVE
  // ==========================================================================

  Future<void> setActive({
    required String id,
    required bool value,
  }) async {
    await _supabase
        .from('exams')
        .update({
          'is_active': value,
        })
        .eq(
          'id',
          id,
        );
  }
}