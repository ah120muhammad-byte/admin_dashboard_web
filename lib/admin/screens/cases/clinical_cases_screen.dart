import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicalCasesScreen extends StatefulWidget {
  const ClinicalCasesScreen({super.key});
  @override State<ClinicalCasesScreen> createState() => _ClinicalCasesScreenState();
}

class _ClinicalCasesScreenState extends State<ClinicalCasesScreen> {
  final _service = ClinicalCaseAdminService();
  late Future<List<Map<String,dynamic>>> _future;

  @override void initState(){super.initState(); _future=_service.list();}
  void _reload(){setState(()=>_future=_service.list());}

  Future<void> _edit([Map<String,dynamic>? item]) async {
    final title=TextEditingController(text:item?['title']?.toString()??'');
    final short=TextEditingController(text:item?['short_description']?.toString()??'');
    final presentation=TextEditingController(text:item?['clinical_presentation']?.toString()??'');
    final history=TextEditingController(text:item?['history']?.toString()??'');
    final exam=TextEditingController(text:item?['examination']?.toString()??'');
    final investigations=TextEditingController(text:item?['investigations']?.toString()??'');
    final diagnosis=TextEditingController(text:item?['diagnosis']?.toString()??'');
    final management=TextEditingController(text:item?['management']?.toString()??'');
    final medications=TextEditingController(text:item?['medications']?.toString()??'');
    DateTime date=DateTime.tryParse(item?['case_date']?.toString()??'')??DateTime.now();
    bool published = (item?['is_published'] as bool?) ?? false;
    List<String> images=List<String>.from(item?['image_urls']??const[]);
    bool saving=false;

    InputDecoration dec(String label)=>InputDecoration(labelText:label,border:const OutlineInputBorder());
    await showDialog<void>(
      context:context,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
        title:Text(item==null?'Add Case of the Day':'Edit Case of the Day'),
        content:SizedBox(width:720,child:SingleChildScrollView(child:Column(children:[
          TextField(controller:title,decoration:dec('Title')),
          const SizedBox(height:10), TextField(controller:short,decoration:dec('Short description'),maxLines:3),
          const SizedBox(height:10),
          ListTile(contentPadding:EdgeInsets.zero,title:Text('Case date: ${date.toLocal().toString().split(' ').first}'),trailing:IconButton(icon:const Icon(Icons.calendar_month),onPressed:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:date);if(d!=null)setLocal(()=>date=d);}),),
          ...[
            ['Clinical presentation',presentation],['History',history],['Examination',exam],['Investigations',investigations],['Diagnosis',diagnosis],['Management / Interventions',management],['Medications',medications]
          ].map((e)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:e[1] as TextEditingController,decoration:dec(e[0] as String),maxLines:5))),
          Align(alignment:Alignment.centerLeft,child:Wrap(spacing:8,runSpacing:8,children:[
            ...images.map((url)=>Chip(label:SizedBox(width:260,child:Text(url,maxLines:1,overflow:TextOverflow.ellipsis)),onDeleted:()=>setLocal(()=>images.remove(url))),
            ActionChip(label:const Text('Add image'),avatar:const Icon(Icons.upload_file),onPressed:()async{
              final p=await FilePicker.platform.pickFiles(type:FileType.image,withData:true,allowMultiple:true);
              if(p==null)return;
              for(final f in p.files){final bytes=f.bytes;if(bytes!=null){final url=await _service.uploadImage(bytes,f.name);setLocal(()=>images.add(url));}}
            })
          ])),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Published'),value:published,onChanged:(v)=>setLocal(()=>published=v)),
        ]))),
        actions:[
          TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:(saving || title.text.trim().isEmpty)?null:()async{
            setLocal(()=>saving=true);
            try{
              final data={'title':title.text.trim(),'case_date':DateTime(date.year,date.month,date.day).toIso8601String().split('T').first,'short_description':short.text.trim(),'clinical_presentation':presentation.text.trim(),'history':history.text.trim(),'examination':exam.text.trim(),'investigations':investigations.text.trim(),'diagnosis':diagnosis.text.trim(),'management':management.text.trim(),'medications':medications.text.trim(),'image_urls':images,'is_published':published};
              await _service.save(data,id:item?['id']?.toString());
              if(ctx.mounted)Navigator.pop(ctx);
              _reload();
            }catch(e){if(ctx.mounted){setLocal(()=>saving=false);ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Save failed: $e')));}}
          },child:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Text('Save'))
        ],
      )),
    );
    for(final c in [title,short,presentation,history,exam,investigations,diagnosis,management,medications])c.dispose();
  }

  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.all(20),
    child:FutureBuilder<List<Map<String,dynamic>>>(
      future:_future,
      builder:(context,s)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Text('Case of the Day',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const Spacer(),FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('Add Case'))]),
        const SizedBox(height:16),
        Expanded(child:s.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):ListView(children:(s.data??[]).map((x)=>Card(child:ListTile(title:Text(x['title']?.toString()??''),subtitle:Text('${x['case_date']}  •  ${x['is_published']==true?'Published':'Draft'}'),leading:const Icon(Icons.local_hospital_outlined),onTap:()=>_edit(x),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{await _service.delete(x['id'].toString());_reload();}))).toList()))
      ]),
  );
}

class ClinicalCaseAdminService {
  final SupabaseClient client=Supabase.instance.client;
  Future<List<Map<String,dynamic>>> list()async=>List<Map<String,dynamic>>.from(await client.from('clinical_cases').select().order('case_date',ascending:false));
  Future<String> uploadImage(Uint8List bytes,String name)async{final path='cases/${DateTime.now().microsecondsSinceEpoch}_$name';await client.storage.from('clinical-case-images').uploadBinary(path,bytes,fileOptions:const FileOptions(upsert:false));return client.storage.from('clinical-case-images').getPublicUrl(path);}
  Future<void> save(Map<String,dynamic> data,{String? id})async{if(id==null){await client.from('clinical_cases').insert(data);}else{await client.from('clinical_cases').update({...data,'updated_at':DateTime.now().toIso8601String()}).eq('id',id);}}
  Future<void> delete(String id)=>client.from('clinical_cases').delete().eq('id',id);
}