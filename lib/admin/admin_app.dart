import 'package:flutter/material.dart';

import '../core/services/admin_settings_service.dart';
import 'layout/admin_shell.dart';
import 'layout/admin_theme.dart';

class AdminApp extends StatefulWidget {
  final AdminSettings settings;

  const AdminApp({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final mode = switch (_themeMode) {
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
      home: AdminShell(
        settings: AdminSettings(
          id: widget.settings.id,
          themeMode: _themeMode,
          sidebarCompact: widget.settings.sidebarCompact,
          analyticsEnabled: widget.settings.analyticsEnabled,
        ),
        onThemeModeChanged: (value) {
          setState(() {
            _themeMode = value;
          });
        },
      ),
    );
  }
}
