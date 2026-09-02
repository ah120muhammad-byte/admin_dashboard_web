import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/admin_users_service.dart';

class UserPersonalAnalytics extends StatefulWidget {
  final AdminUserAnalytics user;

  const UserPersonalAnalytics({
    super.key,
    required this.user,
  });

  @override
  State<UserPersonalAnalytics> createState() => _UserPersonalAnalyticsState();
}

class _UserPersonalAnalyticsState extends State<UserPersonalAnalytics> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<_PersonalAnalytics> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PersonalAnalytics> _load() async {
    final userId = widget.user.id;

    final progress = await _supabase
        .from('lecture_progress')
        .select('lecture_id, audio_completed, video_completed, last_opened_at, updated_at')
        .eq('user_id', userId);

    final attempts = await _supabase
        .from('exam_attempts')
        .select('score, total_questions, correct_answers, status, started_at, completed_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    final activity = <DateTime, int>{};
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));

    for (var i = 0; i < 30; i++) {
      activity[start.add(Duration(days: i))] = 0;
    }

    DateTime? parse(dynamic value) => DateTime.tryParse(value?.toString() ?? '');
    DateTime onlyDay(DateTime value) => DateTime(value.year, value.month, value.day);

    for (final row in progress) {
      final date = parse(row['last_opened_at']) ?? parse(row['updated_at']);
      if (date == null) continue;
      final day = onlyDay(date.toLocal());
      if (activity.containsKey(day)) activity[day] = activity[day]! + 1;
    }

    for (final row in attempts) {
      final date = parse(row['completed_at']) ?? parse(row['created_at']) ?? parse(row['started_at']);
      if (date == null) continue;
      final day = onlyDay(date.toLocal());
      if (activity.containsKey(day)) activity[day] = activity[day]! + 1;
    }

    final completedAttempts = attempts.where((row) {
      final status = row['status']?.toString().toLowerCase();
      return status == 'completed' || parse(row['completed_at']) != null;
    }).toList();

    final scores = <FlSpot>[];
    for (var i = 0; i < completedAttempts.length; i++) {
      final score = (completedAttempts[i]['score'] as num?)?.toDouble() ??
          double.tryParse(completedAttempts[i]['score']?.toString() ?? '') ?? 0;
      scores.add(FlSpot(i.toDouble(), score));
    }

    final lecturesOpened = progress.length;
    final videosCompleted = progress.where((e) => e['video_completed'] == true).length;
    final audiosCompleted = progress.where((e) => e['audio_completed'] == true).length;
    final examAttempts = attempts.length;
    final completedExams = completedAttempts.length;

    var correct = 0;
    var questions = 0;
    for (final row in completedAttempts) {
      correct += (row['correct_answers'] as num?)?.toInt() ?? int.tryParse(row['correct_answers']?.toString() ?? '') ?? 0;
      questions += (row['total_questions'] as num?)?.toInt() ?? int.tryParse(row['total_questions']?.toString() ?? '') ?? 0;
    }

    final avg = completedAttempts.isEmpty
        ? 0.0
        : completedAttempts
                .map((row) => (row['score'] as num?)?.toDouble() ?? double.tryParse(row['score']?.toString() ?? '') ?? 0)
                .reduce((a, b) => a + b) /
            completedAttempts.length;

    return _PersonalAnalytics(
      activityPoints: [
        for (final entry in activity.entries)
          FlSpot(entry.key.difference(start).inDays.toDouble(), entry.value.toDouble()),
      ],
      scorePoints: scores,
      lecturesOpened: lecturesOpened,
      videosCompleted: videosCompleted,
      audiosCompleted: audiosCompleted,
      examAttempts: examAttempts,
      completedExams: completedExams,
      averageScore: avg,
      successRate: questions == 0 ? 0 : (correct / questions) * 100,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PersonalAnalytics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Personal Analytics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Unable to load personal analytics: ${snapshot.error ?? 'Unknown error'}'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          );
        }

        final data = snapshot.data!;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Personal Analytics',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
            _buildSummary(context, data),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final activity = _buildActivityChart(context, data);
                final score = _buildScoreChart(context, data);
                final completion = _buildCompletionPie(context, data);

                final charts = <Widget>[activity, score, completion];
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: 14),
                      Expanded(child: charts[1]),
                      const SizedBox(width: 14),
                      SizedBox(width: 300, child: charts[2]),
                    ],
                  );
                }

                return Column(
                  children: [activity, const SizedBox(height: 14), score, const SizedBox(height: 14), completion],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _card(Widget child) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(20), child: child));

  Widget _buildSummary(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    final items = [
      ('Lectures Opened', data.lecturesOpened, Icons.menu_book_rounded),
      ('Videos Completed', data.videosCompleted, Icons.video_file_rounded),
      ('Audios Completed', data.audiosCompleted, Icons.audio_file_rounded),
      ('Exam Attempts', data.examAttempts, Icons.quiz_rounded),
      ('Completed Exams', data.completedExams, Icons.task_alt_rounded),
      ('Average Score', '${data.averageScore.toStringAsFixed(1)}%', Icons.analytics_outlined),
      ('Success Rate', '${data.successRate.toStringAsFixed(1)}%', Icons.trending_up_rounded),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) => SizedBox(
        width: 180,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(item.$3, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 3),
                      Text('${item.$2}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildActivityChart(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('30-Day Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Lecture progress events + exam activity for this user', style: theme.textTheme.bodySmall),
      const SizedBox(height: 18),
      SizedBox(
        height: 230,
        child: LineChart(LineChartData(
          minX: 0,
          maxX: 29,
          minY: 0,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: data.activityPoints,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              color: theme.colorScheme.primary,
              belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
            ),
          ],
        )),
      ),
    ]));
  }

  Widget _buildScoreChart(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    final maxX = data.scorePoints.isEmpty ? 1.0 : (data.scorePoints.length - 1).toDouble().clamp(1.0, double.infinity).toDouble();

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Exam Score Trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Completed exam attempts for this user', style: theme.textTheme.bodySmall),
      const SizedBox(height: 18),
      SizedBox(
        height: 230,
        child: data.scorePoints.isEmpty
            ? const Center(child: Text('No completed exam attempts'))
            : LineChart(LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.scorePoints,
                    isCurved: true,
                    barWidth: 3,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              )),
      ),
    ]));
  }

  Widget _buildCompletionPie(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    final completed = data.videosCompleted + data.audiosCompleted + data.completedExams;
    final remaining = data.lecturesOpened - (data.videosCompleted + data.audiosCompleted);

    final values = [
      ('Video', data.videosCompleted, theme.colorScheme.primary),
      ('Audio', data.audiosCompleted, theme.colorScheme.tertiary),
      ('Exams', data.completedExams, theme.colorScheme.secondary),
      ('Other / In Progress', remaining < 0 ? 0 : remaining, theme.colorScheme.outlineVariant),
    ];
    final total = values.fold<int>(0, (sum, item) => sum + item.$2);

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Completion Mix', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Only this user', style: theme.textTheme.bodySmall),
      const SizedBox(height: 14),
      SizedBox(
        height: 210,
        child: total == 0
            ? const Center(child: Text('No activity yet'))
            : PieChart(PieChartData(
                centerSpaceRadius: 45,
                sectionsSpace: 3,
                sections: [
                  for (final item in values)
                    if (item.$2 > 0)
                      PieChartSectionData(
                        value: item.$2.toDouble(),
                        title: '${((item.$2 / total) * 100).round()}%',
                        radius: 58,
                        color: item.$3,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                ],
              )),
      ),
      const SizedBox(height: 8),
      for (final item in values)
        if (item.$2 > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: item.$3, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Text(item.$1)),
                Text('${item.$2}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      if (completed > 0) const SizedBox(height: 2),
    ]));
  }
}

class _PersonalAnalytics {
  final List<FlSpot> activityPoints;
  final List<FlSpot> scorePoints;
  final int lecturesOpened;
  final int videosCompleted;
  final int audiosCompleted;
  final int examAttempts;
  final int completedExams;
  final double averageScore;
  final double successRate;

  const _PersonalAnalytics({
    required this.activityPoints,
    required this.scorePoints,
    required this.lecturesOpened,
    required this.videosCompleted,
    required this.audiosCompleted,
    required this.examAttempts,
    required this.completedExams,
    required this.averageScore,
    required this.successRate,
  });
}
