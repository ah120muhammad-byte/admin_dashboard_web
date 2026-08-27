import 'package:flutter/material.dart';
import '../../../core/services/academic_levels_service.dart';

class AcademicLevelsScreen extends StatefulWidget {
  const AcademicLevelsScreen({super.key});

  @override
  State<AcademicLevelsScreen> createState() =>
      _AcademicLevelsScreenState();
}

class _AcademicLevelsScreenState
    extends State<AcademicLevelsScreen> {
  final AcademicLevelsService _service =
      AcademicLevelsService();

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
    setState(() {
      _load();
    });

    await _levelsFuture;
  }

  Future<void> _showLevelDialog({
    AcademicLevel? level,
  }) async {
    final nameController =
        TextEditingController(
      text: level?.name ?? '',
    );

    final descriptionController =
        TextEditingController(
      text: level?.description ?? '',
    );

    final orderController =
        TextEditingController(
      text: (level?.displayOrder ?? 0).toString(),
    );

    final imageController =
        TextEditingController(
      text: level?.imageUrl ?? '',
    );

    bool isActive = level?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
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
                          decoration:
                              const InputDecoration(
                            labelText: 'Name',
                            border:
                                OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Name is required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller:
                              descriptionController,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(
                            labelText: 'Description',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: orderController,
                          keyboardType:
                              TextInputType.number,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Display Order',
                            border:
                                OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final number =
                                int.tryParse(
                              value ?? '',
                            );

                            if (number == null) {
                              return 'Enter a valid number';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: imageController,
                          decoration:
                              const InputDecoration(
                            labelText: 'Image URL',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SwitchListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          title:
                              const Text('Active'),
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
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!
                        .validate()) {
                      return;
                    }

                    final name =
                        nameController.text.trim();

                    final description =
                        descriptionController
                            .text
                            .trim();

                    final displayOrder =
                        int.parse(
                      orderController.text.trim(),
                    );

                    final imageUrl =
                        imageController.text
                            .trim();

                    try {
                      if (level == null) {
                        await _service.addLevel(
                          name: name,
                          description:
                              description.isEmpty
                                  ? null
                                  : description,
                          displayOrder:
                              displayOrder,
                          isActive: isActive,
                          imageUrl:
                              imageUrl.isEmpty
                                  ? null
                                  : imageUrl,
                        );
                      } else {
                        await _service.updateLevel(
                          id: level.id,
                          name: name,
                          description:
                              description.isEmpty
                                  ? null
                                  : description,
                          displayOrder:
                              displayOrder,
                          isActive: isActive,
                          imageUrl:
                              imageUrl.isEmpty
                                  ? null
                                  : imageUrl,
                        );
                      }

                      if (!mounted) return;

                      Navigator.pop(
                        dialogContext,
                      );

                      setState(() {
                        _load();
                      });

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            level == null
                                ? 'Academic level added'
                                : 'Academic level updated',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error: $e',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    level == null
                        ? 'Add'
                        : 'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    orderController.dispose();
    imageController.dispose();
  }

  Future<void> _toggleActive(
    AcademicLevel level,
  ) async {
    try {
      await _service.setActive(
        id: level.id,
        isActive: !level.isActive,
      );

      if (!mounted) return;

      setState(() {
        _load();
      });

      ScaffoldMessenger.of(context).showSnackBar(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Levels'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                _showLevelDialog();
              },
              icon: const Icon(
                Icons.add,
              ),
              label: const Text(
                'Add Level',
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<AcademicLevel>>(
        future: _levelsFuture,
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
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 50,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'Unable to load Academic Levels',
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign:
                          TextAlign.center,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    ElevatedButton(
                      onPressed: _refresh,
                      child:
                          const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final levels =
              snapshot.data ?? [];

          if (levels.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(
                    height: 180,
                  ),
                  Center(
                    child: Text(
                      'No academic levels found.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding:
                  const EdgeInsets.all(24),
              itemCount: levels.length,
              itemBuilder: (
                context,
                index,
              ) {
                final level =
                    levels[index];

                return Card(
                  margin:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        '${level.displayOrder}',
                      ),
                    ),
                    title: Text(
                      level.name,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      level.description
                                  ?.isNotEmpty ==
                              true
                          ? level.description!
                          : 'No description',
                    ),
                    trailing: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            level.isActive
                                ? 'Active'
                                : 'Inactive',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () {
                            _showLevelDialog(
                              level: level,
                            );
                          },
                          icon: const Icon(
                            Icons.edit,
                          ),
                        ),
                        IconButton(
                          tooltip:
                              'Activate / Deactivate',
                          onPressed: () {
                            _toggleActive(
                              level,
                            );
                          },
                          icon: Icon(
                            level.isActive
                                ? Icons
                                    .visibility_off
                                : Icons
                                    .visibility,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}