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
  List<ContentLecture> _lectures = <ContentLecture>[];
  List<LectureFileItem> _files = <LectureFileItem>[];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait<dynamic>([
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
    if (!mounted) return;
    setState(() {
      _loadFuture = future;
    });
    await future;
  }

  List<LectureFileItem> _filesForLecture(String lectureId) {
    final files = _files
        .where((file) => file.lectureId == lectureId)
        .toList(growable: true);

    files.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      if (order != 0) return order;

      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    return files;
  }

  Future<void> _addContent(String lectureId, String fileType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensionsForType(fileType),
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

      final defaultOrder = _nextOrderForLecture(lectureId);
      final details = await showDialog<_FileDetails>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ContentDetailsDialog(
          fileType: fileType,
          fileName: picked.name,
          defaultOrder: defaultOrder,
        ),
      );

      if (!mounted || details == null) return;

      _showBusyMessage('Uploading ${fileType.toUpperCase()}...');

      await _service.addLectureFile(
        lectureId: lectureId,
        title: details.title,
        fileType: fileType,
        bytes: bytes,
        fileName: picked.name,
        displayOrder: details.displayOrder,
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

    var maxOrder = 0;
    for (final file in files) {
      if (file.displayOrder > maxOrder) {
        maxOrder = file.displayOrder;
      }
    }
    return maxOrder + 1;
  }

  List<String> _extensionsForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return <String>['pdf'];
      case 'audio':
        return <String>['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'];
      case 'video':
        return <String>['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'];
      default:
        return <String>[];
    }
  }

  Future<void> _replaceFile(LectureFileItem file) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensionsForType(file.fileType),
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

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace Content'),
          content: Text(
            'Replace "${file.title}" with:\n\n'
            '${picked.name}\n\n'
            'The same content record, title, type and display order will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

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

      final url = await _service.createFileUrl(file);
      final uri = Uri.tryParse(url);

      if (uri == null) {
        throw Exception('Invalid file URL.');
      }

      final launched = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
      );

      if (!launched) {
        throw Exception('Unable to open file.');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to open file: $e', error: true);
    }
  }

  Future<void> _editFileTitle(LectureFileItem file) async {
    final title = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditTitleDialog(initialTitle: file.title),
    );

    if (!mounted || title == null || title.trim().isEmpty) return;

    try {
      await _service.updateFileTitle(
        id: file.id,
        title: title.trim(),
      );

      if (!mounted) return;
      _showMessage('File title updated successfully.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error updating title: $e', error: true);
    }
  }

  Future<void> _toggleFileActive(LectureFileItem file) async {
    try {
      await _service.setFileActive(
        id: file.id,
        value: !file.isActive,
      );

      if (!mounted) return;
      _showMessage(
        file.isActive ? 'File deactivated.' : 'File activated.',
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error updating file: $e', error: true);
    }
  }

  Future<void> _deleteFile(LectureFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Delete "${file.title}"?\n\n'
          'This removes the Storage file and database record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

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

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? Theme.of(context).colorScheme.error : null,
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

  const _FileDetails({
    required this.title,
    required this.displayOrder,
  });
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
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: scheme.surface,
            child: ListTile(
              onTap: () => setState(() => _expanded = !_expanded),
              leading: CircleAvatar(
                child: Text('${widget.lecture.displayOrder}'),
              ),
              title: Text(
                widget.lecture.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${widget.files.length} '
                '${widget.files.length == 1 ? 'file' : 'files'}',
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
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
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
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...widget.files.map(
                      (file) => _FileTile(
                        file: file,
                        icon: widget.fileIcon(file.fileType),
                        iconColor:
                            widget.fileColor(context, file.fileType),
                        onOpen: () => widget.onOpen(file),
                        onReplace: () => widget.onReplace(file),
                        onEdit: () => widget.onEdit(file),
                        onDelete: () => widget.onDelete(file),
                        onToggleActive: () =>
                            widget.onToggleActive(file),
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
        color: file.isActive
            ? scheme.surface
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  file.fileType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            'Order ${file.displayOrder}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
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
                  file.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
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
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentDetailsDialog extends StatefulWidget {
  final String fileType;
  final String fileName;
  final int defaultOrder;

  const _ContentDetailsDialog({
    required this.fileType,
    required this.fileName,
    required this.defaultOrder,
  });

  @override
  State<_ContentDetailsDialog> createState() => _ContentDetailsDialogState();
}

class _ContentDetailsDialogState extends State<_ContentDetailsDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _orderController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.fileName.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      ),
    );
    _orderController = TextEditingController(
      text: widget.defaultOrder.toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  IconData _icon() {
    switch (widget.fileType.toLowerCase()) {
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final order = int.tryParse(_orderController.text.trim());
    if (order == null || order < 1) return;

    Navigator.of(context).pop(
      _FileDetails(
        title: _titleController.text.trim(),
        displayOrder: order,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(_icon()),
          const SizedBox(width: 10),
          Text('Add ${widget.fileType.toUpperCase()}'),
        ],
      ),
      content: SizedBox(
        width: size.width >= 700 ? 440 : size.width * 0.82,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Content Title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter content title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order',
                  prefixIcon:
                      Icon(Icons.format_list_numbered_rounded),
                ),
                validator: (value) {
                  final order = int.tryParse(value?.trim() ?? '');
                  if (order == null || order < 1) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.fileName,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditTitleDialog extends StatefulWidget {
  final String initialTitle;

  const _EditTitleDialog({required this.initialTitle});

  @override
  State<_EditTitleDialog> createState() => _EditTitleDialogState();
}

class _EditTitleDialogState extends State<_EditTitleDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: const Text('Edit File Title'),
      content: SizedBox(
        width: size.width >= 700 ? 440 : size.width * 0.82,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load lecture content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              error,
              textAlign: TextAlign.center,
            ),
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
