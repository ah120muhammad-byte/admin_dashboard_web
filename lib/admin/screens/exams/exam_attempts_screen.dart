import 'package:flutter/material.dart';

import '../../../core/services/exam_attempts_service.dart';

class ExamAttemptsScreen extends StatefulWidget {
  const ExamAttemptsScreen({super.key});

  @override
  State<ExamAttemptsScreen> createState() => _ExamAttemptsScreenState();
}

class _ExamAttemptsScreenState extends State<ExamAttemptsScreen> {
  final ExamAttemptsService _service = ExamAttemptsService();

  late Future<List<AdminExamAttempt>> _future;
  String? _status;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminExamAttempt>> _load() {
    return _service.getAttempts(status: _status);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _showAnswers(AdminExamAttempt attempt) async {
    try {
      final answers = await _service.getAnswers(attempt.id);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('${attempt.studentName} — ${attempt.examTitle}'),
            content: SizedBox(
              width: 760,
              child: answers.isEmpty
                  ? const Text('No saved answers for this attempt.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: answers.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (_, index) {
                        final answer = answers[index];
                        final icon = answer.isCorrect == true
                            ? Icons.check_circle_rounded
                            : answer.isCorrect == false
                                ? Icons.cancel_rounded
                                : Icons.remove_circle_outline_rounded;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}. ${answer.questionText}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    answer.selectedOptionText == null
                                        ? 'Not answered'
                                        : 'Answer: ${answer.selectedOptionText}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load answers: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Attempts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
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
                    setState(() {
                      _status = value;
                      _future = _load();
                    });
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AdminExamAttempt>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load exam attempts.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final attempts = snapshot.data ?? const <AdminExamAttempt>[];
                if (attempts.isEmpty) {
                  return const Center(
                    child: Text('No exam attempts found.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: attempts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    final statusColor = _statusColor(context, attempt.status);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
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
                                  Text(
                                    attempt.studentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (attempt.studentEmail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(attempt.studentEmail),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    attempt.examTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(attempt.lectureTitle),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 6,
                                    children: [
                                      Text('Started: ${_formatDate(attempt.startedAt)}'),
                                      if (attempt.score != null)
                                        Text(
                                          'Score: ${attempt.score}%'
                                          '${attempt.totalQuestions == null ? '' : ' (${attempt.correctAnswers ?? 0}/${attempt.totalQuestions})'}',
                                        ),
                                      Text(
                                        'Status: ${_statusLabel(attempt.status)}',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (attempt.isPaused)
                                        const Text('Paused'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showAnswers(attempt),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Answers'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
