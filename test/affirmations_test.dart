import 'package:astra/models/intention.dart';
import 'package:astra/services/affirmations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the affirmation deck', () {
    test('only draws from the intentions the user chose', () {
      final deck = Affirmations.deck({Intention.love});

      expect(deck, isNotEmpty);
      expect(deck.every((card) => card.intention == Intention.love), isTrue);
    });

    test('falls back to every intention when none are chosen', () {
      final deck = Affirmations.deck({});

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
      });

      // Three intentions means the first three cards should be one of each;
      // grouping would make the deck feel like three separate decks stapled
      // together.
      expect(deck.take(3).map((card) => card.intention).toSet(), hasLength(3));
    });

    test('loses no lines', () {
      final chosen = {Intention.love, Intention.health};
      final deck = Affirmations.deck(chosen);

      expect(deck.map((card) => card.line).toSet(), hasLength(deck.length));
      for (final intention in chosen) {
        expect(deck.where((card) => card.intention == intention), hasLength(3));
      }
    });
  });
}
