import 'package:flutter/material.dart';

import '../../../core/services/exam_questions_service.dart';

class ExamQuestionsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ExamQuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamQuestionsScreen> createState() => _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState extends State<ExamQuestionsScreen> {
  final ExamQuestionsService _service = ExamQuestionsService();
  late Future<List<AdminQuestion>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
  }

  Future<List<AdminQuestion>> _loadQuestions() =>
      _service.getQuestions(widget.examId);

  Future<void> _refresh() async {
    final future = _loadQuestions();
    setState(() {
      _questionsFuture = future;
    });
    await future;
  }

  Future<void> _showQuestionDialog({AdminQuestion? question}) async {
    final result = await showDialog<_QuestionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionDialog(question: question),
    );
    if (result == null) return;

    try {
      final data = QuestionData(
        questionText: result.questionText,
        explanation: result.explanation,
        options: result.options,
        correctOptionIndex: result.correctOptionIndex,
      );

      if (question == null) {
        await _service.createQuestion(examId: widget.examId, data: data);
      } else {
        await _service.updateQuestion(questionId: question.id, data: data);
      }

      if (!mounted) return;
      _showMessage(question == null
          ? 'Question created successfully.'
          : 'Question updated successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _deleteQuestion(AdminQuestion question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text(
          'This question and all its options will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteQuestion(question.id);
      if (!mounted) return;
      _showMessage('Question deleted successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _reorderQuestions(
    List<AdminQuestion> questions,
    int oldIndex,
    int newIndex,
  ) async {
    final updated = List<AdminQuestion>.from(questions);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    try {
      await _service.reorderQuestions(updated);
      if (!mounted) return;
      setState(() {
        _questionsFuture = Future.value(updated);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error reordering questions: $e', error: true);
      await _refresh();
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuestionDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Question'),
      ),
      body: FutureBuilder<List<AdminQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              error: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final questions = snapshot.data ?? const <AdminQuestion>[];
          if (questions.isEmpty) {
            return _EmptyView(onAdd: () => _showQuestionDialog());
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: questions.length,
            onReorderItem: (oldIndex, newIndex) {
              _reorderQuestions(questions, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final question = questions[index];
              return _QuestionTile(
                key: ValueKey(question.id),
                number: index + 1,
                question: question,
                onEdit: () => _showQuestionDialog(question: question),
                onDelete: () => _deleteQuestion(question),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuestionDialogResult {
  final String questionText;
  final String? explanation;
  final List<String> options;
  final int correctOptionIndex;

  const _QuestionDialogResult({
    required this.questionText,
    required this.explanation,
    required this.options,
    required this.correctOptionIndex,
  });
}

class _QuestionDialog extends StatefulWidget {
  final AdminQuestion? question;

  const _QuestionDialog({required this.question});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _explanationController;
  late final List<TextEditingController> _optionControllers;
  int _correctOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    final question = widget.question;

    _questionController = TextEditingController(
      text: question?.questionText ?? '',
    );
    _explanationController = TextEditingController(
      text: question?.explanation ?? '',
    );

    if (question != null && question.options.isNotEmpty) {
      _optionControllers = question.options
          .map((option) => TextEditingController(text: option.optionText))
          .toList();
      final correctIndex = question.options.indexWhere(
        (option) => option.id == question.correctOptionId,
      );
      _correctOptionIndex = correctIndex >= 0 ? correctIndex : 0;
    } else {
      _optionControllers = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final controller = _optionControllers[index];
    setState(() {
      _optionControllers.removeAt(index);
      controller.dispose();
      if (_correctOptionIndex == index) {
        _correctOptionIndex = 0;
      } else if (_correctOptionIndex > index) {
        _correctOptionIndex--;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .toList();
    if (_correctOptionIndex >= options.length) return;

    Navigator.of(context).pop(
      _QuestionDialogResult(
        questionText: _questionController.text.trim(),
        explanation: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        options: options,
        correctOptionIndex: _correctOptionIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.question != null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return AlertDialog(
      title: Text(editing ? 'Edit Question' : 'Add Question'),
      content: SizedBox(
        width: 650,
        height: maxHeight,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              TextFormField(
                controller: _questionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  prefixIcon: Icon(Icons.help_outline_rounded),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _explanationController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Explanation',
                  prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Options',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Option'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: _correctOptionIndex,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _correctOptionIndex = value;
                  });
                },
                child: Column(
                  children: List.generate(_optionControllers.length, (index) {
                    final isCorrect = _correctOptionIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Radio<int>(value: index),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _optionControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                                prefixIcon: Icon(
                                  isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                ),
                                suffixIcon: _optionControllers.length > 2
                                    ? IconButton(
                                        tooltip: 'Remove option',
                                        onPressed: () => _removeOption(index),
                                        icon: const Icon(Icons.close_rounded),
                                      )
                                    : null,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter option text';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the radio button beside the correct answer.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Create Question'),
        ),
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final int number;
  final AdminQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionTile({
    super.key,
    required this.number,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text('$number')),
        title: Text(
          question.questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${question.options.length} options'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.quiz_outlined, size: 52),
          const SizedBox(height: 12),
          const Text('No questions found.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Question'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
