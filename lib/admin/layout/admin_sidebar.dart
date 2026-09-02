import 'package:flutter/material.dart';
import 'admin_theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;

  const AdminSidebar({super.key, required this.selectedIndex, required this.onItemSelected, required this.onLogout});

  static const _items = [
    _SidebarItem(title: 'Dashboard', icon: Icons.dashboard_outlined),
    _SidebarItem(title: 'Users', icon: Icons.people_outline),
    _SidebarItem(title: 'Academic Levels', icon: Icons.school_outlined),
    _SidebarItem(title: 'Modules', icon: Icons.menu_book_outlined),
    _SidebarItem(title: 'Lectures', icon: Icons.video_library_outlined),
    _SidebarItem(title: 'Files / Downloads', icon: Icons.folder_outlined),
    _SidebarItem(title: 'Notifications', icon: Icons.notifications_none_outlined),
    _SidebarItem(title: 'Settings', icon: Icons.settings_outlined),
    _SidebarItem(title: 'Exams', icon: Icons.quiz_outlined),
    _SidebarItem(title: 'Exam Attempts', icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 250,
      decoration: BoxDecoration(color: scheme.surface, border: Border(right: BorderSide(color: theme.dividerColor))),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AdminTheme.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.medical_services_rounded, color: Colors.white)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MediData', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('Admin Dashboard', style: TextStyle(fontSize: 11))])),
              ]),
            ),
            const SizedBox(height: 26),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: selected ? scheme.primary.withValues(alpha: 0.10) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    child: ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      leading: Icon(item.icon, color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.62)),
                      title: Text(item.title, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? scheme.primary : scheme.onSurface)),
                      onTap: () => onItemSelected(index),
                    ),
                  ),
                );
              },
            )),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(dense: true, leading: const Icon(Icons.logout_rounded), title: const Text('Logout'), onTap: onLogout),
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
