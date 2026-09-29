import '../models/affirmation_taste.dart';
import '../models/intention.dart';

/// One card in the affirmation deck: the line and the life area it belongs to.
class Affirmation {
  const Affirmation({
    required this.line,
    required this.intention,
    this.isShortVersion = false,
  });

  final String line;
  final Intention intention;

  /// True for the one distilled line at the head of a generated group — the
  /// single sentence the batch of eight was written down to. Shown with its
  /// own styling in the deck rather than blending in as card nine of nine.
  final bool isShortVersion;
}

/// One area's worth of server-generated lines: eight variations and the one
/// line that distills them, exactly as [functions/index.js] writes them.
///
/// This is the shape `private/affirmations.groups` is stored in — see
/// `writeAffirmations` there. Parsed defensively, the same way [Story] and
/// [UserProfile] are: a field of the wrong type is dropped rather than
/// thrown on, because a malformed group should degrade the deck, not crash
/// the screen showing it.
class AffirmationGroup {
  const AffirmationGroup({
    required this.intention,
    required this.lines,
    required this.shortVersion,
  });

  final Intention intention;
  final List<String> lines;
  final String shortVersion;

  static AffirmationGroup? fromMap(Object? raw) {
    if (raw is! Map) return null;

    final areaKey = raw['areaKey'] as String?;
    final shortVersion = (raw['shortVersion'] as String?)?.trim();
    final lines = (raw['lines'] as List?)
            ?.whereType<String>()
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList() ??
        const <String>[];

    if (areaKey == null || shortVersion == null || shortVersion.isEmpty) {
      return null;
    }

    return AffirmationGroup(
      intention: Intention.fromName(areaKey),
      lines: lines,
      shortVersion: shortVersion,
    );
  }

  /// This group as deck cards: the short version first and marked, then the
  /// eight variations behind it — the order a person should meet them in,
  /// most concentrated line first.
  List<Affirmation> toCards() => [
    Affirmation(line: shortVersion, intention: intention, isShortVersion: true),
    for (final line in lines) Affirmation(line: line, intention: intention),
  ];
}

/// The affirmation pool.
///
/// Eight per intention rather than three: the deck is swiped through one card
/// at a time now, and a stack that runs out in three swipes teaches the app
/// nothing about what the user actually wants to hear.
class Affirmations {
  const Affirmations._();

  static const _byIntention = {
    Intention.career: [
      'Money moves toward me because I move first.',
      'The work I want is looking for someone exactly like me.',
      'I am already the person that role requires.',
      'I do work I would still do if nobody were watching.',
      'The room gets better when I am in it.',
      'I stopped waiting to be picked and started building.',
      'My name opens doors I have not knocked on yet.',
      'I am paid properly for what I am actually worth.',
    ],
    Intention.abundance: [
      'There is enough, and some of it is mine.',
      'I hold money calmly, and it stays.',
      'Abundance is a habit before it is an amount.',
      'I check my balance without holding my breath.',
      'Money is a tool I use, not a weather I survive.',
      'I can be generous because there is more coming.',
      'The bills are paid and the fear has gone quiet.',
      'I am allowed to want more than enough.',
    ],
    Intention.love: [
      'I am loved plainly, without having to earn tomorrow.',
      'The right people find me easy to stay close to.',
      'I let myself be chosen back.',
      'I am glad to come home, and someone is glad I did.',
      'I stopped auditioning for people who were almost right.',
      'Being known is better than being impressive.',
      'I give love without keeping score.',
      'Someone says my name like it is good news.',
    ],
    Intention.health: [
      'My body is on my side and always has been.',
      'I give my body kindness long enough to feel it return.',
      'Rest is part of the work, not a break from it.',
      'I wake up without bracing for how I will feel.',
      'I move because it feels good, not as a punishment.',
      'I sleep through the night and wake up mine again.',
      'My body carries me. I am not at war with it.',
      'I eat like someone who intends to stay.',
    ],
    Intention.confidence: [
      'I say the difficult sentence and the ceiling stays up.',
      'I stopped waiting to feel ready and became ready on the way.',
      'My voice carries because I let it.',
      'I take up the room I am standing in.',
      'I send it without rewriting it four times.',
      'I am not for everyone, and that is the point.',
      'I can be wrong out loud and survive it.',
      'I walk in like I belong there, because I do.',
    ],
    Intention.peace: [
      'Nothing is urgent enough to take my morning.',
      'The quiet was never somewhere else.',
      'I am allowed to be unreachable.',
      'I put the phone down and do not reach for it.',
      'I have stopped bracing for the next thing.',
      'Slow is a decision, not a failure.',
      'An ordinary day is not a wasted one.',
      'I let the silence stay silent.',
    ],
  };

  /// Every line, keyed to the intention it came from.
  static Map<String, Intention> get lineOwners => {
    for (final entry in _byIntention.entries)
      for (final line in entry.value) line: entry.key,
  };

  /// The next cards to swipe, best first.
  ///
  /// Sorted by how much the user has liked each intention so far, so the deck
  /// leans toward what they keep without ever cutting an area off entirely —
  /// a stack that only ever shows one life area stops being a discovery tool.
  /// Lines already decided on are dropped, since re-asking a settled question
  /// is the fastest way to make swiping feel pointless.
  static List<Affirmation> deck(
    Set<Intention> intentions,
    AffirmationTaste taste,
  ) {
    final chosen = intentions.isEmpty ? _byIntention.keys.toSet() : intentions;
    final owners = lineOwners;

    final remaining = [
      for (final intention in chosen)
        for (final line in _byIntention[intention]!)
          if (!taste.hasSeen(line))
            Affirmation(line: line, intention: intention),
    ];

    // Interleave by affinity: take from the strongest intention most often,
    // but never exhaust it before the others get a turn.
    final byIntention = <Intention, List<Affirmation>>{};
    for (final card in remaining) {
      byIntention.putIfAbsent(card.intention, () => []).add(card);
    }

    final order = byIntention.keys.toList()
      ..sort(
        (a, b) => taste
            .affinity(b, owners)
            .compareTo(taste.affinity(a, owners)),
      );

    final deck = <Affirmation>[];
    var added = true;
    while (added) {
      added = false;
      for (final intention in order) {
        final pile = byIntention[intention]!;
        if (pile.isNotEmpty) {
          deck.add(pile.removeAt(0));
          added = true;
        }
      }
    }

    return deck;
  }

  /// The line shown on Home. Chosen deterministically from the date so
  /// everyone opening the app on the same day gets the same one, and reopening
  /// it doesn't reshuffle. Prefers something the user has already liked.
  static String forDay(
    DateTime day,
    Set<Intention> intentions, [
    AffirmationTaste taste = const AffirmationTaste(),
  ]) {
    final pool = taste.liked.isNotEmpty
        ? (taste.liked.toList()..sort())
        : (intentions.isEmpty
              ? _byIntention.values.expand((lines) => lines).toList()
              : intentions.expand((i) => _byIntention[i]!).toList())
          ..sort();

    final dayNumber = DateTime(day.year, day.month, day.day)
        .difference(DateTime(2026))
        .inDays;
    return pool[dayNumber.abs() % pool.length];
  }
}
