import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/exam_attempts_service.dart';

class StudentExamPerformanceScreen extends StatefulWidget {
  const StudentExamPerformanceScreen({super.key});

  @override
  State<StudentExamPerformanceScreen> createState() =>
      _StudentExamPerformanceScreenState();
}

class _StudentExamPerformanceScreenState
    extends State<StudentExamPerformanceScreen> {
  final ExamAttemptsService _service = ExamAttemptsService();

  late Future<List<AdminExamAttempt>> _future;
  String? _selectedUserId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _service.getAttempts();
  }

  Future<void> _refresh() async {
    final future = _service.getAttempts();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  List<AdminExamAttempt> _filtered(List<AdminExamAttempt> attempts) {
    Iterable<AdminExamAttempt> result = attempts;
    if (_selectedUserId != null) {
      result = result.where((item) => item.userId == _selectedUserId);
    }
    final query = _search.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where(
        (item) =>
            item.studentName.toLowerCase().contains(query) ||
            item.studentEmail.toLowerCase().contains(query),
      );
    }
    return result.toList();
  }

  String _date(DateTime value) {
    final v = value.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: FutureBuilder<List<AdminExamAttempt>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            );
          }

          final allAttempts = snapshot.data!;
          final filtered = _filtered(allAttempts);
          final completed = filtered.where((a) => a.isCompleted).toList();
          final scored = completed.where((a) => a.score != null).toList();
          final average = scored.isEmpty
              ? 0.0
              : scored.map((a) => a.score!.toDouble()).reduce((a, b) => a + b) /
                  scored.length;
          final passed = scored.where((a) => (a.score ?? 0) >= 50).length;

          final users = <String, AdminExamAttempt>{};
          for (final attempt in allAttempts) {
            users.putIfAbsent(attempt.userId, () => attempt);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Student Exam Performance',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Analyze exam performance for an individual student using real attempt data.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(() {
                              _search = value;
                              if (value.trim().isEmpty) _selectedUserId = null;
                            }),
                            decoration: const InputDecoration(
                              hintText: 'Search student name or email...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 320,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedUserId,
                            decoration: const InputDecoration(
                              labelText: 'Student',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Students'),
                              ),
                              ...users.values.map(
                                (user) => DropdownMenuItem<String?>(
                                  value: user.userId,
                                  child: Text(
                                    user.studentName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _selectedUserId = value;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Metric(
                          label: 'Attempts',
                          value: '${filtered.length}',
                          icon: Icons.assignment_outlined,
                        ),
                        _Metric(
                          label: 'Completed',
                          value: '${completed.length}',
                          icon: Icons.task_alt_rounded,
                        ),
                        _Metric(
                          label: 'Average Score',
                          value: '${average.toStringAsFixed(1)}%',
                          icon: Icons.insights_outlined,
                        ),
                        _Metric(
                          label: 'Passed',
                          value: '$passed',
                          icon: Icons.check_circle_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No performance data found.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        children: [
                          if (_selectedUserId != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _ChartCard(
                                    title: 'Score Trend',
                                    child: SizedBox(
                                      height: 260,
                                      child: _ScoreChart(attempts: scored),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 320,
                                  child: _ChartCard(
                                    title: 'Pass vs Fail',
                                    child: SizedBox(
                                      height: 260,
                                      child: _PassChart(
                                        passed: passed,
                                        failed: scored.length - passed,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                          _AttemptsTable(attempts: filtered, date: _date),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final List<AdminExamAttempt> attempts;
  const _ScoreChart({required this.attempts});

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) return const Center(child: Text('No scored attempts yet.'));
    final sorted = [...attempts]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final spots = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), (sorted[i].score ?? 0).toDouble()));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: spots.length > 6 ? (spots.length / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= sorted.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${index + 1}', style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _PassChart extends StatelessWidget {
  final int passed;
  final int failed;
  const _PassChart({required this.passed, required this.failed});

  @override
  Widget build(BuildContext context) {
    final total = passed + failed;
    if (total == 0) return const Center(child: Text('No completed scored attempts.'));
    return PieChart(
      PieChartData(
        centerSpaceRadius: 42,
        sectionsSpace: 3,
        sections: [
          PieChartSectionData(value: passed.toDouble(), title: '$passed'),
          PieChartSectionData(value: failed.toDouble(), title: '$failed'),
        ],
      ),
    );
  }
}

class _AttemptsTable extends StatelessWidget {
  final List<AdminExamAttempt> attempts;
  final String Function(DateTime) date;

  const _AttemptsTable({required this.attempts, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attempt History',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...attempts.map(
              (attempt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(attempt.studentName.isEmpty ? '?' : attempt.studentName[0].toUpperCase())),
                title: Text(attempt.examTitle),
                subtitle: Text('${attempt.studentName} • ${attempt.lectureTitle} • ${date(attempt.startedAt)}'),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (attempt.score != null) Text('${attempt.score}%'),
                    Chip(label: Text(attempt.status.replaceAll('_', ' '))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
