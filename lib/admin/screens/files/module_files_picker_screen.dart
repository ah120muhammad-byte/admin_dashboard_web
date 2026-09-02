import 'package:flutter/material.dart';

import '../../../core/services/lectures_service.dart';
import 'module_files_management_screen_v2.dart';

class ModuleFilesPickerScreen extends StatefulWidget {
  const ModuleFilesPickerScreen({super.key});

  @override
  State<ModuleFilesPickerScreen> createState() => _ModuleFilesPickerScreenState();
}

class _ModuleFilesPickerScreenState extends State<ModuleFilesPickerScreen> {
  final LecturesService _service = LecturesService();
  final TextEditingController _searchController = TextEditingController();
  late Future<_PickerData> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _search) return;
    setState(() { _search = value; });
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
      MaterialPageRoute(builder: (_) => ModuleFilesManagementScreen(module: module)),
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
          return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')));
        }
        final data = snapshot.data!;
        final modules = _search.isEmpty ? data.modules : data.modules.where((m) => m.name.toLowerCase().contains(_search)).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Files & Downloads', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Select a module to manage its PDF, audio and video files.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      )),
                      IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Search modules...', prefixIcon: Icon(Icons.search_rounded))),
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
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 420, mainAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14),
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          final count = data.lectures.where((l) => l.moduleId == module.id).length;
                          return _ModuleCard(module: module, lectures: count, onTap: () => _openModule(module));
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
  final int lectures;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.lectures, required this.onTap});

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
              Row(children: [
                Container(width: 54, height: 54, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.folder_rounded, color: scheme.primary)),
                const SizedBox(width: 14),
                Expanded(child: Text(module.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: scheme.onSurfaceVariant),
              ]),
              const Spacer(),
              Text('$lectures ${lectures == 1 ? 'lecture' : 'lectures'}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Open to manage files inside each lecture.', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
