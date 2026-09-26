import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicalCasesScreen extends StatefulWidget {
  const ClinicalCasesScreen({super.key});
  @override State<ClinicalCasesScreen> createState() => _ClinicalCasesScreenState();
}

class _ClinicalCasesScreenState extends State<ClinicalCasesScreen> {
  final ClinicalCaseAdminService _service = ClinicalCaseAdminService();
  late Future<List<Map<String, dynamic>>> _future;

  @override void initState() { super.initState(); _future = _service.list(); }
  void _reload() => setState(() => _future = _service.list());

  QuillController _makeController(String? rich, String? plain) {
    try {
      if ((rich ?? '').trim().isNotEmpty) {
        return QuillController(
          document: Document.fromJson(jsonDecode(rich!)),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {}
    final text = plain ?? '';
    return QuillController(
      document: Document.fromJson([{'insert': '$text\n'}]),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  String _json(QuillController controller) =>
      jsonEncode(controller.document.toDelta().toJson());

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final short = TextEditingController(text: item?['short_description']?.toString() ?? '');

    final editors = <String, QuillController>{
      'Clinical Presentation': _makeController(item?['clinical_presentation_rich']?.toString(), item?['clinical_presentation']?.toString()),
      'History': _makeController(item?['history_rich']?.toString(), item?['history']?.toString()),
      'Examination': _makeController(item?['examination_rich']?.toString(), item?['examination']?.toString()),
      'Investigations': _makeController(item?['investigations_rich']?.toString(), item?['investigations']?.toString()),
      'Diagnosis': _makeController(item?['diagnosis_rich']?.toString(), item?['diagnosis']?.toString()),
      'Management / Interventions': _makeController(item?['management_rich']?.toString(), item?['management']?.toString()),
      'Medications': _makeController(item?['medications_rich']?.toString(), item?['medications']?.toString()),
    };

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

    InputDecoration decoration(String label) => InputDecoration(
      labelText: label, border: const OutlineInputBorder(),
    );

    Future<String?> pickAndUpload() async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true,
      );
      if (picked == null || picked.files.isEmpty) return null;
      final file = picked.files.first;
      if (file.bytes == null) return null;
      return _service.uploadImage(file.bytes!, file.name);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(item == null ? 'Add Case of the Day' : 'Edit Case of the Day'),
          content: SizedBox(
            width: 850,
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
                  for (final entry in editors.entries) ...[
                    _RichCaseEditor(title: entry.key, controller: entry.value),
                    _CaseImagePicker(
                      label: '${entry.key} image',
                      url: sectionImages[entry.key],
                      onPick: () async {
                        final url = await pickAndUpload();
                        if (url != null) setLocalState(() => sectionImages[entry.key] = url);
                      },
                      onRemove: () => setLocalState(() => sectionImages[entry.key] = null),
                    ),
                  ],
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
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Text formatting is applied to the selected text, not to the whole article.'),
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
              onPressed: saving || title.text.trim().isEmpty ? null : () async {
                setLocalState(() => saving = true);
                try {
                  final data = <String, dynamic>{
                    'title': title.text.trim(),
                    'case_date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    'short_description': short.text.trim(),
                    'clinical_presentation': editors['Clinical Presentation']!.document.toPlainText().trim(),
                    'clinical_presentation_rich': _json(editors['Clinical Presentation']!),
                    'history': editors['History']!.document.toPlainText().trim(),
                    'history_rich': _json(editors['History']!),
                    'examination': editors['Examination']!.document.toPlainText().trim(),
                    'examination_rich': _json(editors['Examination']!),
                    'investigations': editors['Investigations']!.document.toPlainText().trim(),
                    'investigations_rich': _json(editors['Investigations']!),
                    'diagnosis': editors['Diagnosis']!.document.toPlainText().trim(),
                    'diagnosis_rich': _json(editors['Diagnosis']!),
                    'management': editors['Management / Interventions']!.document.toPlainText().trim(),
                    'management_rich': _json(editors['Management / Interventions']!),
                    'medications': editors['Medications']!.document.toPlainText().trim(),
                    'medications_rich': _json(editors['Medications']!),
                    'presentation_image_url': sectionImages['Clinical Presentation'],
                    'history_image_url': sectionImages['History'],
                    'examination_image_url': sectionImages['Examination'],
                    'investigations_image_url': sectionImages['Investigations'],
                    'diagnosis_image_url': sectionImages['Diagnosis'],
                    'management_image_url': sectionImages['Management / Interventions'],
                    'medications_image_url': sectionImages['Medications'],
                    'card_background_url': backgroundUrl,
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

    title.dispose();
    short.dispose();
    for (final controller in editors.values) {
      controller.dispose();
    }
  }

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cases = snapshot.data ?? const <Map<String, dynamic>>[];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Case of the Day', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add Case')),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: cases.isEmpty
                  ? const Center(child: Text('No clinical cases yet.'))
                  : ListView.builder(
                      itemCount: cases.length,
                      itemBuilder: (context, index) {
                        final currentCase = cases[index];
                        final published = currentCase['is_published'] == true;
                        final bg = currentCase['card_background_url']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            leading: bg.isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(bg, width: 54, height: 54, fit: BoxFit.cover))
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
          ]);
        },
      ),
    );
  }
}

class _RichCaseEditor extends StatelessWidget {
  const _RichCaseEditor({required this.title, required this.controller});
  final String title;
  final QuillController controller;

  @override Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        QuillSimpleToolbar(
          controller: controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: true,
            showSearchButton: false,
            showCodeBlock: false,
            showQuote: true,
            showLink: true,
            showFontFamily: true,
            showFontSize: true,
            showColorButton: true,
            showBackgroundColorButton: true,
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 180,
          child: QuillEditor.basic(
            controller: controller,
            config: const QuillEditorConfig(
              padding: EdgeInsets.all(12),
              showCodeBlockLineNumbers: false,
            ),
          ),
        ),
      ]),
    );
  }
}

class _CaseImagePicker extends StatelessWidget {
  const _CaseImagePicker({required this.label, required this.url, required this.onPick, required this.onRemove});
  final String label;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override Widget build(BuildContext context) {
    final hasImage = url != null && url!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: Text(hasImage ? '$label • Image selected' : '$label • No image')),
        if (hasImage) IconButton(tooltip: 'Remove image', onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        OutlinedButton.icon(onPressed: onPick, icon: const Icon(Icons.image_outlined), label: Text(hasImage ? 'Change' : 'Add image')),
      ]),
    );
  }
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
      path, bytes, fileOptions: const FileOptions(upsert: false),
    );
    return client.storage.from('clinical-case-images').getPublicUrl(path);
  }

  Future<void> save(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await client.from('clinical_cases').insert(data);
    } else {
      await client.from('clinical_cases').update({
        ...data, 'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await client.from('clinical_cases').delete().eq('id', id);
  }
}
