import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await _supabase
        .from('support_messages')
        .select('id,user_id,subject,message,student_name,student_email,status,created_at,read_at,replied_at')
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _future = future);
    await future;
  }

  Future<void> _markRead(String id) async {
    await _supabase.from('support_messages').update({
      'status': 'read',
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    await _refresh();
  }

  Future<void> _archive(String id) async {
    await _supabase.from('support_messages').update({'status': 'archived'}).eq('id', id);
    await _refresh();
  }

  Future<void> _openMessage(Map<String, dynamic> item) async {
    if (item['status'] == 'unread') {
      try {
        await _markRead(item['id'].toString());
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item['subject']?.toString() ?? 'Support Message'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['student_name']?.toString() ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(item['student_email']?.toString() ?? ''),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 14),
                SelectableText(item['message']?.toString() ?? ''),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.reply_outlined),
            label: const Text('Reply by Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')));
        }

        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final filtered = _status == 'all' ? all : all.where((e) => e['status'] == _status).toList();
        final unread = all.where((e) => e['status'] == 'unread').length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Support Inbox', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Student support emails and messages', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(label: Text('All (${all.length})'), selected: _status == 'all', onSelected: (_) => setState(() => _status = 'all')),
                      FilterChip(label: Text('Unread ($unread)'), selected: _status == 'unread', onSelected: (_) => setState(() => _status = 'unread')),
                      FilterChip(label: Text('Read'), selected: _status == 'read', onSelected: (_) => setState(() => _status = 'read')),
                      FilterChip(label: const Text('Archived'), selected: _status == 'archived', onSelected: (_) => setState(() => _status = 'archived')),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No support messages found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isUnread = item['status'] == 'unread';
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            onTap: () => _openMessage(item),
                            leading: CircleAvatar(
                              backgroundColor: isUnread ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.email_outlined, color: isUnread ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                            ),
                            title: Text(item['subject']?.toString() ?? 'No subject', style: TextStyle(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500)),
                            subtitle: Text('${item['student_name'] ?? 'Student'} • ${item['student_email'] ?? ''}\n${item['message'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'read') await _markRead(item['id'].toString());
                                if (value == 'archive') await _archive(item['id'].toString());
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'read', child: Text('Mark as read')),
                                PopupMenuItem(value: 'archive', child: Text('Archive')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
