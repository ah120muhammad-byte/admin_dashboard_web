import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/lecture_content_service.dart';

class LectureContentScreen extends StatefulWidget {
  const LectureContentScreen({
    super.key,
  });

  @override
  State<LectureContentScreen> createState() =>
      _LectureContentScreenState();
}

class _LectureContentScreenState
    extends State<LectureContentScreen> {
  final LectureContentService _service =
      LectureContentService();

  late Future<void> _loadFuture;

  List<ContentLecture> _lectures = [];
  List<LectureFileItem> _files = [];

  @override
  void initState() {
    super.initState();

    _loadFuture = _loadData();
  }

  // ==========================================================================
  // LOAD DATA
  // ==========================================================================

  Future<void> _loadData() async {
    final results = await Future.wait([
      _service.getLectures(),
      _service.getLectureFiles(),
    ]);

    if (!mounted) return;

    setState(() {
      _lectures =
          results[0] as List<ContentLecture>;

      _files =
          results[1] as List<LectureFileItem>;
    });
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _loadData();
    });

    await _loadFuture;
  }

  // ==========================================================================
  // FILES FOR LECTURE
  // ==========================================================================

  List<LectureFileItem> _filesForLecture(
    String lectureId,
  ) {
    final result = _files
        .where(
          (file) =>
              file.lectureId == lectureId,
        )
        .toList();

    result.sort(
      (a, b) =>
          a.displayOrder.compareTo(
        b.displayOrder,
      ),
    );

    return result;
  }

  // ==========================================================================
  // OPEN FILE
  // ==========================================================================

  Future<void> _openFile(
    LectureFileItem file,
  ) async {
    try {
      _showLoadingMessage(
        'Preparing ${file.fileType.toUpperCase()}...',
      );

      final signedUrl =
          await _service.createFileUrl(file);

      if (!mounted) return;

      final uri = Uri.tryParse(signedUrl);

      if (uri == null) {
        throw Exception(
          'Invalid file URL.',
        );
      }

      final launched = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
      );

      if (!launched) {
        throw Exception(
          'Unable to open file.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to open file: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // EDIT TITLE
  // ==========================================================================

  Future<void> _editFileTitle(
    LectureFileItem file,
  ) async {
    final controller =
        TextEditingController(
      text: file.title,
    );

    final formKey =
        GlobalKey<FormState>();

    final result =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit File Title',
          ),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration:
                    const InputDecoration(
                  labelText: 'Title',
                  hintText:
                      'Enter file title',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter a title';
                  }

                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
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

                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null ||
        result.trim().isEmpty) {
      return;
    }

    try {
      await _service.updateFileTitle(
        id: file.id,
        title: result.trim(),
      );

      if (!mounted) return;

      _showMessage(
        'File title updated successfully.',
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error updating title: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // TOGGLE ACTIVE
  // ==========================================================================

  Future<void> _toggleFileActive(
    LectureFileItem file,
  ) async {
    try {
      await _service.setFileActive(
        id: file.id,
        value: !file.isActive,
      );

      if (!mounted) return;

      _showMessage(
        file.isActive
            ? 'File deactivated.'
            : 'File activated.',
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // DELETE FILE
  // ==========================================================================

  Future<void> _deleteFile(
    LectureFileItem file,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete File',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${file.title}"?\n\n'
            'The file will be removed from '
            'Storage and lecture_files.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .error,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteLectureFile(
        file: file,
      );

      if (!mounted) return;

      _showMessage(
        'File deleted successfully.',
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error deleting file: $e',
        error: true,
      );
    }
  }

  // ==========================================================================
  // FILE ICON
  // ==========================================================================

  IconData _fileIcon(
    String fileType,
  ) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons
            .picture_as_pdf_rounded;

      case 'audio':
        return Icons
            .audio_file_rounded;

      case 'video':
        return Icons
            .video_file_rounded;

      default:
        return Icons
            .insert_drive_file_rounded;
    }
  }

  // ==========================================================================
  // FILE COLOR
  // ==========================================================================

  Color _fileColor(
    BuildContext context,
    String fileType,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

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

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

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

  void _showLoadingMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 2),
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lecture Content',
        ),
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
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error:
                  snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          if (_lectures.isEmpty) {
            return const Center(
              child: Text(
                'No lectures found.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding:
                  const EdgeInsets.all(20),
              itemCount: _lectures.length,
              itemBuilder: (
                context,
                index,
              ) {
                final lecture =
                    _lectures[index];

                return _LectureSection(
                  lecture: lecture,
                  files:
                      _filesForLecture(
                    lecture.id,
                  ),
                  fileIcon: _fileIcon,
                  fileColor: _fileColor,
                  onOpenFile: _openFile,
                  onEditFile:
                      _editFileTitle,
                  onDeleteFile:
                      _deleteFile,
                  onToggleFileActive:
                      _toggleFileActive,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// LECTURE SECTION
// ============================================================================

class _LectureSection
    extends StatefulWidget {
  final ContentLecture lecture;
  final List<LectureFileItem> files;

  final IconData Function(
    String,
  ) fileIcon;

  final Color Function(
    BuildContext,
    String,
  ) fileColor;

  final Future<void> Function(
    LectureFileItem,
  ) onOpenFile;

  final Future<void> Function(
    LectureFileItem,
  ) onEditFile;

  final Future<void> Function(
    LectureFileItem,
  ) onDeleteFile;

  final Future<void> Function(
    LectureFileItem,
  ) onToggleFileActive;

  const _LectureSection({
    required this.lecture,
    required this.files,
    required this.fileIcon,
    required this.fileColor,
    required this.onOpenFile,
    required this.onEditFile,
    required this.onDeleteFile,
    required this.onToggleFileActive,
  });

  @override
  State<_LectureSection> createState() =>
      _LectureSectionState();
}

class _LectureSectionState
    extends State<_LectureSection> {
  bool expanded = true;

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: [
          // ================================================================
          // LECTURE HEADER
          // ================================================================

          Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              leading: CircleAvatar(
                child: Text(
                  '${widget.lecture.displayOrder}',
                ),
              ),
              title: Text(
                widget.lecture.title,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: widget
                          .lecture
                          .description !=
                      null &&
                  widget.lecture.description!
                      .trim()
                      .isNotEmpty
                  ? Text(
                      widget.lecture
                          .description!,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    )
                  : Text(
                      '${widget.files.length} '
                      '${widget.files.length == 1 ? 'file' : 'files'}',
                    ),
              trailing: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  if (widget
                      .lecture
                      .isPublished)
                    Tooltip(
                      message:
                          'Published',
                      child: Icon(
                        Icons
                            .visibility_rounded,
                        color:
                            scheme.primary,
                      ),
                    )
                  else
                    Tooltip(
                      message: 'Draft',
                      child: Icon(
                        Icons
                            .visibility_off_rounded,
                        color: scheme
                            .onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(
                    width: 8,
                  ),
                  if (widget
                      .lecture
                      .isActive)
                    Tooltip(
                      message: 'Active',
                      child: Icon(
                        Icons
                            .check_circle_rounded,
                        color:
                            scheme.primary,
                      ),
                    )
                  else
                    Tooltip(
                      message:
                          'Inactive',
                      child: Icon(
                        Icons
                            .cancel_rounded,
                        color:
                            scheme.error,
                      ),
                    ),
                  const SizedBox(
                    width: 8,
                  ),
                  Icon(
                    expanded
                        ? Icons
                            .expand_less_rounded
                        : Icons
                            .expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),

          // ================================================================
          // FILES
          // ================================================================

          if (expanded)
            Container(
              width: double.infinity,
              decoration:
                  BoxDecoration(
                color: scheme
                    .surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color:
                        scheme.outlineVariant,
                  ),
                ),
              ),
              child: widget.files.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets
                              .all(24),
                      child: Center(
                        child: Text(
                          'No content added to this lecture.',
                          style: TextStyle(
                            color: scheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        12,
                        8,
                        12,
                        8,
                      ),
                      child: Column(
                        children: widget.files
                            .map(
                              (
                                file,
                              ) =>
                                  _FileTile(
                                file: file,
                                icon:
                                    widget.fileIcon(
                                  file.fileType,
                                ),
                                iconColor:
                                    widget.fileColor(
                                  context,
                                  file.fileType,
                                ),
                                onOpen:
                                    () =>
                                        widget.onOpenFile(
                                  file,
                                ),
                                onEdit:
                                    () =>
                                        widget.onEditFile(
                                  file,
                                ),
                                onDelete:
                                    () =>
                                        widget.onDeleteFile(
                                  file,
                                ),
                                onToggleActive:
                                    () =>
                                        widget.onToggleFileActive(
                                  file,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILE TILE
// ============================================================================

class _FileTile extends StatelessWidget {
  final LectureFileItem file;
  final IconData icon;
  final Color iconColor;

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _FileTile({
    required this.file,
    required this.icon,
    required this.iconColor,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          tileColor: file.isActive
              ? scheme.surface
              : scheme
                  .surfaceContainerHighest,
          leading: Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color: iconColor
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  file.title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration:
                    BoxDecoration(
                  color: iconColor
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  file.fileType
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding:
                const EdgeInsets.only(
              top: 4,
            ),
            child: Text(
              file.fileUrl,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme
                    .onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              // ------------------------------------------------------------
              // OPEN
              // ------------------------------------------------------------

              IconButton(
                tooltip: 'Open',
                onPressed: onOpen,
                icon: const Icon(
                  Icons
                      .open_in_new_rounded,
                ),
              ),

              // ------------------------------------------------------------
              // ACTIVE
              // ------------------------------------------------------------

              IconButton(
                tooltip: file.isActive
                    ? 'Deactivate'
                    : 'Activate',
                onPressed:
                    onToggleActive,
                icon: Icon(
                  file.isActive
                      ? Icons
                          .toggle_on_rounded
                      : Icons
                          .toggle_off_rounded,
                ),
              ),

              // ------------------------------------------------------------
              // EDIT
              // ------------------------------------------------------------

              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(
                  Icons
                      .edit_rounded,
                ),
              ),

              // ------------------------------------------------------------
              // DELETE
              // ------------------------------------------------------------

              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(
                  Icons
                      .delete_outline_rounded,
                  color:
                      scheme.error,
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
              'Unable to load lecture content',
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
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}