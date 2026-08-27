import 'package:supabase_flutter/supabase_flutter.dart';

class AdminModule {
  final String id;
  final String academicLevelId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminModule({
    required this.id,
    required this.academicLevelId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminModule.fromMap(Map<String, dynamic> map) {
    return AdminModule(
      id: map['id'] as String,
      academicLevelId: map['academic_level_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      displayOrder: (map['display_order'] as num).toInt(),
      isActive: map['is_active'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class AcademicLevelOption {
  final String id;
  final String name;

  const AcademicLevelOption({
    required this.id,
    required this.name,
  });

  factory AcademicLevelOption.fromMap(
    Map<String, dynamic> map,
  ) {
    return AcademicLevelOption(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

class AdminModulesService {
  final SupabaseClient _supabase;

  AdminModulesService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ?? Supabase.instance.client;

  // ============================================================
  // GET MODULES
  // ============================================================

  Future<List<AdminModule>> getModules({
    String? academicLevelId,
    bool activeOnly = false,
  }) async {
    var query = _supabase
        .from('modules')
        .select(
          'id, academic_level_id, name, description, '
          'image_url, display_order, is_active, '
          'created_at, updated_at',
        );

    if (academicLevelId != null &&
        academicLevelId.isNotEmpty) {
      query = query.eq(
        'academic_level_id',
        academicLevelId,
      );
    }

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order(
      'display_order',
      ascending: true,
    );

    return (response as List)
        .map(
          (item) => AdminModule.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET ACADEMIC LEVELS
  // ============================================================

  Future<List<AcademicLevelOption>>
      getAcademicLevels() async {
    final response = await _supabase
        .from('academic_levels')
        .select('id, name')
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => AcademicLevelOption.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // CREATE MODULE
  // ============================================================

  Future<void> createModule({
    required String academicLevelId,
    required String name,
    String? description,
    String? imageUrl,
    required int displayOrder,
    bool isActive = true,
  }) async {
    await _supabase.from('modules').insert({
      'academic_level_id': academicLevelId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'display_order': displayOrder,
      'is_active': isActive,
    });
  }

  // ============================================================
  // UPDATE MODULE
  // ============================================================

  Future<void> updateModule({
    required String id,
    required String academicLevelId,
    required String name,
    String? description,
    String? imageUrl,
    required int displayOrder,
    required bool isActive,
  }) async {
    await _supabase
        .from('modules')
        .update({
          'academic_level_id': academicLevelId,
          'name': name,
          'description': description,
          'image_url': imageUrl,
          'display_order': displayOrder,
          'is_active': isActive,
          'updated_at':
              DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  // ============================================================
  // TOGGLE ACTIVE
  // ============================================================

  Future<void> toggleModuleStatus({
    required String id,
    required bool isActive,
  }) async {
    await _supabase
        .from('modules')
        .update({
          'is_active': isActive,
          'updated_at':
              DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }
}