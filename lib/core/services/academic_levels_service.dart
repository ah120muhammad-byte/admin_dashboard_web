import 'package:supabase_flutter/supabase_flutter.dart';

class AcademicLevel {
  final String id;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final String? imageUrl;

  const AcademicLevel({
    required this.id,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
    this.imageUrl,
  });

  factory AcademicLevel.fromMap(Map<String, dynamic> map) {
    return AcademicLevel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? false,
      imageUrl: map['image_url'] as String?,
    );
  }
}

class AcademicLevelsService {
  final SupabaseClient _supabase;

  AcademicLevelsService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AcademicLevel>> getLevels() async {
    final response = await _supabase
        .from('academic_levels')
        .select(
          'id, name, description, display_order, is_active, image_url',
        )
        .order('display_order', ascending: true);

    return (response as List)
        .map(
          (item) => AcademicLevel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> addLevel({
    required String name,
    String? description,
    required int displayOrder,
    required bool isActive,
    String? imageUrl,
  }) async {
    await _supabase.from('academic_levels').insert({
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      'image_url': imageUrl,
    });
  }

  Future<void> updateLevel({
    required String id,
    required String name,
    String? description,
    required int displayOrder,
    required bool isActive,
    String? imageUrl,
  }) async {
    await _supabase
        .from('academic_levels')
        .update({
          'name': name,
          'description': description,
          'display_order': displayOrder,
          'is_active': isActive,
          'image_url': imageUrl,
        })
        .eq('id', id);
  }

  Future<void> setActive({
    required String id,
    required bool isActive,
  }) async {
    await _supabase
        .from('academic_levels')
        .update({
          'is_active': isActive,
        })
        .eq('id', id);
  }
}