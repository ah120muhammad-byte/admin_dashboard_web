import 'package:admin_dashboard_web/admin/screens/exams/exam_attempts_screen.dart';
import 'package:admin_dashboard_web/admin/screens/exams/exams_management_screen.dart';
import 'package:admin_dashboard_web/admin/screens/files/module_files_picker_screen.dart';
import 'package:admin_dashboard_web/admin/screens/notifications/notifications_screen.dart';
import 'package:admin_dashboard_web/admin/screens/settings/settings_screen.dart';
import 'package:admin_dashboard_web/admin/screens/lectures/module_content_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/screens/dashboard/dashboard_screen.dart';
import 'package:admin_dashboard_web/admin/screens/levels/academic_levels_screen.dart';
import '../../admin/screens/modules/modules_screen.dart';
import '../screens/admin_login_screen.dart';
import '../screens/users/users_analytics_dashboard.dart';
import 'admin_sidebar.dart';
import 'admin_top_bar.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    UsersAnalyticsDashboard(),
    AcademicLevelsScreen(),
    ModulesScreen(),
    ModuleContentPickerScreen(),
    ModuleFilesPickerScreen(),
    NotificationsScreen(),
    SettingsScreen(),
    ExamsManagementScreen(),
    ExamAttemptsScreen(),
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
  ];

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Even if sign out fails, do not keep the admin UI on screen.
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
            onLogout: _logout,
          ),
          Expanded(
            child: Column(
              children: [
                AdminTopBar(title: _titles[_selectedIndex]),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
