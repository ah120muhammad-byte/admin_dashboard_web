import 'package:flutter/material.dart';

import '../../../core/services/exams_service.dart';
import 'question_bank_screen.dart';

class ExamManagementScreen extends StatelessWidget {
  final AdminExam exam;
  final String lectureName;

  const ExamManagementScreen({
    super.key,
    required this.exam,
    required this.lectureName,
  });

  void _openQuestions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionBankScreen(
          examId: exam.id,
          examTitle: exam.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
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
                      'Exam Control',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lectureName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                avatar: Icon(
                  exam.isActive
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  size: 18,
                ),
                label: Text(exam.isActive ? 'Active' : 'Inactive'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _ControlStat(
                label: 'Duration',
                value: '${exam.durationMinutes} min',
                icon: Icons.timer_outlined,
              ),
              _ControlStat(
                label: 'Passing Score',
                value: '${exam.passingScore.toStringAsFixed(0)}%',
                icon: Icons.percent_rounded,
              ),
              _ControlStat(
                label: 'Status',
                value: exam.isActive ? 'Available' : 'Disabled',
                icon: Icons.tune_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Build and maintain the question bank for this exam. Each question supports multiple options, one correct answer, and an explanation.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _openQuestions(context),
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Manage Questions'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.analytics_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attempts & Results',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Student attempts remain available from the Exam Attempts section in the sidebar.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ControlStat({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
