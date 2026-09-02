import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/admin_users_service.dart';
import 'user_personal_analytics.dart';

class UsersAnalyticsDashboard extends StatefulWidget {
  const UsersAnalyticsDashboard({super.key});

  @override
  State<UsersAnalyticsDashboard> createState() => _UsersAnalyticsDashboardState();
}

class _UsersAnalyticsDashboardState extends State<UsersAnalyticsDashboard> {
  final AdminUsersService _service = AdminUsersService();
  final TextEditingController _searchController = TextEditingController();

  late Future<AdminUsersResult> _future;
  AdminUserAnalytics? _selectedUser;
  String _search = '';
  String _status = 'All';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminUsersResult> _load() async {
    final result = await _service.getUsers();
    if (!mounted) return result;

    final visible = _filter(result.users);
    if (_selectedUser == null && visible.isNotEmpty) {
      _selectedUser = visible.first;
    } else if (_selectedUser != null) {
      final same = result.users.where((u) => u.id == _selectedUser!.id);
      _selectedUser = same.isEmpty ? (visible.isEmpty ? null : visible.first) : same.first;
    }
    return result;
  }

  List<AdminUserAnalytics> _filter(List<AdminUserAnalytics> users) {
    return users.where((user) {
      final matchesSearch = _search.isEmpty ||
          user.name.toLowerCase().contains(_search) ||
          user.email.toLowerCase().contains(_search);
      final matchesStatus = _status == 'All' ||
          (_status == 'Active' && user.isActive) ||
          (_status == 'Inactive' && !user.isActive);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminUsersResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 12),
                const Text('Unable to load users analytics.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final users = _filter(snapshot.data!.users);
        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildToolbar(context),
                const SizedBox(height: 24),
                const Expanded(child: Center(child: Text('No users found.'))),
              ],
            ),
          );
        }

        final selected = _selectedUser ?? users.first;
        final theme = Theme.of(context);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: _buildToolbar(context),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1050;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: wide ? 320 : 290,
                        child: _buildUsersPanel(context, users, selected),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1250),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSelectedUserHeader(context, selected),
                                const SizedBox(height: 18),
                                UserPersonalAnalytics(user: selected),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 145,
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildUsersPanel(
    BuildContext context,
    List<AdminUserAnalytics> users,
    AdminUserAnalytics selected,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final user = users[index];
          final active = user.id == selected.id;
          return Material(
            color: active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              selected: active,
              selectedTileColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: CircleAvatar(child: Text(_initials(user.name))),
              title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${user.examAttempts} exams • ${user.lecturesOpened} lectures',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                user.isActive ? Icons.circle : Icons.circle_outlined,
                size: 11,
                color: user.isActive ? Colors.green : Colors.grey,
              ),
              onTap: () => setState(() => _selectedUser = user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedUserHeader(BuildContext context, AdminUserAnalytics user) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(radius: 30, child: Text(_initials(user.name))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(user.email, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MiniChip(label: user.isActive ? 'Active' : 'Inactive', icon: Icons.person_outline_rounded),
                      _MiniChip(label: 'Avg ${user.averageScore.toStringAsFixed(1)}%', icon: Icons.analytics_outlined),
                      _MiniChip(label: 'Success ${user.successRate.toStringAsFixed(1)}%', icon: Icons.trending_up_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
