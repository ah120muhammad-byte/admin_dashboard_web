import 'package:flutter/material.dart';

import '../../../core/services/exams_service.dart';
import 'question_bank_screen.dart';

class ExamManagementScreen extends StatefulWidget {
  final AdminExam exam;
  final String lectureName;

  const ExamManagementScreen({
    super.key,
    required this.exam,
    required this.lectureName,
  });

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  final ExamsService _service = ExamsService();
  late AdminExam _exam;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _exam = widget.exam;
  }

  Future<void> _toggleActive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.setActive(id: _exam.id, value: !_exam.isActive);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _exam = AdminExam(
          id: _exam.id,
          lectureId: _exam.lectureId,
          title: _exam.title,
          description: _exam.description,
          durationMinutes: _exam.durationMinutes,
          passingScore: _exam.passingScore,
          isActive: !_exam.isActive,
        );
      });
      _message(_exam.isActive ? 'Exam activated.' : 'Exam deactivated.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message('Unable to update exam: $e', error: true);
    }
  }

  void _openQuestions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionBankScreen(
          examId: _exam.id,
          examTitle: _exam.title,
        ),
      ),
    );
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _exam.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.lectureName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(_exam.isActive ? 'Active' : 'Inactive'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam Control',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _exam.description?.trim().isNotEmpty == true
                        ? _exam.description!
                        : 'Manage the exam status and its question bank.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Metric(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '${_exam.durationMinutes} min',
                      ),
                      _Metric(
                        icon: Icons.percent_rounded,
                        label: 'Passing Score',
                        value: '${_exam.passingScore.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openQuestions,
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('Manage Question Bank'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _toggleActive,
                        icon: Icon(
                          _exam.isActive
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                        ),
                        label: Text(
                          _exam.isActive ? 'Deactivate Exam' : 'Activate Exam',
                        ),
                      ),
                    ],
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: scheme.primary),
            const SizedBox(width: 8),
            Text(label),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
