import 'package:flutter/material.dart';

import '../../../core/services/lectures_service.dart';
import '../modules/module_management_screen_v2.dart';

class ModuleContentPickerScreen extends StatefulWidget {
  const ModuleContentPickerScreen({super.key});

  @override
  State<ModuleContentPickerScreen> createState() => _ModuleContentPickerScreenState();
}

class _ModuleContentPickerScreenState extends State<ModuleContentPickerScreen> {
  final LecturesService _service = LecturesService();
  final TextEditingController _searchController = TextEditingController();

  late Future<_PickerData> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value == _search) return;
      setState(() { _search = value; });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_PickerData> _load() async {
    final results = await Future.wait<dynamic>([
      _service.getModules(),
      _service.getLectures(),
    ]);
    return _PickerData(
      modules: results[0] as List<LectureModule>,
      lectures: results[1] as List<AdminLecture>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() { _future = future; });
    await future;
  }

  void _openModule(LectureModule module) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModuleManagementScreen(module: module),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_PickerData>(
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
        final modules = _search.isEmpty
            ? data.modules
            : data.modules.where((m) => m.name.toLowerCase().contains(_search)).toList();

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
                              'Lecture Content',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select a module to manage its lectures and files.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search modules...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${modules.length} module${modules.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: modules.isEmpty
                  ? const Center(child: Text('No modules found.'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 200,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          final lectures = data.lectures.where((l) => l.moduleId == module.id).toList();
                          final published = lectures.where((l) => l.isPublished).length;
                          return _ModuleCard(
                            module: module,
                            lectureCount: lectures.length,
                            publishedCount: published,
                            onTap: () => _openModule(module),
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

class _PickerData {
  final List<LectureModule> modules;
  final List<AdminLecture> lectures;
  const _PickerData({required this.modules, required this.lectures});
}

class _ModuleCard extends StatelessWidget {
  final LectureModule module;
  final int lectureCount;
  final int publishedCount;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.lectureCount,
    required this.publishedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: scheme.primary, size: 27),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      module.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: _Metric(label: 'Lectures', value: '$lectureCount')),
                  const SizedBox(width: 10),
                  Expanded(child: _Metric(label: 'Published', value: '$publishedCount')),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Open to manage lectures & PDF / Audio / Video',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
