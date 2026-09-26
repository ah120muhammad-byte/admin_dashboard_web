import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicalCasesScreen extends StatefulWidget {
  const ClinicalCasesScreen({super.key});

  @override
  State<ClinicalCasesScreen> createState() => _ClinicalCasesScreenState();
}

class _ClinicalCasesScreenState extends State<ClinicalCasesScreen> {
  final ClinicalCaseAdminService _service = ClinicalCaseAdminService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list();
  }

  void _reload() {
    setState(() {
      _future = _service.list();
    });
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final title = TextEditingController(
      text: item?['title']?.toString() ?? '',
    );
    final short = TextEditingController(
      text: item?['short_description']?.toString() ?? '',
    );
    final presentation = TextEditingController(
      text: item?['clinical_presentation']?.toString() ?? '',
    );
    final history = TextEditingController(
      text: item?['history']?.toString() ?? '',
    );
    final examination = TextEditingController(
      text: item?['examination']?.toString() ?? '',
    );
    final investigations = TextEditingController(
      text: item?['investigations']?.toString() ?? '',
    );
    final diagnosis = TextEditingController(
      text: item?['diagnosis']?.toString() ?? '',
    );
    final management = TextEditingController(
      text: item?['management']?.toString() ?? '',
    );
    final medications = TextEditingController(
      text: item?['medications']?.toString() ?? '',
    );

    DateTime date =
        DateTime.tryParse(item?['case_date']?.toString() ?? '') ??
        DateTime.now();

    bool published = (item?['is_published'] as bool?) ?? false;

    List<String> images = List<String>.from(
      (item?['image_urls'] as List?) ?? const <String>[],
    );

    bool saving = false;

    InputDecoration decoration(String label) {
      return InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(
                item == null
                    ? 'Add Case of the Day'
                    : 'Edit Case of the Day',
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        decoration: decoration('Title'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: short,
                        decoration: decoration('Short description'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Case date: '
                          '${date.toLocal().toString().split(' ').first}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: date,
                            );

                            if (selected != null) {
                              setLocalState(() {
                                date = selected;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CaseTextField(
                        controller: presentation,
                        decoration: decoration('Clinical presentation'),
                      ),
                      _CaseTextField(
                        controller: history,
                        decoration: decoration('History'),
                      ),
                      _CaseTextField(
                        controller: examination,
                        decoration: decoration('Examination'),
                      ),
                      _CaseTextField(
                        controller: investigations,
                        decoration: decoration('Investigations'),
                      ),
                      _CaseTextField(
                        controller: diagnosis,
                        decoration: decoration('Diagnosis'),
                      ),
                      _CaseTextField(
                        controller: management,
                        decoration: decoration(
                          'Management / Interventions',
                        ),
                      ),
                      _CaseTextField(
                        controller: medications,
                        decoration: decoration('Medications'),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Images',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...images.map(
                              (url) => Chip(
                                label: SizedBox(
                                  width: 260,
                                  child: Text(
                                    url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                onDeleted: () {
                                  setLocalState(() {
                                    images.remove(url);
                                  });
                                },
                              ),
                            ),
                            ActionChip(
                              label: const Text('Add image'),
                              avatar: const Icon(Icons.upload_file),
                              onPressed: () async {
                                final picked =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  withData: true,
                                  allowMultiple: true,
                                );

                                if (picked == null) {
                                  return;
                                }

                                for (final file in picked.files) {
                                  final bytes = file.bytes;
                                  if (bytes == null) {
                                    continue;
                                  }

                                  final url = await _service.uploadImage(
                                    bytes,
                                    file.name,
                                  );

                                  setLocalState(() {
                                    images.add(url);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Published'),
                        value: published,
                        onChanged: (value) {
                          setLocalState(() {
                            published = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving || title.text.trim().isEmpty
                      ? null
                      : () async {
                          setLocalState(() {
                            saving = true;
                          });

                          try {
                            final data = <String, dynamic>{
                              'title': title.text.trim(),
                              'case_date':
                                  '${date.year.toString().padLeft(4, '0')}-'
                                  '${date.month.toString().padLeft(2, '0')}-'
                                  '${date.day.toString().padLeft(2, '0')}',
                              'short_description': short.text.trim(),
                              'clinical_presentation':
                                  presentation.text.trim(),
                              'history': history.text.trim(),
                              'examination': examination.text.trim(),
                              'investigations': investigations.text.trim(),
                              'diagnosis': diagnosis.text.trim(),
                              'management': management.text.trim(),
                              'medications': medications.text.trim(),
                              'image_urls': images,
                              'is_published': published,
                            };

                            await _service.save(
                              data,
                              id: item?['id']?.toString(),
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            _reload();
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setLocalState(() {
                                saving = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Save failed: $error'),
                                ),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    short.dispose();
    presentation.dispose();
    history.dispose();
    examination.dispose();
    investigations.dispose();
    diagnosis.dispose();
    management.dispose();
    medications.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data ?? const <Map<String, dynamic>>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Case of the Day',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Case'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: cases.isEmpty
                    ? const Center(
                        child: Text('No clinical cases yet.'),
                      )
                    : ListView.builder(
                        itemCount: cases.length,
                        itemBuilder: (context, index) {
                          final currentCase = cases[index];
                          final isPublished =
                              currentCase['is_published'] == true;

                          return Card(
                            child: ListTile(
                              title: Text(
                                currentCase['title']?.toString() ?? '',
                              ),
                              subtitle: Text(
                                '${currentCase['case_date'] ?? ''}  •  '
                                '${isPublished ? 'Published' : 'Draft'}',
                              ),
                              leading: const Icon(
                                Icons.local_hospital_outlined,
                              ),
                              onTap: () => _edit(currentCase),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await _service.delete(
                                    currentCase['id'].toString(),
                                  );
                                  _reload();
                                },
                              ),
                            ),
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

class _CaseTextField extends StatelessWidget {
  const _CaseTextField({
    required this.controller,
    required this.decoration,
  });

  final TextEditingController controller;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: decoration,
        maxLines: 5,
      ),
    );
  }
}

class ClinicalCaseAdminService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await client
        .from('clinical_cases')
        .select()
        .order('case_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> uploadImage(Uint8List bytes, String name) async {
    final path =
        'cases/${DateTime.now().microsecondsSinceEpoch}_$name';

    await client.storage.from('clinical-case-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return client.storage.from('clinical-case-images').getPublicUrl(path);
  }

  Future<void> save(
    Map<String, dynamic> data, {
    String? id,
  }) async {
    if (id == null) {
      await client.from('clinical_cases').insert(data);
      return;
    }

    await client
        .from('clinical_cases')
        .update({
          ...data,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await client.from('clinical_cases').delete().eq('id', id);
  }
}
