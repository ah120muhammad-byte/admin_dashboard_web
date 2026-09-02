import 'package:flutter/material.dart';

import '../../../core/services/exams_service.dart';
import 'exam_management_screen.dart';

class ExamsManagementScreen extends StatefulWidget {
  const ExamsManagementScreen({super.key});

  @override
  State<ExamsManagementScreen> createState() => _ExamsManagementScreenState();
}

class _ExamsManagementScreenState extends State<ExamsManagementScreen> {
  final ExamsService _service = ExamsService();
  late Future<_Data> _future;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _lectureId;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _search.addListener(() {
      final value = _search.text.trim().toLowerCase();
      if (value == _query) return;
      setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_Data> _load() async {
    final result = await Future.wait<dynamic>([
      _service.getExams(),
      _service.getLectures(),
    ]);
    return _Data(
      exams: result[0] as List<AdminExam>,
      lectures: result[1] as List<ExamLecture>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _future = future);
    await future;
  }

  ExamLecture? _lecture(List<ExamLecture> lectures, String id) {
    for (final item in lectures) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<AdminExam> _filtered(_Data data) {
    return data.exams.where((exam) {
      if (_lectureId != null && exam.lectureId != _lectureId) return false;
      if (_query.isEmpty) return true;
      final lecture = _lecture(data.lectures, exam.lectureId);
      return exam.title.toLowerCase().contains(_query) ||
          (exam.description ?? '').toLowerCase().contains(_query) ||
          (lecture?.title.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  void _open(AdminExam exam, String lectureName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamManagementScreen(
          exam: exam,
          lectureName: lectureName,
        ),
      ),
    );
  }

  Future<void> _showExamDialog({AdminExam? exam}) async {
    final data = await _future;
    if (!mounted || data.lectures.isEmpty) return;
    final result = await showDialog<_ExamForm>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExamFormDialog(exam: exam, lectures: data.lectures),
    );
    if (!mounted || result == null) return;
    try {
      if (exam == null) {
        await _service.createExam(
          lectureId: result.lectureId,
          title: result.title,
          description: result.description,
          durationMinutes: result.duration,
          passingScore: result.passingScore,
        );
      } else {
        await _service.updateExam(
          id: exam.id,
          lectureId: result.lectureId,
          title: result.title,
          description: result.description,
          durationMinutes: result.duration,
          passingScore: result.passingScore,
        );
      }
      if (!mounted) return;
      _message(exam == null ? 'Exam created successfully.' : 'Exam updated successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Error: $e', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')));
        }
        final data = snapshot.data!;
        final exams = _filtered(data);
        final active = data.exams.where((e) => e.isActive).length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Exam Management', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Control exam settings separately from the question bank.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ])),
                      IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                      const SizedBox(width: 8),
                      FilledButton.icon(onPressed: () => _showExamDialog(), icon: const Icon(Icons.add_rounded), label: const Text('Add Exam')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _Metric('Total', '${data.exams.length}', Icons.quiz_outlined),
                    _Metric('Active', '$active', Icons.check_circle_outline),
                    _Metric('Lectures', '${data.lectures.length}', Icons.menu_book_outlined),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: TextField(controller: _search, decoration: const InputDecoration(hintText: 'Search exams or lectures...', prefixIcon: Icon(Icons.search_rounded)))),
                    const SizedBox(width: 12),
                    SizedBox(width: 300, child: DropdownButtonFormField<String?>(
                      initialValue: _lectureId,
                      decoration: const InputDecoration(labelText: 'Lecture', prefixIcon: Icon(Icons.school_outlined)),
                      items: [const DropdownMenuItem<String?>(value: null, child: Text('All Lectures')), ...data.lectures.map((l) => DropdownMenuItem<String?>(value: l.id, child: Text(l.title, overflow: TextOverflow.ellipsis)))],
                      onChanged: (value) => setState(() => _lectureId = value),
                    )),
                  ]),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: exams.isEmpty
                  ? const Center(child: Text('No exams found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      itemCount: exams.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final exam = exams[index];
                        final lecture = _lecture(data.lectures, exam.lectureId);
                        return _ExamCard(
                          exam: exam,
                          lectureName: lecture?.title ?? 'Unknown Lecture',
                          onOpen: () => _open(exam, lecture?.title ?? 'Unknown Lecture'),
                          onEdit: () => _showExamDialog(exam: exam),
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

class _Data {
  final List<AdminExam> exams;
  final List<ExamLecture> lectures;
  const _Data({required this.exams, required this.lectures});
}

class _Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(label), const SizedBox(width: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))])));
}

class _ExamCard extends StatelessWidget {
  final AdminExam exam;
  final String lectureName;
  final VoidCallback onOpen, onEdit;
  const _ExamCard({required this.exam, required this.lectureName, required this.onOpen, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(elevation: 0, clipBehavior: Clip.antiAlias, child: InkWell(onTap: onOpen, child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      Container(width: 52, height: 52, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.quiz_rounded, color: scheme.primary)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(exam.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(lectureName, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('${exam.durationMinutes} min')), Chip(label: Text('Pass ${exam.passingScore.toStringAsFixed(0)}%')), Chip(label: Text(exam.isActive ? 'Active' : 'Inactive'))])])),
      IconButton(tooltip: 'Edit', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    ]))));
  }
}

class _ExamForm {
  final String lectureId, title;
  final String? description;
  final int duration;
  final double passingScore;
  const _ExamForm({required this.lectureId, required this.title, required this.description, required this.duration, required this.passingScore});
}

class _ExamFormDialog extends StatefulWidget {
  final AdminExam? exam;
  final List<ExamLecture> lectures;
  const _ExamFormDialog({required this.exam, required this.lectures});
  @override
  State<_ExamFormDialog> createState() => _ExamFormDialogState();
}

class _ExamFormDialogState extends State<_ExamFormDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title, _description, _duration, _passing;
  String? _lectureId;
  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _duration = TextEditingController(text: '${e?.durationMinutes ?? 30}');
    _passing = TextEditingController(text: '${e?.passingScore ?? 50}');
    _lectureId = e?.lectureId ?? widget.lectures.first.id;
  }
  @override
  void dispose() { _title.dispose(); _description.dispose(); _duration.dispose(); _passing.dispose(); super.dispose(); }
  void _save() {
    if (!_key.currentState!.validate()) return;
    final duration = int.tryParse(_duration.text.trim());
    final passing = double.tryParse(_passing.text.trim());
    if (_lectureId == null || duration == null || duration <= 0 || passing == null || passing < 0 || passing > 100) return;
    Navigator.of(context).pop(_ExamForm(lectureId: _lectureId!, title: _title.text.trim(), description: _description.text.trim().isEmpty ? null : _description.text.trim(), duration: duration, passingScore: passing));
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.exam == null ? 'Create Exam' : 'Edit Exam'), content: SizedBox(width: 560, child: Form(key: _key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<String>(initialValue: _lectureId, decoration: const InputDecoration(labelText: 'Lecture', prefixIcon: Icon(Icons.school_outlined)), items: widget.lectures.map((l) => DropdownMenuItem(value: l.id, child: Text(l.title, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _lectureId = v), validator: (v) => v == null ? 'Select a lecture' : null),
    const SizedBox(height: 14),
    TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Exam Title', prefixIcon: Icon(Icons.quiz_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Enter exam title' : null),
    const SizedBox(height: 14),
    TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined))),
    const SizedBox(height: 14),
    Row(children: [Expanded(child: TextFormField(controller: _duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration', suffixText: 'min'), validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Invalid' : null)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _passing, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Passing Score', suffixText: '%'), validator: (v) { final n = double.tryParse(v?.trim() ?? ''); return n == null || n < 0 || n > 100 ? '0 - 100' : null; }))]),
  ]))), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')), FilledButton(onPressed: _save, child: Text(widget.exam == null ? 'Create' : 'Save'))]);
}
