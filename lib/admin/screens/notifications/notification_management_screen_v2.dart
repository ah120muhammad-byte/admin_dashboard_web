import 'package:flutter/material.dart';

import '../../../core/services/admin_notification_service.dart';

class NotificationManagementScreenV2 extends StatefulWidget {
  const NotificationManagementScreenV2({super.key});

  @override
  State<NotificationManagementScreenV2> createState() =>
      _NotificationManagementScreenV2State();
}

class _NotificationManagementScreenV2State
    extends State<NotificationManagementScreenV2> {
  final AdminNotificationService _service =
      AdminNotificationService.instance;
  final TextEditingController _searchController = TextEditingController();

  late Future<_PageData> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (!mounted || value == _search) return;
      setState(() {
        _search = value;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_PageData> _load() async {
    final results = await Future.wait<dynamic>([
      _service.getNotifications(),
      _service.getLectures(),
    ]);
    return _PageData(
      notifications: results[0] as List<AdminNotification>,
      lectures: results[1] as List<NotificationLecture>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _send() async {
    final data = await _future;
    if (!mounted) return;

    final draft = await showDialog<_Draft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NotificationDialog(lectures: data.lectures),
    );

    if (!mounted || draft == null) return;

    try {
      final List<String> recipients;

      if (draft.audience == 'all') {
        final students = await _service.getStudents();
        recipients = students.map((student) => student.id).toSet().toList();
      } else {
        final targets = await _service.getTargetStudents(
          targetType: draft.audience == 'not_opened'
              ? 'lecture_not_opened'
              : draft.audience,
          lectureId: draft.lectureId,
          inactiveDays: draft.inactiveDays,
        );
        recipients = targets.map((student) => student.userId).toSet().toList();
      }

      if (recipients.isEmpty) {
        _message('No students matched the selected audience.', error: true);
        return;
      }

      await _service.sendToStudents(
        userIds: recipients,
        title: draft.title,
        body: draft.body,
        type: draft.type,
        lectureId: draft.lectureId,
      );

      await _service.createNotification(
        title: draft.title,
        body: draft.body,
        type: draft.type,
        lectureId: draft.lectureId,
      );

      if (!mounted) return;
      _message('Notification sent to ${recipients.length} student(s).');
      await _refresh();
    } catch (e) {
      if (mounted) {
        _message('Unable to send notification: $e', error: true);
      }
    }
  }

  Future<void> _delete(AdminNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text('Delete "${notification.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
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

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'new_lecture':
        return 'New Lecture';
      case 'new_exam':
        return 'New Exam';
      case 'app_update':
        return 'App Update';
      default:
        return 'General';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'new_lecture':
        return Icons.menu_book_rounded;
      case 'new_exam':
        return Icons.quiz_rounded;
      case 'app_update':
        return Icons.system_update_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _lectureName(List<NotificationLecture> lectures, String? id) {
    if (id == null || id.isEmpty) return 'All students';
    for (final lecture in lectures) {
      if (lecture.id == id) return lecture.title;
    }
    return 'Linked lecture';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            );
          }

          final data = snapshot.data!;
          final visible = _search.isEmpty
              ? data.notifications
              : data.notifications.where((notification) {
                  return notification.title.toLowerCase().contains(_search) ||
                      notification.body.toLowerCase().contains(_search) ||
                      _typeLabel(notification.type).toLowerCase().contains(_search);
                }).toList();

          final counts = <String, int>{};
          for (final notification in data.notifications) {
            counts[notification.type] = (counts[notification.type] ?? 0) + 1;
          }

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
                                'Notifications',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Send general announcements, lecture alerts, exam alerts, and app updates.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('New Notification'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Metric('Total', '${data.notifications.length}', Icons.notifications_outlined),
                        _Metric('New Lecture', '${counts['new_lecture'] ?? 0}', Icons.menu_book_outlined),
                        _Metric('New Exam', '${counts['new_exam'] ?? 0}', Icons.quiz_outlined),
                        _Metric('App Update', '${counts['app_update'] ?? 0}', Icons.system_update_outlined),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search notifications...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No notifications found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notification = visible[index];
                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _typeIcon(notification.type),
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification.title,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Chip(
                                              label: Text(_typeLabel(notification.type)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(notification.body),
                                        const SizedBox(height: 10),
                                        Text(
                                          _lectureName(data.lectures, notification.lectureId),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(notification),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
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
      ),
    );
  }
}

class _PageData {
  final List<AdminNotification> notifications;
  final List<NotificationLecture> lectures;

  const _PageData({required this.notifications, required this.lectures});
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Draft {
  final String title;
  final String body;
  final String type;
  final String audience;
  final String? lectureId;
  final int inactiveDays;
  final List<String> selectedUserIds;

  const _Draft({
    required this.title,
    required this.body,
    required this.type,
    required this.audience,
    required this.lectureId,
    required this.inactiveDays,
    required this.selectedUserIds,
  });
}

class _NotificationDialog extends StatefulWidget {
  final List<NotificationLecture> lectures;

  const _NotificationDialog({required this.lectures});

  @override
  State<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<_NotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _studentSearch = TextEditingController();

  String _type = 'general';
  String _audience = 'all';
  String? _lectureId;
  int _inactiveDays = 3;
  bool _loadingStudents = false;
  List<NotificationStudent> _students = [];
  final Set<String> _selected = <String>{};

  bool get _audienceNeedsLecture =>
      _audience == 'not_opened' || _audience == 'behind';

  bool get _typeNeedsLecture => _type == 'new_lecture';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _studentSearch.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_loadingStudents) return;
    setState(() {
      _loadingStudents = true;
    });
    try {
      final students = await AdminNotificationService.instance.getStudents(
        search: _studentSearch.text,
      );
      if (!mounted) return;
      setState(() {
        _students = students;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load students: $e')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if ((_typeNeedsLecture || _audienceNeedsLecture) && _lectureId == null) return;
    if (_audience == 'specific' && _selected.isEmpty) return;

    Navigator.of(context).pop(
      _Draft(
        title: _title.text.trim(),
        body: _body.text.trim(),
        type: _type,
        audience: _audience,
        lectureId: _typeNeedsLecture || _audienceNeedsLecture ? _lectureId : null,
        inactiveDays: _inactiveDays,
        selectedUserIds: _selected.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsLecture = _typeNeedsLecture || _audienceNeedsLecture;

    return AlertDialog(
      title: const Text('Send Notification'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Title is required'
                      : null,
                ),
                TextFormField(
                  controller: _body,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    prefixIcon: Icon(Icons.message_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Message is required'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Notification Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'new_lecture', child: Text('New Lecture')),
                    DropdownMenuItem(value: 'new_exam', child: Text('New Exam')),
                    DropdownMenuItem(value: 'app_update', child: Text('App Update')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _type = value ?? 'general';
                      if (_type != 'new_lecture' && !_audienceNeedsLecture) {
                        _lectureId = null;
                      }
                    });
                  },
                ),
                if (needsLecture) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _lectureId,
                    decoration: const InputDecoration(
                      labelText: 'Lecture',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: widget.lectures
                        .map(
                          (lecture) => DropdownMenuItem<String>(
                            value: lecture.id,
                            child: Text(
                              lecture.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _lectureId = value;
                      });
                    },
                    validator: (value) => needsLecture && (value == null || value.isEmpty)
                        ? 'Select a lecture'
                        : null,
                  ),
                ],
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Audience',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(
                    labelText: 'Target audience',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All students')),
                    DropdownMenuItem(value: 'specific', child: Text('Specific students')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive students')),
                    DropdownMenuItem(value: 'not_opened', child: Text('Did not open a lecture')),
                    DropdownMenuItem(value: 'behind', child: Text('Behind / incomplete')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _audience = value ?? 'all';
                      _selected.clear();
                      if (!_audienceNeedsLecture && _type != 'new_lecture') {
                        _lectureId = null;
                      }
                    });
                  },
                ),
                if (_audience == 'inactive') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _inactiveDays,
                    decoration: const InputDecoration(
                      labelText: 'Inactive for',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1+ day')),
                      DropdownMenuItem(value: 3, child: Text('3+ days')),
                      DropdownMenuItem(value: 7, child: Text('7+ days')),
                      DropdownMenuItem(value: 14, child: Text('14+ days')),
                      DropdownMenuItem(value: 30, child: Text('30+ days')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _inactiveDays = value;
                      });
                    },
                  ),
                ],
                if (_audience == 'specific') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _studentSearch,
                          decoration: const InputDecoration(
                            hintText: 'Search students...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Load students',
                        onPressed: _loadingStudents ? null : _loadStudents,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: _loadingStudents
                          ? const Center(child: CircularProgressIndicator())
                          : _students.isEmpty
                              ? const Center(child: Text('Load students to select recipients.'))
                              : ListView.builder(
                                  itemCount: _students.length,
                                  itemBuilder: (context, index) {
                                    final student = _students[index];
                                    return CheckboxListTile(
                                      value: _selected.contains(student.id),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selected.add(student.id);
                                          } else {
                                            _selected.remove(student.id);
                                          }
                                        });
                                      },
                                      title: Text(student.fullName),
                                      subtitle: Text(student.email),
                                    );
                                  },
                                ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_selected.length} student(s) selected'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
      ],
    );
  }
}
