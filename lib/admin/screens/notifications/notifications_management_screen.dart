import 'package:flutter/material.dart';

import '../../../core/services/admin_notification_service.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() => _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState extends State<NotificationsManagementScreen> {
  final AdminNotificationService _service = AdminNotificationService.instance;

  late Future<_NotificationPageData> _future;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value == _search || !mounted) return;
      setState(() => _search = value);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_NotificationPageData> _load() async {
    final results = await Future.wait<dynamic>([
      _service.getNotifications(),
      _service.getLectures(),
    ]);
    return _NotificationPageData(
      notifications: results[0] as List<AdminNotification>,
      lectures: results[1] as List<NotificationLecture>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _future = future);
    await future;
  }

  Future<void> _showSendDialog(List<NotificationLecture> lectures) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final studentSearch = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String type = 'general';
    String audience = 'specific';
    String? lectureId;
    int inactiveDays = 3;
    bool loading = false;
    bool sending = false;
    List<NotificationStudent> students = [];
    List<NotificationTargetStudent> targets = [];
    final selectedIds = <String>{};

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !sending,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadStudents() async {
              if (loading) return;
              setDialogState(() => loading = true);
              try {
                final result = await _service.getStudents(search: studentSearch.text);
                if (!dialogContext.mounted) return;
                setDialogState(() => students = result);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => loading = false);
                }
              }
            }

            Future<void> loadTargets() async {
              if ((audience == 'not_opened' || audience == 'behind') &&
                  (lectureId == null || lectureId!.isEmpty)) {
                return;
              }

              setDialogState(() {
                loading = true;
                targets = [];
              });

              try {
                final targetType = audience == 'not_opened'
                    ? 'lecture_not_opened'
                    : audience == 'behind'
                        ? 'behind'
                        : 'inactive';
                final result = await _service.getTargetStudents(
                  targetType: targetType,
                  lectureId: lectureId,
                  inactiveDays: inactiveDays,
                );
                if (!dialogContext.mounted) return;
                setDialogState(() => targets = result);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => loading = false);
                }
              }
            }

            List<String> recipientIds() {
              switch (audience) {
                case 'all':
                  return students.map((e) => e.id).toSet().toList();
                case 'specific':
                  return selectedIds.toList();
                case 'not_opened':
                case 'behind':
                case 'inactive':
                  return targets.map((e) => e.userId).toSet().toList();
                default:
                  return [];
              }
            }

            Future<void> send() async {
              if (!formKey.currentState!.validate()) return;

              final ids = recipientIds();
              if (ids.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Select at least one recipient.')),
                );
                return;
              }

              setDialogState(() => sending = true);
              try {
                await _service.createNotification(
                  title: title.text.trim(),
                  body: body.text.trim(),
                  type: type,
                  lectureId: type == 'new_lecture' ? lectureId : null,
                );

                await _service.sendToStudents(
                  userIds: ids,
                  title: title.text.trim(),
                  body: body.text.trim(),
                  type: type,
                  lectureId: type == 'new_lecture' ? lectureId : null,
                );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  _message('Notification sent successfully.');
                  await _refresh();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  setDialogState(() => sending = false);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Unable to send notification: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Send Notification'),
              content: SizedBox(
                width: 760,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: title,
                          enabled: !sending,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter notification title'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: body,
                          enabled: !sending,
                          maxLength: 500,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.message_rounded),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter notification message'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Notification Type',
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'general', child: Text('General')),
                            DropdownMenuItem(value: 'new_lecture', child: Text('New Lecture')),
                            DropdownMenuItem(value: 'new_exam', child: Text('New Exam')),
                            DropdownMenuItem(value: 'app_update', child: Text('App Update')),
                          ],
                          onChanged: sending
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    type = value ?? 'general';
                                    if (type != 'new_lecture') lectureId = null;
                                  });
                                },
                        ),
                        if (type == 'new_lecture') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: lectureId,
                            decoration: const InputDecoration(
                              labelText: 'Lecture',
                              prefixIcon: Icon(Icons.menu_book_rounded),
                            ),
                            items: lectures
                                .map((lecture) => DropdownMenuItem(
                                      value: lecture.id,
                                      child: Text(lecture.title, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: sending ? null : (value) => setDialogState(() => lectureId = value),
                            validator: (value) => type == 'new_lecture' && (value == null || value.isEmpty)
                                ? 'Select a lecture'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Target Audience',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: audience,
                          decoration: const InputDecoration(
                            labelText: 'Recipients',
                            prefixIcon: Icon(Icons.groups_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'specific', child: Text('Specific students')),
                            DropdownMenuItem(value: 'all', child: Text('All students')),
                            DropdownMenuItem(value: 'not_opened', child: Text('Did not open lecture')),
                            DropdownMenuItem(value: 'behind', child: Text('Behind / incomplete')),
                            DropdownMenuItem(value: 'inactive', child: Text('Inactive students')),
                          ],
                          onChanged: sending
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    audience = value ?? 'specific';
                                    students = [];
                                    targets = [];
                                    selectedIds.clear();
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        if (audience == 'specific' || audience == 'all') ...[
                          TextField(
                            controller: studentSearch,
                            enabled: !sending,
                            decoration: InputDecoration(
                              hintText: audience == 'all' ? 'Search students to load...' : 'Search students...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Load students',
                                onPressed: loading ? null : loadStudents,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ),
                            onSubmitted: (_) => loadStudents(),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 220,
                            child: loading
                                ? const Center(child: CircularProgressIndicator())
                                : students.isEmpty
                                    ? const Center(child: Text('Load students to choose recipients.'))
                                    : ListView.builder(
                                        itemCount: students.length,
                                        itemBuilder: (_, index) {
                                          final student = students[index];
                                          final selected = selectedIds.contains(student.id);
                                          return CheckboxListTile(
                                            value: selected,
                                            onChanged: sending
                                                ? null
                                                : (value) => setDialogState(() {
                                                      if (value == true) {
                                                        selectedIds.add(student.id);
                                                      } else {
                                                        selectedIds.remove(student.id);
                                                      }
                                                    }),
                                            title: Text(student.fullName),
                                            subtitle: Text(student.email),
                                          );
                                        },
                                      ),
                          ),
                        ] else ...[
                          if (audience == 'not_opened' || audience == 'behind') ...[
                            DropdownButtonFormField<String>(
                              initialValue: lectureId,
                              decoration: const InputDecoration(
                                labelText: 'Lecture',
                                prefixIcon: Icon(Icons.menu_book_outlined),
                              ),
                              items: lectures
                                  .map((lecture) => DropdownMenuItem(
                                        value: lecture.id,
                                        child: Text(lecture.title, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: sending
                                  ? null
                                  : (value) => setDialogState(() {
                                        lectureId = value;
                                        targets = [];
                                      }),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (audience == 'inactive') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Inactive for $inactiveDays days'),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: inactiveDays,
                                    decoration: const InputDecoration(labelText: 'Days'),
                                    items: [3, 7, 14, 30]
                                        .map((days) => DropdownMenuItem(value: days, child: Text('$days')))
                                        .toList(),
                                    onChanged: sending
                                        ? null
                                        : (value) {
                                            setDialogState(() {
                                              inactiveDays = value ?? 3;
                                              targets = [];
                                            });
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          FilledButton.icon(
                            onPressed: sending || loading
                                ? null
                                : loadTargets,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(loading ? 'Calculating...' : 'Calculate Recipients'),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Recipients: ${targets.length}'),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selected recipients: ${recipientIds().length}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(sending ? 'Sending...' : 'Send'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      title.dispose();
      body.dispose();
      studentSearch.dispose();
    }
  }

  Future<void> _delete(AdminNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text('Delete "${notification.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _service.deleteNotification(notification.id);
      if (!mounted) return;
      _message('Notification deleted.');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Unable to delete notification: $e', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'new_lecture': return 'New Lecture';
      case 'new_exam': return 'New Exam';
      case 'app_update': return 'App Update';
      default: return 'General';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'new_lecture': return Icons.menu_book_rounded;
      case 'new_exam': return Icons.quiz_rounded;
      case 'app_update': return Icons.system_update_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<_NotificationPageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')));
        }

        final data = snapshot.data!;
        final query = _search.trim().toLowerCase();
        final notifications = query.isEmpty
            ? data.notifications
            : data.notifications.where((notification) {
                return notification.title.toLowerCase().contains(query) ||
                    notification.body.toLowerCase().contains(query) ||
                    _typeLabel(notification.type).toLowerCase().contains(query);
              }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Send targeted announcements, new exam alerts and app update notices.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: () => _showSendDialog(data.lectures), icon: const Icon(Icons.add_rounded), label: const Text('New Notification')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Search notifications...', prefixIcon: Icon(Icons.search_rounded)))),
                  const SizedBox(width: 12),
                  _Metric('Total', '${data.notifications.length}', Icons.notifications_outlined),
                  const SizedBox(width: 10),
                  _Metric('Exam', '${data.notifications.where((e) => e.type == 'new_exam').length}', Icons.quiz_outlined),
                  const SizedBox(width: 10),
                  _Metric('Updates', '${data.notifications.where((e) => e.type == 'app_update').length}', Icons.system_update_outlined),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text('No notifications found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            leading: CircleAvatar(child: Icon(_typeIcon(notification.type))),
                            title: Row(
                              children: [
                                Expanded(child: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                Chip(label: Text(_typeLabel(notification.type))),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            trailing: IconButton(tooltip: 'Delete', onPressed: () => _delete(notification), icon: const Icon(Icons.delete_outline_rounded)),
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

class _NotificationPageData {
  final List<AdminNotification> notifications;
  final List<NotificationLecture> lectures;
  const _NotificationPageData({required this.notifications, required this.lectures});
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 7),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
