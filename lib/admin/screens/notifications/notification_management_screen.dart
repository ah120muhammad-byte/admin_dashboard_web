import 'package:flutter/material.dart';

import '../../../core/services/admin_notification_service.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends State<NotificationManagementScreen> {
  final AdminNotificationService _service =
      AdminNotificationService.instance;

  late Future<_NotificationPageData> _future;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _query) return;
    setState(() {
      _query = value;
    });
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
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _createAndSend() async {
    final data = await _future;
    if (!mounted) return;

    final result = await showDialog<_NotificationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NotificationDialog(lectures: data.lectures),
    );

    if (!mounted || result == null) return;

    try {
      List<String> recipientIds;

      if (result.targetMode == 'specific') {
        recipientIds = result.selectedUserIds;
      } else {
        final targets = await _service.getTargetStudents(
          targetType: result.targetMode == 'not_opened'
              ? 'lecture_not_opened'
              : result.targetMode,
          lectureId: result.lectureId,
          inactiveDays: result.inactiveDays,
        );
        recipientIds = targets.map((e) => e.userId).toSet().toList();
      }

      if (recipientIds.isEmpty) {
        if (mounted) {
          _message('No recipients matched the selected targeting rule.',
              error: true);
        }
        return;
      }

      await _service.sendToStudents(
        userIds: recipientIds,
        title: result.title,
        body: result.body,
        type: result.type,
        lectureId: result.lectureId,
      );

      await _service.createNotification(
        title: result.title,
        body: result.body,
        type: result.type,
        lectureId: result.lectureId,
      );

      if (!mounted) return;
      _message('Notification sent to ${recipientIds.length} student(s).');
      await _refresh();
    } catch (e) {
      if (mounted) _message('Unable to send notification: $e', error: true);
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

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'new_lecture':
        return 'New Lecture';
      default:
        return 'General';
    }
  }

  String _lectureName(List<NotificationLecture> lectures, String? id) {
    if (id == null) return 'All students';
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
      child: FutureBuilder<_NotificationPageData>(
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
          final notifications = _query.isEmpty
              ? data.notifications
              : data.notifications.where((item) {
                  return item.title.toLowerCase().contains(_query) ||
                      item.body.toLowerCase().contains(_query);
                }).toList();

          final lectureNotifications = data.notifications
              .where((item) => item.type == 'new_lecture')
              .length;

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
                                'Send targeted updates and manage the notification history.',
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
                          onPressed: _createAndSend,
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
                        _Metric(
                          label: 'Total Sent',
                          value: '${data.notifications.length}',
                          icon: Icons.notifications_outlined,
                        ),
                        _Metric(
                          label: 'New Lecture',
                          value: '$lectureNotifications',
                          icon: Icons.menu_book_outlined,
                        ),
                        _Metric(
                          label: 'Lectures',
                          value: '${data.lectures.length}',
                          icon: Icons.school_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search notification title or message...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('No notifications found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final lecture = _lectureName(
                            data.lectures,
                            notification.lectureId,
                          );

                          return Card(
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
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
                                      notification.type == 'new_lecture'
                                          ? Icons.menu_book_rounded
                                          : Icons.notifications_rounded,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification.title,
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                _typeLabel(notification.type),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          notification.body,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 14,
                                          runSpacing: 6,
                                          children: [
                                            Text(
                                              lecture,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color:
                                                    scheme.onSurfaceVariant,
                                              ),
                                            ),
                                            if (notification.createdAt != null)
                                              Text(
                                                _formatDate(
                                                    notification.createdAt!),
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: scheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                          ],
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _NotificationPageData {
  final List<AdminNotification> notifications;
  final List<NotificationLecture> lectures;

  const _NotificationPageData({
    required this.notifications,
    required this.lectures,
  });
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

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
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDraft {
  final String title;
  final String body;
  final String type;
  final String targetMode;
  final String? lectureId;
  final int inactiveDays;
  final List<String> selectedUserIds;

  const _NotificationDraft({
    required this.title,
    required this.body,
    required this.type,
    required this.targetMode,
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

  String _type = 'general';
  String _targetMode = 'inactive';
  String? _lectureId;
  int _inactiveDays = 3;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _needsLecture =>
      _targetMode == 'not_opened' || _targetMode == 'behind';

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_needsLecture && _lectureId == null) return;

    Navigator.of(context).pop(
      _NotificationDraft(
        title: _title.text.trim(),
        body: _body.text.trim(),
        type: _type,
        targetMode: _targetMode,
        lectureId: _lectureId,
        inactiveDays: _inactiveDays,
        selectedUserIds: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Notification'),
      content: SizedBox(
        width: 620,
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _body,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    prefixIcon: Icon(Icons.message_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Message is required'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Notification Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'general',
                      child: Text('General'),
                    ),
                    DropdownMenuItem(
                      value: 'new_lecture',
                      child: Text('New Lecture'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _targetMode,
                  decoration: const InputDecoration(
                    labelText: 'Audience',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive students'),
                    ),
                    DropdownMenuItem(
                      value: 'not_opened',
                      child: Text('Students who did not open a lecture'),
                    ),
                    DropdownMenuItem(
                      value: 'behind',
                      child: Text('Students behind on a lecture'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _targetMode = value;
                      if (!_needsLecture) _lectureId = null;
                    });
                  },
                ),
                if (_needsLecture) ...[
                  const SizedBox(height: 12),
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
                    validator: (value) => _needsLecture && value == null
                        ? 'Select a lecture'
                        : null,
                  ),
                ],
                if (_targetMode == 'inactive') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _inactiveDays,
                    decoration: const InputDecoration(
                      labelText: 'Inactive For',
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
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'The audience is resolved from live Supabase data immediately before sending.',
                  ),
                ),
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
          icon: const Icon(Icons.send_rounded),
          label: const Text('Send'),
        ),
      ],
    );
  }
}
