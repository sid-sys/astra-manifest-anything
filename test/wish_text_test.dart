import 'package:astra/models/wish_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gate on the generate button, which used to be a character count.
///
/// Twenty characters was a proxy for effort and wrong in both directions: it
/// refused "I want my own home" and accepted "aaaaaaaaaaaaaaaaaaaaaa". These
/// cases are the ones that matter — a real wish must get through, and a mash
/// must not, and the second half is what costs money when it fails.
void main() {
  group('real wishes get through', () {
    const wishes = [
      'I want to live in a big beautiful apartment I can call home',
      'I want to find my soulmate',
      'I want my app to make ten thousand dollars every month',
      'financial freedom',
      'my own home',
      'I want to run a marathon',
      // Short, complete, and under the old twenty-character floor.
      'I want a dog',
    ];

    for (final wish in wishes) {
      test('"$wish"', () => expect(looksMeaningful(wish), isTrue));
    }
  });

  group('nonsense does not', () {
    const rubbish = {
      'empty': '',
      'spaces': '     ',
      'punctuation only': '... !!! ???',
      // The owner's own example.
      'one long mash': 'eqwuydgydgiau',
      'repeated word': 'asdf asdf',
      'too few letters': 'qwer tyui',
      'no vowels': 'hjklm bcdfg',
      'a fistful of keys': 'asdfghjkl qwertyuiop',
      'one real word': 'millionaire',
      'padding': 'aaaaaaaaaaaaaaaaaaaaaa',
    };

    rubbish.forEach((name, text) {
      test(name, () => expect(looksMeaningful(text), isFalse));
    });
  });

  test('the check is about words, not length', () {
    // The whole point of the change. The first of these is shorter than the
    // old minimum and is a wish; the second is longer than it and is not.
    expect(looksMeaningful('I want a dog'), isTrue);
    expect(looksMeaningful('aaaaaaaaaaaaaaaaaaaaaaaaa'), isFalse);
  });
}
