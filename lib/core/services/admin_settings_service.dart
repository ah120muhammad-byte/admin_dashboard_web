import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettings {
  final String id;
  final String themeMode;
  final bool sidebarCompact;
  final bool analyticsEnabled;

  const AdminSettings({
    required this.id,
    required this.themeMode,
    required this.sidebarCompact,
    required this.analyticsEnabled,
  });

  factory AdminSettings.fromMap(Map<String, dynamic> map) {
    return AdminSettings(
      id: map['id']?.toString() ?? '',
      themeMode: map['theme_mode']?.toString() ?? 'system',
      sidebarCompact: map['sidebar_compact'] as bool? ?? false,
      analyticsEnabled: map['analytics_enabled'] as bool? ?? true,
    );
  }
}

class StudentAppSettings {
  final String id;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool allowRegistration;
  final bool notificationsEnabled;
  final String homeAnnouncement;
  final String minimumSupportedVersion;
  final bool forceUpdate;
  final String supportEmail;
  final String appName;
  final String appVersion;

  const StudentAppSettings({
    required this.id,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.allowRegistration,
    required this.notificationsEnabled,
    required this.homeAnnouncement,
    required this.minimumSupportedVersion,
    required this.forceUpdate,
    required this.supportEmail,
    required this.appName,
    required this.appVersion,
  });

  factory StudentAppSettings.fromMap(Map<String, dynamic> map) {
    return StudentAppSettings(
      id: map['id']?.toString() ?? '',
      maintenanceMode: map['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: map['maintenance_message']?.toString() ?? '',
      allowRegistration: map['allow_registration'] as bool? ?? true,
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      homeAnnouncement: map['home_announcement']?.toString() ?? '',
      minimumSupportedVersion:
          map['minimum_supported_version']?.toString() ?? '1.0.0',
      forceUpdate: map['force_update'] as bool? ?? false,
      supportEmail: map['support_email']?.toString() ?? '',
      appName: map['app_name']?.toString() ?? 'MediData',
      appVersion: map['app_version']?.toString() ?? '1.0.0',
    );
  }
}

class AdminSettingsService {
  AdminSettingsService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<AdminSettings> getAdminSettings() async {
    final response = await _supabase
        .from('admin_settings')
        .select('id,theme_mode,sidebar_compact,analytics_enabled')
        .limit(1)
        .single();
    return AdminSettings.fromMap(Map<String, dynamic>.from(response));
  }

  Future<StudentAppSettings> getStudentSettings() async {
    final response = await _supabase
        .from('student_app_settings')
        .select(
          'id,maintenance_mode,maintenance_message,allow_registration,'
          'notifications_enabled,home_announcement,minimum_supported_version,'
          'force_update,support_email,app_name,app_version',
        )
        .limit(1)
        .single();
    return StudentAppSettings.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> updateAdminSettings({
    required String id,
    required String themeMode,
    required bool sidebarCompact,
    required bool analyticsEnabled,
  }) async {
    await _supabase
        .from('admin_settings')
        .update({
          'theme_mode': themeMode,
          'sidebar_compact': sidebarCompact,
          'analytics_enabled': analyticsEnabled,
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': _supabase.auth.currentUser?.id,
        })
        .eq('id', id);
  }

  Future<void> updateStudentSettings({
    required String id,
    required bool maintenanceMode,
    required String maintenanceMessage,
    required bool allowRegistration,
    required bool notificationsEnabled,
    required String homeAnnouncement,
    required String minimumSupportedVersion,
    required bool forceUpdate,
    required String supportEmail,
    required String appName,
    required String appVersion,
  }) async {
    await _supabase
        .from('student_app_settings')
        .update({
          'maintenance_mode': maintenanceMode,
          'maintenance_message': maintenanceMessage,
          'allow_registration': allowRegistration,
          'notifications_enabled': notificationsEnabled,
          'home_announcement': homeAnnouncement,
          'minimum_supported_version': minimumSupportedVersion,
          'force_update': forceUpdate,
          'support_email': supportEmail,
          'app_name': appName,
          'app_version': appVersion,
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': _supabase.auth.currentUser?.id,
        })
        .eq('id', id);
  }
}
