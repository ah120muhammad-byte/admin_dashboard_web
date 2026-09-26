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

  void _reload() => setState(() => _future = _service.list());

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final short = TextEditingController(text: item?['short_description']?.toString() ?? '');
    final presentation = TextEditingController(text: item?['clinical_presentation']?.toString() ?? '');
    final history = TextEditingController(text: item?['history']?.toString() ?? '');
    final examination = TextEditingController(text: item?['examination']?.toString() ?? '');
    final investigations = TextEditingController(text: item?['investigations']?.toString() ?? '');
    final diagnosis = TextEditingController(text: item?['diagnosis']?.toString() ?? '');
    final management = TextEditingController(text: item?['management']?.toString() ?? '');
    final medications = TextEditingController(text: item?['medications']?.toString() ?? '');
    final color = TextEditingController(text: item?['font_color']?.toString() ?? '#000000');

    DateTime date = DateTime.tryParse(item?['case_date']?.toString() ?? '') ?? DateTime.now();
    bool published = item?['is_published'] == true;
    bool saving = false;

    final sectionImages = <String, String?>{
      'Clinical Presentation': item?['presentation_image_url']?.toString(),
      'History': item?['history_image_url']?.toString(),
      'Examination': item?['examination_image_url']?.toString(),
      'Investigations': item?['investigations_image_url']?.toString(),
      'Diagnosis': item?['diagnosis_image_url']?.toString(),
      'Management / Interventions': item?['management_image_url']?.toString(),
      'Medications': item?['medications_image_url']?.toString(),
    };

    String? backgroundUrl = item?['card_background_url']?.toString();
    String fontFamily = item?['font_family']?.toString() ?? 'default';
    double fontSize = (item?['font_size'] as num?)?.toDouble() ?? 16;

    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );

    Future<String?> pickAndUpload() async {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (picked == null || picked.files.isEmpty) return null;
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) return null;
      return _service.uploadImage(bytes, file.name);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(item == null ? 'Add Case of the Day' : 'Edit Case of the Day'),
          content: SizedBox(
            width: 780,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: decoration('Title')),
                  const SizedBox(height: 10),
                  TextField(controller: short, decoration: decoration('Short description'), maxLines: 3),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Case date: ${date.toLocal().toString().split(' ').first}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: date,
                        );
                        if (selected != null) setLocalState(() => date = selected);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CaseTextField(controller: presentation, decoration: decoration('Clinical presentation')),
                  _CaseImagePicker(
                    label: 'Clinical Presentation image',
                    url: sectionImages['Clinical Presentation'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['Clinical Presentation'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['Clinical Presentation'] = null),
                  ),
                  _CaseTextField(controller: history, decoration: decoration('History')),
                  _CaseImagePicker(
                    label: 'History image',
                    url: sectionImages['History'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['History'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['History'] = null),
                  ),
                  _CaseTextField(controller: examination, decoration: decoration('Examination')),
                  _CaseImagePicker(
                    label: 'Examination image',
                    url: sectionImages['Examination'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['Examination'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['Examination'] = null),
                  ),
                  _CaseTextField(controller: investigations, decoration: decoration('Investigations')),
                  _CaseImagePicker(
                    label: 'Investigations image',
                    url: sectionImages['Investigations'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['Investigations'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['Investigations'] = null),
                  ),
                  _CaseTextField(controller: diagnosis, decoration: decoration('Diagnosis')),
                  _CaseImagePicker(
                    label: 'Diagnosis image',
                    url: sectionImages['Diagnosis'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['Diagnosis'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['Diagnosis'] = null),
                  ),
                  _CaseTextField(controller: management, decoration: decoration('Management / Interventions')),
                  _CaseImagePicker(
                    label: 'Management image',
                    url: sectionImages['Management / Interventions'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['Management / Interventions'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['Management / Interventions'] = null),
                  ),
                  _CaseTextField(controller: medications, decoration: decoration('Medications')),
                  _CaseImagePicker(
                    label: 'Medications image',
                    url: sectionImages['Medications'],
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => sectionImages['Medications'] = url);
                    },
                    onRemove: () => setLocalState(() => sectionImages['Medications'] = null),
                  ),
                  const Divider(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Home card background', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  _CaseImagePicker(
                    label: 'Card background image',
                    url: backgroundUrl,
                    onPick: () async {
                      final url = await pickAndUpload();
                      if (url != null) setLocalState(() => backgroundUrl = url);
                    },
                    onRemove: () => setLocalState(() => backgroundUrl = null),
                  ),
                  const Divider(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Article text style', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: fontFamily,
                    decoration: decoration('Font type'),
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('Default')),
                      DropdownMenuItem(value: 'serif', child: Text('Serif')),
                      DropdownMenuItem(value: 'monospace', child: Text('Monospace')),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocalState(() => fontFamily = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Font size: ${fontSize.toStringAsFixed(0)} px'),
                      ),
                      SizedBox(
                        width: 300,
                        child: Slider(
                          min: 12,
                          max: 30,
                          divisions: 18,
                          value: fontSize,
                          label: '${fontSize.toStringAsFixed(0)} px',
                          onChanged: (value) => setLocalState(() => fontSize = value),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: color,
                    decoration: decoration('Font color (HEX, e.g. #1F2937)'),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _parseColor(color.text),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Published'),
                    value: published,
                    onChanged: (value) => setLocalState(() => published = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving || title.text.trim().isEmpty
                  ? null
                  : () async {
                      setLocalState(() => saving = true);
                      try {
                        final data = <String, dynamic>{
                          'title': title.text.trim(),
                          'case_date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                          'short_description': short.text.trim(),
                          'clinical_presentation': presentation.text.trim(),
                          'history': history.text.trim(),
                          'examination': examination.text.trim(),
                          'investigations': investigations.text.trim(),
                          'diagnosis': diagnosis.text.trim(),
                          'management': management.text.trim(),
                          'medications': medications.text.trim(),
                          'presentation_image_url': sectionImages['Clinical Presentation'],
                          'history_image_url': sectionImages['History'],
                          'examination_image_url': sectionImages['Examination'],
                          'investigations_image_url': sectionImages['Investigations'],
                          'diagnosis_image_url': sectionImages['Diagnosis'],
                          'management_image_url': sectionImages['Management / Interventions'],
                          'medications_image_url': sectionImages['Medications'],
                          'card_background_url': backgroundUrl,
                          'font_family': fontFamily,
                          'font_size': fontSize,
                          'font_color': color.text.trim().isEmpty ? '#000000' : color.text.trim(),
                          'is_published': published,
                        };
                        await _service.save(data, id: item?['id']?.toString());
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _reload();
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setLocalState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Save failed: $error')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      title, short, presentation, history, examination, investigations,
      diagnosis, management, medications, color,
    ]) {
      controller.dispose();
    }
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
                  Text('Case of the Day', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
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
                    ? const Center(child: Text('No clinical cases yet.'))
                    : ListView.builder(
                        itemCount: cases.length,
                        itemBuilder: (context, index) {
                          final currentCase = cases[index];
                          final published = currentCase['is_published'] == true;
                          final hasBackground = (currentCase['card_background_url']?.toString() ?? '').isNotEmpty;
                          return Card(
                            child: ListTile(
                              leading: hasBackground
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        currentCase['card_background_url'].toString(),
                                        width: 54,
                                        height: 54,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.local_hospital_outlined),
                              title: Text(currentCase['title']?.toString() ?? ''),
                              subtitle: Text('${currentCase['case_date'] ?? ''}  •  ${published ? 'Published' : 'Draft'}'),
                              onTap: () => _edit(currentCase),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await _service.delete(currentCase['id'].toString());
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
  const _CaseTextField({required this.controller, required this.decoration});
  final TextEditingController controller;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, decoration: decoration, maxLines: 5),
  );
}

class _CaseImagePicker extends StatelessWidget {
  const _CaseImagePicker({
    required this.label,
    required this.url,
    required this.onPick,
    required this.onRemove,
  });

  final String label;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(hasImage ? '$label • Image selected' : '$label • No image')),
          if (hasImage)
            IconButton(
              tooltip: 'Remove image',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.image_outlined),
            label: Text(hasImage ? 'Change' : 'Add image'),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String value) {
  var hex = value.trim().replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return Colors.black;
  return Color(int.tryParse(hex, radix: 16) ?? 0xFF000000);
}

class ClinicalCaseAdminService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await client.from('clinical_cases').select().order('case_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> uploadImage(Uint8List bytes, String name) async {
    final path = 'cases/${DateTime.now().microsecondsSinceEpoch}_$name';
    await client.storage.from('clinical-case-images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: false),
    );
    return client.storage.from('clinical-case-images').getPublicUrl(path);
  }

  Future<void> save(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await client.from('clinical_cases').insert(data);
    } else {
      await client.from('clinical_cases').update({
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await client.from('clinical_cases').delete().eq('id', id);
  }
}
