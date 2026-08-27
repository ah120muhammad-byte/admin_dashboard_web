import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// QUESTION
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
    required this.options,
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
// QUESTIONS SERVICE
// ============================================================================

class QuestionsService {
  final SupabaseClient _supabase;

  QuestionsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ==========================================================================
  // GET QUESTIONS
  // ==========================================================================

  Future<List<AdminQuestion>> getQuestions(String examId) async {
    final questionsResponse = await _supabase
        .from('questions')
        .select(
          'id, exam_id, question_text, '
          'explanation, display_order, '
          'created_at, updated_at',
        )
        .eq('exam_id', examId)
        .order('display_order', ascending: true);

    final questions = (questionsResponse as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (questions.isEmpty) {
      return [];
    }

    final questionIds = questions
        .map((question) => question['id'] as String)
        .toList();

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
    // MAP DATA
    // ------------------------------------------------------------------------

    return questions.map((question) {
      final questionId = question['id'] as String;

      final questionOptions = options
          .where((option) => option.questionId == questionId)
          .toList();

      final correctAnswer = correctAnswers.where(
        (answer) => answer.questionId == questionId,
      );

      return AdminQuestion.fromMap(
        question,
        options: questionOptions,
        correctOptionId: correctAnswer.isEmpty
            ? null
            : correctAnswer.first.correctOptionId,
      );
    }).toList();
  }

  // ==========================================================================
  // CREATE QUESTION
  // ==========================================================================

  Future<String> createQuestion({
    required String examId,
    required String questionText,
    String? explanation,
    required List<String> options,
    required int correctOptionIndex,
  }) async {
    final questionResponse = await _supabase
        .from('questions')
        .insert({
          'exam_id': examId,
          'question_text': questionText,
          'explanation': explanation,
          'display_order': 0,
        })
        .select('id')
        .single();

    final questionId = questionResponse['id'] as String;

    try {
      final optionRows = <Map<String, dynamic>>[];

      for (int i = 0; i < options.length; i++) {
        optionRows.add({
          'question_id': questionId,
          'option_text': options[i],
          'display_order': i,
        });
      }

      final optionsResponse = await _supabase
          .from('question_options')
          .insert(optionRows)
          .select('id, question_id, option_text, display_order');

      final insertedOptions = (optionsResponse as List)
          .map(
            (item) => QuestionOption.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();

      if (correctOptionIndex < 0 ||
          correctOptionIndex >= insertedOptions.length) {
        throw Exception('Invalid correct option.');
      }

      await _supabase.from('question_correct_answers').insert({
        'question_id': questionId,
        'correct_option_id': insertedOptions[correctOptionIndex].id,
      });

      return questionId;
    } catch (e) {
      await _supabase.from('questions').delete().eq('id', questionId);

      rethrow;
    }
  }

  // ==========================================================================
  // UPDATE QUESTION
  // ==========================================================================

  Future<void> updateQuestion({
    required String id,
    required String questionText,
    String? explanation,
    required List<String> options,
    required int correctOptionIndex,
  }) async {
    await _supabase
        .from('questions')
        .update({'question_text': questionText, 'explanation': explanation})
        .eq('id', id);

    await _supabase
        .from('question_correct_answers')
        .delete()
        .eq('question_id', id);

    await _supabase.from('question_options').delete().eq('question_id', id);

    final optionRows = <Map<String, dynamic>>[];

    for (int i = 0; i < options.length; i++) {
      optionRows.add({
        'question_id': id,
        'option_text': options[i],
        'display_order': i,
      });
    }

    final optionsResponse = await _supabase
        .from('question_options')
        .insert(optionRows)
        .select('id, question_id, option_text, display_order');

    final insertedOptions = (optionsResponse as List)
        .map((item) => QuestionOption.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    if (correctOptionIndex < 0 ||
        correctOptionIndex >= insertedOptions.length) {
      throw Exception('Invalid correct option.');
    }

    await _supabase.from('question_correct_answers').insert({
      'question_id': id,
      'correct_option_id': insertedOptions[correctOptionIndex].id,
    });
  }

  // ==========================================================================
  // DELETE QUESTION
  // ==========================================================================

  Future<void> deleteQuestion(String id) async {
    await _supabase
        .from('question_correct_answers')
        .delete()
        .eq('question_id', id);

    await _supabase.from('question_options').delete().eq('question_id', id);

    await _supabase.from('questions').delete().eq('id', id);
  }

  // ==========================================================================
  // REORDER
  // ==========================================================================

  Future<void> updateDisplayOrder({
    required String id,
    required int displayOrder,
  }) async {
    await _supabase
        .from('questions')
        .update({'display_order': displayOrder})
        .eq('id', id);
  }
}
