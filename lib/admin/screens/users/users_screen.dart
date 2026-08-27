import 'package:flutter/material.dart';
import '../../../core/services/admin_users_service.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState
    extends State<UsersManagementScreen> {
  final AdminUsersService _usersService =
      AdminUsersService();

  late Future<AdminUsersResult> _usersFuture;

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();

    _searchController.addListener(() {
      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminUsersResult> _loadUsers() {
    return _usersService.getUsers();
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = _loadUsers();
    });

    await _usersFuture;
  }

  List<AdminUserAnalytics> _filteredUsers(
    List<AdminUserAnalytics> users,
  ) {
    return users.where((user) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          user.name
              .toLowerCase()
              .contains(_searchQuery) ||
          user.email
              .toLowerCase()
              .contains(_searchQuery);

      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Active' &&
              user.isActive) ||
          (_statusFilter == 'Inactive' &&
              !user.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<AdminUsersResult>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _ErrorView(
                  error: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }

              final result = snapshot.data;

              if (result == null) {
                return const Center(
                  child: Text(
                    'No users data available.',
                  ),
                );
              }

              final users =
                  _filteredUsers(result.users);

              return _UsersManagementContent(
                stats: result.stats,
                users: users,
                searchController:
                    _searchController,
                statusFilter: _statusFilter,
                onStatusChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
                onUserTap: (user) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          UserDetailsScreen(
                        user: user,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN CONTENT
// ============================================================================

class _UsersManagementContent
    extends StatelessWidget {
  final AdminUsersStats stats;
  final List<AdminUserAnalytics> users;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<AdminUserAnalytics> onUserTap;

  const _UsersManagementContent({
    required this.stats,
    required this.users,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= 1100;

        final horizontalPadding =
            isWide ? 32.0 : 20.0;

        return ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            50,
          ),
          children: [
            // ================================================================
            // HEADER
            // ================================================================

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Users Management',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage users and monitor their learning activity.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                    alpha: 0.60,
                                  ),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // ================================================================
            // GENERAL STATISTICS
            // ================================================================

            _UsersStatsGrid(
              stats: stats,
              isWide: isWide,
            ),

            const SizedBox(height: 30),

            // ================================================================
            // SEARCH + FILTER
            // ================================================================

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        searchController,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Search by name or email...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: statusFilter,
                    borderRadius:
                        BorderRadius.circular(14),
                    items: const [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: 'Active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'Inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onStatusChanged(value);
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ================================================================
            // RESULTS COUNT
            // ================================================================

            Text(
              '${users.length} user${users.length == 1 ? '' : 's'} found',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(
                          alpha: 0.60,
                        ),
                  ),
            ),

            const SizedBox(height: 12),

            // ================================================================
            // USERS
            // ================================================================

            if (users.isEmpty)
              const _NoUsersFound()
            else
              ...users.map(
                (user) => Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _UserCard(
                    user: user,
                    onTap: () =>
                        onUserTap(user),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// STATS GRID
// ============================================================================

class _UsersStatsGrid extends StatelessWidget {
  final AdminUsersStats stats;
  final bool isWide;

  const _UsersStatsGrid({
    required this.stats,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final columns = isWide ? 4 : 2;

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      childAspectRatio:
          isWide ? 1.9 : 1.65,
      children: [
        _UserStatCard(
          title: 'Total Users',
          value: stats.totalUsers,
          icon: Icons.people_alt_rounded,
        ),
        _UserStatCard(
          title: 'Active Users',
          value: stats.activeUsers,
          icon: Icons.person_rounded,
        ),
        _UserStatCard(
          title: 'Inactive Users',
          value: stats.inactiveUsers,
          icon: Icons.person_off_rounded,
        ),
        _UserStatCard(
          title: 'Lecture Activity',
          value:
              stats.usersWithLectureActivity,
          icon: Icons.play_circle_fill_rounded,
        ),
        _UserStatCard(
          title: 'Exam Activity',
          value:
              stats.usersWithExamActivity,
          icon: Icons.assignment_rounded,
        ),
        _UserStatCard(
          title: 'Lectures Opened',
          value:
              stats.totalLecturesOpened,
          icon: Icons.menu_book_rounded,
        ),
        _UserStatCard(
          title: 'Videos Completed',
          value:
              stats.totalVideosCompleted,
          icon: Icons.video_file_rounded,
        ),
        _UserStatCard(
          title: 'Audios Completed',
          value:
              stats.totalAudiosCompleted,
          icon: Icons.audio_file_rounded,
        ),
        _UserStatCard(
          title: 'Exam Attempts',
          value:
              stats.totalExamAttempts,
          icon: Icons.quiz_rounded,
        ),
        _UserStatCard(
          title: 'Completed Exams',
          value:
              stats.completedExams,
          icon: Icons.task_alt_rounded,
        ),
        _UserStatCard(
          title: 'Average Score',
          value:
              '${stats.averageScore.toStringAsFixed(1)}%',
          icon: Icons.analytics_rounded,
        ),
        _UserStatCard(
          title: 'Success Rate',
          value:
              '${stats.successRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }
}

// ============================================================================
// STAT CARD
// ============================================================================

class _UserStatCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;

  const _UserStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary =
        theme.colorScheme.primary;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    primary.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: 0.60,
                              ),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
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

// ============================================================================
// USER CARD
// ============================================================================

class _UserCard extends StatelessWidget {
  final AdminUserAnalytics user;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ==============================================================
              // AVATAR
              // ==============================================================

              _UserAvatar(
                user: user,
              ),

              const SizedBox(width: 14),

              // ==============================================================
              // USER INFO
              // ==============================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: theme
                                .colorScheme
                                .onSurface
                                .withValues(
                                  alpha: 0.60,
                                ),
                          ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          active:
                              user.isActive,
                        ),
                        _InfoChip(
                          icon: Icons.menu_book,
                          label:
                              '${user.lecturesOpened} lectures',
                        ),
                        _InfoChip(
                          icon: Icons.quiz,
                          label:
                              '${user.examAttempts} exams',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ==============================================================
              // SCORE
              // ==============================================================

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user.averageScore.toStringAsFixed(1)}%',
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Avg. Score',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: 0.55,
                              ),
                        ),
                  ),
                ],
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// AVATAR
// ============================================================================

class _UserAvatar extends StatelessWidget {
  final AdminUserAnalytics user;

  const _UserAvatar({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        user.imageUrl?.trim();

    if (imageUrl != null &&
        imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 27,
        backgroundImage:
            NetworkImage(imageUrl),
        onBackgroundImageError:
            (_, _) {},
        child: const SizedBox(),
      );
    }

    return CircleAvatar(
      radius: 27,
      child: Text(
        _initials(user.name),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length.clamp(0, 1),
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================

class _StatusChip extends StatelessWidget {
  final bool active;

  const _StatusChip({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Colors.green
        : Colors.grey;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// INFO CHIP
// ============================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .onSurface
            .withValues(alpha: 0.05),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: theme
                .colorScheme
                .onSurface
                .withValues(
                  alpha: 0.60,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NO USERS
// ============================================================================

class _NoUsersFound
    extends StatelessWidget {
  const _NoUsersFound();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 55,
              color: theme
                  .colorScheme
                  .onSurface
                  .withValues(
                    alpha: 0.30,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Users Found',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your search or filter.',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String error;

  const _ErrorView({
    required this.onRetry,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height:
              MediaQuery.sizeOf(context)
                      .height *
                  0.70,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 60,
                    color: theme
                        .colorScheme
                        .error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load users',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check the Supabase connection.',
                    textAlign:
                        TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text(
                      'Try Again',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (error.isNotEmpty)
                    SelectableText(
                      error,
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// USER DETAILS SCREEN
// ============================================================================

class UserDetailsScreen
    extends StatelessWidget {
  final AdminUserAnalytics user;

  const UserDetailsScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Details',
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(24),
        children: [
          // ================================================================
          // PROFILE
          // ================================================================

          Card(
            elevation: 0,
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                children: [
                  _UserAvatar(user: user),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    textAlign:
                        TextAlign.center,
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user.email,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: 0.60,
                              ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  _StatusChip(
                    active:
                        user.isActive,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ================================================================
          // LEARNING ANALYTICS
          // ================================================================

          Text(
            'Learning Analytics',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          _DetailsGrid(
            items: [
              _DetailItem(
                'Lectures Opened',
                user.lecturesOpened,
              ),
              _DetailItem(
                'Videos Completed',
                user.videosCompleted,
              ),
              _DetailItem(
                'Audios Completed',
                user.audiosCompleted,
              ),
              _DetailItem(
                'In Progress',
                user.lecturesInProgress,
              ),
            ],
          ),

          const SizedBox(height: 26),

          // ================================================================
          // EXAM ANALYTICS
          // ================================================================

          Text(
            'Exam Analytics',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          _DetailsGrid(
            items: [
              _DetailItem(
                'Attempts',
                user.examAttempts,
              ),
              _DetailItem(
                'Completed',
                user.completedExams,
              ),
              _DetailItem(
                'Average Score',
                '${user.averageScore.toStringAsFixed(1)}%',
              ),
              _DetailItem(
                'Best Score',
                '${user.bestScore.toStringAsFixed(1)}%',
              ),
              _DetailItem(
                'Correct Answers',
                user.correctAnswers,
              ),
              _DetailItem(
                'Total Questions',
                user.totalQuestions,
              ),
              _DetailItem(
                'Success Rate',
                '${user.successRate.toStringAsFixed(1)}%',
              ),
            ],
          ),

          const SizedBox(height: 26),

          // ================================================================
          // LAST ACTIVITY
          // ================================================================

          Text(
            'Activity',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 0,
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                children: [
                  _ActivityRow(
                    title:
                        'Last Lecture Activity',
                    date:
                        user.lastLectureActivity,
                  ),
                  const Divider(height: 28),
                  _ActivityRow(
                    title:
                        'Last Exam Activity',
                    date:
                        user.lastExamActivity,
                  ),
                  const Divider(height: 28),
                  _ActivityRow(
                    title: 'Last Activity',
                    date:
                        user.lastActivity,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DETAILS GRID
// ============================================================================

class _DetailsGrid
    extends StatelessWidget {
  final List<_DetailItem> items;

  const _DetailsGrid({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Card(
          elevation: 0,
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(
                              alpha: 0.60,
                            ),
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.value.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailItem {
  final String title;
  final dynamic value;

  const _DetailItem(
    this.title,
    this.value,
  );
}

// ============================================================================
// ACTIVITY ROW
// ============================================================================

class _ActivityRow
    extends StatelessWidget {
  final String title;
  final DateTime? date;

  const _ActivityRow({
    required this.title,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          color:
              theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme
                .textTheme
                .bodyMedium,
          ),
        ),
        Text(
          _formatDate(date),
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurface
                    .withValues(
                      alpha: 0.60,
                    ),
              ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'No activity';
    }

    final local =
        date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
