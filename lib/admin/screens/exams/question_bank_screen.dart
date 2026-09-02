import 'package:flutter/material.dart';

import '../../../core/services/questions_service.dart';

class QuestionBankScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const QuestionBankScreen({super.key, required this.examId, required this.examTitle});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final QuestionsService _service = QuestionsService();
  late Future<List<AdminQuestion>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminQuestion>> _load() => _service.getQuestions(widget.examId);

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _editQuestion({AdminQuestion? question}) async {
    final result = await showDialog<_QuestionData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionDialog(question: question),
    );
    if (!mounted || result == null) return;

    try {
      if (question == null) {
        await _service.createQuestion(
          examId: widget.examId,
          questionText: result.text,
          explanation: result.explanation,
          options: result.options,
          correctOptionIndex: result.correctIndex,
        );
      } else {
        await _service.updateQuestion(
          id: question.id,
          questionText: result.text,
          explanation: result.explanation,
          options: result.options,
          correctOptionIndex: result.correctIndex,
        );
      }
      if (!mounted) return;
      _message(question == null ? 'Question created.' : 'Question updated.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Error: $e', error: true);
    }
  }

  Future<void> _delete(AdminQuestion question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('This will delete the question, its options, and correct answer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      await _service.deleteQuestion(question.id);
      if (!mounted) return;
      _message('Question deleted.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Error: $e', error: true);
    }
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

    return Material(
      color: scheme.surface,
      child: FutureBuilder<List<AdminQuestion>>(
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
          final query = _search.trim().toLowerCase();
          final questions = query.isEmpty
              ? all
              : all.where((q) => q.questionText.toLowerCase().contains(query)).toList();

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
                                'Question Bank',
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.examTitle} • ${all.length} questions',
                                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _editQuestion(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Question'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _search = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search questions...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: questions.isEmpty
                    ? const Center(child: Text('No questions found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        itemCount: questions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final q = questions[index];
                          final correctIndex = q.correctOptionId == null
                              ? -1
                              : q.options.indexWhere((o) => o.id == q.correctOptionId);

                          return Card(
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(child: Text('${index + 1}')),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          q.questionText,
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editQuestion(question: q);
                                          } else if (value == 'delete') {
                                            _delete(q);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ...List.generate(q.options.length, (i) {
                                    final correct = i == correctIndex;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 7),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: correct
                                            ? scheme.primaryContainer
                                            : scheme.surfaceContainerHighest.withValues(alpha: .35),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            correct
                                                ? Icons.check_circle_rounded
                                                : Icons.radio_button_unchecked_rounded,
                                            size: 18,
                                            color: correct ? scheme.primary : scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(q.options[i].optionText)),
                                        ],
                                      ),
                                    );
                                  }),
                                  if ((q.explanation ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Explanation: ${q.explanation}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionData {
  final String text;
  final String? explanation;
  final List<String> options;
  final int correctIndex;

  const _QuestionData({
    required this.text,
    required this.explanation,
    required this.options,
    required this.correctIndex,
  });
}

class _QuestionDialog extends StatefulWidget {
  final AdminQuestion? question;

  const _QuestionDialog({this.question});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _text;
  late final TextEditingController _explanation;
  late List<TextEditingController> _options;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _text = TextEditingController(text: q?.questionText ?? '');
    _explanation = TextEditingController(text: q?.explanation ?? '');
    _options = q == null || q.options.isEmpty
        ? List.generate(4, (_) => TextEditingController())
        : q.options.map((o) => TextEditingController(text: o.optionText)).toList();

    if (q?.correctOptionId != null) {
      final index = q!.options.indexWhere((o) => o.id == q.correctOptionId);
      if (index >= 0) _correct = index;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _explanation.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _options.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final controller = _options.removeAt(index);
    controller.dispose();
    setState(() {
      if (_correct == index) {
        _correct = 0;
      } else if (_correct > index) {
        _correct--;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _QuestionData(
        text: _text.text.trim(),
        explanation: _explanation.text.trim().isEmpty ? null : _explanation.text.trim(),
        options: _options.map((c) => c.text.trim()).toList(),
        correctIndex: _correct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.question != null;

    return AlertDialog(
      title: Text(editing ? 'Edit Question' : 'Add Question'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: RadioGroup<int>(
              groupValue: _correct,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _correct = value;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _text,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      prefixIcon: Icon(Icons.help_outline_rounded),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Enter the question' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _explanation,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Explanation (optional)',
                      prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_options.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Radio<int>(value: index),
                          Expanded(
                            child: TextFormField(
                              controller: _options[index],
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                                prefixIcon: const Icon(Icons.radio_button_unchecked_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Enter option text' : null,
                            ),
                          ),
                          if (_options.length > 2)
                            IconButton(
                              tooltip: 'Remove option',
                              onPressed: () => _removeOption(index),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Option'),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose the correct answer with the radio button.'),
                  ),
                ],
              ),
            ),
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
          child: Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
