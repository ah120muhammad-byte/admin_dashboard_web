import 'package:flutter/material.dart';

import '../../../core/services/questions_service.dart';

class QuestionsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const QuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<QuestionsScreen> createState() =>
      _QuestionsScreenState();
}

class _QuestionsScreenState
    extends State<QuestionsScreen> {
  final QuestionsService _service =
      QuestionsService();

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
      builder: (context) {
        return _QuestionDialog(
          question: question,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      if (question == null) {
        await _service.createQuestion(
          examId: widget.examId,
          questionText:
              result.questionText,
          explanation:
              result.explanation,
          options: result.options,
          correctOptionIndex:
              result.correctOptionIndex,
        );

        if (!mounted) return;

        _showMessage(
          'Question created successfully.',
        );
      } else {
        await _service.updateQuestion(
          id: question.id,
          questionText:
              result.questionText,
          explanation:
              result.explanation,
          options: result.options,
          correctOptionIndex:
              result.correctOptionIndex,
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
            'Delete Question',
          ),
          content: const Text(
            'Are you sure you want to delete this question?',
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
        'Question deleted.',
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

      body:
          FutureBuilder<List<AdminQuestion>>(
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
            return const Center(
              child: Text(
                'No questions found.',
              ),
            );
          }

          return ListView.separated(
            padding:
                const EdgeInsets.all(20),
            itemCount:
                questions.length,
            separatorBuilder:
                (_, _) =>
                    const SizedBox(
              height: 12,
            ),
            itemBuilder:
                (context, index) {
              final question =
                  questions[index];

              return _QuestionCard(
                question: question,
                number: index + 1,
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
// DIALOG RESULT
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

  late List<TextEditingController>
      _optionControllers;

  int _correctOptionIndex = 0;

  @override
  void initState() {
    super.initState();

    final question = widget.question;

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

      final correctId =
          question.correctOptionId;

      if (correctId != null) {
        final index = question.options
            .indexWhere(
          (option) =>
              option.id == correctId,
        );

        if (index >= 0) {
          _correctOptionIndex = index;
        }
      }
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

    if (_correctOptionIndex >=
        options.length) {
      return;
    }

    Navigator.of(context).pop(
      _QuestionDialogResult(
        questionText:
            _questionController.text.trim(),
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
        width: 650,
        child: Form(
          key: _formKey,
          child:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
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
                    alignLabelWithHint:
                        true,
                  ),
                  validator:
                      (value) {
                    if (value == null ||
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
                    prefixIcon:
                        Icon(
                      Icons
                          .lightbulb_outline_rounded,
                    ),
                    alignLabelWithHint:
                        true,
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Options',
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                // ============================================================
                // OPTIONS
                // ============================================================

                ...List.generate(
                  _optionControllers.length,
                  (index) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: index,
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
                                    const Icon(
                                  Icons
                                      .radio_button_unchecked,
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
                                                  .close_rounded,
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

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child:
                      TextButton.icon(
                    onPressed:
                        _addOption,
                    icon: const Icon(
                      Icons
                          .add_rounded,
                    ),
                    label: const Text(
                      'Add Option',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Select the radio button beside the correct answer.',
                    style:
                        Theme.of(context)
                            .textTheme
                            .bodySmall,
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
// QUESTION CARD
// ============================================================================

class _QuestionCard
    extends StatelessWidget {
  final AdminQuestion question;
  final int number;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.number,
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
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ================================================================
            // HEADER
            // ================================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    '$number',
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child: Text(
                    question.questionText,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons
                        .delete_outline_rounded,
                    color: scheme.error,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            // ================================================================
            // OPTIONS
            // ================================================================

            ...question.options.map(
              (option) {
                final isCorrect =
                    option.id ==
                        question
                            .correctOptionId;

                return Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.only(
                    bottom: 8,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration:
                      BoxDecoration(
                    color: isCorrect
                        ? scheme
                            .primaryContainer
                        : scheme
                            .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius
                            .circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect
                            ? Icons
                                .check_circle_rounded
                            : Icons
                                .radio_button_unchecked,
                        color: isCorrect
                            ? scheme
                                .primary
                            : scheme
                                .onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          option.optionText,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ================================================================
            // EXPLANATION
            // ================================================================

            if (question.explanation !=
                    null &&
                question.explanation!
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),
              Text(
                'Explanation',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  color:
                      scheme.primary,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                question.explanation!,
              ),
            ],
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