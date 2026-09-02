import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================================
/// USER ANALYTICS
/// ============================================================================

class AdminUserAnalytics {
  final String id;
  final String name;
  final String email;
  final String? imageUrl;
  final String role;
  final DateTime? createdAt;

  // --------------------------------------------------------------------------
  // LECTURE ANALYTICS
  // --------------------------------------------------------------------------

  final int lecturesOpened;
  final int videosCompleted;
  final int audiosCompleted;
  final int lecturesInProgress;
  final DateTime? lastLectureActivity;

  // --------------------------------------------------------------------------
  // EXAM ANALYTICS
  // --------------------------------------------------------------------------

  final int examAttempts;
  final int completedExams;
  final double averageScore;
  final double bestScore;
  final int correctAnswers;
  final int totalQuestions;
  final double successRate;
  final DateTime? lastExamActivity;

  // --------------------------------------------------------------------------
  // GENERAL ACTIVITY
  // --------------------------------------------------------------------------

  final DateTime? lastActivity;

  const AdminUserAnalytics({
    required this.id,
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.role,
    required this.createdAt,
    required this.lecturesOpened,
    required this.videosCompleted,
    required this.audiosCompleted,
    required this.lecturesInProgress,
    required this.lastLectureActivity,
    required this.examAttempts,
    required this.completedExams,
    required this.averageScore,
    required this.bestScore,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.successRate,
    required this.lastExamActivity,
    required this.lastActivity,
  });

  bool get isActive {
    if (lastActivity == null) {
      return false;
    }

    final difference = DateTime.now().difference(lastActivity!);

    return difference.inDays <= 30;
  }
}

/// ============================================================================
/// GENERAL USERS STATISTICS
/// ============================================================================

class AdminUsersStats {
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;

  final int usersWithLectureActivity;
  final int usersWithExamActivity;

  final int totalLecturesOpened;
  final int totalVideosCompleted;
  final int totalAudiosCompleted;

  final int totalExamAttempts;
  final int completedExams;

  final int totalCorrectAnswers;
  final int totalQuestions;

  final double averageScore;
  final double successRate;

  const AdminUsersStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.usersWithLectureActivity,
    required this.usersWithExamActivity,
    required this.totalLecturesOpened,
    required this.totalVideosCompleted,
    required this.totalAudiosCompleted,
    required this.totalExamAttempts,
    required this.completedExams,
    required this.totalCorrectAnswers,
    required this.totalQuestions,
    required this.averageScore,
    required this.successRate,
  });
}

/// ============================================================================
/// USERS RESULT
/// ============================================================================

class AdminUsersResult {
  final List<AdminUserAnalytics> users;
  final AdminUsersStats stats;

  const AdminUsersResult({required this.users, required this.stats});
}

/// ============================================================================
/// ADMIN USERS SERVICE
/// ============================================================================

class AdminUsersService {
  final SupabaseClient _supabase;

  AdminUsersService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ==========================================================================
  // LOAD EVERYTHING
  // ==========================================================================

  Future<AdminUsersResult> getUsers() async {
    // ------------------------------------------------------------------------
    // PROFILES
    // ------------------------------------------------------------------------

    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, full_name, email, profile_image_url, role, created_at')
        .order('created_at', ascending: false);

    // ------------------------------------------------------------------------
    // LECTURE PROGRESS
    // ------------------------------------------------------------------------

    final progressResponse = await _supabase.from('lecture_progress').select('''
          id,
          user_id,
          lecture_id,
          audio_position,
          video_position,
          audio_completed,
          video_completed,
          last_opened_at,
          updated_at
          ''');

    // ------------------------------------------------------------------------
    // EXAM ATTEMPTS
    // ------------------------------------------------------------------------

    final attemptsResponse = await _supabase.from('exam_attempts').select('''
          id,
          user_id,
          exam_id,
          score,
          total_questions,
          correct_answers,
          started_at,
          completed_at,
          status,
          created_at
          ''');

    // ------------------------------------------------------------------------
    // INDEX LECTURE PROGRESS BY USER
    // ------------------------------------------------------------------------

    final progressByUser = <String, List<Map<String, dynamic>>>{};

    for (final item in progressResponse) {
      final userId = item['user_id']?.toString();

      if (userId == null || userId.isEmpty) {
        continue;
      }

      progressByUser.putIfAbsent(userId, () => []).add(
            Map<String, dynamic>.from(item),
          );
    }

    // ------------------------------------------------------------------------
    // INDEX EXAM ATTEMPTS BY USER
    // ------------------------------------------------------------------------

    final attemptsByUser = <String, List<Map<String, dynamic>>>{};

    for (final item in attemptsResponse) {
      final userId = item['user_id']?.toString();

      if (userId == null || userId.isEmpty) {
        continue;
      }

      attemptsByUser.putIfAbsent(userId, () => []).add(
            Map<String, dynamic>.from(item),
          );
    }

    // ------------------------------------------------------------------------
    // BUILD USER ANALYTICS
    // ------------------------------------------------------------------------

    final users = <AdminUserAnalytics>[];

    for (final profile in profilesResponse) {
      final userId = profile['id']?.toString() ?? '';

      if (userId.isEmpty) {
        continue;
      }

      final progress = progressByUser[userId] ?? [];
      final attempts = attemptsByUser[userId] ?? [];

      users.add(
        _buildUserAnalytics(
          profile: Map<String, dynamic>.from(profile),
          progress: progress,
          attempts: attempts,
        ),
      );
    }

    // ------------------------------------------------------------------------
    // GENERAL STATISTICS
    // ------------------------------------------------------------------------

    final stats = _buildGeneralStats(users);

    return AdminUsersResult(users: users, stats: stats);
  }

  // ==========================================================================
  // BUILD USER
  // ==========================================================================

  AdminUserAnalytics _buildUserAnalytics({
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> progress,
    required List<Map<String, dynamic>> attempts,
  }) {
    final userId = profile['id']?.toString() ?? '';

    final name = _stringValue(
      profile['full_name'],
      fallback: 'Unknown User',
    );

    final email = _stringValue(
      profile['email'],
      fallback: '',
    );

    final imageUrl = _nullableString(profile['profile_image_url']);
    final role = _stringValue(profile['role'], fallback: 'user');
    final createdAt = _parseDate(profile['created_at']);

    // ------------------------------------------------------------------------
    // LECTURES
    // ------------------------------------------------------------------------

    final lecturesOpened = progress.length;

    var videosCompleted = 0;
    var audiosCompleted = 0;

    DateTime? lastLectureActivity;

    for (final item in progress) {
      if (_boolValue(item['video_completed'])) {
        videosCompleted++;
      }

      if (_boolValue(item['audio_completed'])) {
        audiosCompleted++;
      }

      final activityDate =
          _parseDate(item['last_opened_at']) ??
          _parseDate(item['updated_at']);

      lastLectureActivity = _latestDate(
        lastLectureActivity,
        activityDate,
      );
    }

    final lecturesInProgress = _calculateLecturesInProgress(progress);

    // ------------------------------------------------------------------------
    // EXAMS
    // ------------------------------------------------------------------------

    final examAttempts = attempts.length;

    // Analytics that represent scores should only use completed attempts.
    // An in-progress attempt normally has score=0 and must not drag the
    // student's average down while the exam is still being taken.
    final completedAttempts = attempts.where((attempt) {
      final status = attempt['status']?.toString().toLowerCase();
      final completedAt = _parseDate(attempt['completed_at']);

      return status == 'completed' || completedAt != null;
    }).toList();

    final completedExams = completedAttempts.length;

    var totalCorrectAnswers = 0;
    var totalQuestions = 0;

    double scoreSum = 0;
    double bestScore = 0;

    DateTime? lastExamActivity;

    for (final attempt in attempts) {
      final completedAt = _parseDate(attempt['completed_at']);

      final activityDate =
          completedAt ??
          _parseDate(attempt['created_at']) ??
          _parseDate(attempt['started_at']);

      lastExamActivity = _latestDate(
        lastExamActivity,
        activityDate,
      );
    }

    for (final attempt in completedAttempts) {
      final correct = _intValue(attempt['correct_answers']);
      final questions = _intValue(attempt['total_questions']);

      totalCorrectAnswers += correct;
      totalQuestions += questions;

      final score = _doubleValue(attempt['score']);
      scoreSum += score;

      if (score > bestScore) {
        bestScore = score;
      }
    }

    final double averageScore = completedAttempts.isNotEmpty
        ? scoreSum / completedAttempts.length
        : 0.0;

    final double successRate = totalQuestions > 0
        ? (totalCorrectAnswers / totalQuestions) * 100
        : 0.0;

    final lastActivity = _latestDate(
      lastLectureActivity,
      lastExamActivity,
    );

    return AdminUserAnalytics(
      id: userId,
      name: name,
      email: email,
      imageUrl: imageUrl,
      role: role,
      createdAt: createdAt,
      lecturesOpened: lecturesOpened,
      videosCompleted: videosCompleted,
      audiosCompleted: audiosCompleted,
      lecturesInProgress: lecturesInProgress,
      lastLectureActivity: lastLectureActivity,
      examAttempts: examAttempts,
      completedExams: completedExams,
      averageScore: averageScore,
      bestScore: bestScore,
      correctAnswers: totalCorrectAnswers,
      totalQuestions: totalQuestions,
      successRate: successRate,
      lastExamActivity: lastExamActivity,
      lastActivity: lastActivity,
    );
  }

  // ==========================================================================
  // GENERAL STATS
  // ==========================================================================

  AdminUsersStats _buildGeneralStats(List<AdminUserAnalytics> users) {
    var activeUsers = 0;
    var usersWithLectureActivity = 0;
    var usersWithExamActivity = 0;

    var totalLecturesOpened = 0;
    var totalVideosCompleted = 0;
    var totalAudiosCompleted = 0;

    var totalExamAttempts = 0;
    var completedExams = 0;

    var totalCorrectAnswers = 0;
    var totalQuestions = 0;

    double scoreSum = 0;
    var usersWithScores = 0;

    for (final user in users) {
      if (user.isActive) {
        activeUsers++;
      }

      if (user.lecturesOpened > 0) {
        usersWithLectureActivity++;
      }

      if (user.examAttempts > 0) {
        usersWithExamActivity++;
      }

      totalLecturesOpened += user.lecturesOpened;
      totalVideosCompleted += user.videosCompleted;
      totalAudiosCompleted += user.audiosCompleted;
      totalExamAttempts += user.examAttempts;
      completedExams += user.completedExams;
      totalCorrectAnswers += user.correctAnswers;
      totalQuestions += user.totalQuestions;

      // User averageScore already excludes in-progress attempts.
      if (user.completedExams > 0) {
        scoreSum += user.averageScore;
        usersWithScores++;
      }
    }

    final double averageScore = usersWithScores > 0
        ? scoreSum / usersWithScores
        : 0.0;

    final double successRate = totalQuestions > 0
        ? (totalCorrectAnswers / totalQuestions) * 100
        : 0.0;

    return AdminUsersStats(
      totalUsers: users.length,
      activeUsers: activeUsers,
      inactiveUsers: users.length - activeUsers,
      usersWithLectureActivity: usersWithLectureActivity,
      usersWithExamActivity: usersWithExamActivity,
      totalLecturesOpened: totalLecturesOpened,
      totalVideosCompleted: totalVideosCompleted,
      totalAudiosCompleted: totalAudiosCompleted,
      totalExamAttempts: totalExamAttempts,
      completedExams: completedExams,
      totalCorrectAnswers: totalCorrectAnswers,
      totalQuestions: totalQuestions,
      averageScore: averageScore,
      successRate: successRate,
    );
  }

  // ==========================================================================
  // LECTURES IN PROGRESS
  // ==========================================================================

  int _calculateLecturesInProgress(
    List<Map<String, dynamic>> progress,
  ) {
    var result = 0;

    for (final item in progress) {
      final videoCompleted = _boolValue(item['video_completed']);
      final audioCompleted = _boolValue(item['audio_completed']);

      if (!videoCompleted && !audioCompleted) {
        result++;
      }
    }

    return result;
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      return value != 0;
    }

    return false;
  }

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  DateTime? _latestDate(DateTime? first, DateTime? second) {
    if (first == null) {
      return second;
    }

    if (second == null) {
      return first;
    }

    return second.isAfter(first) ? second : first;
  }
}
