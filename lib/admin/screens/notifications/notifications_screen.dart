import 'package:flutter/material.dart';

import '../../../core/services/admin_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final AdminNotificationService _service =
      AdminNotificationService.instance;

  late Future<List<AdminNotification>>
      _notificationsFuture;

  List<NotificationLecture> _lectures = [];

  @override
  void initState() {
    super.initState();

    _notificationsFuture =
        _loadData();
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<List<AdminNotification>>
      _loadData() async {
    final lectures =
        await _service.getLectures();

    if (mounted) {
      setState(() {
        _lectures = lectures;
      });
    }

    return _service.getNotifications();
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture =
          _loadData();
    });

    await _notificationsFuture;
  }

  // ===========================================================================
  // SEND NOTIFICATION
  // ===========================================================================

  Future<void> _showSendDialog() async {
    final titleController =
        TextEditingController();

    final bodyController =
        TextEditingController();

    final studentSearchController =
        TextEditingController();

    final formKey =
        GlobalKey<FormState>();

    String notificationType =
        'general';

    String recipientMode =
        'specific';

    String? lectureId;

    int inactiveDays = 3;

    bool loadingRecipients =
        false;

    bool sending = false;

    List<NotificationStudent>
        loadedStudents = [];

    List<NotificationTargetStudent>
        targetStudents = [];

    final Set<String>
        selectedUserIds = {};

    try {
      final result =
          await showDialog<bool>(
        context: context,
        barrierDismissible:
            !sending,
        builder:
            (dialogContext) {
          return StatefulBuilder(
            builder:
                (
              context,
              setDialogState,
            ) {
              // =============================================================
              // LOAD SPECIFIC STUDENTS
              // =============================================================

              Future<void>
                  loadSpecificStudents() async {
                if (loadingRecipients) {
                  return;
                }

                setDialogState(() {
                  loadingRecipients =
                      true;
                });

                try {
                  final students =
                      await _service
                          .getStudents(
                    search:
                        studentSearchController
                            .text,
                  );

                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  setDialogState(() {
                    loadedStudents =
                        students;
                  });
                } catch (e) {
                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  ScaffoldMessenger
                      .of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to load students: $e',
                      ),
                    ),
                  );
                } finally {
                  if (dialogContext
                      .mounted) {
                    setDialogState(() {
                      loadingRecipients =
                          false;
                    });
                  }
                }
              }

              // =============================================================
              // LOAD SMART TARGET
              // =============================================================

              Future<void>
                  loadSmartTarget() async {
                if ((recipientMode ==
                            'not_opened' ||
                        recipientMode ==
                            'behind') &&
                    (lectureId == null ||
                        lectureId!
                            .isEmpty)) {
                  return;
                }

                setDialogState(() {
                  loadingRecipients =
                      true;
                  targetStudents =
                      [];
                });

                try {
                  final result =
                      await _service
                          .getTargetStudents(
                    targetType:
                        recipientMode ==
                                'not_opened'
                            ? 'lecture_not_opened'
                            : 'behind',
                    lectureId:
                        lectureId,
                    inactiveDays:
                        inactiveDays,
                  );

                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  setDialogState(() {
                    targetStudents =
                        result;
                  });
                } catch (e) {
                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  ScaffoldMessenger
                      .of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to calculate target students: $e',
                      ),
                    ),
                  );
                } finally {
                  if (dialogContext
                      .mounted) {
                    setDialogState(() {
                      loadingRecipients =
                          false;
                    });
                  }
                }
              }

              // =============================================================
              // LOAD INACTIVE
              // =============================================================

              Future<void>
                  loadInactiveTarget() async {
                setDialogState(() {
                  loadingRecipients =
                      true;
                  targetStudents =
                      [];
                });

                try {
                  final result =
                      await _service
                          .getTargetStudents(
                    targetType:
                        'inactive',
                    inactiveDays:
                        inactiveDays,
                  );

                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  setDialogState(() {
                    targetStudents =
                        result;
                  });
                } catch (e) {
                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  ScaffoldMessenger
                      .of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to calculate inactive students: $e',
                      ),
                    ),
                  );
                } finally {
                  if (dialogContext
                      .mounted) {
                    setDialogState(() {
                      loadingRecipients =
                          false;
                    });
                  }
                }
              }

              // =============================================================
              // GET RECIPIENT IDS
              // =============================================================

              List<String>
                  getRecipientIds() {
                switch (recipientMode) {
                  case 'all':
                    return loadedStudents
                        .map(
                          (
                            student,
                          ) =>
                              student.id,
                        )
                        .toSet()
                        .toList();

                  case 'specific':
                    return selectedUserIds
                        .toList();

                  case 'not_opened':
                  case 'behind':
                  case 'inactive':
                    return targetStudents
                        .map(
                          (
                            student,
                          ) =>
                              student.userId,
                        )
                        .toSet()
                        .toList();

                  default:
                    return [];
                }
              }

              // =============================================================
              // RECIPIENT COUNT
              // =============================================================

              final recipientCount =
                  getRecipientIds().length;

              return AlertDialog(
                title: const Text(
                  'Send Notification',
                ),
                content: SizedBox(
                  width: 760,
                  child: Form(
                    key: formKey,
                    child:
                        SingleChildScrollView(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          // ===================================================
                          // TITLE
                          // ===================================================

                          TextFormField(
                            controller:
                                titleController,
                            enabled: !sending,
                            maxLength: 120,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Title',
                              prefixIcon:
                                  Icon(
                                Icons
                                    .title_rounded,
                              ),
                            ),
                            validator:
                                (value) {
                              if (value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Enter notification title';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ===================================================
                          // BODY
                          // ===================================================

                          TextFormField(
                            controller:
                                bodyController,
                            enabled: !sending,
                            maxLength: 500,
                            maxLines: 4,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Message',
                              alignLabelWithHint:
                                  true,
                              prefixIcon:
                                  Icon(
                                Icons
                                    .message_rounded,
                              ),
                            ),
                            validator:
                                (value) {
                              if (value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Enter notification message';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ===================================================
                          // TYPE
                          // ===================================================

                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                notificationType,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Notification Type',
                              prefixIcon:
                                  Icon(
                                Icons
                                    .category_rounded,
                              ),
                            ),
                            items:
                                const [
                              DropdownMenuItem(
                                value:
                                    'general',
                                child:
                                    Text(
                                  'General',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'new_lecture',
                                child:
                                    Text(
                                  'New Lecture',
                                ),
                              ),
                            ],
                            onChanged:
                                sending
                                    ? null
                                    : (
                                        value,
                                      ) {
                                        setDialogState(
                                          () {
                                            notificationType =
                                                value ??
                                                    'general';

                                            if (notificationType ==
                                                'general') {
                                              lectureId =
                                                  null;
                                            }
                                          },
                                        );
                                      },
                          ),

                          if (notificationType ==
                              'new_lecture') ...[
                            const SizedBox(
                              height: 12,
                            ),
                            DropdownButtonFormField<
                                String>(
                              initialValue:
                                  lectureId,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Lecture',
                                prefixIcon:
                                    Icon(
                                  Icons
                                      .menu_book_rounded,
                                ),
                              ),
                              items:
                                  _lectures
                                      .map(
                                    (
                                      lecture,
                                    ) {
                                      return DropdownMenuItem<
                                          String>(
                                        value:
                                            lecture.id,
                                        child:
                                            Text(
                                          lecture.title,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ).toList(),
                              onChanged:
                                  sending
                                      ? null
                                      : (
                                          value,
                                        ) {
                                          setDialogState(
                                            () {
                                              lectureId =
                                                  value;
                                            },
                                          );
                                        },
                              validator:
                                  (value) {
                                if (notificationType ==
                                        'new_lecture' &&
                                    (value ==
                                            null ||
                                        value
                                            .isEmpty)) {
                                  return 'Select a lecture';
                                }

                                return null;
                              },
                            ),
                          ],

                          const SizedBox(
                            height: 20,
                          ),

                          // ===================================================
                          // RECIPIENT MODE
                          // ===================================================

                          Align(
                            alignment:
                                Alignment
                                    .centerLeft,
                            child:
                                Text(
                              'Recipients',
                              style:
                                  Theme.of(
                                context,
                              )
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                recipientMode,
                            decoration:
                                const InputDecoration(
                              prefixIcon:
                                  Icon(
                                Icons
                                    .groups_rounded,
                              ),
                              labelText:
                                  'Target audience',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value:
                                    'specific',
                                child:
                                    Text(
                                  'Specific students',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'all',
                                child:
                                    Text(
                                  'All students',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'not_opened',
                                child:
                                    Text(
                                  'Did not open lecture',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'behind',
                                child:
                                    Text(
                                  'Behind / incomplete',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'inactive',
                                child:
                                    Text(
                                  'Inactive students',
                                ),
                              ),
                            ],
                            onChanged:
                                sending
                                    ? null
                                    : (
                                        value,
                                      ) {
                                        setDialogState(
                                          () {
                                            recipientMode =
                                                value ??
                                                    'specific';

                                            loadedStudents =
                                                [];
                                            targetStudents =
                                                [];
                                            selectedUserIds
                                                .clear();
                                          },
                                        );
                                      },
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ===================================================
                          // SPECIFIC
                          // ===================================================

                          if (recipientMode ==
                              'specific') ...[
                            TextField(
                              controller:
                                  studentSearchController,
                              enabled:
                                  !sending,
                              decoration:
                                  InputDecoration(
                                hintText:
                                    'Search students...',
                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .search_rounded,
                                ),
                                suffixIcon:
                                    IconButton(
                                  onPressed:
                                      loadingRecipients
                                          ? null
                                          : loadSpecificStudents,
                                  icon:
                                      const Icon(
                                    Icons
                                        .refresh_rounded,
                                  ),
                                ),
                              ),
                              onChanged:
                                  (value) {
                                if (value
                                        .trim()
                                        .length >=
                                    2) {
                                  loadSpecificStudents();
                                }
                              },
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            if (loadedStudents
                                .isNotEmpty)
                              Align(
                                alignment:
                                    Alignment
                                        .centerLeft,
                                child:
                                    TextButton.icon(
                                  onPressed:
                                      sending
                                          ? null
                                          : () {
                                              setDialogState(
                                                () {
                                                  final ids =
                                                      loadedStudents
                                                          .map(
                                                            (
                                                              student,
                                                            ) =>
                                                                student.id,
                                                          )
                                                          .toSet();

                                                  final allSelected =
                                                      ids.difference(
                                                    selectedUserIds,
                                                  ).isEmpty;

                                                  if (allSelected) {
                                                    selectedUserIds
                                                        .removeAll(
                                                      ids,
                                                    );
                                                  } else {
                                                    selectedUserIds
                                                        .addAll(
                                                      ids,
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                  icon:
                                      const Icon(
                                    Icons
                                        .checklist_rounded,
                                  ),
                                  label:
                                      const Text(
                                    'Select / deselect loaded students',
                                  ),
                                ),
                              ),

                            Container(
                              height:
                                  240,
                              decoration:
                                  BoxDecoration(
                                border:
                                    Border.all(
                                  color:
                                      Theme.of(
                                    context,
                                  ).dividerColor,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                              child:
                                  loadingRecipients
                                      ? const Center(
                                          child:
                                              CircularProgressIndicator(),
                                        )
                                      : loadedStudents
                                              .isEmpty
                                          ? const Center(
                                              child:
                                                  Text(
                                                'Search for students above.',
                                              ),
                                            )
                                          : ListView
                                              .separated(
                                              itemCount:
                                                  loadedStudents.length,
                                              separatorBuilder:
                                                  (_, _) =>
                                                      const Divider(
                                                height:
                                                    1,
                                              ),
                                              itemBuilder:
                                                  (
                                                context,
                                                index,
                                              ) {
                                                final student =
                                                    loadedStudents[index];

                                                final selected =
                                                    selectedUserIds.contains(
                                                  student.id,
                                                );

                                                return CheckboxListTile(
                                                  value:
                                                      selected,
                                                  title:
                                                      Text(
                                                    student.fullName,
                                                    maxLines:
                                                        1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  subtitle:
                                                      student.email.isEmpty
                                                          ? null
                                                          : Text(
                                                              student.email,
                                                              maxLines:
                                                                  1,
                                                              overflow:
                                                                  TextOverflow.ellipsis,
                                                            ),
                                                  onChanged:
                                                      sending
                                                          ? null
                                                          : (
                                                              value,
                                                            ) {
                                                              setDialogState(
                                                                () {
                                                                  if (value ==
                                                                      true) {
                                                                    selectedUserIds
                                                                        .add(
                                                                      student.id,
                                                                    );
                                                                  } else {
                                                                    selectedUserIds
                                                                        .remove(
                                                                      student.id,
                                                                    );
                                                                  }
                                                                },
                                                              );
                                                            },
                                                );
                                              },
                                            ),
                            ),
                          ],

                          // ===================================================
                          // ALL STUDENTS
                          // ===================================================

                          if (recipientMode ==
                              'all') ...[
                            const Align(
                              alignment:
                                  Alignment
                                      .centerLeft,
                              child: Text(
                                'All students will be resolved when you send.',
                              ),
                            ),
                          ],

                          // ===================================================
                          // SMART TARGETS
                          // ===================================================

                          if (recipientMode ==
                                  'not_opened' ||
                              recipientMode ==
                                  'behind') ...[
                            DropdownButtonFormField<
                                String>(
                              initialValue:
                                  lectureId,
                              decoration:
                                  InputDecoration(
                                labelText:
                                    recipientMode ==
                                            'not_opened'
                                        ? 'Lecture not opened'
                                        : 'Lecture to check',
                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .menu_book_rounded,
                                ),
                              ),
                              items:
                                  _lectures
                                      .map(
                                    (
                                      lecture,
                                    ) {
                                      return DropdownMenuItem<
                                          String>(
                                        value:
                                            lecture.id,
                                        child:
                                            Text(
                                          lecture.title,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ).toList(),
                              onChanged:
                                  sending
                                      ? null
                                      : (
                                          value,
                                        ) {
                                          setDialogState(
                                            () {
                                              lectureId =
                                                  value;
                                              targetStudents =
                                                  [];
                                            },
                                          );

                                          if (value !=
                                              null) {
                                            loadSmartTarget();
                                          }
                                        },
                              validator:
                                  (value) {
                                if (value ==
                                        null ||
                                    value
                                        .isEmpty) {
                                  return 'Select a lecture';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _TargetPreview(
                              students:
                                  targetStudents,
                              loading:
                                  loadingRecipients,
                              emptyMessage:
                                  'No matching students found.',
                            ),
                          ],

                          // ===================================================
                          // INACTIVE
                          // ===================================================

                          if (recipientMode ==
                              'inactive') ...[
                            Row(
                              children: [
                                const Text(
                                  'Inactive for',
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                SizedBox(
                                  width: 90,
                                  child:
                                      DropdownButtonFormField<
                                          int>(
                                    initialValue:
                                        inactiveDays,
                                    decoration:
                                        const InputDecoration(
                                      isDense:
                                          true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value:
                                            1,
                                        child:
                                            Text(
                                          '1 day',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            3,
                                        child:
                                            Text(
                                          '3 days',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            7,
                                        child:
                                            Text(
                                          '7 days',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            14,
                                        child:
                                            Text(
                                          '14 days',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            30,
                                        child:
                                            Text(
                                          '30 days',
                                        ),
                                      ),
                                    ],
                                    onChanged:
                                        sending
                                            ? null
                                            : (
                                                value,
                                              ) {
                                                setDialogState(
                                                  () {
                                                    inactiveDays =
                                                        value ??
                                                            3;
                                                  },
                                                );

                                                loadInactiveTarget();
                                              },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _TargetPreview(
                              students:
                                  targetStudents,
                              loading:
                                  loadingRecipients,
                              emptyMessage:
                                  'No inactive students found.',
                            ),
                          ],

                          const SizedBox(
                            height: 14,
                          ),

                          // ===================================================
                          // SELECTED COUNT
                          // ===================================================

                          Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets
                                    .all(
                              14,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Theme.of(
                                context,
                              )
                                      .colorScheme
                                      .primary
                                      .withValues(
                                    alpha:
                                        0.08,
                                  ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons
                                      .people_alt_rounded,
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      Text(
                                    '$recipientCount student(s) selected',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        sending
                            ? null
                            : () {
                                Navigator.pop(
                                  dialogContext,
                                  false,
                                );
                              },
                    child:
                        const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        sending
                            ? null
                            : () async {
                                if (!formKey
                                    .currentState!
                                    .validate()) {
                                  return;
                                }

                                List<String>
                                    recipientIds;

                                if (recipientMode ==
                                    'all') {
                                  setDialogState(
                                    () {
                                      loadingRecipients =
                                          true;
                                    },
                                  );

                                  try {
                                    final
                                        allStudents =
                                        await _service
                                            .getStudents();

                                    recipientIds =
                                        allStudents
                                            .map(
                                              (
                                                student,
                                              ) =>
                                                  student.id,
                                            )
                                            .toSet()
                                            .toList();
                                  } finally {
                                    if (dialogContext
                                        .mounted) {
                                      setDialogState(
                                        () {
                                          loadingRecipients =
                                              false;
                                        },
                                      );
                                    }
                                  }
                                } else if (recipientMode ==
                                    'specific') {
                                  recipientIds =
                                      selectedUserIds
                                          .toList();
                                } else {
                                  recipientIds =
                                      targetStudents
                                          .map(
                                            (
                                              student,
                                            ) =>
                                                student.userId,
                                          )
                                          .toSet()
                                          .toList();
                                }

                                if (recipientIds
                                    .isEmpty) {
                                  ScaffoldMessenger
                                      .of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text(
                                        'No students match the selected target.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (recipientIds
                                        .length >
                                    500) {
                                  ScaffoldMessenger
                                      .of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text(
                                        'Maximum 500 students per notification.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(
                                  () {
                                    sending =
                                        true;
                                  },
                                );

                                try {
                                  final result =
                                      await _service
                                          .sendToStudents(
                                    userIds:
                                        recipientIds,
                                    title:
                                        titleController
                                            .text
                                            .trim(),
                                    body:
                                        bodyController
                                            .text
                                            .trim(),
                                    type:
                                        notificationType,
                                    lectureId:
                                        lectureId,
                                  );

                                  if (!dialogContext
                                      .mounted) {
                                    return;
                                  }

                                  Navigator.pop(
                                    dialogContext,
                                    true,
                                  );

                                  final recipients =
                                      result[
                                          'recipients'];

                                  final pushSent =
                                      result[
                                          'pushSent'];

                                  final pushFailed =
                                      result[
                                          'pushFailed'];

                                  if (mounted) {
                                    _showMessage(
                                      'Sent to ${recipients ?? recipientIds.length} student(s). '
                                      'Push sent: ${pushSent ?? 0}. '
                                      'Failed: ${pushFailed ?? 0}.',
                                    );
                                  }
                                } catch (e) {
                                  if (!dialogContext
                                      .mounted) {
                                    return;
                                  }

                                  setDialogState(
                                    () {
                                      sending =
                                          false;
                                    },
                                  );

                                  ScaffoldMessenger
                                      .of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(
                                        'Error: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                    icon:
                        sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .send_rounded,
                              ),
                    label:
                        Text(
                      sending
                          ? 'Sending...'
                          : 'Send',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        await _refresh();
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
      studentSearchController.dispose();
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _deleteNotification(
    AdminNotification notification,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        context,
      ) {
        return AlertDialog(
          title: const Text(
            'Delete Notification',
          ),
          content: const Text(
            'Are you sure you want to delete this notification?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(
                  context,
                )
                        .colorScheme
                        .error,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteNotification(
        notification.id,
      );

      await _refresh();

      _showMessage(
        'Notification deleted',
      );
    } catch (e) {
      _showMessage(
        'Error: $e',
      );
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Notifications',
        ),
        actions: [
          IconButton(
            tooltip:
                'Refresh',
            onPressed:
                _refresh,
            icon:
                const Icon(
              Icons
                  .refresh_rounded,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _showSendDialog,
        icon:
            const Icon(
          Icons.send_rounded,
        ),
        label:
            const Text(
          'Send Notification',
        ),
      ),
      body:
          FutureBuilder<
              List<AdminNotification>>(
        future:
            _notificationsFuture,
        builder:
            (
          context,
          snapshot,
        ) {
          if (snapshot
                  .connectionState ==
              ConnectionState
                  .waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error:
                  snapshot.error
                      .toString(),
              onRetry:
                  _refresh,
            );
          }

          final notifications =
              snapshot.data ??
                  [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .notifications_none_rounded,
                    size:
                        64,
                  ),
                  SizedBox(
                    height:
                        16,
                  ),
                  Text(
                    'No notifications found.',
                  ),
                ],
              ),
            );
          }

          return ListView
              .separated(
            padding:
                const EdgeInsets
                    .all(
              20,
            ),
            itemCount:
                notifications.length,
            separatorBuilder:
                (
              _,
              _,
            ) =>
                    const SizedBox(
              height: 10,
            ),
            itemBuilder:
                (
              context,
              index,
            ) {
              final notification =
                  notifications[
                      index];

              return _NotificationTile(
                notification:
                    notification,
                lectureTitle:
                    _lectureTitle(
                  notification
                      .lectureId,
                ),
                onDelete:
                    () =>
                        _deleteNotification(
                  notification,
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // LECTURE TITLE
  // ===========================================================================

  String? _lectureTitle(
    String? lectureId,
  ) {
    if (lectureId == null) {
      return null;
    }

    for (final lecture
        in _lectures) {
      if (lecture.id ==
          lectureId) {
        return lecture.title;
      }
    }

    return null;
  }
}

// ============================================================================
// TARGET PREVIEW
// ============================================================================

class _TargetPreview
    extends StatelessWidget {
  final List<NotificationTargetStudent>
      students;

  final bool loading;
  final String emptyMessage;

  const _TargetPreview({
    required this.students,
    required this.loading,
    required this.emptyMessage,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      height: 220,
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color:
              Theme.of(
            context,
          ).dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : students
                      .isEmpty
                  ? Center(
                      child:
                          Text(
                        emptyMessage,
                      ),
                    )
                  : ListView
                      .separated(
                      itemCount:
                          students.length,
                      separatorBuilder:
                          (
                        _,
                        _,
                      ) =>
                              const Divider(
                        height:
                            1,
                      ),
                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        final student =
                            students[
                                index];

                        return ListTile(
                          dense:
                              true,
                          leading:
                              const Icon(
                            Icons
                                .person_outline_rounded,
                          ),
                          title:
                              Text(
                            student.fullName,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                          subtitle:
                              student.email
                                      .isEmpty
                                  ? null
                                  : Text(
                                      student.email,
                                      maxLines:
                                          1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                        );
                      },
                    ),
    );
  }
}

// ============================================================================
// NOTIFICATION TILE
// ============================================================================

class _NotificationTile
    extends StatelessWidget {
  final AdminNotification
      notification;

  final String? lectureTitle;

  final VoidCallback
      onDelete;

  const _NotificationTile({
    required this.notification,
    required this.lectureTitle,
    required this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isLecture =
        notification.type ==
            'new_lecture';

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets
                .symmetric(
          horizontal:
              18,
          vertical:
              8,
        ),
        leading:
            CircleAvatar(
          child:
              Icon(
            isLecture
                ? Icons
                    .menu_book_rounded
                : Icons
                    .notifications_rounded,
          ),
        ),
        title:
            Text(
          notification.title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
        subtitle:
            Padding(
          padding:
              const EdgeInsets.only(
            top:
                6,
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                notification
                    .body,
              ),
              if (lectureTitle !=
                  null) ...[
                const SizedBox(
                  height:
                      6,
                ),
                Text(
                  'Lecture: $lectureTitle',
                  style:
                      Theme.of(
                    context,
                  )
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                ),
              ],
              if (notification
                      .createdAt !=
                  null) ...[
                const SizedBox(
                  height:
                      4,
                ),
                Text(
                  _formatDate(
                    notification
                        .createdAt!,
                  ),
                  style:
                      Theme.of(
                    context,
                  )
                              .textTheme
                              .bodySmall,
                ),
              ],
            ],
          ),
        ),
        trailing:
            IconButton(
          tooltip:
              'Delete',
          onPressed:
              onDelete,
          icon:
              const Icon(
            Icons
                .delete_outline_rounded,
          ),
        ),
      ),
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    final local =
        date.toLocal();

    final day =
        local.day
            .toString()
            .padLeft(
          2,
          '0',
        );

    final month =
        local.month
            .toString()
            .padLeft(
          2,
          '0',
        );

    final year =
        local.year
            .toString();

    final hour =
        local.hour
            .toString()
            .padLeft(
          2,
          '0',
        );

    final minute =
        local.minute
            .toString()
            .padLeft(
          2,
          '0',
        );

    return '$day/$month/$year  $hour:$minute';
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  final String error;

  final Future<void>
      Function() onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(
          32,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize
                  .min,
          children: [
            Icon(
              Icons
                  .cloud_off_rounded,
              size:
                  56,
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .error,
            ),
            const SizedBox(
              height:
                  16,
            ),
            const Text(
              'Unable to load notifications',
              style:
                  TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight
                        .bold,
              ),
            ),
            const SizedBox(
              height:
                  8,
            ),
            SelectableText(
              error,
              textAlign:
                  TextAlign
                      .center,
            ),
            const SizedBox(
              height:
                  16,
            ),
            FilledButton.icon(
              onPressed:
                  onRetry,
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}