import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? lectureId;
  final DateTime? createdAt;

  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.lectureId,
    this.createdAt,
  });

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      lectureId: map['lecture_id']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class NotificationLecture {
  final String id;
  final String title;

  const NotificationLecture({required this.id, required this.title});

  factory NotificationLecture.fromMap(Map<String, dynamic> map) {
    return NotificationLecture(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
    );
  }
}

class NotificationStudent {
  final String id;
  final String fullName;
  final String email;

  const NotificationStudent({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory NotificationStudent.fromMap(Map<String, dynamic> map) {
    final fullNameValue = map['full_name']?.toString().trim() ?? '';
    final emailValue = map['email']?.toString().trim() ?? '';

    return NotificationStudent(
      id: map['id']?.toString() ?? '',
      fullName: fullNameValue.isEmpty ? 'Unnamed student' : fullNameValue,
      email: emailValue,
    );
  }

  String get displayName => email.isEmpty ? fullName : '$fullName • $email';
}

class NotificationTargetStudent {
  final String userId;
  final String fullName;
  final String email;

  const NotificationTargetStudent({
    required this.userId,
    required this.fullName,
    required this.email,
  });

  factory NotificationTargetStudent.fromMap(Map<String, dynamic> map) {
    final fullNameValue = map['full_name']?.toString().trim() ?? '';
    final emailValue = map['email']?.toString().trim() ?? '';

    return NotificationTargetStudent(
      userId: map['user_id']?.toString() ?? '',
      fullName: fullNameValue.isEmpty ? 'Unnamed student' : fullNameValue,
      email: emailValue,
    );
  }

  String get displayName => email.isEmpty ? fullName : '$fullName • $email';
}

class AdminNotificationService {
  AdminNotificationService._();

  static final AdminNotificationService instance = AdminNotificationService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const Set<String> supportedTypes = {
    'general',
    'new_lecture',
    'new_exam',
    'app_update',
  };

  Future<List<NotificationLecture>> getLectures() async {
    final response = await _supabase
        .from('lectures')
        .select('id,title')
        .eq('is_active', true)
        .order('display_order');

    return (response as List)
        .map((item) => NotificationLecture.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AdminNotification>> getNotifications() async {
    final response = await _supabase
        .from('notifications')
        .select('id,title,body,type,lecture_id,created_at')
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => AdminNotification.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<NotificationStudent>> getStudents({String search = ''}) async {
    var query = _supabase
        .from('profiles')
        .select('id,full_name,email,role')
        .eq('role', 'student');

    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) {
      query = query.or(
        'full_name.ilike.%$normalizedSearch%,email.ilike.%$normalizedSearch%',
      );
    }

    final response = await query.order('full_name').limit(1000);

    return (response as List)
        .map((item) => NotificationStudent.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<NotificationTargetStudent>> getTargetStudents({
    required String targetType,
    String? lectureId,
    int inactiveDays = 3,
  }) async {
    const allowedTargets = {'lecture_not_opened', 'inactive', 'behind'};

    if (!allowedTargets.contains(targetType)) {
      throw ArgumentError('Invalid notification target.');
    }

    if ((targetType == 'lecture_not_opened' || targetType == 'behind') &&
        (lectureId == null || lectureId.trim().isEmpty)) {
      throw ArgumentError('Lecture is required for this target.');
    }

    if (targetType == 'inactive' && inactiveDays < 1) {
      throw ArgumentError('Inactive days must be at least 1.');
    }

    final response = await _supabase.rpc(
      'get_notification_target_students',
      params: {
        'target_type': targetType,
        'target_lecture_id': lectureId,
        'inactive_days': inactiveDays,
      },
    );

    if (response is! List) {
      throw Exception('Unexpected smart targeting response.');
    }

    return response
        .map((item) => NotificationTargetStudent.fromMap(Map<String, dynamic>.from(item)))
        .where((student) => student.userId.isNotEmpty)
        .toList();
  }

  String _normalizeType(String type) {
    final normalized = type == 'lecture' ? 'new_lecture' : type.trim();
    if (!supportedTypes.contains(normalized)) {
      throw ArgumentError('Invalid notification type.');
    }
    return normalized;
  }

  Future<AdminNotification> createNotification({
    required String title,
    required String body,
    String type = 'general',
    String? lectureId,
  }) async {
    final normalizedType = _normalizeType(type);

    final cleanTitle = title.trim();
    final cleanBody = body.trim();

    if (cleanTitle.isEmpty) throw ArgumentError('Notification title is required.');
    if (cleanBody.isEmpty) throw ArgumentError('Notification body is required.');
    if (cleanTitle.length > 120) {
      throw ArgumentError('Notification title must be 120 characters or less.');
    }
    if (cleanBody.length > 500) {
      throw ArgumentError('Notification body must be 500 characters or less.');
    }

    if (normalizedType == 'new_lecture' &&
        (lectureId == null || lectureId.trim().isEmpty)) {
      throw ArgumentError('Lecture is required for a new lecture notification.');
    }

    final response = await _supabase
        .from('notifications')
        .insert({
          'title': cleanTitle,
          'body': cleanBody,
          'type': normalizedType,
          'lecture_id': normalizedType == 'new_lecture' ? lectureId : null,
        })
        .select('id,title,body,type,lecture_id,created_at')
        .single();

    return AdminNotification.fromMap(Map<String, dynamic>.from(response));
  }

  Future<AdminNotification> createNewExamNotification({
    required String title,
    required String body,
  }) {
    return createNotification(
      title: title,
      body: body,
      type: 'new_exam',
    );
  }

  Future<AdminNotification> createAppUpdateNotification({
    required String title,
    required String body,
  }) {
    return createNotification(
      title: title,
      body: body,
      type: 'app_update',
    );
  }

  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      throw ArgumentError('Notification ID is required.');
    }

    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  Future<Map<String, dynamic>> sendToStudents({
    required List<String> userIds,
    required String title,
    required String body,
    String type = 'general',
    String? lectureId,
  }) async {
    final cleanUserIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanUserIds.isEmpty) {
      throw ArgumentError('At least one recipient is required.');
    }
    if (cleanUserIds.length > 500) {
      throw ArgumentError('Maximum 500 recipients per request.');
    }

    final cleanTitle = title.trim();
    final cleanBody = body.trim();

    if (cleanTitle.isEmpty) throw ArgumentError('Notification title is required.');
    if (cleanBody.isEmpty) throw ArgumentError('Notification body is required.');
    if (cleanTitle.length > 120) {
      throw ArgumentError('Notification title must be 120 characters or less.');
    }
    if (cleanBody.length > 500) {
      throw ArgumentError('Notification body must be 500 characters or less.');
    }

    final normalizedType = _normalizeType(type);

    if (normalizedType == 'new_lecture' &&
        (lectureId == null || lectureId.trim().isEmpty)) {
      throw ArgumentError('Lecture is required for a new lecture notification.');
    }

    final response = await _supabase.functions.invoke(
      'send-targeted-notification',
      body: {
        'userIds': cleanUserIds,
        'title': cleanTitle,
        'body': cleanBody,
        'type': normalizedType,
        if (lectureId != null && lectureId.trim().isNotEmpty)
          'lectureId': lectureId.trim(),
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected notification response.');
  }

  Future<List<String>> getUserIdsWithRegisteredDevices(List<String> userIds) async {
    final cleanIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanIds.isEmpty) return [];

    final response = await _supabase
        .from('device_tokens')
        .select('user_id')
        .inFilter('user_id', cleanIds);

    return (response as List)
        .map((item) => item['user_id'].toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }
}
