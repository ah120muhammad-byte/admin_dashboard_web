import 'package:flutter/material.dart';
import '../../../core/services/admin_modules_service.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final AdminModulesService _service = AdminModulesService();

  late Future<List<AdminModule>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _modulesFuture = _service.getModules();
  }

  Future<void> _refresh() async {
    setState(() {
      _load();
    });

    await _modulesFuture;
  }

  Future<void> _showModuleDialog({AdminModule? module}) async {
    final levels = await _service.getAcademicLevels();

    if (!mounted) return;

    String? selectedLevelId = module?.academicLevelId;

    final nameController = TextEditingController(text: module?.name ?? '');

    final descriptionController = TextEditingController(
      text: module?.description ?? '',
    );

    final orderController = TextEditingController(
      text: (module?.displayOrder ?? 0).toString(),
    );

    final imageController = TextEditingController(text: module?.imageUrl ?? '');

    bool isActive = module?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(module == null ? 'Add Module' : 'Edit Module'),
              content: SizedBox(
                width: 500,
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
                            border: OutlineInputBorder(),
                          ),
                          items: levels.map((level) {
                            return DropdownMenuItem<String>(
                              value: level.id,
                              child: Text(level.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedLevelId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Academic Level is required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

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
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final academicLevelId = selectedLevelId!;

                    final name = nameController.text.trim();

                    final description = descriptionController.text.trim();

                    final displayOrder = int.parse(orderController.text.trim());

                    final imageUrl = imageController.text.trim();

                    try {
                      if (module == null) {
                        await _service.createModule(
                          academicLevelId: academicLevelId,
                          name: name,
                          description: description,
                          imageUrl: imageUrl,
                          displayOrder: displayOrder,
                        );
                      } else {
                        await _service.updateModule(
                          id: module.id,
                          academicLevelId: academicLevelId,
                          name: name,
                          description: description.isEmpty ? null : description,
                          imageUrl: imageUrl.isEmpty ? null : imageUrl,
                          displayOrder: displayOrder,
                          isActive: isActive,
                        );
                      }

                      if (!mounted) return;

                      Navigator.pop(dialogContext);

                      setState(() {
                        _load();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            module == null ? 'Module added' : 'Module updated',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: Text(module == null ? 'Add' : 'Save'),
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

  Future<void> _toggleActive(AdminModule module) async {
    try {
      await _service.toggleModuleStatus(
        id: module.id,
        isActive: !module.isActive,
      );

      if (!mounted) return;

      setState(() {
        _load();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            module.isActive ? 'Module deactivated' : 'Module activated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                _showModuleDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Module'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<AdminModule>>(
        future: _modulesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 50),
                    const SizedBox(height: 12),
                    const Text('Unable to load Modules'),
                    const SizedBox(height: 8),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final modules = snapshot.data ?? [];

          if (modules.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('No modules found.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${module.displayOrder}'),
                    ),
                    title: Text(
                      module.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      module.description?.isNotEmpty == true
                          ? module.description!
                          : 'No description',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(module.isActive ? 'Active' : 'Inactive'),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () {
                            _showModuleDialog(module: module);
                          },
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'Activate / Deactivate',
                          onPressed: () {
                            _toggleActive(module);
                          },
                          icon: Icon(
                            module.isActive
                                ? Icons.visibility_off
                                : Icons.visibility,
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
