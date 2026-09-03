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
  final LecturesService _lectures = LecturesService();
  final LectureContentService _files = LectureContentService();

  late Future<_Data> _future;
  bool _addingFile = false;
  final Set<String> _busyFileIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final results = await Future.wait<dynamic>([
      _lectures.getLectures(),
      _files.getLectureFiles(),
    ]);

    final lectures = (results[0] as List<AdminLecture>)
        .where((e) => e.moduleId == widget.module.id)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final files = results[1] as List<LectureFileItem>;
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

  List<String> _extensionsForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return ['pdf'];
      case 'audio':
        return ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'];
      case 'video':
        return ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'];
      default:
        return <String>[];
    }
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
      _message(
        lecture == null
            ? 'Lecture added successfully.'
            : 'Lecture updated successfully.',
      );
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
    if (_addingFile) return;

    final extensions = _extensionsForType(type);

    setState(() {
      _addingFile = true;
    });

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
          bytes: bytes,
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
          _addingFile = false;
        });
      }
    }
  }

  Future<void> _replaceFile(LectureFileItem file) async {
    if (_busyFileIds.contains(file.id)) return;

    setState(() {
      _busyFileIds.add(file.id);
    });

    try {
      final extensions = _extensionsForType(file.fileType);
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );

      if (!mounted || picked == null || picked.files.isEmpty) return;

      final selected = picked.files.single;
      final bytes = selected.bytes;
      if (bytes == null || bytes.isEmpty) {
        _message('Unable to read the selected file.', error: true);
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace File'),
          content: Text(
            'Replace "${file.title}" with "${selected.name}"? The old storage file will be removed after the new file is linked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      await _files.replaceLectureFile(
        file: file,
        bytes: bytes,
        newFileName: selected.name,
      );

      if (!mounted) return;
      _message('${file.fileType.toUpperCase()} replaced successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Replace failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyFileIds.remove(file.id);
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
    if (_busyFileIds.contains(file.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Delete "${file.title}"? This will remove the storage file too.',
        ),
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

    setState(() {
      _busyFileIds.add(file.id);
    });

    try {
      await _files.deleteLectureFile(file: file);
      if (!mounted) return;
      _message('File deleted successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Delete failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyFileIds.remove(file.id);
        });
      }
    }
  }

  Future<void> _toggleLecture(AdminLecture lecture, bool publish) async {
    try {
      if (publish) {
        await _lectures.setPublished(
          id: lecture.id,
          value: !lecture.isPublished,
        );
      } else {
        await _lectures.setActive(
          id: lecture.id,
          value: !lecture.isActive,
        );
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
          return Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reload Module'),
            ),
          );
        }

        final data = snapshot.data!;
        final active = data.lectures.where((e) => e.isActive).length;
        final published = data.lectures.where((e) => e.isPublished).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
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
                              widget.module.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage lectures and their PDF, audio and video content.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
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
                        onPressed: () => _editLecture(),
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
                      _Stat('Lectures', '${data.lectures.length}', Icons.menu_book_outlined),
                      _Stat('Active', '$active', Icons.check_circle_outline),
                      _Stat('Published', '$published', Icons.visibility_outlined),
                      _Stat('Files', '${data.files.length}', Icons.folder_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: data.lectures.isEmpty
                  ? const _Empty()
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

                          return _LectureExpansion(
                            lecture: lecture,
                            files: files,
                            fileIcon: _fileIcon,
                            onEdit: () => _editLecture(lecture: lecture),
                            onPublish: () => _toggleLecture(lecture, true),
                            onActive: () => _toggleLecture(lecture, false),
                            onAddFile: (type) => _addFile(lecture, type),
                            onOpenFile: _openFile,
                            onReplaceFile: _replaceFile,
                            onDeleteFile: _deleteFile,
                            addingFile: _addingFile,
                            busyFileIds: _busyFileIds,
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

class _LectureExpansion extends StatefulWidget {
  final AdminLecture lecture;
  final List<LectureFileItem> files;
  final IconData Function(String) fileIcon;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onActive;
  final ValueChanged<String> onAddFile;
  final Future<void> Function(LectureFileItem) onOpenFile;
  final Future<void> Function(LectureFileItem) onReplaceFile;
  final Future<void> Function(LectureFileItem) onDeleteFile;
  final bool addingFile;
  final Set<String> busyFileIds;

  const _LectureExpansion({
    required this.lecture,
    required this.files,
    required this.fileIcon,
    required this.onEdit,
    required this.onPublish,
    required this.onActive,
    required this.onAddFile,
    required this.onOpenFile,
    required this.onReplaceFile,
    required this.onDeleteFile,
    required this.addingFile,
    required this.busyFileIds,
  });

  @override
  State<_LectureExpansion> createState() => _LectureExpansionState();
}

class _LectureExpansionState extends State<_LectureExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: scheme.surface,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.primary,
                  child: Text(
                    '${widget.lecture.displayOrder}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  widget.lecture.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Badge(
                      text: widget.lecture.isPublished ? 'Published' : 'Draft',
                      active: widget.lecture.isPublished,
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      text: widget.lecture.isActive ? 'Active' : 'Inactive',
                      active: widget.lecture.isActive,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              color: scheme.surfaceContainerLowest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.lecture.description?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        widget.lecture.description!.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.addingFile
                            ? null
                            : () => widget.onAddFile('pdf'),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Add PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.addingFile
                            ? null
                            : () => widget.onAddFile('audio'),
                        icon: const Icon(Icons.audio_file_rounded),
                        label: const Text('Add Audio'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.addingFile
                            ? null
                            : () => widget.onAddFile('video'),
                        icon: const Icon(Icons.video_file_rounded),
                        label: const Text('Add Video'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Lecture'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onPublish,
                        icon: Icon(
                          widget.lecture.isPublished
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        label: Text(
                          widget.lecture.isPublished ? 'Unpublish' : 'Publish',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onActive,
                        icon: Icon(
                          widget.lecture.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          widget.lecture.isActive ? 'Deactivate' : 'Activate',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (widget.files.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No files in this lecture yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...widget.files.map(
                      (file) {
                        final fileBusy = widget.busyFileIds.contains(file.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: fileBusy
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      widget.fileIcon(file.fileType),
                                      color: scheme.primary,
                                    ),
                              title: Text(
                                file.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${file.fileType.toUpperCase()} • order ${file.displayOrder} • ${file.isActive ? 'Active' : 'Inactive'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Open',
                                    onPressed: fileBusy
                                        ? null
                                        : () => widget.onOpenFile(file),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Replace / Switch File',
                                    onPressed: fileBusy
                                        ? null
                                        : () => widget.onReplaceFile(file),
                                    icon: fileBusy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.swap_horiz_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: fileBusy
                                        ? null
                                        : () => widget.onDeleteFile(file),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
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

  const _LectureForm({
    required this.title,
    required this.description,
    required this.order,
  });
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat(this.label, this.value, this.icon);

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
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool active;

  const _Badge({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

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
              'No lectures yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Add the first lecture to this module.'),
          ],
        ),
      ),
    );
  }
}
