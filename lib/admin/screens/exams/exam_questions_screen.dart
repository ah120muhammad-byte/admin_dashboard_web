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
  State<ExamQuestionsScreen> createState() =>
      _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState
    extends State<ExamQuestionsScreen> {
  final ExamQuestionsService _service =
      ExamQuestionsService();

  late Future<List<AdminQuestion>>
      _questionsFuture;

  @override
  void initState() {
    super.initState();

    _questionsFuture =
        _loadQuestions();
  }

  // ==========================================================================
  // LOAD
  // ==========================================================================

  Future<List<AdminQuestion>>
      _loadQuestions() {
    return _service.getQuestions(
      widget.examId,
    );
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    final future = _loadQuestions();

    setState(() {
      _questionsFuture = future;
    });

    await future;
  }

  // ==========================================================================
  // ADD / EDIT
  // ==========================================================================

  Future<void> _showQuestionDialog({
    AdminQuestion? question,
  }) async {
    final result =
        await showDialog<_QuestionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _QuestionDialog(
          question: question,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      final data = QuestionData(
        questionText:
            result.questionText,
        explanation:
            result.explanation,
        options: result.options,
        correctOptionIndex:
            result.correctOptionIndex,
      );

      if (question == null) {
        await _service.createQuestion(
          examId: widget.examId,
          data: data,
        );

        if (!mounted) return;

        _showMessage(
          'Question created successfully.',
        );
      } else {
        await _service.updateQuestion(
          questionId: question.id,
          data: data,
        );

        if (!mounted) return;

        _showMessage(
          'Question updated successfully.',
        );
      }

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  Future<void> _deleteQuestion(
    AdminQuestion question,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Question?',
          ),
          content: const Text(
            'This question and all its options '
            'will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .error,
              ),
              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteQuestion(
        question.id,
      );

      if (!mounted) return;

      _showMessage(
        'Question deleted successfully.',
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // REORDER
  // ==========================================================================

  Future<void> _reorderQuestions(
    List<AdminQuestion> questions,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) {
      newIndex--;
    }

    final updated =
        List<AdminQuestion>.from(
      questions,
    );

    final item =
        updated.removeAt(oldIndex);

    updated.insert(
      newIndex,
      item,
    );

    try {
      await _service.reorderQuestions(
        updated,
      );

      if (!mounted) return;

      setState(() {
        _questionsFuture =
            Future.value(updated);
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error reordering questions: $e',
        error: true,
      );

      await _refresh();
    }
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? Theme.of(context)
                  .colorScheme
                  .error
              : null,
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.examTitle,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ======================================================================
      // ADD
      // ======================================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          _showQuestionDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Question',
        ),
      ),

      // ======================================================================
      // BODY
      // ======================================================================

      body: FutureBuilder<
          List<AdminQuestion>>(
        future: _questionsFuture,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error:
                  snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final questions =
              snapshot.data ?? [];

          if (questions.isEmpty) {
            return _EmptyView(
              onAdd: () {
                _showQuestionDialog();
              },
            );
          }

          return ReorderableListView.builder(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount:
                questions.length,
            onReorder: (
              oldIndex,
              newIndex,
            ) {
              _reorderQuestions(
                questions,
                oldIndex,
                newIndex,
              );
            },
            itemBuilder: (
              context,
              index,
            ) {
              final question =
                  questions[index];

              return _QuestionTile(
                key: ValueKey(
                  question.id,
                ),
                number: index + 1,
                question: question,
                onEdit: () {
                  _showQuestionDialog(
                    question: question,
                  );
                },
                onDelete: () {
                  _deleteQuestion(
                    question,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// QUESTION DIALOG RESULT
// ============================================================================

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

// ============================================================================
// QUESTION DIALOG
// ============================================================================

class _QuestionDialog
    extends StatefulWidget {
  final AdminQuestion? question;

  const _QuestionDialog({
    required this.question,
  });

  @override
  State<_QuestionDialog> createState() =>
      _QuestionDialogState();
}

class _QuestionDialogState
    extends State<_QuestionDialog> {
  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _questionController;

  late final TextEditingController
      _explanationController;

  late final List<TextEditingController>
      _optionControllers;

  int _correctOptionIndex = 0;

  @override
  void initState() {
    super.initState();

    final question =
        widget.question;

    _questionController =
        TextEditingController(
      text:
          question?.questionText ?? '',
    );

    _explanationController =
        TextEditingController(
      text:
          question?.explanation ?? '',
    );

    if (question != null &&
        question.options.isNotEmpty) {
      _optionControllers =
          question.options
              .map(
                (option) =>
                    TextEditingController(
                  text:
                      option.optionText,
                ),
              )
              .toList();

      final correctIndex =
          question.options.indexWhere(
        (option) =>
            option.id ==
            question.correctOptionId,
      );

      _correctOptionIndex =
          correctIndex >= 0
              ? correctIndex
              : 0;
    } else {
      _optionControllers = [
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();

    for (final controller
        in _optionControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ==========================================================================
  // ADD OPTION
  // ==========================================================================

  void _addOption() {
    setState(() {
      _optionControllers.add(
        TextEditingController(),
      );
    });
  }

  // ==========================================================================
  // REMOVE OPTION
  // ==========================================================================

  void _removeOption(
    int index,
  ) {
    if (_optionControllers.length <= 2) {
      return;
    }

    setState(() {
      _optionControllers[index]
          .dispose();

      _optionControllers.removeAt(
        index,
      );

      if (_correctOptionIndex ==
          index) {
        _correctOptionIndex = 0;
      } else if (_correctOptionIndex >
          index) {
        _correctOptionIndex--;
      }
    });
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  void _save() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final options =
        _optionControllers
            .map(
              (controller) =>
                  controller.text.trim(),
            )
            .toList();

    if (options.length < 2) {
      return;
    }

    Navigator.of(context).pop(
      _QuestionDialogResult(
        questionText:
            _questionController.text
                .trim(),
        explanation:
            _explanationController.text
                    .trim()
                    .isEmpty
                ? null
                : _explanationController
                    .text
                    .trim(),
        options: options,
        correctOptionIndex:
            _correctOptionIndex,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final editing =
        widget.question != null;

    return AlertDialog(
      title: Text(
        editing
            ? 'Edit Question'
            : 'Add Question',
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ============================================================
                // QUESTION
                // ============================================================

                TextFormField(
                  controller:
                      _questionController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Question',
                    prefixIcon:
                        Icon(
                      Icons
                          .help_outline_rounded,
                    ),
                  ),
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter the question';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 18,
                ),

                // ============================================================
                // EXPLANATION
                // ============================================================

                TextFormField(
                  controller:
                      _explanationController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Explanation',
                    hintText:
                        'Optional explanation for the correct answer',
                    prefixIcon:
                        Icon(
                      Icons
                          .lightbulb_outline_rounded,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // ============================================================
                // OPTIONS TITLE
                // ============================================================

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Options',
                        style:
                            TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed:
                          _addOption,
                      icon:
                          const Icon(
                        Icons
                            .add_rounded,
                      ),
                      label:
                          const Text(
                        'Add Option',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 8,
                ),

                // ============================================================
                // OPTIONS
                // ============================================================

                ...List.generate(
                  _optionControllers
                      .length,
                  (index) {
                    final isCorrect =
                        _correctOptionIndex ==
                            index;

                    return Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 10,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Radio<int>(
                            value:
                                index,
                            groupValue:
                                _correctOptionIndex,
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setState(() {
                                _correctOptionIndex =
                                    value;
                              });
                            },
                          ),
                          Expanded(
                            child:
                                TextFormField(
                              controller:
                                  _optionControllers[
                                      index],
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Option ${index + 1}',
                                prefixIcon:
                                    Icon(
                                  isCorrect
                                      ? Icons
                                          .check_circle_rounded
                                      : Icons
                                          .radio_button_unchecked_rounded,
                                ),
                                suffixIcon:
                                    _optionControllers
                                                .length >
                                            2
                                        ? IconButton(
                                            tooltip:
                                                'Remove option',
                                            onPressed:
                                                () {
                                              _removeOption(
                                                index,
                                              );
                                            },
                                            icon:
                                                const Icon(
                                              Icons
                                                  .remove_circle_outline_rounded,
                                            ),
                                          )
                                        : null,
                              ),
                              validator:
                                  (value) {
                                if (value ==
                                        null ||
                                    value
                                        .trim()
                                        .isEmpty) {
                                  return 'Enter option text';
                                }

                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Select the radio button next to the correct answer.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context)
                .pop();
          },
          child:
              const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(
            editing
                ? 'Save'
                : 'Create Question',
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// QUESTION TILE
// ============================================================================

class _QuestionTile
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================================
            // DRAG
            // ==================================================================

            Padding(
              padding:
                  const EdgeInsets.only(
                top: 8,
              ),
              child: Icon(
                Icons
                    .drag_indicator_rounded,
                color: scheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            // ==================================================================
            // NUMBER
            // ==================================================================

            CircleAvatar(
              radius: 20,
              child: Text(
                '$number',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(
              width: 14,
            ),

            // ==================================================================
            // CONTENT
            // ==================================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    question.questionText,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  ...question.options
                      .map(
                    (option) {
                      final correct =
                          option.id ==
                              question
                                  .correctOptionId;

                      return Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              correct
                                  ? Icons
                                      .check_circle_rounded
                                  : Icons
                                      .radio_button_unchecked_rounded,
                              size: 18,
                              color: correct
                                  ? scheme
                                      .primary
                                  : scheme
                                      .onSurfaceVariant,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child:
                                  Text(
                                option
                                    .optionText,
                                style:
                                    TextStyle(
                                  fontWeight:
                                      correct
                                          ? FontWeight
                                              .w600
                                          : FontWeight
                                              .normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (question
                              .explanation !=
                          null &&
                      question
                          .explanation!
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'Explanation: ${question.explanation}',
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        color: scheme
                            .onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ==================================================================
            // ACTIONS
            // ==================================================================

            Column(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon:
                      const Icon(
                    Icons
                        .edit_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons
                        .delete_outline_rounded,
                    color:
                        scheme.error,
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

// ============================================================================
// EMPTY VIEW
// ============================================================================

class _EmptyView
    extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyView({
    required this.onAdd,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .quiz_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'No questions yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Add the first question to this exam.',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text(
                'Add Question',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  final String error;
  final Future<void> Function()
      onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .cloud_off_rounded,
              size: 56,
              color: scheme.error,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'Unable to load questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            SelectableText(
              error,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height: 16,
            ),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons
                    .refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}