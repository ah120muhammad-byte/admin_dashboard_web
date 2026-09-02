import 'package:flutter/material.dart';

import '../../../core/services/exam_attempts_service.dart';

class ExamAttemptsScreen extends StatefulWidget {
  const ExamAttemptsScreen({super.key});

  @override
  State<ExamAttemptsScreen> createState() => _ExamAttemptsScreenState();
}

class _ExamAttemptsScreenState extends State<ExamAttemptsScreen> {
  final ExamAttemptsService _service = ExamAttemptsService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<AdminExamAttempt>> _future;
  String? _status;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _query) return;
    setState(() {
      _query = value;
    });
  }

  Future<List<AdminExamAttempt>> _load() {
    return _service.getAttempts(status: _status);
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  List<AdminExamAttempt> _filtered(List<AdminExamAttempt> attempts) {
    if (_query.isEmpty) return attempts;

    return attempts.where((attempt) {
      return attempt.studentName.toLowerCase().contains(_query) ||
          attempt.studentEmail.toLowerCase().contains(_query) ||
          attempt.examTitle.toLowerCase().contains(_query) ||
          attempt.lectureTitle.toLowerCase().contains(_query);
    }).toList();
  }

  Future<void> _showAttemptDetails(AdminExamAttempt attempt) async {
    try {
      final answers = await _service.getAnswers(attempt.id);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            child: SizedBox(
              width: 820,
              height: 680,
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                                attempt.examTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                attempt.studentName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (attempt.studentEmail.isNotEmpty)
                                Text(attempt.studentEmail),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(
                          label: 'Score',
                          value: attempt.score == null
                              ? '—'
                              : '${attempt.score}%',
                          icon: Icons.score_outlined,
                        ),
                        _InfoChip(
                          label: 'Correct',
                          value: attempt.totalQuestions == null
                              ? '—'
                              : '${attempt.correctAnswers ?? 0}/${attempt.totalQuestions}',
                          icon: Icons.check_circle_outline,
                        ),
                        _InfoChip(
                          label: 'Status',
                          value: _statusLabel(attempt.status),
                          icon: Icons.flag_outlined,
                        ),
                        _InfoChip(
                          label: 'Started',
                          value: _formatDate(attempt.startedAt),
                          icon: Icons.schedule_outlined,
                        ),
                        if (attempt.completedAt != null)
                          _InfoChip(
                            label: 'Completed',
                            value: _formatDate(attempt.completedAt!),
                            icon: Icons.task_alt_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Answers',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: answers.isEmpty
                          ? const Center(child: Text('No saved answers for this attempt.'))
                          : ListView.separated(
                              itemCount: answers.length,
                              separatorBuilder: (_, _) => const Divider(height: 24),
                              itemBuilder: (context, index) {
                                final answer = answers[index];
                                final correct = answer.isCorrect == true;
                                final incorrect = answer.isCorrect == false;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: correct
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : incorrect
                                                ? Theme.of(context).colorScheme.errorContainer
                                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        correct
                                            ? Icons.check_rounded
                                            : incorrect
                                                ? Icons.close_rounded
                                                : Icons.remove_rounded,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${index + 1}. ${answer.questionText}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            answer.selectedOptionText == null
                                                ? 'Not answered'
                                                : 'Answer: ${answer.selectedOptionText}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            correct
                                                ? 'Correct answer'
                                                : incorrect
                                                    ? 'Incorrect answer'
                                                    : 'Not graded',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: correct
                                                  ? Theme.of(context).colorScheme.primary
                                                  : incorrect
                                                      ? Theme.of(context).colorScheme.error
                                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _message('Unable to load attempt details: $e', error: true);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'abandoned':
        return 'Abandoned';
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'completed':
        return scheme.primary;
      case 'in_progress':
        return scheme.tertiary;
      default:
        return scheme.error;
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<List<AdminExamAttempt>>(
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

        final all = snapshot.data!;
        final attempts = _filtered(all);
        final completed = all.where((a) => a.status == 'completed').length;
        final inProgress = all.where((a) => a.status == 'in_progress').length;
        final abandoned = all.where((a) => a.status == 'abandoned').length;
        final scored = all.where((a) => a.score != null).toList();
        final average = scored.isEmpty
            ? 0.0
            : scored.fold<double>(0, (sum, a) => sum + (a.score ?? 0)) /
                scored.length;

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
                              'Exam Attempts',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Monitor student attempts, performance, timing and saved answers.',
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
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Metric('Total', '${all.length}', Icons.assignment_outlined),
                      _Metric('Completed', '$completed', Icons.task_alt_outlined),
                      _Metric('In progress', '$inProgress', Icons.timelapse_outlined),
                      _Metric('Abandoned', '$abandoned', Icons.cancel_outlined),
                      _Metric('Avg score', '${average.toStringAsFixed(1)}%', Icons.insights_outlined),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search student, email, exam or lecture...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.filter_alt_outlined),
                          ),
                          items: const [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All attempts'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'in_progress',
                              child: Text('In progress'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'completed',
                              child: Text('Completed'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'abandoned',
                              child: Text('Abandoned'),
                            ),
                          ],
                          onChanged: (value) {
                            final future = _service.getAttempts(status: value);
                            setState(() {
                              _status = value;
                              _future = future;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: attempts.isEmpty
                  ? const Center(child: Text('No exam attempts found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      itemCount: attempts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final attempt = attempts[index];
                        final statusColor = _statusColor(context, attempt.status);

                        return Card(
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _showAttemptDetails(attempt),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    child: Text(
                                      attempt.studentName.isEmpty
                                          ? '?'
                                          : attempt.studentName[0].toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                attempt.studentName,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _statusLabel(attempt.status),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (attempt.studentEmail.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            attempt.studentEmail,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          attempt.examTitle,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(attempt.lectureTitle),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 8,
                                          children: [
                                            Text('Score: ${attempt.score == null ? '—' : '${attempt.score}%'}'),
                                            Text(
                                              'Correct: ${attempt.totalQuestions == null ? '—' : '${attempt.correctAnswers ?? 0}/${attempt.totalQuestions}'}',
                                            ),
                                            Text('Started: ${_formatDate(attempt.startedAt)}'),
                                            if (attempt.completedAt != null)
                                              Text('Completed: ${_formatDate(attempt.completedAt!)}'),
                                            if (attempt.isPaused)
                                              const Text('Paused'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    tooltip: 'View details',
                                    onPressed: () => _showAttemptDetails(attempt),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric(this.label, this.value, this.icon);

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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
