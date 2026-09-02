import 'package:flutter/material.dart';

import '../../../core/services/academic_levels_service.dart';
import '../../../core/services/admin_modules_service.dart';
import '../../../core/services/lectures_service.dart';

class ContentDeletionScreen extends StatefulWidget {
  const ContentDeletionScreen({super.key});

  @override
  State<ContentDeletionScreen> createState() => _ContentDeletionScreenState();
}

class _ContentDeletionScreenState extends State<ContentDeletionScreen> {
  final _levels = AcademicLevelsService();
  final _modules = AdminModulesService();
  final _lectures = LecturesService();
  late Future<_Data> _future;
  int _tab = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final result = await Future.wait<dynamic>([
      _levels.getLevels(),
      _modules.getModules(),
      _lectures.getLectures(),
    ]);
    return _Data(
      levels: result[0] as List<AcademicLevel>,
      modules: result[1] as List<AdminModule>,
      lectures: result[2] as List<AdminLecture>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _deleteLevel(AcademicLevel level, _Data data) async {
    final count = data.modules.where((m) => m.academicLevelId == level.id).length;
    final confirmed = await _confirm(
      'Delete Academic Level?',
      'Delete "${level.name}" permanently? It currently contains $count module(s).',
    );
    if (!confirmed || !mounted) return;

    try {
      await _levels.deleteLevel(level.id);
      await _refresh();
      if (mounted) _message('Academic level deleted.');
    } catch (e) {
      if (mounted) _message('Delete failed: $e', error: true);
    }
  }

  Future<void> _deleteModule(AdminModule module, _Data data) async {
    final count = data.lectures.where((l) => l.moduleId == module.id).length;
    final confirmed = await _confirm(
      'Delete Module?',
      'Delete "${module.name}" permanently? It currently contains $count lecture(s).',
    );
    if (!confirmed || !mounted) return;

    try {
      await _modules.deleteModule(module.id);
      await _refresh();
      if (mounted) _message('Module deleted.');
    } catch (e) {
      if (mounted) _message('Delete failed: $e', error: true);
    }
  }

  Future<void> _deleteLecture(AdminLecture lecture) async {
    final confirmed = await _confirm(
      'Delete Lecture?',
      'Delete "${lecture.title}" permanently and remove its uploaded files from storage?',
    );
    if (!confirmed || !mounted) return;

    try {
      await _lectures.deleteLecture(lecture.id);
      await _refresh();
      if (mounted) _message('Lecture deleted.');
    } catch (e) {
      if (mounted) _message('Delete failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              label: const Text('Try Again'),
            ),
          );
        }
        final data = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Content Cleanup',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Permanently delete academic levels, modules and lectures.',
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.school_outlined),
                        label: Text('Levels (${data.levels.length})'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text('Modules (${data.modules.length})'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: const Icon(Icons.video_library_outlined),
                        label: Text('Lectures (${data.lectures.length})'),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (value) {
                      setState(() {
                        _tab = value.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim().toLowerCase();
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList(data)),
          ],
        );
      },
    );
  }

  Widget _buildList(_Data data) {
    if (_tab == 0) {
      final items = data.levels
          .where((x) => _search.isEmpty || x.name.toLowerCase().contains(_search))
          .toList();
      return _itemsList(items, (level) {
        final count = data.modules.where((m) => m.academicLevelId == level.id).length;
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
          title: Text(level.name),
          subtitle: Text('$count module(s) • ${level.isActive ? 'Active' : 'Inactive'}'),
          trailing: _deleteButton(() => _deleteLevel(level, data)),
        );
      });
    }

    if (_tab == 1) {
      final items = data.modules
          .where((x) => _search.isEmpty || x.name.toLowerCase().contains(_search))
          .toList();
      return _itemsList(items, (module) {
        final count = data.lectures.where((l) => l.moduleId == module.id).length;
        String levelName = 'Unknown Level';
        for (final level in data.levels) {
          if (level.id == module.academicLevelId) {
            levelName = level.name;
            break;
          }
        }
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
          title: Text(module.name),
          subtitle: Text('$levelName • $count lecture(s)'),
          trailing: _deleteButton(() => _deleteModule(module, data)),
        );
      });
    }

    final items = data.lectures
        .where((x) => _search.isEmpty || x.title.toLowerCase().contains(_search))
        .toList();
    return _itemsList(items, (lecture) {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.video_library_outlined)),
        title: Text(lecture.title),
        subtitle: Text(
          '${lecture.isPublished ? 'Published' : 'Draft'} • ${lecture.isActive ? 'Active' : 'Inactive'}',
        ),
        trailing: _deleteButton(() => _deleteLecture(lecture)),
      );
    });
  }

  Widget _deleteButton(VoidCallback onPressed) {
    return IconButton(
      tooltip: 'Delete permanently',
      onPressed: onPressed,
      icon: Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _itemsList<T>(List<T> items, Widget Function(T item) builder) {
    if (items.isEmpty) return const Center(child: Text('No items found.'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => Card(
        elevation: 0,
        child: builder(items[index]),
      ),
    );
  }
}

class _Data {
  final List<AcademicLevel> levels;
  final List<AdminModule> modules;
  final List<AdminLecture> lectures;

  const _Data({
    required this.levels,
    required this.modules,
    required this.lectures,
  });
}
