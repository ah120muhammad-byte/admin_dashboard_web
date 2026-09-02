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
    final files = _files.where((file) => file.lectureId == lectureId).toList();
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

      final details = await showDialog<_FileDetails>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ContentDetailsDialog(
          fileType: fileType,
          fileName: picked.name,
          defaultOrder: _nextOrderForLecture(lectureId),
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
      if (file.displayOrder > maxOrder) maxOrder = file.displayOrder;
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
            'Replace "${file.title}" with:\n\n${picked.name}\n\n'
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
      if (uri == null) throw Exception('Invalid file URL.');
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) throw Exception('Unable to open file.');
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
      await _service.updateFileTitle(id: file.id, title: title.trim());
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
      await _service.setFileActive(id: file.id, value: !file.isActive);
      if (!mounted) return;
      _showMessage(file.isActive ? 'File deactivated.' : 'File activated.');
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
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
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
    final theme = Theme.of(context);
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error.toString(), onRetry: _refresh);
        }
        if (_lectures.isEmpty) {
          return const Center(child: Text('No lectures found.'));
        }
        final totalFiles = _files.length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Files & Downloads',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage PDF, audio and video files inside each lecture.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SummaryChip(label: 'Lectures', value: '${_lectures.length}'),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Files', value: '$totalFiles'),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  itemCount: _lectures.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lecture = _lectures[index];
                    return _LectureSection(
                      lecture: lecture,
                      files: _filesForLecture(lecture.id),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(value, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: scheme.surface,
            child: ListTile(
              onTap: () => setState(() {
                _expanded = !_expanded;
              }),
              leading: CircleAvatar(
                child: Text('${widget.lecture.displayOrder}'),
              ),
              title: Text(
                widget.lecture.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
                    color: widget.lecture.isActive ? scheme.primary : scheme.error,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              color: scheme.surfaceContainerLowest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.onAdd('pdf'),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Add PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onAdd('audio'),
                        icon: const Icon(Icons.audio_file_rounded),
                        label: const Text('Add Audio'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onAdd('video'),
                        icon: const Icon(Icons.video_file_rounded),
                        label: const Text('Add Video'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.files.isEmpty)
                    Text(
                      'No files uploaded for this lecture.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    )
                  else
                    ...widget.files.map(
                      (file) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            widget.fileIcon(file.fileType),
                            color: widget.fileColor(context, file.fileType),
                          ),
                          title: Text(
                            file.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${file.fileType.toUpperCase()} • ${file.isActive ? 'Active' : 'Inactive'}',
                          ),
                          onTap: () => widget.onOpen(file),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'open':
                                  widget.onOpen(file);
                                  break;
                                case 'replace':
                                  widget.onReplace(file);
                                  break;
                                case 'edit':
                                  widget.onEdit(file);
                                  break;
                                case 'active':
                                  widget.onToggleActive(file);
                                  break;
                                case 'delete':
                                  widget.onDelete(file);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'open', child: Text('Open')),
                              const PopupMenuItem(value: 'replace', child: Text('Replace')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit Title')),
                              PopupMenuItem(
                                value: 'active',
                                child: Text(file.isActive ? 'Deactivate' : 'Activate'),
                              ),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
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
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    _orderController = TextEditingController(text: '${widget.defaultOrder}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final order = int.tryParse(_orderController.text.trim());
    if (order == null || order < 0) return;
    Navigator.of(context).pop(
      _FileDetails(
        title: _titleController.text.trim(),
        displayOrder: order,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.fileType.toUpperCase()}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'File Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter file title'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Display Order'),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
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

class _FileDetails {
  final String title;
  final int displayOrder;

  const _FileDetails({required this.title, required this.displayOrder});
}

class _EditTitleDialog extends StatefulWidget {
  final String initialTitle;

  const _EditTitleDialog({required this.initialTitle});

  @override
  State<_EditTitleDialog> createState() => _EditTitleDialogState();
}

class _EditTitleDialogState extends State<_EditTitleDialog> {
  late final TextEditingController _controller;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit File Title'),
      content: TextField(
        controller: _controller,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
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
            Icon(Icons.cloud_off_rounded, size: 52, color: scheme.error),
            const SizedBox(height: 12),
            const Text('Unable to load files.'),
            const SizedBox(height: 12),
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
