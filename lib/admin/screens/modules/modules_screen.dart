import 'package:flutter/material.dart';

import '../../../core/services/admin_modules_service.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final AdminModulesService _service = AdminModulesService();
  final TextEditingController _searchController = TextEditingController();

  late Future<_ModulesPageData> _future;
  String _search = '';
  String? _selectedLevelId;
  String _status = 'All';

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _search) return;
    setState(() => _search = value);
  }

  Future<_ModulesPageData> _loadData() async {
    final responses = await Future.wait([
      _service.getModules(),
      _service.getAcademicLevels(),
    ]);

    return _ModulesPageData(
      modules: responses[0] as List<AdminModule>,
      levels: responses[1] as List<AcademicLevelOption>,
    );
  }

  Future<void> _refresh() async {
    final future = _loadData();
    setState(() {
      _future = future;
    });
    await future;
  }

  List<AdminModule> _filteredModules(List<AdminModule> modules) {
    return modules.where((module) {
      final matchesSearch = _search.isEmpty ||
          module.name.toLowerCase().contains(_search) ||
          (module.description ?? '').toLowerCase().contains(_search);
      final matchesLevel = _selectedLevelId == null ||
          module.academicLevelId == _selectedLevelId;
      final matchesStatus = _status == 'All' ||
          (_status == 'Active' && module.isActive) ||
          (_status == 'Inactive' && !module.isActive);

      return matchesSearch && matchesLevel && matchesStatus;
    }).toList();
  }

  String _levelName(
    String levelId,
    List<AcademicLevelOption> levels,
  ) {
    for (final level in levels) {
      if (level.id == levelId) return level.name;
    }
    return 'Unknown Level';
  }

  Future<void> _showModuleDialog({AdminModule? module}) async {
    final levels = await _service.getAcademicLevels();
    if (!mounted) return;

    String? selectedLevelId = module?.academicLevelId;
    bool isActive = module?.isActive ?? true;

    final nameController = TextEditingController(text: module?.name ?? '');
    final descriptionController = TextEditingController(
      text: module?.description ?? '',
    );
    final orderController = TextEditingController(
      text: (module?.displayOrder ?? 0).toString(),
    );
    final imageController = TextEditingController(
      text: module?.imageUrl ?? '',
    );
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(module == null ? 'Add Module' : 'Edit Module'),
            content: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedLevelId,
                        decoration: const InputDecoration(
                          labelText: 'Academic Level',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: levels
                            .map(
                              (level) => DropdownMenuItem<String>(
                                value: level.id,
                                child: Text(level.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedLevelId = value);
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Academic Level is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Module Name',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Display Order',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        validator: (value) =>
                            int.tryParse(value ?? '') == null
                                ? 'Enter a valid number'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: 'Image URL',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text('Make this module visible to students'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final levelId = selectedLevelId;
                  if (levelId == null) return;

                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  final displayOrder = int.parse(orderController.text.trim());
                  final imageUrl = imageController.text.trim();

                  try {
                    if (module == null) {
                      await _service.createModule(
                        academicLevelId: levelId,
                        name: name,
                        description: description.isEmpty ? null : description,
                        imageUrl: imageUrl.isEmpty ? null : imageUrl,
                        displayOrder: displayOrder,
                        isActive: isActive,
                      );
                    } else {
                      await _service.updateModule(
                        id: module.id,
                        academicLevelId: levelId,
                        name: name,
                        description: description.isEmpty ? null : description,
                        imageUrl: imageUrl.isEmpty ? null : imageUrl,
                        displayOrder: displayOrder,
                        isActive: isActive,
                      );
                    }

                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    final future = _loadData();
                    setState(() => _future = future);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          module == null ? 'Module added' : 'Module updated',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                icon: Icon(module == null ? Icons.add : Icons.save_outlined),
                label: Text(module == null ? 'Add Module' : 'Save Changes'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      orderController.dispose();
      imageController.dispose();
    }
  }

  Future<void> _toggleActive(AdminModule module) async {
    try {
      await _service.toggleModuleStatus(
        id: module.id,
        isActive: !module.isActive,
      );
      if (!mounted) return;

      final future = _loadData();
      setState(() => _future = future);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            module.isActive ? 'Module deactivated' : 'Module activated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_ModulesPageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _ErrorState(
            message: 'Unable to load modules.',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final modules = _filteredModules(data.modules);
        final activeCount = data.modules.where((e) => e.isActive).length;
        final inactiveCount = data.modules.length - activeCount;

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
                              'Modules',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage modules, academic levels and visibility.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showModuleDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Module'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        icon: Icons.menu_book_outlined,
                        label: 'Total Modules',
                        value: data.modules.length.toString(),
                      ),
                      _StatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Active',
                        value: activeCount.toString(),
                      ),
                      _StatCard(
                        icon: Icons.visibility_off_outlined,
                        label: 'Inactive',
                        value: inactiveCount.toString(),
                      ),
                      _StatCard(
                        icon: Icons.school_outlined,
                        label: 'Academic Levels',
                        value: data.levels.length.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 850;
                      final search = TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search modules...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      );
                      final levelFilter = DropdownButtonFormField<String>(
                        initialValue: _selectedLevelId,
                        decoration: const InputDecoration(labelText: 'Academic Level'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Levels'),
                          ),
                          ...data.levels.map(
                            (level) => DropdownMenuItem<String>(
                              value: level.id,
                              child: Text(level.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _selectedLevelId = value),
                      );
                      final statusFilter = DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'Active', child: Text('Active')),
                          DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _status = value);
                        },
                      );

                      return compact
                          ? Column(
                              children: [
                                search,
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: levelFilter),
                                    const SizedBox(width: 10),
                                    Expanded(child: statusFilter),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(flex: 2, child: search),
                                const SizedBox(width: 10),
                                SizedBox(width: 210, child: levelFilter),
                                const SizedBox(width: 10),
                                SizedBox(width: 180, child: statusFilter),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: modules.isEmpty
                  ? const _EmptyModules()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          return _ModuleCard(
                            module: module,
                            levelName: _levelName(module.academicLevelId, data.levels),
                            onEdit: () => _showModuleDialog(module: module),
                            onToggle: () => _toggleActive(module),
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

class _ModulesPageData {
  final List<AdminModule> modules;
  final List<AcademicLevelOption> levels;

  const _ModulesPageData({required this.modules, required this.levels});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 190,
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

class _ModuleCard extends StatelessWidget {
  final AdminModule module;
  final String levelName;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _ModuleCard({
    required this.module,
    required this.levelName,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = module.imageUrl?.trim() ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: imageUrl.isEmpty
                    ? Container(
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: theme.colorScheme.primary,
                          size: 30,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: theme.colorScheme.primary,
                            size: 30,
                          ),
                        ),
                      ),
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
                        module.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _StatusChip(active: module.isActive),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    levelName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    module.description?.isNotEmpty == true
                        ? module.description!
                        : 'No description provided.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '#${module.displayOrder}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: module.isActive ? 'Deactivate' : 'Activate',
                      onPressed: onToggle,
                      icon: Icon(
                        module.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
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
  final bool active;

  const _StatusChip({required this.active});

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
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyModules extends StatelessWidget {
  const _EmptyModules();

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
              'No modules found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing the search or filters, or add a new module.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
