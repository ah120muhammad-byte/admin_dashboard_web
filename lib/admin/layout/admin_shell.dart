import 'package:admin_dashboard_web/admin/screens/exams/exam_attempts_screen.dart';
import 'package:admin_dashboard_web/admin/screens/exams/exams_management_screen.dart';
import 'package:admin_dashboard_web/admin/screens/exams/student_exam_performance_screen.dart';
import 'package:admin_dashboard_web/admin/screens/files/module_files_picker_screen.dart';
import 'package:admin_dashboard_web/admin/screens/notifications/notification_management_screen_v2.dart';
import 'package:admin_dashboard_web/admin/screens/settings/settings_screen_v2.dart';
import 'package:admin_dashboard_web/admin/screens/lectures/module_content_picker_screen.dart';
import 'package:admin_dashboard_web/admin/screens/content/content_deletion_screen.dart';
import 'package:admin_dashboard_web/admin/screens/support/support_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../admin/screens/dashboard/dashboard_screen.dart';
import 'package:admin_dashboard_web/admin/screens/levels/academic_levels_screen.dart';
import '../../admin/screens/modules/modules_screen.dart';
import '../screens/admin_login_screen.dart';
import '../screens/users/users_analytics_dashboard.dart';
import '../../core/services/admin_settings_service.dart';
import 'admin_sidebar.dart';
import 'admin_top_bar.dart';
import 'admin_theme.dart';

class AdminShell extends StatefulWidget {
  final AdminSettings settings;
  final ValueChanged<String>? onThemeModeChanged;

  const AdminShell({
    super.key,
    this.settings = const AdminSettings(
      id: '',
      themeMode: 'system',
      sidebarCompact: false,
      analyticsEnabled: true,
    ),
    this.onThemeModeChanged,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  late String _themeMode;

  final List<Widget> _pages = const [
    DashboardScreen(),
    UsersAnalyticsDashboard(),
    AcademicLevelsScreen(),
    ModulesScreen(),
    ModuleContentPickerScreen(),
    ModuleFilesPickerScreen(),
    NotificationManagementScreenV2(),
    SettingsScreenV2(),
    ExamsManagementScreen(),
    ExamAttemptsScreen(),
    StudentExamPerformanceScreen(),
    ContentDeletionScreen(),
    SupportInboxScreen(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Users',
    'Academic Levels',
    'Modules',
    'Lectures & Content',
    'Files / Downloads',
    'Notifications',
    'Settings',
    'Exams',
    'Exam Attempts',
    'Student Performance',
    'Content Cleanup',
    'Support Inbox',
  ];

  @override
  void initState() {
    super.initState();
    _themeMode = widget.settings.themeMode;
  }

  ThemeData _currentTheme(BuildContext context) {
    return _themeMode == 'dark' ? AdminTheme.darkTheme : AdminTheme.lightTheme;
  }

  void _setThemeMode(String mode) {
    if (mode != 'light' && mode != 'dark' && mode != 'system') return;
    if (_themeMode == mode) return;

    setState(() => _themeMode = mode);
    widget.onThemeModeChanged?.call(mode);

    final id = widget.settings.id;
    if (id.isEmpty) return;

    AdminSettingsService().updateAdminSettings(
      id: id,
      themeMode: mode,
      sidebarCompact: widget.settings.sidebarCompact,
      analyticsEnabled: widget.settings.analyticsEnabled,
    ).catchError((_) {});
  }

  void _toggleTheme() {
    final isDark = _themeMode == 'dark' ||
        (_themeMode == 'system' && Theme.of(context).brightness == Brightness.dark);
    _setThemeMode(isDark ? 'light' : 'dark');
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSettings = AdminSettings(
      id: widget.settings.id,
      themeMode: _themeMode,
      sidebarCompact: widget.settings.sidebarCompact,
      analyticsEnabled: widget.settings.analyticsEnabled,
    );

    final inheritedBrightness = Theme.of(context).brightness;
    final isDark = _themeMode == 'dark' ||
        (_themeMode == 'system' && inheritedBrightness == Brightness.dark);

    return Theme(
      data: _themeMode == 'system' ? Theme.of(context) : _currentTheme(context),
      child: Scaffold(
        body: Row(
          children: [
            AdminSidebar(
              selectedIndex: _selectedIndex,
              compact: effectiveSettings.sidebarCompact,
              analyticsEnabled: effectiveSettings.analyticsEnabled,
              onItemSelected: (index) => setState(() => _selectedIndex = index),
              onLogout: _logout,
            ),
            Expanded(
              child: Column(
                children: [
                  AdminTopBar(
                    title: _titles[_selectedIndex],
                    isDark: isDark,
                    onThemeToggle: _toggleTheme,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages.map((page) {
                        if (page is SettingsScreenV2) {
                          return SettingsScreenV2(
                            onThemeModeChanged: _setThemeMode,
                          );
                        }
                        return page;
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
