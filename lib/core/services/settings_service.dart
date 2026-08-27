import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettings {
  final String id;
  final String appName;
  final String appVersion;
  final bool maintenanceMode;
  final bool allowRegistration;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppSettings({
    required this.id,
    required this.appName,
    required this.appVersion,
    required this.maintenanceMode,
    required this.allowRegistration,
    this.createdAt,
    this.updatedAt,
  });

  factory AppSettings.fromMap(
    Map<String, dynamic> map,
  ) {
    return AppSettings(
      id: map['id'] as String,
      appName:
          map['app_name'] as String? ??
              'Data App',
      appVersion:
          map['app_version'] as String? ??
              '1.0.0',
      maintenanceMode:
          map['maintenance_mode']
                  as bool? ??
              false,
      allowRegistration:
          map['allow_registration']
                  as bool? ??
              true,
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(
                  map['created_at'].toString(),
                )
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(
                  map['updated_at'].toString(),
                )
              : null,
    );
  }
}

class SettingsService {
  final SupabaseClient _supabase;

  SettingsService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ??
                Supabase.instance.client;

  // ============================================================
  // GET SETTINGS
  // ============================================================

  Future<AppSettings> getSettings() async {
    final response = await _supabase
        .from('app_settings')
        .select(
          'id, app_name, app_version, '
          'maintenance_mode, allow_registration, '
          'created_at, updated_at',
        )
        .limit(1)
        .single();

    return AppSettings.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // UPDATE SETTINGS
  // ============================================================

  Future<void> updateSettings({
    required String id,
    required String appName,
    required String appVersion,
    required bool maintenanceMode,
    required bool allowRegistration,
  }) async {
    await _supabase
        .from('app_settings')
        .update({
      'app_name': appName,
      'app_version': appVersion,
      'maintenance_mode':
          maintenanceMode,
      'allow_registration':
          allowRegistration,
      'updated_at':
          DateTime.now()
              .toIso8601String(),
    }).eq(
      'id',
      id,
    );
  }
}