import 'package:flutter/material.dart';

import '../../../core/services/academic_levels_service.dart';

class AcademicLevelsScreen extends StatefulWidget {
  const AcademicLevelsScreen({super.key});

  @override
  State<AcademicLevelsScreen> createState() => _AcademicLevelsScreenState();
}

class _AcademicLevelsScreenState extends State<AcademicLevelsScreen> {
  final AcademicLevelsService _service = AcademicLevelsService();

  late Future<List<AcademicLevel>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _levelsFuture = _service.getLevels();
  }

  Future<void> _refresh() async {
    final future = _service.getLevels();

    setState(() {
      _levelsFuture = future;
    });

    await future;
  }

  Future<void> _showLevelDialog({AcademicLevel? level}) async {
    final nameController = TextEditingController(text: level?.name ?? '');
    final descriptionController = TextEditingController(
      text: level?.description ?? '',
    );
    final orderController = TextEditingController(
      text: (level?.displayOrder ?? 0).toString(),
    );
    final imageController = TextEditingController(
      text: level?.imageUrl ?? '',
    );

    bool isActive = level?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  level == null
                      ? 'Add Academic Level'
                      : 'Edit Academic Level',
                ),
                content: SizedBox(
                  width: 500,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: orderController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Display Order',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final number = int.tryParse(value ?? '');
                              if (number == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: imageController,
                            decoration: const InputDecoration(
                              labelText: 'Image URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active'),
                            value: isActive,
                            onChanged: (value) {
                              setDialogState(() {
                                isActive = value;
                              });
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
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();
                      final displayOrder =
                          int.parse(orderController.text.trim());
                      final imageUrl = imageController.text.trim();

                      setDialogState(() {});

                      try {
                        if (level == null) {
                          await _service.addLevel(
                            name: name,
                            description:
                                description.isEmpty ? null : description,
                            displayOrder: displayOrder,
                            isActive: isActive,
                            imageUrl: imageUrl.isEmpty ? null : imageUrl,
                          );
                        } else {
                          await _service.updateLevel(
                            id: level.id,
                            name: name,
                            description:
                                description.isEmpty ? null : description,
                            displayOrder: displayOrder,
                            isActive: isActive,
                            imageUrl: imageUrl.isEmpty ? null : imageUrl,
                          );
                        }

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!mounted) return;
                        final future = _service.getLevels();
                        setState(() {
                          _levelsFuture = future;
                        });

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              level == null
                                  ? 'Academic level added'
                                  : 'Academic level updated',
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
                    child: Text(level == null ? 'Add' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      orderController.dispose();
      imageController.dispose();
    }
  }

  Future<void> _toggleActive(AcademicLevel level) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _service.setActive(
        id: level.id,
        isActive: !level.isActive,
      );

      if (!mounted) return;

      final future = _service.getLevels();
      setState(() {
        _levelsFuture = future;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            level.isActive
                ? 'Academic level deactivated'
                : 'Academic level activated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<AcademicLevel>>(
      future: _levelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        }

        final levels = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Academic Levels',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Manage academic levels, ordering, visibility and images.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _showLevelDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Level'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                sliver: levels.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyLevelsState(),
                      )
                    : SliverList.separated(
                        itemCount: levels.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final level = levels[index];
                          return _LevelCard(
                            level: level,
                            onEdit: () => _showLevelDialog(level: level),
                            onToggle: () => _toggleActive(level),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 52,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(
                  'Unable to load Academic Levels',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SelectableText(
                    error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final AcademicLevel level;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LevelCard({
    required this.level,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = level.imageUrl?.trim();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _LevelThumbnail(imageUrl: imageUrl),
            const SizedBox(width: 16),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${level.displayOrder}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          level.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(isActive: level.isActive),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    level.description?.trim().isNotEmpty == true
                        ? level.description!.trim()
                        : 'No description provided.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: level.isActive ? 'Deactivate' : 'Activate',
              onPressed: onToggle,
              icon: Icon(
                level.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _LevelThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.school_outlined,
          color: theme.colorScheme.primary,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl!,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 76,
          height: 76,
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyLevelsState extends StatelessWidget {
  const _EmptyLevelsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_outlined,
                size: 58,
                color: theme.colorScheme.primary.withValues(alpha: 0.70),
              ),
              const SizedBox(height: 14),
              Text(
                'No academic levels yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create your first academic level using the button above.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
