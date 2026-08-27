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

  List<LectureModule> _modules = [];

  String? _selectedModuleId;
  bool? _selectedPublished;

  @override
  void initState() {
    super.initState();
    _lecturesFuture = _loadData();
  }

  // ==========================================================================
  // LOAD DATA
  // ==========================================================================

  Future<List<AdminLecture>> _loadData() async {
    final modules = await _service.getModules();

    if (mounted) {
      setState(() {
        _modules = modules;
      });
    }

    return _service.getLectures();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    final future = _loadData();

    setState(() {
      _lecturesFuture = future;
    });

    await future;
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  List<AdminLecture> _filterLectures(
    List<AdminLecture> lectures,
  ) {
    return lectures.where((lecture) {
      final moduleMatch =
          _selectedModuleId == null ||
          lecture.moduleId == _selectedModuleId;

      final publishedMatch =
          _selectedPublished == null ||
          lecture.isPublished == _selectedPublished;

      return moduleMatch && publishedMatch;
    }).toList();
  }

  // ==========================================================================
  // MODULE
  // ==========================================================================

  LectureModule? _moduleFor(String moduleId) {
    for (final module in _modules) {
      if (module.id == moduleId) {
        return module;
      }
    }

    return null;
  }

  // ==========================================================================
  // ADD / EDIT LECTURE
  // ==========================================================================

  Future<void> _showLectureDialog({
    AdminLecture? lecture,
  }) async {
    if (_modules.isEmpty) {
      _showMessage(
        'No active modules available.',
        error: true,
      );
      return;
    }

    final result = await showDialog<_LectureDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _LectureDialog(
          lecture: lecture,
          modules: _modules,
          service: _service,
        );
      },
    );

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

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

        if (!mounted) {
          return;
        }

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

        if (!mounted) {
          return;
        }

        _showMessage(
          'Lecture updated successfully.',
        );
      }

      await _refresh();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Error: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // ACTIVE
  // ==========================================================================

  Future<void> _toggleActive(
    AdminLecture lecture,
  ) async {
    try {
      await _service.setActive(
        id: lecture.id,
        value: !lecture.isActive,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        lecture.isActive
            ? 'Lecture deactivated.'
            : 'Lecture activated.',
      );

      await _refresh();
    } catch (e) {
      _showMessage(
        'Error: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // PUBLISHED
  // ==========================================================================

  Future<void> _togglePublished(
    AdminLecture lecture,
  ) async {
    try {
      await _service.setPublished(
        id: lecture.id,
        value: !lecture.isPublished,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        lecture.isPublished
            ? 'Lecture unpublished.'
            : 'Lecture published.',
      );

      await _refresh();
    } catch (e) {
      _showMessage(
        'Error: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

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

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectures'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ======================================================================
      // ADD BUTTON
      // ======================================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _modules.isEmpty
            ? null
            : () {
                _showLectureDialog();
              },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Lecture',
        ),
      ),

      // ======================================================================
      // BODY
      // ======================================================================

      body: FutureBuilder<List<AdminLecture>>(
        future: _lecturesFuture,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final lectures = _filterLectures(
            snapshot.data ?? [],
          );

          return Column(
            children: [
              _Filters(
                modules: _modules,
                selectedModuleId: _selectedModuleId,
                selectedPublished: _selectedPublished,
                onModuleChanged: (value) {
                  setState(() {
                    _selectedModuleId = value;
                  });
                },
                onPublishedChanged: (value) {
                  setState(() {
                    _selectedPublished = value;
                  });
                },
              ),

              Expanded(
                child: lectures.isEmpty
                    ? const Center(
                        child: Text(
                          'No lectures found.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: lectures.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(
                          height: 10,
                        ),
                        itemBuilder: (
                          context,
                          index,
                        ) {
                          final lecture =
                              lectures[index];

                          final module = _moduleFor(
                            lecture.moduleId,
                          );

                          return _LectureTile(
                            lecture: lecture,
                            moduleName:
                                module?.name ??
                                    'Unknown Module',
                            onEdit: () {
                              _showLectureDialog(
                                lecture: lecture,
                              );
                            },
                            onToggleActive: () {
                              _toggleActive(
                                lecture,
                              );
                            },
                            onTogglePublished: () {
                              _togglePublished(
                                lecture,
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

// ============================================================================
// LECTURE DIALOG
// ============================================================================

class _LectureDialog extends StatefulWidget {
  final AdminLecture? lecture;
  final List<LectureModule> modules;
  final LecturesService service;

  const _LectureDialog({
    required this.lecture,
    required this.modules,
    required this.service,
  });

  @override
  State<_LectureDialog> createState() =>
      _LectureDialogState();
}

class _LectureDialogState extends State<_LectureDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;

  late String? _moduleId;

  final List<LectureContentInput> _contents = [];

  final bool _saving = false;

  @override
  void initState() {
    super.initState();

    final lecture = widget.lecture;

    _titleController = TextEditingController(
      text: lecture?.title ?? '',
    );

    _descriptionController = TextEditingController(
      text: lecture?.description ?? '',
    );

    _orderController = TextEditingController(
      text: lecture?.displayOrder.toString() ?? '0',
    );

    _moduleId =
        lecture?.moduleId ??
        (widget.modules.isNotEmpty
            ? widget.modules.first.id
            : null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // ADD CONTENT
  // ==========================================================================

  Future<void> _addContent(
    String fileType,
  ) async {
    if (_saving) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );

    if (!mounted) {
      return;
    }

    if (result == null ||
        result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.first;

    if (pickedFile.bytes == null) {
      _showMessage(
        'Unable to read selected file.',
        error: true,
      );
      return;
    }

    final content =
        await _showContentDialog(
      fileType: fileType,
      fileName: pickedFile.name,
      bytes: pickedFile.bytes!,
    );

    if (!mounted) {
      return;
    }

    if (content == null) {
      return;
    }

    setState(() {
      _contents.add(content);
    });
  }

  // ==========================================================================
  // CONTENT DIALOG
  // ==========================================================================

  Future<LectureContentInput?> _showContentDialog({
    required String fileType,
    required String fileName,
    required dynamic bytes,
  }) async {
    final titleController =
        TextEditingController(
      text: fileName.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      ),
    );

    final orderController =
        TextEditingController(
      text: '${_contents.length + 1}',
    );

    final formKey =
        GlobalKey<FormState>();

    try {
      final result =
          await showDialog<LectureContentInput>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _ContentDialog(
            fileType: fileType,
            fileName: fileName,
            bytes: bytes,
            titleController: titleController,
            orderController: orderController,
            formKey: formKey,
          );
        },
      );

      return result;
    } finally {
      titleController.dispose();
      orderController.dispose();
    }
  }

  // ==========================================================================
  // REMOVE CONTENT
  // ==========================================================================

  void _removeContent(
    LectureContentInput content,
  ) {
    if (_saving) {
      return;
    }

    setState(() {
      _contents.remove(content);
    });
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  void _save() {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_moduleId == null ||
        _moduleId!.isEmpty) {
      _showMessage(
        'Please select a module.',
        error: true,
      );
      return;
    }

    final order = int.tryParse(
      _orderController.text.trim(),
    );

    if (order == null) {
      _showMessage(
        'Enter a valid display order.',
        error: true,
      );
      return;
    }

    final title =
        _titleController.text.trim();

    final descriptionText =
        _descriptionController.text.trim();

    final description =
        descriptionText.isEmpty
            ? null
            : descriptionText;

    Navigator.of(context).pop(
      _LectureDialogResult(
        moduleId: _moduleId!,
        title: title,
        description: description,
        displayOrder: order,
        contents: List.unmodifiable(
          _contents,
        ),
      ),
    );
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? Theme.of(context)
                  .colorScheme
                  .error
              : null,
        ),
      );
  }

  // ==========================================================================
  // FILE ICON
  // ==========================================================================

  IconData _iconForType(
    String type,
  ) {
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
    final isEditing =
        widget.lecture != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Edit Lecture'
            : 'Add Lecture',
      ),

      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ============================================================
                // MODULE
                // ============================================================

                DropdownButtonFormField<String>(
                  initialValue: _moduleId,
                  decoration:
                      const InputDecoration(
                    labelText: 'Module',
                    prefixIcon: Icon(
                      Icons.menu_book_rounded,
                    ),
                  ),
                  items: widget.modules
                      .map(
                        (module) =>
                            DropdownMenuItem<String>(
                          value: module.id,
                          child: Text(
                            module.name,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _moduleId = value;
                          });
                        },
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Select a module';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                // ============================================================
                // TITLE
                // ============================================================

                TextFormField(
                  controller:
                      _titleController,
                  enabled: !_saving,
                  decoration:
                      const InputDecoration(
                    labelText: 'Lecture Title',
                    prefixIcon: Icon(
                      Icons.title_rounded,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter lecture title';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                // ============================================================
                // DESCRIPTION
                // ============================================================

                TextFormField(
                  controller:
                      _descriptionController,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(
                      Icons.description_rounded,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // ============================================================
                // ORDER
                // ============================================================

                TextFormField(
                  controller:
                      _orderController,
                  enabled: !_saving,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText: 'Display Order',
                    prefixIcon: Icon(
                      Icons.format_list_numbered_rounded,
                    ),
                  ),
                  validator: (value) {
                    if (int.tryParse(
                          value?.trim() ?? '',
                        ) ==
                        null) {
                      return 'Enter a valid number';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 24,
                ),

                // ============================================================
                // CONTENT HEADER
                // ============================================================

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Lecture Content',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ============================================================
                // ADD FILE BUTTONS
                // ============================================================

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                                _addContent(
                                  'pdf',
                                ),
                        icon: const Icon(
                          Icons
                              .picture_as_pdf_rounded,
                        ),
                        label:
                            const Text('PDF'),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                                _addContent(
                                  'audio',
                                ),
                        icon: const Icon(
                          Icons
                              .audio_file_rounded,
                        ),
                        label:
                            const Text('Audio'),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                                _addContent(
                                  'video',
                                ),
                        icon: const Icon(
                          Icons
                              .video_file_rounded,
                        ),
                        label:
                            const Text('Video'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 12,
                ),

                // ============================================================
                // CONTENT LIST
                // ============================================================

                if (_contents.isEmpty)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                    ),
                    child: Text(
                      'No content added yet.',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),

                if (_contents.isNotEmpty)
                  ..._contents.map(
                    (content) {
                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 8,
                        ),
                        clipBehavior:
                            Clip.antiAlias,
                        child: Material(
                          color:
                              Colors.transparent,
                          child: ListTile(
                            leading: Icon(
                              _iconForType(
                                content.fileType,
                              ),
                            ),
                            title: Text(
                              content.title,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${content.fileType.toUpperCase()} • '
                              '${content.fileName}',
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                            trailing:
                                IconButton(
                              tooltip:
                                  'Remove',
                              onPressed:
                                  _saving
                                      ? null
                                      : () =>
                                          _removeContent(
                                            content,
                                          ),
                              icon:
                                  const Icon(
                                Icons
                                    .delete_outline_rounded,
                              ),
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
      ),

      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context)
                      .pop();
                },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed:
              _saving ? null : _save,
          child: Text(
            isEditing
                ? 'Save'
                : 'Create Lecture',
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CONTENT DIALOG
// ============================================================================

class _ContentDialog extends StatelessWidget {
  final String fileType;
  final String fileName;
  final dynamic bytes;

  final TextEditingController titleController;
  final TextEditingController orderController;

  final GlobalKey<FormState> formKey;

  const _ContentDialog({
    required this.fileType,
    required this.fileName,
    required this.bytes,
    required this.titleController,
    required this.orderController,
    required this.formKey,
  });

  IconData _icon() {
    switch (fileType) {
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
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_icon()),
          const SizedBox(
            width: 10,
          ),
          Text(
            'Add ${fileType.toUpperCase()}',
          ),
        ],
      ),

      content: SizedBox(
        width: 450,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // ==============================================================
              // TITLE
              // ==============================================================

              TextFormField(
                controller:
                    titleController,
                autofocus: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Content Title',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter content title';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // ==============================================================
              // ORDER
              // ==============================================================

              TextFormField(
                controller:
                    orderController,
                keyboardType:
                    TextInputType.number,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Display Order',
                  prefixIcon: Icon(
                    Icons
                        .format_list_numbered_rounded,
                  ),
                ),
                validator: (value) {
                  if (int.tryParse(
                        value?.trim() ?? '',
                      ) ==
                      null) {
                    return 'Enter a valid number';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // ==============================================================
              // FILE NAME
              // ==============================================================

              Align(
                alignment:
                    Alignment.centerLeft,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child: Text(
                    fileName,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!
                .validate()) {
              return;
            }

            final order =
                int.parse(
              orderController.text.trim(),
            );

            Navigator.of(context).pop(
              LectureContentInput(
                title:
                    titleController.text.trim(),
                fileType: fileType,
                bytes: bytes,
                fileName: fileName,
                displayOrder: order,
              ),
            );
          },
          child: const Text(
            'Add',
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FILTERS
// ============================================================================

class _Filters extends StatelessWidget {
  final List<LectureModule> modules;

  final String? selectedModuleId;
  final bool? selectedPublished;

  final ValueChanged<String?>
      onModuleChanged;

  final ValueChanged<bool?>
      onPublishedChanged;

  const _Filters({
    required this.modules,
    required this.selectedModuleId,
    required this.selectedPublished,
    required this.onModuleChanged,
    required this.onPublishedChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        4,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          // ================================================================
          // MODULE FILTER
          // ================================================================

          SizedBox(
            width: 260,
            child:
                DropdownButtonFormField<String?>(
              initialValue:
                  selectedModuleId,
              decoration:
                  const InputDecoration(
                labelText: 'Module',
                prefixIcon: Icon(
                  Icons.menu_book_rounded,
                ),
              ),
              items: [
                const DropdownMenuItem<
                    String?>(
                  value: null,
                  child:
                      Text('All Modules'),
                ),
                ...modules.map(
                  (module) =>
                      DropdownMenuItem<
                          String?>(
                    value: module.id,
                    child: Text(
                      module.name,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged:
                  onModuleChanged,
            ),
          ),

          // ================================================================
          // PUBLISHED FILTER
          // ================================================================

          SizedBox(
            width: 220,
            child:
                DropdownButtonFormField<bool?>(
              initialValue:
                  selectedPublished,
              decoration:
                  const InputDecoration(
                labelText:
                    'Publication',
                prefixIcon: Icon(
                  Icons.publish_rounded,
                ),
              ),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('All'),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child:
                      Text('Published'),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child:
                      Text('Draft'),
                ),
              ],
              onChanged:
                  onPublishedChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LECTURE TILE
// ============================================================================

class _LectureTile
    extends StatelessWidget {
  final AdminLecture lecture;
  final String moduleName;

  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onTogglePublished;

  const _LectureTile({
    required this.lecture,
    required this.moduleName,
    required this.onEdit,
    required this.onToggleActive,
    required this.onTogglePublished,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),

          leading: CircleAvatar(
            child: Text(
              '${lecture.displayOrder}',
            ),
          ),

          title: Text(
            lecture.title,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          subtitle: Padding(
            padding:
                const EdgeInsets.only(
              top: 4,
            ),
            child: Text(
              '$moduleName'
              '${lecture.description != null && lecture.description!.isNotEmpty ? ' • ${lecture.description}' : ''}',
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),

          trailing: Wrap(
            spacing: 4,
            children: [
              // ============================================================
              // PUBLISH
              // ============================================================

              IconButton(
                tooltip:
                    lecture.isPublished
                        ? 'Unpublish'
                        : 'Publish',
                onPressed:
                    onTogglePublished,
                icon: Icon(
                  lecture.isPublished
                      ? Icons
                          .visibility_rounded
                      : Icons
                          .visibility_off_rounded,
                ),
              ),

              // ============================================================
              // ACTIVE
              // ============================================================

              IconButton(
                tooltip:
                    lecture.isActive
                        ? 'Deactivate'
                        : 'Activate',
                onPressed:
                    onToggleActive,
                icon: Icon(
                  lecture.isActive
                      ? Icons
                          .toggle_on_rounded
                      : Icons
                          .toggle_off_rounded,
                  color: lecture.isActive
                      ? scheme.primary
                      : scheme
                          .onSurfaceVariant,
                ),
              ),

              // ============================================================
              // EDIT
              // ============================================================

              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  final String error;
  final Future<void> Function()
      onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .cloud_off_rounded,
              size: 56,
              color: scheme.error,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Unable to load lectures',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 8,
            ),

            SelectableText(
              error,
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 16,
            ),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}