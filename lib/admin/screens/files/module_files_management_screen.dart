import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/lecture_content_service.dart';
import '../../../core/services/lectures_service.dart';

class ModuleFilesManagementScreen extends StatefulWidget {
  final LectureModule module;

  const ModuleFilesManagementScreen({super.key, required this.module});

  @override
  State<ModuleFilesManagementScreen> createState() =>
      _ModuleFilesManagementScreenState();
}

class _ModuleFilesManagementScreenState
    extends State<ModuleFilesManagementScreen> {
  final LecturesService _lecturesService = LecturesService();
  final LectureContentService _service = LectureContentService();

  late Future<_ModuleFilesData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ModuleFilesData> _load() async {
    final results = await Future.wait<dynamic>([
      _lecturesService.getLectures(),
      _service.getLectureFiles(),
    ]);

    final lectures = (results[0] as List<AdminLecture>)
        .where((e) => e.moduleId == widget.module.id)
        .toList();
    final files = results[1] as List<LectureFileItem>;

    final moduleLectureIds = lectures.map((e) => e.id).toSet();
    final moduleFiles = files.where((e) => moduleLectureIds.contains(e.lectureId)).toList();

    return _ModuleFilesData(lectures: lectures, files: moduleFiles);
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _future = future);
    await future;
  }

  Future<void> _addFile(AdminLecture lecture, String type) async {
    if (_busy) return;

    final extensions = switch (type) {
      'pdf' => ['pdf'],
      'audio' => ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'],
      'video' => ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'],
      _ => <String>[],
    };

    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _message('Unable to read the selected file.', error: true);
        return;
      }

      final titleController = TextEditingController(
        text: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
      final orderController = TextEditingController(text: '${_nextOrder(lecture.id)}');
      final formKey = GlobalKey<FormState>();

      try {
        final details = await showDialog<_FileDetails>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text('Add ${type.toUpperCase()}'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'File Title'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Display Order'),
                      validator: (v) => int.tryParse(v?.trim() ?? '') == null ? 'Enter a valid number' : null,
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: Text(file.name)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    dialogContext,
                    _FileDetails(
                      title: titleController.text.trim(),
                      displayOrder: int.parse(orderController.text.trim()),
                    ),
                  );
                },
                child: const Text('Add File'),
              ),
            ],
          ),
        );

        if (!mounted || details == null) return;

        await _service.addLectureFile(
          lectureId: lecture.id,
          title: details.title,
          fileType: type,
          bytes: bytes,
          fileName: file.name,
          displayOrder: details.displayOrder,
        );

        if (!mounted) return;
        _message('${type.toUpperCase()} added successfully.');
        await _refresh();
      } finally {
        titleController.dispose();
        orderController.dispose();
      }
    } catch (e) {
      if (mounted) _message('Error adding file: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _nextOrder(String lectureId) => 1;

  Future<void> _open(LectureFileItem file) async {
    try {
      final url = await _service.createFileUrl(file);
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid file URL.');
      final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!ok) throw Exception('Unable to open file.');
    } catch (e) {
      if (mounted) _message('Unable to open file: $e', error: true);
    }
  }

  Future<void> _editTitle(LectureFileItem file) async {
    final controller = TextEditingController(text: file.title);
    try {
      final title = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit File Title'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (!mounted || title == null || title.isEmpty) return;
      await _service.updateFileTitle(id: file.id, title: title);
      if (!mounted) return;
      _message('File title updated.');
      await _refresh();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _toggle(LectureFileItem file) async {
    try {
      await _service.setFileActive(id: file.id, value: !file.isActive);
      if (!mounted) return;
      _message(file.isActive ? 'File deactivated.' : 'File activated.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Error: $e', error: true);
    }
  }

  Future<void> _delete(LectureFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      await _service.deleteLectureFile(file: file);
      if (!mounted) return;
      _message('File deleted successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Error deleting file: $e', error: true);
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

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'audio': return Icons.audio_file_rounded;
      case 'video': return Icons.video_file_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _color(BuildContext context, String type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type.toLowerCase()) {
      case 'pdf': return scheme.error;
      case 'audio': return scheme.primary;
      case 'video': return scheme.secondary;
      default: return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_ModuleFilesData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')));
        }

        final data = snapshot.data!;
        final pdf = data.files.where((f) => f.fileType == 'pdf').length;
        final audio = data.files.where((f) => f.fileType == 'audio').length;
        final video = data.files.where((f) => f.fileType == 'video').length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  IconButton(tooltip: 'Back', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.module.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Manage PDF, audio and video files by lecture.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 12,
                children: [
                  _Stat(label: 'Lectures', value: '${data.lectures.length}', icon: Icons.menu_book_outlined),
                  _Stat(label: 'PDF', value: '$pdf', icon: Icons.picture_as_pdf_outlined),
                  _Stat(label: 'Audio', value: '$audio', icon: Icons.audio_file_outlined),
                  _Stat(label: 'Video', value: '$video', icon: Icons.video_file_outlined),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  itemCount: data.lectures.length,
                  itemBuilder: (context, index) {
                    final lecture = data.lectures[index];
                    final files = data.files.where((f) => f.lectureId == lecture.id).toList()
                      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(child: Text('${lecture.displayOrder}')),
                                const SizedBox(width: 12),
                                Expanded(child: Text(lecture.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                                PopupMenuButton<String>(
                                  onSelected: (type) => _addFile(lecture, type),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'pdf', child: Text('Add PDF')),
                                    PopupMenuItem(value: 'audio', child: Text('Add Audio')),
                                    PopupMenuItem(value: 'video', child: Text('Add Video')),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (files.isEmpty)
                              Padding(padding: const EdgeInsets.all(12), child: Text('No files in this lecture.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
                            else
                              ...files.map((file) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: Icon(_icon(file.fileType), color: _color(context, file.fileType)),
                                title: Text(file.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${file.fileType.toUpperCase()} • Order ${file.displayOrder} • ${file.isActive ? 'Active' : 'Inactive'}'),
                                onTap: () => _open(file),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'open': _open(file); break;
                                      case 'edit': _editTitle(file); break;
                                      case 'toggle': _toggle(file); break;
                                      case 'delete': _delete(file); break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'open', child: Text('Open')),
                                    const PopupMenuItem(value: 'edit', child: Text('Edit Title')),
                                    PopupMenuItem(value: 'toggle', child: Text(file.isActive ? 'Deactivate' : 'Activate')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModuleFilesData {
  final List<AdminLecture> lectures;
  final List<LectureFileItem> files;

  const _ModuleFilesData({required this.lectures, required this.files});
}

class _FileDetails {
  final String title;
  final int displayOrder;

  const _FileDetails({required this.title, required this.displayOrder});
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
