import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/admin_users_service.dart';

class UserPersonalAnalytics extends StatefulWidget {
  final AdminUserAnalytics user;

  const UserPersonalAnalytics({super.key, required this.user});

  @override
  State<UserPersonalAnalytics> createState() => _UserPersonalAnalyticsState();
}

class _UserPersonalAnalyticsState extends State<UserPersonalAnalytics> {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, Future<_PersonalAnalytics>> _cache = {};
  late Future<_PersonalAnalytics> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCached(widget.user.id);
  }

  @override
  void didUpdateWidget(covariant UserPersonalAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      setState(() => _future = _loadCached(widget.user.id));
    }
  }

  Future<_PersonalAnalytics> _loadCached(String userId) {
    return _cache.putIfAbsent(userId, () => _load(userId));
  }

  Future<_PersonalAnalytics> _load(String userId) async {
    final responses = await Future.wait([
      _supabase
          .from('lecture_progress')
          .select('lecture_id, audio_completed, video_completed, last_opened_at, updated_at')
          .eq('user_id', userId),
      _supabase
          .from('exam_attempts')
          .select('score, total_questions, correct_answers, status, started_at, completed_at, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: true),
    ]);

    final progress = responses[0] as List;
    final attempts = responses[1] as List;

    final activity = <DateTime, int>{};
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));

    for (var i = 0; i < 30; i++) {
      activity[start.add(Duration(days: i))] = 0;
    }

    DateTime? parse(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '');
    DateTime onlyDay(DateTime value) =>
        DateTime(value.year, value.month, value.day);

    for (final row in progress) {
      final date = parse(row['last_opened_at']) ?? parse(row['updated_at']);
      if (date == null) continue;
      final day = onlyDay(date.toLocal());
      if (activity.containsKey(day)) {
        activity[day] = activity[day]! + 1;
      }
    }

    for (final row in attempts) {
      final date = parse(row['completed_at']) ??
          parse(row['created_at']) ??
          parse(row['started_at']);
      if (date == null) continue;
      final day = onlyDay(date.toLocal());
      if (activity.containsKey(day)) {
        activity[day] = activity[day]! + 1;
      }
    }

    final completedAttempts = attempts.where((row) {
      final status = row['status']?.toString().toLowerCase();
      return status == 'completed' || parse(row['completed_at']) != null;
    }).toList();

    final scores = <FlSpot>[];
    for (var i = 0; i < completedAttempts.length; i++) {
      final score = (completedAttempts[i]['score'] as num?)?.toDouble() ??
          double.tryParse(completedAttempts[i]['score']?.toString() ?? '') ??
          0.0;
      scores.add(FlSpot(i.toDouble(), score));
    }

    final lecturesOpened = progress.length;
    final videosCompleted =
        progress.where((e) => e['video_completed'] == true).length;
    final audiosCompleted =
        progress.where((e) => e['audio_completed'] == true).length;
    final incompleteLectures = progress
        .where((e) =>
            e['video_completed'] != true && e['audio_completed'] != true)
        .length;

    final examAttempts = attempts.length;
    final completedExams = completedAttempts.length;

    var correct = 0;
    var questions = 0;
    for (final row in completedAttempts) {
      correct += (row['correct_answers'] as num?)?.toInt() ??
          int.tryParse(row['correct_answers']?.toString() ?? '') ??
          0;
      questions += (row['total_questions'] as num?)?.toInt() ??
          int.tryParse(row['total_questions']?.toString() ?? '') ??
          0;
    }

    final avg = completedAttempts.isEmpty
        ? 0.0
        : completedAttempts
                  .map((row) =>
                      (row['score'] as num?)?.toDouble() ??
                      double.tryParse(row['score']?.toString() ?? '') ??
                      0.0)
                  .reduce((a, b) => a + b) /
              completedAttempts.length;

    return _PersonalAnalytics(
      activityPoints: [
        for (final entry in activity.entries)
          FlSpot(
            entry.key.difference(start).inDays.toDouble(),
            entry.value.toDouble(),
          ),
      ],
      scorePoints: scores,
      lecturesOpened: lecturesOpened,
      videosCompleted: videosCompleted,
      audiosCompleted: audiosCompleted,
      incompleteLectures: incompleteLectures,
      examAttempts: examAttempts,
      completedExams: completedExams,
      averageScore: avg,
      successRate: questions == 0 ? 0.0 : (correct / questions) * 100.0,
    );
  }

  Future<void> _refresh() async {
    _cache.remove(widget.user.id);
    setState(() => _future = _loadCached(widget.user.id));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PersonalAnalytics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load personal analytics: '
                '${snapshot.error ?? 'Unknown error'}',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                final activityCard = _buildActivityChart(context, data);
                final scoreCard = _buildScoreChart(context, data);

                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: activityCard),
                          const SizedBox(width: 14),
                          Expanded(child: scoreCard),
                        ],
                      )
                    : Column(
                        children: [
                          activityCard,
                          const SizedBox(height: 14),
                          scoreCard,
                        ],
                      );
              },
            ),
            const SizedBox(height: 14),
            _buildCompletionChart(context, data),
          ],
        );
      },
    );
  }

  Widget _card(Widget child) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      );

  Widget _buildSummary(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    final items = [
      ('Lectures Opened', data.lecturesOpened, Icons.menu_book_rounded),
      ('Videos Completed', data.videosCompleted, Icons.video_file_rounded),
      ('Audios Completed', data.audiosCompleted, Icons.audio_file_rounded),
      ('Exam Attempts', data.examAttempts, Icons.quiz_rounded),
      ('Completed Exams', data.completedExams, Icons.task_alt_rounded),
      ('Average Score', '${data.averageScore.toStringAsFixed(1)}%', Icons.analytics_rounded),
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
                      Text(item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 3),
                      Text('${item.$2}',
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700)),
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
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('30-Day Activity',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('This user only: lecture progress events + exam activity',
            style: theme.textTheme.bodySmall),
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
            lineBarsData: [LineChartBarData(
              spots: data.activityPoints,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              color: theme.colorScheme.primary,
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            )],
          )),
        ),
      ],
    ));
  }

  Widget _buildScoreChart(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    final double maxX = data.scorePoints.isEmpty
        ? 4.0
        : (data.scorePoints.length - 1).toDouble().clamp(1, double.infinity).toDouble();

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exam Score Trend',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Completed attempts for this user', style: theme.textTheme.bodySmall),
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
                  lineBarsData: [LineChartBarData(
                    spots: data.scorePoints,
                    isCurved: true,
                    barWidth: 3,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: true),
                  )],
                )),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            Text('Average: ${data.averageScore.toStringAsFixed(1)}%'),
            Text('Success: ${data.successRate.toStringAsFixed(1)}%'),
          ],
        ),
      ],
    ));
  }

  Widget _buildCompletionChart(BuildContext context, _PersonalAnalytics data) {
    final theme = Theme.of(context);
    final total = data.videosCompleted +
        data.audiosCompleted +
        data.incompleteLectures;

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Learning Completion',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Content completion breakdown for this user', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: total == 0
              ? const Center(child: Text('No learning activity yet'))
              : PieChart(PieChartData(
                  centerSpaceRadius: 52,
                  sectionsSpace: 3,
                  sections: [
                    PieChartSectionData(
                      value: data.videosCompleted.toDouble(),
                      title: '${data.videosCompleted}',
                      radius: 58,
                      color: theme.colorScheme.primary,
                    ),
                    PieChartSectionData(
                      value: data.audiosCompleted.toDouble(),
                      title: '${data.audiosCompleted}',
                      radius: 58,
                      color: theme.colorScheme.secondary,
                    ),
                    PieChartSectionData(
                      value: data.incompleteLectures.toDouble(),
                      title: '${data.incompleteLectures}',
                      radius: 58,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ],
                )),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _legend(theme.colorScheme.primary, 'Videos', data.videosCompleted),
            _legend(theme.colorScheme.secondary, 'Audios', data.audiosCompleted),
            _legend(theme.colorScheme.outlineVariant, 'Incomplete', data.incompleteLectures),
          ],
        ),
      ],
    ));
  }

  Widget _legend(Color color, String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ($value)'),
      ],
    );
  }
}

class _PersonalAnalytics {
  final List<FlSpot> activityPoints;
  final List<FlSpot> scorePoints;
  final int lecturesOpened;
  final int videosCompleted;
  final int audiosCompleted;
  final int incompleteLectures;
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
    required this.incompleteLectures,
    required this.examAttempts,
    required this.completedExams,
    required this.averageScore,
    required this.successRate,
  });
}
