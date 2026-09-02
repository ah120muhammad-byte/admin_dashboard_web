import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_dashboard_web/admin/layout/admin_shell.dart';
import 'package:admin_dashboard_web/admin/layout/admin_theme.dart';
import 'package:admin_dashboard_web/admin/screens/admin_login_screen.dart';
import 'package:admin_dashboard_web/core/services/admin_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
    publishableKey: 'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
  );

  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  bool isAdmin = false;

  if (session != null) {
    try {
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();
      isAdmin = profile?['role']?.toString().toLowerCase().trim() == 'admin';
    } catch (_) {
      isAdmin = false;
    }
  }

  AdminSettings settings = const AdminSettings(
    id: '',
    themeMode: 'system',
    sidebarCompact: false,
    analyticsEnabled: true,
  );

  if (isAdmin) {
    try {
      settings = await AdminSettingsService().getAdminSettings();
    } catch (_) {}
  }

  runApp(AdminApp(isAdmin: isAdmin, settings: settings));
}

class AdminApp extends StatelessWidget {
  final bool isAdmin;
  final AdminSettings settings;

  const AdminApp({
    super.key,
    required this.isAdmin,
    this.settings = const AdminSettings(
      id: '',
      themeMode: 'system',
      sidebarCompact: false,
      analyticsEnabled: true,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final mode = switch (settings.themeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediData Admin',
      theme: AdminTheme.lightTheme,
      darkTheme: AdminTheme.darkTheme,
      themeMode: mode,
      home: isAdmin ? AdminShell(settings: settings) : const AdminLoginScreen(),
    );
  }
}
