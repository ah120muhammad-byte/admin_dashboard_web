import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// QUESTION OPTION
// ============================================================================

class QuestionOption {
  final String id;
  final String questionId;
  final String optionText;
  final int displayOrder;

  const QuestionOption({
    required this.id,
    required this.questionId,
    required this.optionText,
    required this.displayOrder,
  });

  factory QuestionOption.fromMap(Map<String, dynamic> map) {
    return QuestionOption(
      id: map['id'] as String,
      questionId: map['question_id'] as String,
      optionText: map['option_text'] as String? ?? '',
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

// ============================================================================
// CORRECT ANSWER
// ============================================================================

class QuestionCorrectAnswer {
  final String questionId;
  final String correctOptionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuestionCorrectAnswer({
    required this.questionId,
    required this.correctOptionId,
    this.createdAt,
    this.updatedAt,
  });

  factory QuestionCorrectAnswer.fromMap(Map<String, dynamic> map) {
    return QuestionCorrectAnswer(
      questionId: map['question_id'] as String,
      correctOptionId: map['correct_option_id'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }
}

// ============================================================================
// ADMIN QUESTION
// ============================================================================

class AdminQuestion {
  final String id;
  final String examId;
  final String questionText;
  final String? explanation;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<QuestionOption> options;
  final String? correctOptionId;

  const AdminQuestion({
    required this.id,
    required this.examId,
    required this.questionText,
    this.explanation,
    required this.displayOrder,
    this.createdAt,
    this.updatedAt,
    this.options = const [],
    this.correctOptionId,
  });

  AdminQuestion copyWith({
    String? id,
    String? examId,
    String? questionText,
    String? explanation,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuestionOption>? options,
    String? correctOptionId,
  }) {
    return AdminQuestion(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      questionText: questionText ?? this.questionText,
      explanation: explanation ?? this.explanation,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      options: options ?? this.options,
      correctOptionId: correctOptionId ?? this.correctOptionId,
    );
  }

  factory AdminQuestion.fromMap(
    Map<String, dynamic> map, {
    List<QuestionOption> options = const [],
    String? correctOptionId,
  }) {
    return AdminQuestion(
      id: map['id'] as String,
      examId: map['exam_id'] as String,
      questionText: map['question_text'] as String? ?? '',
      explanation: map['explanation'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      options: options,
      correctOptionId: correctOptionId,
    );
  }
}

// ============================================================================
// QUESTION DATA
// ============================================================================

class QuestionData {
  final String questionText;
  final String? explanation;
  final List<String> options;
  final int correctOptionIndex;

  const QuestionData({
    required this.questionText,
    required this.explanation,
    required this.options,
    required this.correctOptionIndex,
  });
}

// ============================================================================
// EXAM QUESTIONS SERVICE
// ============================================================================

class ExamQuestionsService {
  final SupabaseClient _supabase;

  ExamQuestionsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ==========================================================================
  // GET QUESTIONS
  // ==========================================================================

  Future<List<AdminQuestion>> getQuestions(String examId) async {
    final questionsResponse = await _supabase
        .from('questions')
        .select(
          'id, exam_id, question_text, explanation, '
          'display_order, created_at, updated_at',
        )
        .eq('exam_id', examId)
        .order('display_order', ascending: true);

    final questions = (questionsResponse as List)
        .map((item) => AdminQuestion.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    if (questions.isEmpty) {
      return [];
    }

    final questionIds = questions.map((q) => q.id).toList();

    // ------------------------------------------------------------------------
    // OPTIONS
    // ------------------------------------------------------------------------

    final optionsResponse = await _supabase
        .from('question_options')
        .select('id, question_id, option_text, display_order')
        .inFilter('question_id', questionIds)
        .order('display_order', ascending: true);

    final options = (optionsResponse as List)
        .map((item) => QuestionOption.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    // ------------------------------------------------------------------------
    // CORRECT ANSWERS
    // ------------------------------------------------------------------------

    final correctResponse = await _supabase
        .from('question_correct_answers')
        .select(
          'question_id, correct_option_id, '
          'created_at, updated_at',
        )
        .inFilter('question_id', questionIds);

    final correctAnswers = (correctResponse as List)
        .map(
          (item) =>
              QuestionCorrectAnswer.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();

    // ------------------------------------------------------------------------
    // COMBINE
    // ------------------------------------------------------------------------

    return questions.map((question) {
      final questionOptions = options
          .where((option) => option.questionId == question.id)
          .toList();

      final correct = correctAnswers
          .where((answer) => answer.questionId == question.id)
          .firstOrNull;

      return question.copyWith(
        options: questionOptions,
        correctOptionId: correct?.correctOptionId,
      );
    }).toList();
  }

  // ==========================================================================
  // CREATE QUESTION
  // ==========================================================================

  Future<String> createQuestion({
    required String examId,
    required QuestionData data,
  }) async {
    if (data.options.length < 2) {
      throw Exception('A question must have at least 2 options.');
    }

    if (data.correctOptionIndex < 0 ||
        data.correctOptionIndex >= data.options.length) {
      throw Exception('Invalid correct answer.');
    }

    // ------------------------------------------------------------------------
    // GET NEXT DISPLAY ORDER
    // ------------------------------------------------------------------------

    final lastQuestion = await _supabase
        .from('questions')
        .select('display_order')
        .eq('exam_id', examId)
        .order('display_order', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextOrder = lastQuestion == null
        ? 0
        : ((lastQuestion['display_order'] as num?)?.toInt() ?? 0) + 1;

    // ------------------------------------------------------------------------
    // CREATE QUESTION
    // ------------------------------------------------------------------------

    final questionResponse = await _supabase
        .from('questions')
        .insert({
          'exam_id': examId,
          'question_text': data.questionText,
          'explanation': data.explanation,
          'display_order': nextOrder,
        })
        .select('id')
        .single();

    final questionId = questionResponse['id'] as String;

    try {
      // ----------------------------------------------------------------------
      // CREATE OPTIONS
      // ----------------------------------------------------------------------

      final optionRows = <Map<String, dynamic>>[];

      for (int i = 0; i < data.options.length; i++) {
        optionRows.add({
          'question_id': questionId,
          'option_text': data.options[i],
          'display_order': i,
        });
      }

      final optionsResponse = await _supabase
          .from('question_options')
          .insert(optionRows)
          .select('id, question_id, option_text, display_order');

      final createdOptions = (optionsResponse as List)
          .map(
            (item) => QuestionOption.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();

      createdOptions.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      final correctOption = createdOptions[data.correctOptionIndex];

      // ----------------------------------------------------------------------
      // CREATE CORRECT ANSWER
      // ----------------------------------------------------------------------

      await _supabase.from('question_correct_answers').insert({
        'question_id': questionId,
        'correct_option_id': correctOption.id,
      });

      return questionId;
    } catch (e) {
      // ----------------------------------------------------------------------
      // CLEANUP IF CREATION FAILS
      // ----------------------------------------------------------------------

      await _supabase
          .from('question_correct_answers')
          .delete()
          .eq('question_id', questionId);

      await _supabase
          .from('question_options')
          .delete()
          .eq('question_id', questionId);

      await _supabase.from('questions').delete().eq('id', questionId);

      rethrow;
    }
  }

  // ==========================================================================
  // UPDATE QUESTION
  // ==========================================================================

  Future<void> updateQuestion({
    required String questionId,
    required QuestionData data,
  }) async {
    if (data.options.length < 2) {
      throw Exception('A question must have at least 2 options.');
    }

    if (data.correctOptionIndex < 0 ||
        data.correctOptionIndex >= data.options.length) {
      throw Exception('Invalid correct answer.');
    }

    // ------------------------------------------------------------------------
    // UPDATE QUESTION
    // ------------------------------------------------------------------------

    await _supabase
        .from('questions')
        .update({
          'question_text': data.questionText,
          'explanation': data.explanation,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', questionId);

    // ------------------------------------------------------------------------
    // REMOVE OLD OPTIONS
    // ------------------------------------------------------------------------

    await _supabase
        .from('question_correct_answers')
        .delete()
        .eq('question_id', questionId);

    await _supabase
        .from('question_options')
        .delete()
        .eq('question_id', questionId);

    // ------------------------------------------------------------------------
    // CREATE NEW OPTIONS
    // ------------------------------------------------------------------------

    final optionRows = <Map<String, dynamic>>[];

    for (int i = 0; i < data.options.length; i++) {
      optionRows.add({
        'question_id': questionId,
        'option_text': data.options[i],
        'display_order': i,
      });
    }

    final optionsResponse = await _supabase
        .from('question_options')
        .insert(optionRows)
        .select('id, question_id, option_text, display_order');

    final createdOptions = (optionsResponse as List)
        .map((item) => QuestionOption.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    createdOptions.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final correctOption = createdOptions[data.correctOptionIndex];

    // ------------------------------------------------------------------------
    // CREATE CORRECT ANSWER
    // ------------------------------------------------------------------------

    await _supabase.from('question_correct_answers').insert({
      'question_id': questionId,
      'correct_option_id': correctOption.id,
    });
  }

  // ==========================================================================
  // DELETE QUESTION
  // ==========================================================================

  Future<void> deleteQuestion(String questionId) async {
    // Correct answer
    await _supabase
        .from('question_correct_answers')
        .delete()
        .eq('question_id', questionId);

    // Options
    await _supabase
        .from('question_options')
        .delete()
        .eq('question_id', questionId);

    // Question
    await _supabase.from('questions').delete().eq('id', questionId);
  }

  // ==========================================================================
  // REORDER
  // ==========================================================================

  Future<void> reorderQuestions(List<AdminQuestion> questions) async {
    for (int i = 0; i < questions.length; i++) {
      await _supabase
          .from('questions')
          .update({
            'display_order': i,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', questions[i].id);
    }
  }
}
