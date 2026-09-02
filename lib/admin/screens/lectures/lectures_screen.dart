import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/lectures_service.dart';

class LecturesScreen extends StatefulWidget {
  const LecturesScreen({super.key});

  @override
  State<LecturesScreen> createState() => _LecturesScreenState();
}

class _LecturesScreenState extends State<LecturesScreen> {
  final LecturesService _service = LecturesService();

  late Future<List<AdminLecture>> _lecturesFuture;
  List<LectureModule> _modules = <LectureModule>[];
  String? _selectedModuleId;
  bool? _selectedPublished;

  @override
  void initState() {
    super.initState();
    _lecturesFuture = _loadData();
  }

  Future<List<AdminLecture>> _loadData() async {
    final responses = await Future.wait([
      _service.getModules(),
      _service.getLectures(),
    ]);

    final modules = responses[0] as List<LectureModule>;
    final lectures = responses[1] as List<AdminLecture>;

    if (mounted) {
      setState(() {
        _modules = modules;
      });
    }

    return lectures;
  }

  Future<void> _refresh() async {
    final future = _loadData();
    if (!mounted) return;

    setState(() {
      _lecturesFuture = future;
    });

    await future;
  }

  List<AdminLecture> _filtered(List<AdminLecture> lectures) {
    return lectures.where((lecture) {
      final moduleMatch =
          _selectedModuleId == null || lecture.moduleId == _selectedModuleId;
      final publishedMatch =
          _selectedPublished == null ||
          lecture.isPublished == _selectedPublished;
      return moduleMatch && publishedMatch;
    }).toList();
  }

  LectureModule? _moduleFor(String id) {
    for (final module in _modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  Future<void> _showLectureDialog({AdminLecture? lecture}) async {
    if (_modules.isEmpty) {
      _showMessage('No active modules available.', error: true);
      return;
    }

    final result = await showDialog<_LectureDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LectureDialog(
        lecture: lecture,
        modules: _modules,
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (lecture == null) {
        final lectureId = await _service.createLecture(
          moduleId: result.moduleId,
          title: result.title,
          description: result.description,
          displayOrder: result.displayOrder,
        );

        for (final content in result.contents) {
          await _service.addLectureContent(
            lectureId: lectureId,
            content: content,
          );
        }

        if (!mounted) return;
        _showMessage(
          result.contents.isEmpty
              ? 'Lecture added successfully.'
              : 'Lecture and content added successfully.',
        );
      } else {
        await _service.updateLecture(
          id: lecture.id,
          moduleId: result.moduleId,
          title: result.title,
          description: result.description,
          displayOrder: result.displayOrder,
        );

        if (!mounted) return;
        _showMessage('Lecture updated successfully.');
      }

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _toggleActive(AdminLecture lecture) async {
    try {
      await _service.setActive(id: lecture.id, value: !lecture.isActive);
      if (!mounted) return;
      _showMessage(
        lecture.isActive ? 'Lecture deactivated.' : 'Lecture activated.',
      );
      await _refresh();
    } catch (e) {
      if (mounted) _showMessage('Error: $e', error: true);
    }
  }

  Future<void> _togglePublished(AdminLecture lecture) async {
    try {
      await _service.setPublished(
        id: lecture.id,
        value: !lecture.isPublished,
      );
      if (!mounted) return;
      _showMessage(
        lecture.isPublished ? 'Lecture unpublished.' : 'Lecture published.',
      );
      await _refresh();
    } catch (e) {
      if (mounted) _showMessage('Error: $e', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<AdminLecture>>(
      future: _lecturesFuture,
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

        final lectures = _filtered(snapshot.data ?? <AdminLecture>[]);
        final publishedCount = snapshot.data
                ?.where((lecture) => lecture.isPublished)
                .length ??
            0;
        final draftCount = (snapshot.data?.length ?? 0) - publishedCount;
        final activeCount = snapshot.data
                ?.where((lecture) => lecture.isActive)
                .length ??
            0;
        final inactiveCount = (snapshot.data?.length ?? 0) - activeCount;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lectures',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage lectures and their learning content.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _modules.isEmpty
                            ? null
                            : () => _showLectureDialog(),
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
                      _StatCard(
                        icon: Icons.menu_book_rounded,
                        label: 'Total Lectures',
                        value: '${snapshot.data?.length ?? 0}',
                      ),
                      _StatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Active',
                        value: '$activeCount',
                      ),
                      _StatCard(
                        icon: Icons.publish_outlined,
                        label: 'Published',
                        value: '$publishedCount',
                      ),
                      _StatCard(
                        icon: Icons.drafts_outlined,
                        label: 'Drafts',
                        value: '$draftCount',
                      ),
                      _StatCard(
                        icon: Icons.visibility_off_outlined,
                        label: 'Inactive',
                        value: '$inactiveCount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;

                      final moduleFilter = DropdownButtonFormField<String?>(
                        initialValue: _selectedModuleId,
                        decoration: const InputDecoration(
                          labelText: 'Module',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Modules'),
                          ),
                          ..._modules.map(
                            (module) => DropdownMenuItem<String?>(
                              value: module.id,
                              child: Text(
                                module.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedModuleId = value;
                          });
                        },
                      );

                      final publicationFilter =
                          DropdownButtonFormField<bool?>(
                        initialValue: _selectedPublished,
                        decoration: const InputDecoration(
                          labelText: 'Publication',
                          prefixIcon: Icon(Icons.publish_outlined),
                        ),
                        items: const [
                          DropdownMenuItem<bool?>(
                            value: null,
                            child: Text('All'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: true,
                            child: Text('Published'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: false,
                            child: Text('Draft'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPublished = value;
                          });
                        },
                      );

                      return compact
                          ? Row(
                              children: [
                                Expanded(child: moduleFilter),
                                const SizedBox(width: 10),
                                Expanded(child: publicationFilter),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: moduleFilter),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 220,
                                  child: publicationFilter,
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: lectures.isEmpty
                  ? const _EmptyLectures()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        itemCount: lectures.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final lecture = lectures[index];
                          final module = _moduleFor(lecture.moduleId);

                          return _LectureCard(
                            lecture: lecture,
                            moduleName: module?.name ?? 'Unknown Module',
                            onEdit: () =>
                                _showLectureDialog(lecture: lecture),
                            onToggleActive: () => _toggleActive(lecture),
                            onTogglePublished: () =>
                                _togglePublished(lecture),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 170,
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
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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

class _LectureCard extends StatelessWidget {
  final AdminLecture lecture;
  final String moduleName;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onTogglePublished;

  const _LectureCard({
    required this.lecture,
    required this.moduleName,
    required this.onEdit,
    required this.onToggleActive,
    required this.onTogglePublished,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.primary,
              child: Text(
                '${lecture.displayOrder}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        lecture.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _StatusChip(
                        label: lecture.isPublished ? 'Published' : 'Draft',
                        active: lecture.isPublished,
                      ),
                      _StatusChip(
                        label: lecture.isActive ? 'Active' : 'Inactive',
                        active: lecture.isActive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    moduleName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lecture.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      lecture.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'publish':
                    onTogglePublished();
                    break;
                  case 'active':
                    onToggleActive();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'publish',
                  child: Text(
                    lecture.isPublished ? 'Unpublish' : 'Publish',
                  ),
                ),
                PopupMenuItem(
                  value: 'active',
                  child: Text(
                    lecture.isActive ? 'Deactivate' : 'Activate',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusChip({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LectureDialogResult {
  final String moduleId;
  final String title;
  final String? description;
  final int displayOrder;
  final List<LectureContentInput> contents;

  const _LectureDialogResult({
    required this.moduleId,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.contents,
  });
}

class _LectureDialog extends StatefulWidget {
  final AdminLecture? lecture;
  final List<LectureModule> modules;

  const _LectureDialog({
    required this.lecture,
    required this.modules,
  });

  @override
  State<_LectureDialog> createState() => _LectureDialogState();
}

class _LectureDialogState extends State<_LectureDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late String _moduleId;

  final List<LectureContentInput> _contents = <LectureContentInput>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final lecture = widget.lecture;
    _titleController = TextEditingController(text: lecture?.title ?? '');
    _descriptionController =
        TextEditingController(text: lecture?.description ?? '');
    _orderController =
        TextEditingController(text: '${lecture?.displayOrder ?? 0}');
    _moduleId = lecture?.moduleId ?? widget.modules.first.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _addContent(String fileType) async {
    if (_busy) return;

    final extensions = switch (fileType) {
      'pdf' => <String>['pdf'],
      'audio' => <String>['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      'video' => <String>['mp4', 'mov', 'mkv', 'webm'],
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

      final initialTitle = picked.name.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      );

      final input = await showDialog<LectureContentInput>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ContentEditorDialog(
          fileType: fileType,
          fileName: picked.name,
          bytes: bytes,
          initialTitle: initialTitle,
          initialOrder: _contents.length + 1,
        ),
      );

      if (!mounted || input == null) return;
      setState(() {
        _contents.add(input);
      });
    } catch (e) {
      if (mounted) _showMessage('Unable to add content: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _removeContent(LectureContentInput content) {
    if (_busy) return;
    setState(() {
      _contents.remove(content);
    });
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  void _save() {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    final order = int.tryParse(_orderController.text.trim());
    if (order == null || order < 0) {
      _showMessage('Enter a valid display order.', error: true);
      return;
    }

    Navigator.of(context).pop(
      _LectureDialogResult(
        moduleId: _moduleId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        displayOrder: order,
        contents: List<LectureContentInput>.unmodifiable(_contents),
      ),
    );
  }

  IconData _contentIcon(String type) {
    switch (type) {
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
    final editing = widget.lecture != null;
    final size = MediaQuery.sizeOf(context);
    final maxHeight = size.height * 0.78;

    return AlertDialog(
      title: Text(editing ? 'Edit Lecture' : 'Add Lecture'),
      content: SizedBox(
        width: size.width >= 900 ? 680 : size.width * 0.88,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _moduleId,
                    decoration: const InputDecoration(
                      labelText: 'Module',
                      prefixIcon: Icon(Icons.menu_book_rounded),
                    ),
                    items: widget.modules
                        .map(
                          (module) => DropdownMenuItem<String>(
                            value: module.id,
                            child: Text(
                              module.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _moduleId = value;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Lecture Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter lecture title'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      prefixIcon: Icon(Icons.format_list_numbered_rounded),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Lecture Content',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _addContent('pdf'),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Add PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _addContent('audio'),
                        icon: const Icon(Icons.audio_file_rounded),
                        label: const Text('Add Audio'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _addContent('video'),
                        icon: const Icon(Icons.video_file_rounded),
                        label: const Text('Add Video'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_contents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No new content selected.'),
                    )
                  else
                    ..._contents.map(
                      (content) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: ListTile(
                            leading: Icon(_contentIcon(content.fileType)),
                            title: Text(
                              content.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${content.fileType.toUpperCase()} • '
                              '${content.fileName} • order ${content.displayOrder}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              onPressed: _busy
                                  ? null
                                  : () => _removeContent(content),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(editing ? 'Save' : 'Create Lecture'),
        ),
      ],
    );
  }
}

class _ContentEditorDialog extends StatefulWidget {
  final String fileType;
  final String fileName;
  final Uint8List bytes;
  final String initialTitle;
  final int initialOrder;

  const _ContentEditorDialog({
    required this.fileType,
    required this.fileName,
    required this.bytes,
    required this.initialTitle,
    required this.initialOrder,
  });

  @override
  State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

class _ContentEditorDialogState extends State<_ContentEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _orderController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _orderController = TextEditingController(text: '${widget.initialOrder}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  IconData _icon() {
    switch (widget.fileType) {
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
    if (order == null || order < 0) return;

    Navigator.of(context).pop(
      LectureContentInput(
        title: _titleController.text.trim(),
        fileType: widget.fileType,
        bytes: widget.bytes,
        fileName: widget.fileName,
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
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Enter content title'
                        : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
                validator: (value) {
                  final order = int.tryParse(value?.trim() ?? '');
                  return order == null || order < 0
                      ? 'Enter a valid number'
                      : null;
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

class _EmptyLectures extends StatelessWidget {
  const _EmptyLectures();

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
              'No lectures found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try changing the filters or add a new lecture.',
              textAlign: TextAlign.center,
            ),
          ],
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
              'Unable to load lectures.',
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
