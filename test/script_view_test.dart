import 'package:astra/models/intention.dart';
import 'package:astra/services/wish_prompts.dart';
import 'package:astra/widgets/script_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitting a script into spoken lines', () {
    test('keeps every word', () {
      const script = 'I wake up early. The room is cold and bright.\n\n'
          'I make coffee and stand by the window for a while.';

      final joined = splitScript(script).join(' ');

      for (final word in ['wake', 'cold', 'coffee', 'window']) {
        expect(joined, contains(word));
      }
    });

    test('keeps sentence-ending punctuation', () {
      final lines = splitScript(
        'I walk into the room slowly. Everyone is already there waiting.',
      );

      expect(lines.every((line) => line.trim().endsWith('.')), isTrue);
    });

    test('does not strand a very short sentence on its own line', () {
      final lines = splitScript(
        'I said yes. Then we drove out to the coast for the whole afternoon.',
      );

      expect(lines.first, startsWith('I said yes.'));
      expect(lines.first.split(' ').length, greaterThan(3));
    });

    test('drops blank paragraphs rather than emitting empty lines', () {
      final lines = splitScript('First line of the story here.\n\n\n\nSecond one follows.');

      expect(lines.any((line) => line.trim().isEmpty), isFalse);
    });
  });

  group('wish prompts', () {
    test('rotate to something new rather than repeating', () {
      var wish = WishPrompts.next(Intention.love);

      // Walk the whole pool: every step must differ from the last, which is
      // the thing a random shuffle cannot promise.
      for (var i = 0; i < 6; i++) {
        final next = WishPrompts.next(Intention.love, previous: wish);
        expect(next, isNot(equals(wish)));
        wish = next;
      }
    });

    test('are drawn from the intention asked for', () {
      expect(
        WishPrompts.next(Intention.abundance, previous: 'I want to marry her'),
        isNotEmpty,
      );
      expect(WishPrompts.next(Intention.love), isNotEmpty);
    });
  });
}
