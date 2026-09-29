/// Four questions written for one desire, each with four answers.
///
/// This is what replaced onboarding. Twelve fixed questions asked at signup
/// could only ever be generic, because they were written before anybody knew
/// what the person wanted — "how realistic should it feel" is the same question
/// for somebody who wants to be a millionaire and somebody who wants to run a
/// 10k, and neither answer tells the writer much.
///
/// Asked *after* the desire, four questions can be about the desire. Same four
/// taps, an order of magnitude more signal.
class QuestionPlan {
  const QuestionPlan({required this.category, required this.questions});

  /// A word or two for the kind of desire this is — "home", "love", "career".
  /// Not shown to the user; it is there so the admin panel can eventually say
  /// what people are actually asking for.
  final String category;

  final List<PlannedQuestion> questions;

  bool get isUsable => questions.length == 4;

  factory QuestionPlan.fromMap(Map<String, dynamic> map) => QuestionPlan(
    category: map['category'] as String? ?? '',
    questions: ((map['questions'] as List?) ?? const [])
        .map(
          (question) =>
              PlannedQuestion.fromMap(Map<String, dynamic>.from(question as Map)),
        )
        .toList(),
  );
}

/// One question and its four answers.
class PlannedQuestion {
  const PlannedQuestion({required this.question, required this.options});

  final String question;

  /// Four of them, each opening with an emoji. The emoji comes from the model
  /// rather than a lookup table here, because it has to match an answer nobody
  /// wrote in advance.
  final List<String> options;

  factory PlannedQuestion.fromMap(Map<String, dynamic> map) => PlannedQuestion(
    question: map['question'] as String? ?? '',
    options: ((map['options'] as List?) ?? const [])
        .map((option) => option.toString())
        .where((option) => option.trim().isNotEmpty)
        .toList(),
  );
}
