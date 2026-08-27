import 'package:flutter/material.dart';
import '../../../core/services/exams_service.dart';
import 'questions_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final ExamsService _service = ExamsService();

  late Future<List<AdminExam>> _examsFuture;

  List<ExamLecture> _lectures = [];

  String? _selectedLectureId;

  @override
  void initState() {
    super.initState();

    _examsFuture = _loadData();
  }

  // ==========================================================================
  // LOAD
  // ==========================================================================

  Future<List<AdminExam>> _loadData() async {
    final lectures = await _service.getLectures();

    if (mounted) {
      setState(() {
        _lectures = lectures;
      });
    }

    return _service.getExams();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    final future = _loadData();

    setState(() {
      _examsFuture = future;
    });

    await future;
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  List<AdminExam> _filterExams(List<AdminExam> exams) {
    if (_selectedLectureId == null) {
      return exams;
    }

    return exams.where((exam) => exam.lectureId == _selectedLectureId).toList();
  }

  // ==========================================================================
  // GET LECTURE
  // ==========================================================================

  ExamLecture? _lectureFor(String lectureId) {
    for (final lecture in _lectures) {
      if (lecture.id == lectureId) {
        return lecture;
      }
    }

    return null;
  }

  // ==========================================================================
  // ADD / EDIT
  // ==========================================================================

  Future<void> _showExamDialog({AdminExam? exam}) async {
    if (_lectures.isEmpty) {
      _showMessage('No active lectures available.', error: true);

      return;
    }

    final result = await showDialog<_ExamDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ExamDialog(exam: exam, lectures: _lectures);
      },
    );

    if (result == null) {
      return;
    }

    try {
      if (exam == null) {
        await _service.createExam(
          lectureId: result.lectureId,
          title: result.title,
          description: result.description,
          durationMinutes: result.durationMinutes,
          passingScore: result.passingScore,
        );

        if (!mounted) return;

        _showMessage('Exam created successfully.');
      } else {
        await _service.updateExam(
          id: exam.id,
          lectureId: result.lectureId,
          title: result.title,
          description: result.description,
          durationMinutes: result.durationMinutes,
          passingScore: result.passingScore,
        );

        if (!mounted) return;

        _showMessage('Exam updated successfully.');
      }

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error: $e', error: true);
    }
  }

  // ==========================================================================
  // ACTIVE
  // ==========================================================================

  Future<void> _toggleActive(AdminExam exam) async {
    try {
      await _service.setActive(id: exam.id, value: !exam.isActive);

      if (!mounted) return;

      _showMessage(exam.isActive ? 'Exam deactivated.' : 'Exam activated.');

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error: $e', error: true);
    }
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(String message, {bool error = false}) {
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

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ======================================================================
      // ADD EXAM
      // ======================================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _lectures.isEmpty
            ? null
            : () {
                _showExamDialog();
              },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Exam'),
      ),

      // ======================================================================
      // BODY
      // ======================================================================
      body: FutureBuilder<List<AdminExam>>(
        future: _examsFuture,
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

          final exams = _filterExams(snapshot.data ?? []);

          return Column(
            children: [
              // ==============================================================
              // FILTER
              // ==============================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedLectureId,
                      decoration: const InputDecoration(
                        labelText: 'Lecture',
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Lectures'),
                        ),
                        ..._lectures.map(
                          (lecture) => DropdownMenuItem<String?>(
                            value: lecture.id,
                            child: Text(
                              lecture.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedLectureId = value;
                        });
                      },
                    ),
                  ),
                ),
              ),

              // ==============================================================
              // LIST
              // ==============================================================
              Expanded(
                child: exams.isEmpty
                    ? const Center(child: Text('No exams found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: exams.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final exam = exams[index];

                          final lecture = _lectureFor(exam.lectureId);

                          return _ExamTile(
                            exam: exam,
                            lectureName: lecture?.title ?? 'Unknown Lecture',
                            onEdit: () {
                              _showExamDialog(exam: exam);
                            },
                            onToggleActive: () {
                              _toggleActive(exam);
                            },
                            onQuestions: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuestionsScreen(
        examId: exam.id,
        examTitle: exam.title,
      ),
    ),
  );
},
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

// ============================================================================
// DIALOG RESULT
// ============================================================================

class _ExamDialogResult {
  final String lectureId;
  final String title;
  final String? description;
  final int durationMinutes;
  final double passingScore;

  const _ExamDialogResult({
    required this.lectureId,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.passingScore,
  });
}

// ============================================================================
// EXAM DIALOG
// ============================================================================

class _ExamDialog extends StatefulWidget {
  final AdminExam? exam;
  final List<ExamLecture> lectures;

  const _ExamDialog({required this.exam, required this.lectures});

  @override
  State<_ExamDialog> createState() => _ExamDialogState();
}

class _ExamDialogState extends State<_ExamDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;

  late final TextEditingController _descriptionController;

  late final TextEditingController _durationController;

  late final TextEditingController _passingController;

  String? _lectureId;

  @override
  void initState() {
    super.initState();

    final exam = widget.exam;

    _titleController = TextEditingController(text: exam?.title ?? '');

    _descriptionController = TextEditingController(
      text: exam?.description ?? '',
    );

    _durationController = TextEditingController(
      text: exam?.durationMinutes.toString() ?? '30',
    );

    _passingController = TextEditingController(
      text: exam?.passingScore.toString() ?? '50',
    );

    _lectureId =
        exam?.lectureId ??
        (widget.lectures.isNotEmpty ? widget.lectures.first.id : null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _passingController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_lectureId == null || _lectureId!.isEmpty) {
      return;
    }

    final duration = int.tryParse(_durationController.text.trim());

    final passing = double.tryParse(_passingController.text.trim());

    if (duration == null || duration <= 0) {
      return;
    }

    if (passing == null || passing < 0 || passing > 100) {
      return;
    }

    final descriptionText = _descriptionController.text.trim();

    Navigator.of(context).pop(
      _ExamDialogResult(
        lectureId: _lectureId!,
        title: _titleController.text.trim(),
        description: descriptionText.isEmpty ? null : descriptionText,
        durationMinutes: duration,
        passingScore: passing,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final editing = widget.exam != null;

    return AlertDialog(
      title: Text(editing ? 'Edit Exam' : 'Add Exam'),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ============================================================
                // LECTURE
                // ============================================================
                DropdownButtonFormField<String>(
                  initialValue: _lectureId,
                  decoration: const InputDecoration(
                    labelText: 'Lecture',
                    prefixIcon: Icon(Icons.school_rounded),
                  ),
                  items: widget.lectures
                      .map(
                        (lecture) => DropdownMenuItem<String>(
                          value: lecture.id,
                          child: Text(
                            lecture.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _lectureId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select a lecture';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ============================================================
                // TITLE
                // ============================================================
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Exam Title',
                    prefixIcon: Icon(Icons.quiz_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter exam title';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ============================================================
                // DESCRIPTION
                // ============================================================
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                ),

                const SizedBox(height: 16),

                // ============================================================
                // DURATION + PASSING
                // ============================================================
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          suffixText: 'min',
                          prefixIcon: Icon(Icons.timer_rounded),
                        ),
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');

                          if (number == null || number <= 0) {
                            return 'Invalid duration';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _passingController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Passing Score',
                          suffixText: '%',
                          prefixIcon: Icon(Icons.percent_rounded),
                        ),
                        validator: (value) {
                          final number = double.tryParse(value?.trim() ?? '');

                          if (number == null || number < 0 || number > 100) {
                            return 'Use 0 - 100';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Create Exam'),
        ),
      ],
    );
  }
}

// ============================================================================
// EXAM TILE
// ============================================================================

class _ExamTile extends StatelessWidget {
  final AdminExam exam;
  final String lectureName;

  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onQuestions;

  const _ExamTile({
    required this.exam,
    required this.lectureName,
    required this.onEdit,
    required this.onToggleActive,
    required this.onQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),

        // ====================================================================
        // ICON
        // ====================================================================
        leading: CircleAvatar(child: const Icon(Icons.quiz_rounded)),

        // ====================================================================
        // TITLE
        // ====================================================================
        title: Text(
          exam.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),

        // ====================================================================
        // SUBTITLE
        // ====================================================================
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lectureName,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${exam.durationMinutes} min'
                ' • Passing ${exam.passingScore}%'
                '${exam.description != null && exam.description!.trim().isNotEmpty ? ' • ${exam.description}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // ====================================================================
        // ACTIONS
        // ====================================================================
        trailing: Wrap(
          spacing: 4,
          children: [
            // ================================================================
            // QUESTIONS
            // ================================================================
            IconButton(
              tooltip: 'Manage Questions',
              onPressed: onQuestions,
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),

            // ================================================================
            // ACTIVE
            // ================================================================
            IconButton(
              tooltip: exam.isActive ? 'Deactivate' : 'Activate',
              onPressed: onToggleActive,
              icon: Icon(
                exam.isActive
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: exam.isActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),

            // ================================================================
            // EDIT
            // ================================================================
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
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

class _ErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            const Text(
              'Unable to load exams',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
