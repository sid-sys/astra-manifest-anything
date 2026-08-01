import '../models/intention.dart';

/// A one-tap manifestation, shown as a chip under the wish box.
///
/// [label] is what fits on a chip; [wish] is what actually goes into the box,
/// because "Own the room" is a good chip and a bad prompt — the generator needs
/// a sentence with a person in it.
class TrendingWish {
  const TrendingWish(this.label, this.wish, this.intention);

  final String label;
  final String wish;
  final Intention intention;
}

/// The chips under the wish box.
///
/// These are curated, not computed. A real trending list would aggregate what
/// people are actually asking for, which needs a counter in Firestore and
/// enough users for the counts to mean anything; until both exist, a ranking
/// derived from four accounts would be a made-up number wearing a real one's
/// clothes. The rotation below is honest about being an editorial pick: it
/// changes daily so the row feels alive, and the order is seeded by the date
/// rather than by popularity.
///
/// When the counters do exist, replace [forDay] and leave everything else —
/// the home screen only ever asks for a list.
class TrendingManifestations {
  const TrendingManifestations._();

  static const all = <TrendingWish>[
    TrendingWish(
      'Studio of my own',
      'I want to run my own studio',
      Intention.career,
    ),
    TrendingWish(
      'The call that changes it',
      'I want to be the one they call when it matters',
      Intention.career,
    ),
    TrendingWish(
      'Debt-free',
      'I want to pay off everything I owe',
      Intention.abundance,
    ),
    TrendingWish(
      'A house for my parents',
      'I want to buy my parents a house',
      Intention.abundance,
    ),
    TrendingWish(
      'Money without flinching',
      'I want to stop checking my balance before I buy food',
      Intention.abundance,
    ),
    TrendingWish('Marry her', 'I want to marry her', Intention.love),
    TrendingWish(
      'Glad I came home',
      'I want someone who is glad I came home',
      Intention.love,
    ),
    TrendingWish(
      'Wake up without hurting',
      'I want to wake up without hurting',
      Intention.health,
    ),
    TrendingWish(
      'Five kilometres',
      'I want to run five kilometres without stopping',
      Intention.health,
    ),
    TrendingWish(
      'Speak and not shake',
      'I want to speak up in the room and not shake',
      Intention.confidence,
    ),
    TrendingWish(
      'Walk in like I belong',
      'I want to walk in like I belong there',
      Intention.confidence,
    ),
    TrendingWish(
      'A summer with nowhere to be',
      'I want to travel around the UK with nowhere to be',
      Intention.peace,
    ),
    TrendingWish(
      'Nobody needs anything',
      'I want a morning that nobody needs anything from',
      Intention.peace,
    ),
  ];

  /// The row for [day], with anything matching [intentions] pulled to the
  /// front.
  ///
  /// Two things are happening: the whole list rotates by the day of the year so
  /// the row is not identical every morning, and the user's own intentions are
  /// stably partitioned to the front so the first chips are ones they might
  /// plausibly tap. Partitioning after rotating keeps both — the order inside
  /// each group still moves day to day.
  static List<TrendingWish> forDay(DateTime day, Set<Intention> intentions) {
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    final offset = dayOfYear % all.length;
    final rotated = [...all.sublist(offset), ...all.sublist(0, offset)];

    if (intentions.isEmpty) return rotated;

    return [
      ...rotated.where((w) => intentions.contains(w.intention)),
      ...rotated.where((w) => !intentions.contains(w.intention)),
    ];
  }
}
