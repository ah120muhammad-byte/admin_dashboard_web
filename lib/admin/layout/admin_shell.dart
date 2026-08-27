import 'package:admin_dashboard_web/admin/screens/files/lecture_content_screen.dart';
import 'package:admin_dashboard_web/admin/screens/lectures/lectures_screen.dart';
import 'package:admin_dashboard_web/admin/screens/notifications/notifications_screen.dart';
import 'package:admin_dashboard_web/admin/screens/settings/settings_screen.dart';
import 'package:admin_dashboard_web/admin/screens/users/users_screen.dart';
import 'package:flutter/material.dart';
import '../../admin/screens/dashboard/dashboard_screen.dart';
import 'package:admin_dashboard_web/admin/screens/levels/academic_levels_screen.dart';
import '../../admin/screens/modules/modules_screen.dart';
import '../screens/exams/exams_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    UsersManagementScreen(),
    AcademicLevelsScreen(),
    ModulesScreen(),
    LecturesScreen(),
    LectureContentScreen(),
    NotificationsScreen(),
    SettingsScreen(),
    ExamsScreen(),
  ];

  final List<_SidebarItem> _items = const [
    _SidebarItem(title: 'Dashboard', icon: Icons.dashboard_rounded),
    _SidebarItem(title: 'Users', icon: Icons.people_alt_rounded),
    _SidebarItem(title: 'Academic Levels', icon: Icons.school_rounded),
    _SidebarItem(title: 'Modules', icon: Icons.menu_book_rounded),
    _SidebarItem(title: 'Lectures', icon: Icons.play_circle_fill_rounded),
    _SidebarItem(title: 'Files', icon: Icons.folder_rounded),
    _SidebarItem(title: 'Notifications', icon: Icons.notifications_rounded),
    _SidebarItem(title: 'Settings', icon: Icons.settings_rounded),
    _SidebarItem(title: 'Exams', icon: Icons.question_mark_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // ============================================================
            // BRAND
            // ============================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MediData',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Admin Dashboard',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ============================================================
            // NAVIGATION
            // ============================================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final selected = _selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        item.icon,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            // ============================================================
            // FOOTER
            // ============================================================
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'MediData Admin',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem {
  final String title;
  final IconData icon;

  const _SidebarItem({required this.title, required this.icon});
}

