import 'package:flutter/material.dart';
import 'admin_theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;
  final bool compact;
  final bool analyticsEnabled;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    this.compact = false,
    this.analyticsEnabled = true,
  });

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
    _SidebarItem(title: 'Student Performance', icon: Icons.insights_outlined),
    _SidebarItem(title: 'Content Cleanup', icon: Icons.delete_sweep_outlined),
    _SidebarItem(title: 'Support Inbox', icon: Icons.mark_email_unread_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = <Widget>[];

    if (!compact) {
      items.addAll([
        const _SectionLabel('OVERVIEW'),
        _item(context, 0),
        const _SectionGap(),
        const _SectionLabel('CONTENT'),
        _item(context, 2),
        _item(context, 3),
        _item(context, 4),
        _item(context, 5),
        const _SectionGap(),
        const _SectionLabel('USER MANAGEMENT'),
        _item(context, 1),
        _item(context, 6),
        const _SectionGap(),
        const _SectionLabel('ASSESSMENT'),
        _item(context, 8),
        _item(context, 9),
        if (analyticsEnabled) _item(context, 10),
        const _SectionGap(),
        const _SectionLabel('SYSTEM'),
        _item(context, 7),
        const _SectionGap(),
        const _SectionLabel('MAINTENANCE'),
        _item(context, 11),
        const _SectionGap(),
        const _SectionLabel('SUPPORT'),
        _item(context, 12),
      ]);
    } else {
      const compactOrder = [0, 1, 2, 3, 4, 5, 6, 8, 9, 7, 11, 12];
      for (final index in compactOrder) {
        if (index == 10 && !analyticsEnabled) continue;
        items.add(_item(context, index));
      }
      if (analyticsEnabled) items.insert(8, _item(context, 10));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: compact ? 78 : 250,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor.withValues(alpha: .75))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 20),
              child: compact
                  ? const Icon(Icons.medical_services_rounded, color: AdminTheme.primary, size: 36)
                  : Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AdminTheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.medical_services_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MediData', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('Admin Dashboard', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 0, compact ? 8 : 12, 16),
                children: items,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 10, compact ? 8 : 12, 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: Tooltip(
                  message: 'Logout',
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.logout_rounded),
                    title: compact ? null : const Text('Logout'),
                    onTap: onLogout,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index) {
    final item = _items[index];
    final selected = selectedIndex == index;
    final scheme = Theme.of(context).colorScheme;
    final tile = ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      leading: Icon(item.icon, color: selected ? AdminTheme.primary : scheme.onSurface.withValues(alpha: .62)),
      title: compact
          ? null
          : Text(
              item.title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AdminTheme.primary : scheme.onSurface,
              ),
            ),
      onTap: () => onItemSelected(index),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: compact ? item.title : '',
        child: Material(
          color: selected ? AdminTheme.primary.withValues(alpha: .10) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: tile,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.15,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .45),
          ),
        ),
      );
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 16);
}

class _SidebarItem {
  final String title;
  final IconData icon;
  const _SidebarItem({required this.title, required this.icon});
}
