import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const _items = [
    _SidebarItem(title: 'Dashboard', icon: Icons.dashboard_outlined),
    _SidebarItem(title: 'Academic Levels', icon: Icons.school_outlined),
    _SidebarItem(title: 'Modules', icon: Icons.menu_book_outlined),
    _SidebarItem(title: 'Lectures', icon: Icons.video_library_outlined),
    _SidebarItem(title: 'Files / Downloads', icon: Icons.folder_outlined),
    _SidebarItem(title: 'AI Content', icon: Icons.auto_awesome_outlined),
    _SidebarItem(title: 'Users', icon: Icons.people_outline),
    _SidebarItem(title: 'Notifications', icon: Icons.notifications_none_outlined),
    _SidebarItem(title: 'Settings', icon: Icons.settings_outlined),
    _SidebarItem(title: 'Exams', icon: Icons.question_mark_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'MediData',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.10)
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        item.icon,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: 0.60),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurface,
                        ),
                      ),
                      onTap: () => onItemSelected(index),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final String title;
  final IconData icon;

  const _SidebarItem({
    required this.title,
    required this.icon,
  });
}
