import 'package:supabase_flutter/supabase_flutter.dart';

class AdminExamAttempt {
  final String id;
  final String userId;
  final String studentName;
  final String studentEmail;
  final String examId;
  final String examTitle;
  final String lectureTitle;
  final int? score;
  final int? totalQuestions;
  final int? correctAnswers;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int remainingSeconds;
  final bool isPaused;
  final int currentQuestionIndex;

  const AdminExamAttempt({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.studentEmail,
    required this.examId,
    required this.examTitle,
    required this.lectureTitle,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.remainingSeconds,
    required this.isPaused,
    required this.currentQuestionIndex,
  });

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
}

class AdminExamAttemptAnswer {
  final String questionId;
  final String questionText;
  final String? selectedOptionText;
  final bool? isCorrect;

  const AdminExamAttemptAnswer({
    required this.questionId,
    required this.questionText,
    required this.selectedOptionText,
    required this.isCorrect,
  });
}

class ExamAttemptsService {
  final SupabaseClient _supabase;

  ExamAttemptsService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminExamAttempt>> getAttempts({
    String? examId,
    String? status,
  }) async {
    var query = _supabase.from('exam_attempts').select('''
          id,
          user_id,
          exam_id,
          score,
          total_questions,
          correct_answers,
          started_at,
          completed_at,
          status,
          remaining_seconds,
          is_paused,
          current_question_index,
          profiles!exam_attempts_user_id_fkey(
            full_name,
            email
          ),
          exams!exam_attempts_exam_id_fkey(
            title,
            lectures!exams_lecture_id_fkey(
              title
            )
          )
        ''');

    if (examId != null && examId.trim().isNotEmpty) {
      query = query.eq('exam_id', examId.trim());
    }

    if (status != null && status.trim().isNotEmpty) {
      query = query.eq('status', status.trim());
    }

    final response = await query.order('started_at', ascending: false);

    return (response as List).map((item) {
      final map = Map<String, dynamic>.from(item);
      final profile = map['profiles'] is Map
          ? Map<String, dynamic>.from(map['profiles'])
          : <String, dynamic>{};
      final exam = map['exams'] is Map
          ? Map<String, dynamic>.from(map['exams'])
          : <String, dynamic>{};
      final lecture = exam['lectures'] is Map
          ? Map<String, dynamic>.from(exam['lectures'])
          : <String, dynamic>{};

      return AdminExamAttempt(
        id: map['id'].toString(),
        userId: map['user_id'].toString(),
        studentName: profile['full_name']?.toString() ?? 'Unknown student',
        studentEmail: profile['email']?.toString() ?? '',
        examId: map['exam_id'].toString(),
        examTitle: exam['title']?.toString() ?? 'Exam',
        lectureTitle: lecture['title']?.toString() ?? 'Lecture',
        score: (map['score'] as num?)?.toInt(),
        totalQuestions: (map['total_questions'] as num?)?.toInt(),
        correctAnswers: (map['correct_answers'] as num?)?.toInt(),
        status: map['status']?.toString() ?? 'abandoned',
        startedAt: DateTime.parse(map['started_at'].toString()),
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.tryParse(map['completed_at'].toString()),
        remainingSeconds: (map['remaining_seconds'] as num?)?.toInt() ?? 0,
        isPaused: map['is_paused'] as bool? ?? false,
        currentQuestionIndex:
            (map['current_question_index'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<AdminExamAttemptAnswer>> getAnswers(String attemptId) async {
    final response = await _supabase.from('exam_answers').select('''
          question_id,
          selected_option_id,
          is_correct,
          questions!exam_answers_question_id_fkey(
            question_text
          ),
          question_options!exam_answers_selected_option_id_fkey(
            option_text
          )
        ''').eq('attempt_id', attemptId).order('answered_at');

    return (response as List).map((item) {
      final map = Map<String, dynamic>.from(item);
      final question = map['questions'] is Map
          ? Map<String, dynamic>.from(map['questions'])
          : <String, dynamic>{};
      final option = map['question_options'] is Map
          ? Map<String, dynamic>.from(map['question_options'])
          : <String, dynamic>{};

      return AdminExamAttemptAnswer(
        questionId: map['question_id'].toString(),
        questionText: question['question_text']?.toString() ?? 'Question',
        selectedOptionText: option['option_text']?.toString(),
        isCorrect: map['is_correct'] as bool?,
      );
    }).toList();
  }
}
