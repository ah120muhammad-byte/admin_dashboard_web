import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/admin_users_service.dart';
import 'users_screen.dart';

class UsersAnalyticsDashboard extends StatelessWidget {
  const UsersAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 610,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: UserAnalyticsCharts(key: const ValueKey('user-analytics')),
          ),
        ),
        const Expanded(child: UsersManagementScreen()),
      ],
    );
  }
}

class UserAnalyticsCharts extends StatefulWidget {
  const UserAnalyticsCharts({super.key});

  @override
  State<UserAnalyticsCharts> createState() => _UserAnalyticsChartsState();
}

class _UserAnalyticsChartsState extends State<UserAnalyticsCharts> {
  final _supabase = Supabase.instance.client;
  late Future<_UserAnalyticsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UserAnalyticsSnapshot> _load() async {
    final usersResult = await AdminUsersService(supabase: _supabase).getUsers();

    final progressResponse = await _supabase
        .from('lecture_progress')
        .select('last_opened_at, updated_at');

    final attemptsResponse = await _supabase
        .from('exam_attempts')
        .select('created_at, completed_at, status');

    final activityByDay = <DateTime, int>{};
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));

    DateTime dayOnly(DateTime value) => DateTime(value.year, value.month, value.day);

    for (var i = 0; i < 30; i++) {
      final date = start.add(Duration(days: i));
      activityByDay[date] = 0;
    }

    for (final row in progressResponse) {
      final raw = row['last_opened_at'] ?? row['updated_at'];
      final date = DateTime.tryParse(raw?.toString() ?? '');
      if (date == null) continue;
      final day = dayOnly(date.toLocal());
      if (activityByDay.containsKey(day)) {
        activityByDay[day] = activityByDay[day]! + 1;
      }
    }

    for (final row in attemptsResponse) {
      final raw = row['completed_at'] ?? row['created_at'];
      final date = DateTime.tryParse(raw?.toString() ?? '');
      if (date == null) continue;
      final day = dayOnly(date.toLocal());
      if (activityByDay.containsKey(day)) {
        activityByDay[day] = activityByDay[day]! + 1;
      }
    }

    return _UserAnalyticsSnapshot(
      stats: usersResult.stats,
      activityPoints: [
        for (final entry in activityByDay.entries)
          FlSpot(
            entry.key.difference(start).inDays.toDouble(),
            entry.value.toDouble(),
          ),
      ],
      lectureActivity: usersResult.stats.totalLecturesOpened,
      videoActivity: usersResult.stats.totalVideosCompleted,
      audioActivity: usersResult.stats.totalAudiosCompleted,
      examActivity: usersResult.stats.totalExamAttempts,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UserAnalyticsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _AnalyticsError(
            onRetry: _refresh,
            error: snapshot.error,
          );
        }

        final data = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Analytics',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real activity from lectures and exam attempts over the last 30 days.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh analytics',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTrendCard(context, data)),
                        const SizedBox(width: 14),
                        SizedBox(width: 360, child: _buildStatusCard(context, data)),
                      ],
                    )
                  else ...[
                    _buildTrendCard(context, data),
                    const SizedBox(height: 14),
                    _buildStatusCard(context, data),
                  ],
                  const SizedBox(height: 14),
                  _buildActivityCard(context, data),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Card(
      elevation: 0,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _buildTrendCard(BuildContext context, _UserAnalyticsSnapshot data) {
    final theme = Theme.of(context);
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('30-Day Activity Trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Lecture progress events + exam activity', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 29,
                minY: 0,
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: _yInterval(data.activityPoints))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${value.toInt() + 1}d', style: theme.textTheme.labelSmall),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((spot) => LineTooltipItem('${spot.y.toInt()} activities', const TextStyle()))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.activityPoints,
                    isCurved: true,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _yInterval(List<FlSpot> spots) {
    final max = spots.fold<double>(0, (value, spot) => spot.y > value ? spot.y : value);
    return max <= 5 ? 1 : (max / 5).ceilToDouble();
  }

  Widget _buildStatusCard(BuildContext context, _UserAnalyticsSnapshot data) {
    final theme = Theme.of(context);
    final active = data.stats.activeUsers;
    final inactive = data.stats.inactiveUsers;
    final total = active + inactive;

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Based on activity within the last 30 days', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: total == 0
                ? const Center(child: Text('No users available'))
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 48,
                      sectionsSpace: 3,
                      sections: [
                        PieChartSectionData(value: active.toDouble(), title: '$active', radius: 58, color: theme.colorScheme.primary),
                        PieChartSectionData(value: inactive.toDouble(), title: '$inactive', radius: 58, color: theme.colorScheme.outlineVariant),
                      ],
                    ),
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(label: 'Active', value: active, color: theme.colorScheme.primary),
              const SizedBox(width: 18),
              _LegendDot(label: 'Inactive', value: inactive, color: theme.colorScheme.outlineVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, _UserAnalyticsSnapshot data) {
    final theme = Theme.of(context);
    final max = [data.lectureActivity, data.videoActivity, data.audioActivity, data.examActivity]
        .fold<int>(0, (value, item) => item > value ? item : value);

    final items = [
      ('Lectures Opened', data.lectureActivity, Icons.menu_book_rounded),
      ('Videos Completed', data.videoActivity, Icons.video_file_rounded),
      ('Audios Completed', data.audioActivity, Icons.audio_file_rounded),
      ('Exam Attempts', data.examActivity, Icons.quiz_rounded),
    ];

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Real totals from the current users dataset', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: max == 0 ? 1 : max * 1.15,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= items.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${index + 1}', style: theme.textTheme.labelSmall),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < items.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: items[i].$2.toDouble(),
                          width: 32,
                          borderRadius: BorderRadius.circular(6),
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].$3, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('${i + 1}. ${items[i].$1}: ${items[i].$2}'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _LegendDot({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($value)'),
      ],
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  final VoidCallback onRetry;
  final Object? error;

  const _AnalyticsError({required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 10),
          const Text('Unable to load user analytics.'),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _UserAnalyticsSnapshot {
  final AdminUsersStats stats;
  final List<FlSpot> activityPoints;
  final int lectureActivity;
  final int videoActivity;
  final int audioActivity;
  final int examActivity;

  const _UserAnalyticsSnapshot({
    required this.stats,
    required this.activityPoints,
    required this.lectureActivity,
    required this.videoActivity,
    required this.audioActivity,
    required this.examActivity,
  });
}
