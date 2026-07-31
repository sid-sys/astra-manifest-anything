import 'intention.dart';

/// What the user has kept and what they have thrown away.
///
/// Swiping is only worth the effort if it changes what comes next, so this
/// records both sides: the lines themselves, to avoid repeating a decision the
/// user has already made, and the per-intention tally that decides which life
/// areas the deck leans toward.
class AffirmationTaste {
  const AffirmationTaste({this.liked = const {}, this.passed = const {}});

  /// Lines the user swiped right, newest last.
  final Set<String> liked;

  /// Lines the user swiped left. Kept so they are not offered again.
  final Set<String> passed;

  bool get isEmpty => liked.isEmpty && passed.isEmpty;

  bool hasSeen(String line) => liked.contains(line) || passed.contains(line);

  AffirmationTaste like(String line) => AffirmationTaste(
    liked: {...liked, line},
    passed: passed.where((l) => l != line).toSet(),
  );

  AffirmationTaste pass(String line) => AffirmationTaste(
    liked: liked.where((l) => l != line).toSet(),
    passed: {...passed, line},
  );

  AffirmationTaste unlike(String line) =>
      AffirmationTaste(liked: liked.where((l) => l != line).toSet(), passed: passed);

  /// How strongly the user leans toward an intention, from 0 to 1.
  ///
  /// Laplace-smoothed, so one early swipe cannot drive a whole life area to
  /// zero and hide it forever. A user who has never swiped sits at 0.5 for
  /// everything, which is the same as no opinion.
  double affinity(Intention intention, Map<String, Intention> lineOwner) {
    var likes = 0;
    var passes = 0;

    for (final line in liked) {
      if (lineOwner[line] == intention) likes++;
    }
    for (final line in passed) {
      if (lineOwner[line] == intention) passes++;
    }

    return (likes + 1) / (likes + passes + 2);
  }

  Map<String, dynamic> toMap() => {
    'liked': liked.toList(),
    'passed': passed.toList(),
  };

  factory AffirmationTaste.fromMap(Map<String, dynamic> map) => AffirmationTaste(
    liked: ((map['liked'] as List?) ?? const []).map((l) => l as String).toSet(),
    passed:
        ((map['passed'] as List?) ?? const []).map((l) => l as String).toSet(),
  );
}
