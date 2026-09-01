import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/lecture_content_service.dart';

class LectureContentScreen extends StatefulWidget {
  const LectureContentScreen({super.key});

  @override
  State<LectureContentScreen> createState() => _LectureContentScreenState();
}

class _LectureContentScreenState extends State<LectureContentScreen> {
  final LectureContentService _service = LectureContentService();

  late Future<void> _loadFuture;

  List<ContentLecture> _lectures = [];
  List<LectureFileItem> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _service.getLectures(),
      _service.getLectureFiles(),
    ]);

    if (!mounted) return;

    setState(() {
      _lectures = results[0] as List<ContentLecture>;
      _files = results[1] as List<LectureFileItem>;
    });
  }

  Future<void> _refresh() async {
    final future = _loadData();
    setState(() {
      _loadFuture = future;
    });
    await future;
  }

  List<LectureFileItem> _filesForLecture(String lectureId) {
    final result = _files.where((file) => file.lectureId == lectureId).toList();
    result.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      if (order != 0) return order;
      return a.createdAt?.compareTo(b.createdAt ?? a.createdAt!) ?? 0;
    });
    return result;
  }

  Future<void> _addContent(String lectureId, String fileType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: _extensionsForType(fileType),
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;

      if (bytes == null || bytes.isEmpty) {
        _showMessage('Unable to read the selected file.', error: true);
        return;
      }

      final content = await _showFileDetailsDialog(
        fileType: fileType,
        fileName: picked.name,
        defaultOrder: _nextOrderForLecture(lectureId),
      );

      if (content == null) return;

      _showBusyMessage('Uploading ${fileType.toUpperCase()}...');

      await _service.addLectureFile(
        lectureId: lectureId,
        title: content.title,
        fileType: fileType,
        bytes: bytes,
        fileName: picked.name,
        displayOrder: content.displayOrder,
      );

      if (!mounted) return;
      _showMessage('${fileType.toUpperCase()} added successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error adding content: $e', error: true);
    }
  }

  int _nextOrderForLecture(String lectureId) {
    final files = _filesForLecture(lectureId);
    if (files.isEmpty) return 1;
    return files.map((e) => e.displayOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  List<String> _extensionsForType(String type) {
    switch (type) {
      case 'pdf':
        return ['pdf'];
      case 'audio':
        return ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'];
      case 'video':
        return ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'];
      default:
        return [];
    }
  }

  Future<_FileDetails?> _showFileDetailsDialog({
    required String fileType,
    required String fileName,
    required int defaultOrder,
  }) async {
    final titleController = TextEditingController(
      text: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final orderController = TextEditingController(
      text: '$defaultOrder',
    );
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<_FileDetails>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Add ${fileType.toUpperCase()}'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Content title',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Display order',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      validator: (value) {
                        if (int.tryParse(value?.trim() ?? '') == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(dialogContext).textTheme.bodySmall,
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
                    _FileDetails(
                      title: titleController.text.trim(),
                      displayOrder: int.parse(orderController.text.trim()),
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    } finally {
      titleController.dispose();
      orderController.dispose();
    }
  }

  Future<void> _replaceFile(LectureFileItem file) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: _extensionsForType(file.fileType),
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;

      if (bytes == null || bytes.isEmpty) {
        _showMessage('Unable to read the selected file.', error: true);
        return;
      }

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Replace Content'),
            content: Text(
              'Replace "${file.title}" with:\n\n${picked.name}\n\n'
              'The current file will be replaced, but the lecture content record, '
              'title, type and display order will stay the same.',
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
          );
        },
      );

      if (confirmed != true) return;

      _showBusyMessage('Replacing ${file.fileType.toUpperCase()}...');

      await _service.replaceLectureFile(
        file: file,
        bytes: bytes,
        newFileName: picked.name,
      );

      if (!mounted) return;
      _showMessage('File replaced successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error replacing file: $e', error: true);
    }
  }

  Future<void> _openFile(LectureFileItem file) async {
    try {
      _showBusyMessage('Preparing ${file.fileType.toUpperCase()}...');

      final signedUrl = await _service.createFileUrl(file);
      final uri = Uri.tryParse(signedUrl);
      if (uri == null) throw Exception('Invalid file URL.');

      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) throw Exception('Unable to open file.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to open file: $e', error: true);
    }
  }

  Future<void> _editFileTitle(LectureFileItem file) async {
    final controller = TextEditingController(text: file.title);
    final formKey = GlobalKey<FormState>();

    try {
      final title = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit File Title'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
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
                  Navigator.pop(dialogContext, controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (title == null || title.trim().isEmpty) return;

      await _service.updateFileTitle(id: file.id, title: title.trim());

      if (!mounted) return;
      _showMessage('File title updated successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error updating title: $e', error: true);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _toggleFileActive(LectureFileItem file) async {
    try {
      await _service.setFileActive(id: file.id, value: !file.isActive);
      if (!mounted) return;
      _showMessage(file.isActive ? 'File deactivated.' : 'File activated.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _deleteFile(LectureFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Delete "${file.title}"?\n\n'
            'This removes the database record and the Storage file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteLectureFile(file: file);
      if (!mounted) return;
      _showMessage('File deleted successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error deleting file: $e', error: true);
    }
  }

  IconData _fileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
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

  Color _fileColor(BuildContext context, String fileType) {
    final scheme = Theme.of(context).colorScheme;
    switch (fileType.toLowerCase()) {
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

  void _showBusyMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture Content'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
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

          if (_lectures.isEmpty) {
            return const Center(child: Text('No lectures found.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _lectures.length,
              itemBuilder: (context, index) {
                final lecture = _lectures[index];
                final files = _filesForLecture(lecture.id);

                return _LectureSection(
                  lecture: lecture,
                  files: files,
                  fileIcon: _fileIcon,
                  fileColor: _fileColor,
                  onAdd: (type) => _addContent(lecture.id, type),
                  onOpen: _openFile,
                  onReplace: _replaceFile,
                  onEdit: _editFileTitle,
                  onDelete: _deleteFile,
                  onToggleActive: _toggleFileActive,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FileDetails {
  final String title;
  final int displayOrder;

  const _FileDetails({required this.title, required this.displayOrder});
}

class _LectureSection extends StatefulWidget {
  final ContentLecture lecture;
  final List<LectureFileItem> files;
  final IconData Function(String) fileIcon;
  final Color Function(BuildContext, String) fileColor;
  final Future<void> Function(String) onAdd;
  final Future<void> Function(LectureFileItem) onOpen;
  final Future<void> Function(LectureFileItem) onReplace;
  final Future<void> Function(LectureFileItem) onEdit;
  final Future<void> Function(LectureFileItem) onDelete;
  final Future<void> Function(LectureFileItem) onToggleActive;

  const _LectureSection({
    required this.lecture,
    required this.files,
    required this.fileIcon,
    required this.fileColor,
    required this.onAdd,
    required this.onOpen,
    required this.onReplace,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  State<_LectureSection> createState() => _LectureSectionState();
}

class _LectureSectionState extends State<_LectureSection> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => expanded = !expanded),
            leading: CircleAvatar(child: Text('${widget.lecture.displayOrder}')),
            title: Text(
              widget.lecture.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              '${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.lecture.isPublished
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: widget.lecture.isPublished
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Icon(
                  widget.lecture.isActive
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: widget.lecture.isActive
                      ? scheme.primary
                      : scheme.error,
                ),
                const SizedBox(width: 8),
                Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ],
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Column(
                children: [
                  _AddContentBar(onAdd: widget.onAdd),
                  const SizedBox(height: 10),
                  if (widget.files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No content added to this lecture.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ...widget.files.map(
                      (file) => _FileTile(
                        file: file,
                        icon: widget.fileIcon(file.fileType),
                        iconColor: widget.fileColor(context, file.fileType),
                        onOpen: () => widget.onOpen(file),
                        onReplace: () => widget.onReplace(file),
                        onEdit: () => widget.onEdit(file),
                        onDelete: () => widget.onDelete(file),
                        onToggleActive: () => widget.onToggleActive(file),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddContentBar extends StatelessWidget {
  final Future<void> Function(String) onAdd;

  const _AddContentBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Add content:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            OutlinedButton.icon(
              onPressed: () => onAdd('pdf'),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => onAdd('audio'),
              icon: const Icon(Icons.audio_file_rounded),
              label: const Text('Audio'),
            ),
            OutlinedButton.icon(
              onPressed: () => onAdd('video'),
              icon: const Icon(Icons.video_file_rounded),
              label: const Text('Video'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final LectureFileItem file;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onOpen;
  final VoidCallback onReplace;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _FileTile({
    required this.file,
    required this.icon,
    required this.iconColor,
    required this.onOpen,
    required this.onReplace,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: file.isActive ? scheme.surface : scheme.surfaceContainerHighest,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  file.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  file.fileType.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor),
                ),
              ),
            ],
          ),
          subtitle: Text(
            'Order ${file.displayOrder} • ${file.fileUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                tooltip: 'Open',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              IconButton(
                tooltip: 'Replace',
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
              IconButton(
                tooltip: file.isActive ? 'Deactivate' : 'Activate',
                onPressed: onToggleActive,
                icon: Icon(
                  file.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Edit title',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ),
        ),
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
              'Unable to load lecture content',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
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
