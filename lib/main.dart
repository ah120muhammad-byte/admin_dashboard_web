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

class AdminApp extends StatefulWidget {
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
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late String _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.settings.themeMode;
  }

  Future<void> _setThemeMode(String mode) async {
    if (mode != 'light' && mode != 'dark') return;

    setState(() {
      _themeMode = mode;
    });

    if (!widget.isAdmin || widget.settings.id.isEmpty) return;

    try {
      await AdminSettingsService().updateAdminSettings(
        id: widget.settings.id,
        themeMode: mode,
        sidebarCompact: widget.settings.sidebarCompact,
        analyticsEnabled: widget.settings.analyticsEnabled,
      );
    } catch (e) {
      debugPrint('Unable to save theme mode: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = switch (_themeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    final settings = AdminSettings(
      id: widget.settings.id,
      themeMode: _themeMode,
      sidebarCompact: widget.settings.sidebarCompact,
      analyticsEnabled: widget.settings.analyticsEnabled,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediData Admin',
      theme: AdminTheme.lightTheme,
      darkTheme: AdminTheme.darkTheme,
      themeMode: mode,
      home: widget.isAdmin
          ? AdminShell(
              settings: settings,
              onThemeModeChanged: _setThemeMode,
            )
          : const AdminLoginScreen(),
    );
  }
}
