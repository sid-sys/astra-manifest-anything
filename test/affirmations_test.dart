import 'package:astra/models/affirmation_taste.dart';
import 'package:astra/models/intention.dart';
import 'package:astra/services/affirmations.dart';
import 'package:flutter_test/flutter_test.dart';

const _noTaste = AffirmationTaste();

void main() {
  group('the affirmation deck', () {
    test('only draws from the intentions the user chose', () {
      final deck = Affirmations.deck({Intention.love}, _noTaste);

      expect(deck, isNotEmpty);
      expect(deck.every((card) => card.intention == Intention.love), isTrue);
    });

    test('falls back to every intention when none are chosen', () {
      final deck = Affirmations.deck({}, _noTaste);

      expect(
        deck.map((card) => card.intention).toSet(),
        equals(Intention.values.toSet()),
      );
    });

    test('alternates intentions rather than grouping them', () {
      final deck = Affirmations.deck({
        Intention.love,
        Intention.career,
        Intention.peace,
      }, _noTaste);

      expect(deck.take(3).map((card) => card.intention).toSet(), hasLength(3));
    });

    test('never offers a card the user has already decided on', () {
      final first = Affirmations.deck({Intention.love}, _noTaste).first;
      final after = Affirmations.deck(
        {Intention.love},
        _noTaste.pass(first.line),
      );

      expect(after.map((card) => card.line), isNot(contains(first.line)));
      expect(after, hasLength(Affirmations.deck({Intention.love}, _noTaste).length - 1));
    });

    test('leans toward the intention the user keeps', () {
      // Keep two career lines, pass two love lines. Career should now lead.
      final owners = Affirmations.lineOwners;
      final career = owners.entries
          .where((e) => e.value == Intention.career)
          .map((e) => e.key)
          .toList();
      final love = owners.entries
          .where((e) => e.value == Intention.love)
          .map((e) => e.key)
          .toList();

      var taste = _noTaste.like(career[0]).like(career[1]);
      taste = taste.pass(love[0]).pass(love[1]);

      final deck = Affirmations.deck({Intention.career, Intention.love}, taste);

      expect(deck.first.intention, Intention.career);
    });

    test('runs dry once everything has been decided on', () {
      var taste = _noTaste;
      for (final card in Affirmations.deck({Intention.peace}, _noTaste)) {
        taste = taste.pass(card.line);
      }

      expect(Affirmations.deck({Intention.peace}, taste), isEmpty);
    });
  });

  group('affirmation taste', () {
    test('a like moves a line off the passed pile', () {
      final line = Affirmations.lineOwners.keys.first;
      final taste = _noTaste.pass(line).like(line);

      expect(taste.liked, contains(line));
      expect(taste.passed, isNot(contains(line)));
    });

    test('an unswiped intention sits at no opinion', () {
      expect(
        _noTaste.affinity(Intention.health, Affirmations.lineOwners),
        closeTo(0.5, 0.001),
      );
    });

    test('survives a round trip through storage', () {
      final line = Affirmations.lineOwners.keys.first;
      final restored = AffirmationTaste.fromMap(_noTaste.like(line).toMap());

      expect(restored.liked, contains(line));
    });
  });

  group('the daily affirmation', () {
    test('prefers something the user has kept', () {
      final line = Affirmations.lineOwners.keys.first;
      final today = Affirmations.forDay(
        DateTime(2026, 7, 31),
        {Intention.peace},
        _noTaste.like(line),
      );

      expect(today, equals(line));
    });

    test('is stable across the same day', () {
      final a = Affirmations.forDay(DateTime(2026, 7, 31), {Intention.love});
      final b = Affirmations.forDay(DateTime(2026, 7, 31), {Intention.love});

      expect(a, equals(b));
    });
  });
}
