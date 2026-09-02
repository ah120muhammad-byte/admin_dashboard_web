import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/lecture_content_service.dart';
import '../../../core/services/lectures_service.dart';

class ModuleManagementScreen extends StatefulWidget {
  final LectureModule module;

  const ModuleManagementScreen({super.key, required this.module});

  @override
  State<ModuleManagementScreen> createState() => _ModuleManagementScreenState();
}

class _ModuleManagementScreenState extends State<ModuleManagementScreen> {
  final LecturesService _lecturesService = LecturesService();
  final LectureContentService _contentService = LectureContentService();

  late Future<_ModuleData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ModuleData> _loadData() async {
    final results = await Future.wait<dynamic>([
      _lecturesService.getLectures(),
      _contentService.getLectureFiles(),
    ]);

    final lectures = (results[0] as List<AdminLecture>)
        .where((lecture) => lecture.moduleId == widget.module.id)
        .toList();
    final files = results[1] as List<LectureFileItem>;

    return _ModuleData(
      lectures: lectures,
      files: files,
    );
  }

  Future<void> _refresh() async {
    final future = _loadData();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _showLectureDialog({AdminLecture? lecture}) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: lecture?.title ?? '');
    final descriptionController =
        TextEditingController(text: lecture?.description ?? '');
    final orderController =
        TextEditingController(text: '${lecture?.displayOrder ?? 0}');

    try {
      final result = await showDialog<_LectureFormResult>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(lecture == null ? 'Add Lecture' : 'Edit Lecture'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.module.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Lecture Title',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter lecture title'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Display Order',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      validator: (value) =>
                          int.tryParse(value?.trim() ?? '') == null
                              ? 'Enter a valid number'
                              : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(
                  dialogContext,
                  _LectureFormResult(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    displayOrder: int.parse(orderController.text.trim()),
                  ),
                );
              },
              icon: Icon(lecture == null ? Icons.add_rounded : Icons.save_outlined),
              label: Text(lecture == null ? 'Add Lecture' : 'Save Changes'),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      if (lecture == null) {
        await _lecturesService.createLecture(
          moduleId: widget.module.id,
          title: result.title,
          description: result.description,
          displayOrder: result.displayOrder,
        );
      } else {
        await _lecturesService.updateLecture(
          id: lecture.id,
          moduleId: widget.module.id,
          title: result.title,
          description: result.description,
          displayOrder: result.displayOrder,
        );
      }

      if (!mounted) return;
      _showMessage(lecture == null ? 'Lecture added successfully.' : 'Lecture updated successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      orderController.dispose();
    }
  }

  Future<void> _addFile(AdminLecture lecture, String fileType) async {
    if (_busy) return;

    final extensions = switch (fileType) {
      'pdf' => <String>['pdf'],
      'audio' => <String>['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'],
      'video' => <String>['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'],
      _ => <String>[],
    };

    setState(() {
      _busy = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
        allowMultiple: false,
      );

      if (!mounted || result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showMessage('Unable to read the selected file.', error: true);
        return;
      }

      final titleController = TextEditingController(
        text: picked.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
      final orderController = TextEditingController(
        text: '${_nextFileOrder(lecture.id)}',
      );
      final formKey = GlobalKey<FormState>();

      try {
        final details = await showDialog<_FileFormResult>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(_fileIcon(fileType)),
                const SizedBox(width: 10),
                Text('Add ${fileType.toUpperCase()}'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Content Title',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter content title'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Display Order',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      validator: (value) =>
                          int.tryParse(value?.trim() ?? '') == null
                              ? 'Enter a valid number'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        picked.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                    _FileFormResult(
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

        await _contentService.addLectureFile(
          lectureId: lecture.id,
          title: details.title,
          fileType: fileType,
          bytes: bytes,
          fileName: picked.name,
          displayOrder: details.displayOrder,
        );

        if (!mounted) return;
        _showMessage('${fileType.toUpperCase()} added successfully.');
        await _refresh();
      } finally {
        titleController.dispose();
        orderController.dispose();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error adding file: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  int _nextFileOrder(String lectureId) {
    return 1;
  }

  Future<void> _toggleLecturePublished(AdminLecture lecture) async {
    try {
      await _lecturesService.setPublished(
        id: lecture.id,
        value: !lecture.isPublished,
      );
      if (!mounted) return;
      _showMessage(lecture.isPublished ? 'Lecture unpublished.' : 'Lecture published.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _toggleLectureActive(AdminLecture lecture) async {
    try {
      await _lecturesService.setActive(
        id: lecture.id,
        value: !lecture.isActive,
      );
      if (!mounted) return;
      _showMessage(lecture.isActive ? 'Lecture deactivated.' : 'Lecture activated.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _openFile(LectureFileItem file) async {
    try {
      final url = await _contentService.createFileUrl(file);
      if (!mounted) return;
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid file URL.');

      // url_launcher is intentionally avoided here so module management stays
      // focused on CRUD; the existing Files screen remains the dedicated viewer.
      _showMessage('File URL ready: $url');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to prepare file: $e', error: true);
    }
  }

  Future<void> _deleteFile(LectureFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.title}"? This removes the storage file and record.'),
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
      await _contentService.deleteLectureFile(file: file);
      if (!mounted) return;
      _showMessage('File deleted successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error deleting file: $e', error: true);
    }
  }

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

  IconData _fileIcon(String type) {
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

  Color _fileColor(BuildContext context, String type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type.toLowerCase()) {
      case 'pdf':
        return scheme.error;
      case 'audio':
        return scheme.primary;
      case 'video':
        return scheme.secondary;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_ModuleData>(
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
        final totalFiles = data.files.length;
        final published = data.lectures.where((e) => e.isPublished).length;
        final active = data.lectures.where((e) => e.isActive).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to modules',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.module.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage lectures and learning files inside this module.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                        onPressed: () => _showLectureDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Lecture'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(label: 'Lectures', value: '${data.lectures.length}', icon: Icons.menu_book_outlined),
                      _StatCard(label: 'Active', value: '$active', icon: Icons.check_circle_outline_rounded),
                      _StatCard(label: 'Published', value: '$published', icon: Icons.visibility_outlined),
                      _StatCard(label: 'Files', value: '$totalFiles', icon: Icons.folder_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: data.lectures.isEmpty
                  ? const _EmptyModuleState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        itemCount: data.lectures.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final lecture = data.lectures[index];
                          final files = data.files
                              .where((file) => file.lectureId == lecture.id)
                              .toList()
                            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

                          return _LectureCard(
                            lecture: lecture,
                            files: files,
                            fileIcon: _fileIcon,
                            fileColor: _fileColor,
                            onEdit: () => _showLectureDialog(lecture: lecture),
                            onToggleActive: () => _toggleLectureActive(lecture),
                            onTogglePublished: () => _toggleLecturePublished(lecture),
                            onAddFile: (type) => _addFile(lecture, type),
                            onOpenFile: _openFile,
                            onDeleteFile: _deleteFile,
                            busy: _busy,
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

class _ModuleData {
  final List<AdminLecture> lectures;
  final List<LectureFileItem> files;

  const _ModuleData({required this.lectures, required this.files});
}

class _LectureFormResult {
  final String title;
  final String? description;
  final int displayOrder;

  const _LectureFormResult({
    required this.title,
    required this.description,
    required this.displayOrder,
  });
}

class _FileFormResult {
  final String title;
  final int displayOrder;

  const _FileFormResult({required this.title, required this.displayOrder});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LectureCard extends StatefulWidget {
  final AdminLecture lecture;
  final List<LectureFileItem> files;
  final IconData Function(String) fileIcon;
  final Color Function(BuildContext, String) fileColor;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onTogglePublished;
  final ValueChanged<String> onAddFile;
  final Future<void> Function(LectureFileItem) onOpenFile;
  final Future<void> Function(LectureFileItem) onDeleteFile;
  final bool busy;

  const _LectureCard({
    required this.lecture,
    required this.files,
    required this.fileIcon,
    required this.fileColor,
    required this.onEdit,
    required this.onToggleActive,
    required this.onTogglePublished,
    required this.onAddFile,
    required this.onOpenFile,
    required this.onDeleteFile,
    required this.busy,
  });

  @override
  State<_LectureCard> createState() => _LectureCardState();
}

class _LectureCardState extends State<_LectureCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: CircleAvatar(child: Text('${widget.lecture.displayOrder}')),
            title: Text(
              widget.lecture.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'}'
              ' • ${widget.lecture.isPublished ? 'Published' : 'Draft'}'
              ' • ${widget.lecture.isActive ? 'Active' : 'Inactive'}',
            ),
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  tooltip: 'Edit lecture',
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: widget.lecture.isPublished ? 'Unpublish' : 'Publish',
                  onPressed: widget.onTogglePublished,
                  icon: Icon(
                    widget.lecture.isPublished
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                IconButton(
                  tooltip: widget.lecture.isActive ? 'Deactivate' : 'Activate',
                  onPressed: widget.onToggleActive,
                  icon: Icon(
                    widget.lecture.isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                  ),
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
                  Text(
                    widget.lecture.description?.isNotEmpty == true
                        ? widget.lecture.description!
                        : 'No lecture description.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.busy ? null : () => widget.onAddFile('pdf'),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.busy ? null : () => widget.onAddFile('audio'),
                        icon: const Icon(Icons.audio_file_outlined),
                        label: const Text('Audio'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.busy ? null : () => widget.onAddFile('video'),
                        icon: const Icon(Icons.video_file_outlined),
                        label: const Text('Video'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.files.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No files added to this lecture yet.'),
                    )
                  else
                    ...widget.files.map(
                      (file) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        child: ListTile(
                          leading: Icon(
                            widget.fileIcon(file.fileType),
                            color: widget.fileColor(context, file.fileType),
                          ),
                          title: Text(file.title),
                          subtitle: Text(
                            '${file.fileType.toUpperCase()} • order ${file.displayOrder}'
                            ' • ${file.isActive ? 'Active' : 'Inactive'}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                tooltip: 'Open file',
                                onPressed: () => widget.onOpenFile(file),
                                icon: const Icon(Icons.open_in_new_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete file',
                                onPressed: () => widget.onDeleteFile(file),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
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

class _EmptyModuleState extends StatelessWidget {
  const _EmptyModuleState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              'No lectures in this module',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('Add the first lecture to start building this module.'),
          ],
        ),
      ),
    );
  }
}
