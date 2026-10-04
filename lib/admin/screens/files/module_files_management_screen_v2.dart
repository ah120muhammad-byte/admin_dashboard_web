import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/lecture_content_service.dart';
import '../../../core/services/lectures_service.dart';

class ModuleFilesManagementScreen extends StatefulWidget {
  final LectureModule module;

  const ModuleFilesManagementScreen({super.key, required this.module});

  @override
  State<ModuleFilesManagementScreen> createState() => _ModuleFilesManagementScreenState();
}

class _ModuleFilesManagementScreenState extends State<ModuleFilesManagementScreen> {
  final LecturesService _lectures = LecturesService();
  final LectureContentService _filesService = LectureContentService();
  late Future<_Data> _future;
  bool _busy = false;
  double? _uploadProgress;
  String? _uploadLabel;
  String _uploadCurrentFile = '';
  int _uploadCompleted = 0;
  int _uploadTotal = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final results = await Future.wait<dynamic>([
      _lectures.getLectures(),
      _filesService.getLectureFiles(),
    ]);
    final lectures = (results[0] as List<AdminLecture>)
        .where((e) => e.moduleId == widget.module.id)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final allFiles = results[1] as List<LectureFileItem>;
    final ids = lectures.map((e) => e.id).toSet();
    final files = allFiles.where((e) => ids.contains(e.lectureId)).toList();
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
      case 'video':
        return ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'];
      case 'audio':
        // Audio uses FileType.audio below, so we intentionally do not
        // maintain a fixed extension whitelist.
        return <String>[];
      default:
        return <String>[];
    }
  }

  Future<void> _addFile(AdminLecture lecture, String type) async {
    if (_busy) return;

    final extensions = _extensionsForType(type);
    setState(() {
      _busy = true;
      _uploadProgress = 0;
      _uploadLabel = 'Preparing upload...';
      _uploadCurrentFile = '';
      _uploadCompleted = 0;
      _uploadTotal = 0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: type == 'audio' ? FileType.audio : FileType.custom,
        allowedExtensions: type == 'audio' ? null : extensions,
        allowMultiple: true,
        withData: type != 'video',
        withReadStream: true,
        readSequential: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final files = result.files;
      setState(() {
        _uploadTotal = files.length;
        _uploadCurrentFile = files.first.name;
      });

      var nextOrder = await _nextOrder(lecture.id);

      for (final picked in files) {
        if (!mounted) return;

        setState(() {
          _uploadCurrentFile = picked.name;
          _uploadProgress = 0;
          _uploadLabel =
              'Uploading ${type.toUpperCase()} • ${_uploadCompleted + 1}/$_uploadTotal';
        });

        if (type == 'video') {
          if (picked.readStream == null) {
            throw Exception(
              'Unable to stream "${picked.name}". Please select it again.',
            );
          }

          await _filesService.addLectureVideo(
            lectureId: lecture.id,
            title: picked.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            file: picked,
            displayOrder: nextOrder++,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = progress;
              });
            },
          );
        } else {
          Uint8List? bytes = picked.bytes;
          if (bytes == null) {
            final stream = picked.readStream;
            if (stream == null) {
              throw Exception('Unable to read "${picked.name}".');
            }
            final builder = BytesBuilder();
            await for (final chunk in stream) {
              builder.add(chunk);
            }
            bytes = builder.takeBytes();
          }

          if (bytes.isEmpty) {
            throw Exception('Unable to read "${picked.name}".');
          }

          await _filesService.addLectureFile(
            lectureId: lecture.id,
            title: picked.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            fileType: type,
            bytes: bytes,
            fileName: picked.name,
            displayOrder: nextOrder++,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = progress;
              });
            },
          );
        }

        if (!mounted) return;
        setState(() {
          _uploadCompleted++;
          _uploadProgress = 1;
        });
      }

      if (!mounted) return;
      _message(
        '${files.length} ${type.toUpperCase()} file${files.length == 1 ? '' : 's'} uploaded successfully.',
      );
      await _refresh();
    } catch (e) {
      if (mounted) _message('Upload failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
          _uploadLabel = null;
          _uploadCurrentFile = '';
          _uploadCompleted = 0;
          _uploadTotal = 0;
        });
      }
    }
  }

  Future<int> _nextOrder(String lectureId) async {
    final files = await _filesService.getFilesForLecture(lectureId);
    if (files.isEmpty) return 1;
    return files.map((file) => file.displayOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _replaceFile(LectureFileItem file) async {
    if (_busy) return;

    final extensions = _extensionsForType(file.fileType);
    setState(() {
      _busy = true;
      _uploadProgress = null;
      _uploadLabel = 'Preparing replacement...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: file.fileType == 'audio' ? FileType.audio : FileType.custom,
        allowedExtensions: file.fileType == 'audio' ? null : extensions,
        withData: file.fileType != 'video',
        withReadStream: file.fileType == 'video',
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final picked = result.files.single;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace File'),
          content: Text(
            'Replace "${file.title}" with "${picked.name}"? '
            'The old storage file will be removed after the new file is linked.',
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

      if (file.fileType == 'video') {
        if (picked.readStream == null) {
          _message(
            'Unable to stream the selected video. Please select it again.',
            error: true,
          );
          return;
        }

        await _filesService.replaceLectureVideo(
          file: file,
          newFile: picked,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = progress;
              _uploadLabel = 'Replacing VIDEO...';
            });
          },
        );
      } else {
        final bytes = picked.bytes;
        if (bytes == null || bytes.isEmpty) {
          _message('Unable to read the selected file.', error: true);
          return;
        }

        await _filesService.replaceLectureFile(
          file: file,
          bytes: bytes,
          newFileName: picked.name,
        );
      }

      if (!mounted) return;
      _message('${file.fileType.toUpperCase()} replaced successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Replace failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
          _uploadLabel = null;
        });
      }
    }
  }

  Future<void> _openFile(LectureFileItem file) async {
    try {
      final url = await _filesService.createFileUrl(file);
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid file URL.');
      final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!opened) throw Exception('Unable to open file.');
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
      await _filesService.updateFileTitle(id: file.id, title: title);
      if (!mounted) return;
      _message('File title updated.');
      await _refresh();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _toggleFile(LectureFileItem file) async {
    try {
      await _filesService.setFileActive(id: file.id, value: !file.isActive);
      if (!mounted) return;
      _message(file.isActive ? 'File deactivated.' : 'File activated.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Update failed: $e', error: true);
    }
  }

  Future<void> _deleteFile(LectureFileItem file) async {
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
      await _filesService.deleteLectureFile(file: file);
      if (!mounted) return;
      _message('File deleted successfully.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Delete failed: $e', error: true);
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

  IconData _fileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'audio': return Icons.audio_file_rounded;
      case 'video': return Icons.video_file_rounded;
      default: return Icons.insert_drive_file_rounded;
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
          return Center(child: FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ));
        }
        final data = snapshot.data!;
        final pdf = data.files.where((f) => f.fileType == 'pdf').length;
        final audio = data.files.where((f) => f.fileType == 'audio').length;
        final video = data.files.where((f) => f.fileType == 'video').length;
        return Material(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.module.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Manage files by lecture.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  )),
                  IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(spacing: 12, children: [
                _Stat('Lectures', '${data.lectures.length}', Icons.menu_book_outlined),
                _Stat('PDF', '$pdf', Icons.picture_as_pdf_outlined),
                _Stat('Audio', '$audio', Icons.audio_file_outlined),
                _Stat('Video', '$video', Icons.video_file_outlined),
              ]),
            ),
            const SizedBox(height: 12),
            if (_busy) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_uploadLabel != null)
                      Text(
                        _uploadLabel!,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (_uploadCurrentFile.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _uploadCurrentFile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 4),
                    if (_uploadProgress != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(_uploadProgress! * 100).toInt()}%',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
                    return _LectureFilesTile(
                      lecture: lecture,
                      files: files,
                      fileIcon: _fileIcon,
                      onAdd: (type) => _addFile(lecture, type),
                      onOpen: _openFile,
                      onEdit: _editTitle,
                      onReplace: _replaceFile,
                      onToggle: _toggleFile,
                      onDelete: _deleteFile,
                      busy: _busy,
                    );
                  },
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }
}

class _LectureFilesTile extends StatefulWidget {
  final AdminLecture lecture;
  final List<LectureFileItem> files;
  final IconData Function(String) fileIcon;
  final ValueChanged<String> onAdd;
  final Future<void> Function(LectureFileItem) onOpen;
  final Future<void> Function(LectureFileItem) onEdit;
  final Future<void> Function(LectureFileItem) onReplace;
  final Future<void> Function(LectureFileItem) onToggle;
  final Future<void> Function(LectureFileItem) onDelete;
  final bool busy;

  const _LectureFilesTile({
    required this.lecture,
    required this.files,
    required this.fileIcon,
    required this.onAdd,
    required this.onOpen,
    required this.onEdit,
    required this.onReplace,
    required this.onToggle,
    required this.onDelete,
    required this.busy,
  });

  @override
  State<_LectureFilesTile> createState() => _LectureFilesTileState();
}

class _LectureFilesTileState extends State<_LectureFilesTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (value) => setState(() { _expanded = value; }),
        leading: CircleAvatar(child: Text('${widget.lecture.displayOrder}')),
        title: Text(widget.lecture.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text('${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.lecture.isPublished ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 18,
              color: widget.lecture.isPublished ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.busy ? null : () => widget.onAdd('pdf'),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Add PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.busy ? null : () => widget.onAdd('audio'),
                      icon: const Icon(Icons.audio_file_rounded),
                      label: const Text('Add Audio'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.busy ? null : () => widget.onAdd('video'),
                      icon: const Icon(Icons.video_file_rounded),
                      label: const Text('Add Video'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.files.isEmpty)
                  Text('No files in this lecture.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                else
                  ...widget.files.map((file) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(widget.fileIcon(file.fileType), color: scheme.primary),
                      title: Text(file.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${file.fileType.toUpperCase()} • ${file.isActive ? 'Active' : 'Inactive'}'),
                      onTap: () => widget.onOpen(file),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          switch (action) {
                            case 'open': widget.onOpen(file); break;
                            case 'edit': widget.onEdit(file); break;
                            case 'replace': widget.onReplace(file); break;
                            case 'toggle': widget.onToggle(file); break;
                            case 'delete': widget.onDelete(file); break;
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'open', child: Text('Open')),
                          const PopupMenuItem(value: 'edit', child: Text('Edit Title')),
                          const PopupMenuItem(value: 'replace', child: Text('Replace / Switch File')),
                          PopupMenuItem(value: 'toggle', child: Text(file.isActive ? 'Deactivate' : 'Activate')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  )),
              ],
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


class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
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
