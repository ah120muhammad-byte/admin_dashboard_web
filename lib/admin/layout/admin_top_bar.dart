import 'package:flutter/material.dart';

class AdminTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isDark;
  final VoidCallback? onThemeToggle;

  const AdminTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.isDark = false,
    this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            onPressed: onThemeToggle,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
