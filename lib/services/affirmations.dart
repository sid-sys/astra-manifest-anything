import '../models/intention.dart';

/// The daily affirmation pool.
///
/// Chosen deterministically from the date so everyone opening the app on the
/// same day gets the same line, and reopening it doesn't reshuffle.
class Affirmations {
  const Affirmations._();

  static const _byIntention = {
    Intention.career: [
      'Money moves toward me because I move first.',
      'The work I want is looking for someone exactly like me.',
      'I am already the person that role requires.',
    ],
    Intention.abundance: [
      'There is enough, and some of it is mine.',
      'I hold money calmly, and it stays.',
      'Abundance is a habit before it is an amount.',
    ],
    Intention.love: [
      'I am loved plainly, without having to earn tomorrow.',
      'The right people find me easy to stay close to.',
      'I let myself be chosen back.',
    ],
    Intention.health: [
      'My body is on my side and always has been.',
      'I give my body kindness long enough to feel it return.',
      'Rest is part of the work, not a break from it.',
    ],
    Intention.confidence: [
      'I say the difficult sentence and the ceiling stays up.',
      'I stopped waiting to feel ready and became ready on the way.',
      'My voice carries because I let it.',
    ],
    Intention.peace: [
      'Nothing is urgent enough to take my morning.',
      'The quiet was never somewhere else.',
      'I am allowed to be unreachable.',
    ],
  };

  static String forDay(DateTime day, Set<Intention> intentions) {
    final pool = intentions.isEmpty
        ? _byIntention.values.expand((lines) => lines).toList()
        : intentions.expand((i) => _byIntention[i]!).toList()
      ..sort();

    final dayNumber = DateTime(day.year, day.month, day.day)
        .difference(DateTime(2026))
        .inDays;
    return pool[dayNumber.abs() % pool.length];
  }
}
