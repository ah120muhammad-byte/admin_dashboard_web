import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/lecture_content_service.dart';
import '../../../core/services/lectures_service.dart';

class ModuleManagementScreen extends StatefulWidget {
  final LectureModule module;

  const ModuleManagementScreen({super.key, required this.module});

  @override
  State<ModuleManagementScreen> createState() => _ModuleManagementScreenState();
}

class _ModuleManagementScreenState extends State<ModuleManagementScreen> {
  final _lectures = LecturesService();
  final _files = LectureContentService();

  late Future<_Data> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final result = await Future.wait<dynamic>([
      _lectures.getLectures(),
      _files.getLectureFiles(),
    ]);

    final lectures = (result[0] as List<AdminLecture>)
        .where((e) => e.moduleId == widget.module.id)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final files = result[1] as List<LectureFileItem>;
    return _Data(lectures: lectures, files: files);
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _editLecture({AdminLecture? lecture}) async {
    final title = TextEditingController(text: lecture?.title ?? '');
    final description = TextEditingController(text: lecture?.description ?? '');
    final order = TextEditingController(text: '${lecture?.displayOrder ?? 1}');
    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<_LectureForm>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(lecture == null ? 'Add Lecture' : 'Edit Lecture'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Lecture Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Lecture title is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      prefixIcon: Icon(Icons.format_list_numbered_rounded),
                    ),
                    validator: (v) => int.tryParse(v?.trim() ?? '') == null
                        ? 'Enter a valid number'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  _LectureForm(
                    title: title.text.trim(),
                    description: description.text.trim().isEmpty
                        ? null
                        : description.text.trim(),
                    order: int.parse(order.text.trim()),
                  ),
                );
              },
              child: Text(lecture == null ? 'Add Lecture' : 'Save Changes'),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      if (lecture == null) {
        await _lectures.createLecture(
          moduleId: widget.module.id,
          title: result.title,
          description: result.description,
          displayOrder: result.order,
        );
      } else {
        await _lectures.updateLecture(
          id: lecture.id,
          moduleId: widget.module.id,
          title: result.title,
          description: result.description,
          displayOrder: result.order,
        );
      }

      if (!mounted) return;
      _message(lecture == null ? 'Lecture added successfully.' : 'Lecture updated successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Error: $e', error: true);
    } finally {
      title.dispose();
      description.dispose();
      order.dispose();
    }
  }

  Future<void> _addFile(AdminLecture lecture, String type) async {
    if (_busy) return;

    final extensions = switch (type) {
      'pdf' => ['pdf'],
      'audio' => ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'],
      'video' => ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'],
      _ => <String>[],
    };

    setState(() {
      _busy = true;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );

      if (!mounted || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        _message('Unable to read the selected file.', error: true);
        return;
      }

      final titleController = TextEditingController(
        text: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
      final formKey = GlobalKey<FormState>();

      try {
        final title = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Add ${type.toUpperCase()}'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Content Title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Content title is required'
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(dialogContext, titleController.text.trim());
                },
                child: const Text('Upload'),
              ),
            ],
          ),
        );

        if (!mounted || title == null) return;

        await _files.addLectureFile(
          lectureId: lecture.id,
          title: title,
          fileType: type,
          bytes: file.bytes!,
          fileName: file.name,
        );

        if (!mounted) return;
        _message('${type.toUpperCase()} uploaded successfully.');
        await _refresh();
      } finally {
        titleController.dispose();
      }
    } catch (e) {
      if (mounted) _message('Upload failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openFile(LectureFileItem file) async {
    try {
      final url = await _files.createFileUrl(file);
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid file URL.');
      final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!opened) throw Exception('Unable to open file.');
    } catch (e) {
      if (mounted) _message('Unable to open file: $e', error: true);
    }
  }

  Future<void> _deleteFile(LectureFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.title}"? This will remove the storage file too.'),
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
      await _files.deleteLectureFile(file: file);
      if (!mounted) return;
      _message('File deleted successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Delete failed: $e', error: true);
    }
  }

  Future<void> _toggleLecture(AdminLecture lecture, bool published) async {
    try {
      if (published) {
        await _lectures.setPublished(id: lecture.id, value: !lecture.isPublished);
      } else {
        await _lectures.setActive(id: lecture.id, value: !lecture.isActive);
      }
      if (!mounted) return;
      _message('Lecture updated successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Update failed: $e', error: true);
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

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'audio':
        return Icons.audio_file_rounded;
      case 'video':
        return Icons.video_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.name),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _editLecture(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Lecture'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<_Data>(
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
                label: const Text('Reload Module'),
              ),
            );
          }

          final data = snapshot.data!;
          final filesCount = data.files.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Stat(label: 'Lectures', value: '${data.lectures.length}', icon: Icons.menu_book_outlined),
                    _Stat(label: 'Active', value: '${data.lectures.where((e) => e.isActive).length}', icon: Icons.check_circle_outline),
                    _Stat(label: 'Published', value: '${data.lectures.where((e) => e.isPublished).length}', icon: Icons.visibility_outlined),
                    _Stat(label: 'Files', value: '$filesCount', icon: Icons.folder_outlined),
                  ],
                ),
                const SizedBox(height: 20),
                if (data.lectures.isEmpty)
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No lectures in this module yet.',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  )
                else
                  ...data.lectures.map((lecture) {
                    final files = data.files
                        .where((file) => file.lectureId == lecture.id)
                        .toList()
                      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

                    return _LectureSection(
                      lecture: lecture,
                      files: files,
                      icon: _icon,
                      onEdit: () => _editLecture(lecture: lecture),
                      onPublish: () => _toggleLecture(lecture, true),
                      onActive: () => _toggleLecture(lecture, false),
                      onAddFile: (type) => _addFile(lecture, type),
                      onOpenFile: _openFile,
                      onDeleteFile: _deleteFile,
                      busy: _busy,
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Data {
  final List<AdminLecture> lectures;
  final List<LectureFileItem> files;

  const _Data({required this.lectures, required this.files});
}

class _LectureForm {
  final String title;
  final String? description;
  final int order;

  const _LectureForm({required this.title, required this.description, required this.order});
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 175,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LectureSection extends StatefulWidget {
  final AdminLecture lecture;
  final List<LectureFileItem> files;
  final IconData Function(String) icon;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onActive;
  final ValueChanged<String> onAddFile;
  final Future<void> Function(LectureFileItem) onOpenFile;
  final Future<void> Function(LectureFileItem) onDeleteFile;
  final bool busy;

  const _LectureSection({
    required this.lecture,
    required this.files,
    required this.icon,
    required this.onEdit,
    required this.onPublish,
    required this.onActive,
    required this.onAddFile,
    required this.onOpenFile,
    required this.onDeleteFile,
    required this.busy,
  });

  @override
  State<_LectureSection> createState() => _LectureSectionState();
}

class _LectureSectionState extends State<_LectureSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: CircleAvatar(child: Text('${widget.lecture.displayOrder}')),
            title: Text(widget.lecture.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'} • '
              '${widget.lecture.isPublished ? 'Published' : 'Draft'} • '
              '${widget.lecture.isActive ? 'Active' : 'Inactive'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: widget.onEdit, tooltip: 'Edit', icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  onPressed: widget.onPublish,
                  tooltip: widget.lecture.isPublished ? 'Unpublish' : 'Publish',
                  icon: Icon(widget.lecture.isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
                IconButton(
                  onPressed: widget.onActive,
                  tooltip: widget.lecture.isActive ? 'Deactivate' : 'Activate',
                  icon: Icon(widget.lecture.isActive ? Icons.toggle_on_outlined : Icons.toggle_off_outlined),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(onPressed: widget.busy ? null : () => widget.onAddFile('pdf'), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Add PDF')),
                      OutlinedButton.icon(onPressed: widget.busy ? null : () => widget.onAddFile('audio'), icon: const Icon(Icons.audio_file_outlined), label: const Text('Add Audio')),
                      OutlinedButton.icon(onPressed: widget.busy ? null : () => widget.onAddFile('video'), icon: const Icon(Icons.video_file_outlined), label: const Text('Add Video')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.files.isEmpty)
                    Text('No files added to this lecture yet.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                  else
                    ...widget.files.map(
                      (file) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(widget.icon(file.fileType), color: scheme.primary),
                          title: Text(file.title),
                          subtitle: Text('${file.fileType.toUpperCase()} • order ${file.displayOrder} • ${file.isActive ? 'Active' : 'Inactive'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(onPressed: () => widget.onOpenFile(file), tooltip: 'Open', icon: const Icon(Icons.open_in_new_rounded)),
                              IconButton(onPressed: () => widget.onDeleteFile(file), tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
