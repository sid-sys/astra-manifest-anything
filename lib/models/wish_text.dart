/// Whether a typed wish is worth sending to the writer.
///
/// This replaced a character count. Twenty characters was a proxy for effort
/// and a bad one in both directions: it refused "I want my own home", which is
/// a complete wish, and it happily accepted "aaaaaaaaaaaaaaaaaaaaaa", which is
/// not. What actually matters is whether there are words in the box.
///
/// No dictionary, and deliberately no network call. This runs on every
/// keystroke to decide whether a button is live, so it has to be instant and
/// work offline. What it does instead is check the shape of the text against
/// how written English is shaped — which catches a keyboard mash without
/// needing to know what any particular word means.
///
/// It is a guard, not a judge. The server checks the same thing before spending
/// money, and anything that gets past both is a real sentence Mayow can try to
/// write from. Being slightly too permissive is the right way to be wrong: the
/// cost of letting an odd wish through is one odd manifestation, and the cost of
/// refusing a real one is a person who cannot use the app.
library;

/// Letters, in either case, plus the apostrophes inside words.
final _wordish = RegExp(r"[a-zA-Z']+");
final _vowel = RegExp('[aeiouyAEIOUY]');

/// Five consonants in a row. English has a few — "strengths" — but they are
/// rare enough that this only fires on a mash.
final _consonantRun = RegExp('[^aeiouy\\s]{5,}', caseSensitive: false);

/// The words a short wish is almost certainly made of.
///
/// Not a spellcheck and not meant to be — a few dozen of the commonest English
/// words, enough to tell "my own home" from "qwer tyui". A longer phrase does
/// not need to match any of them, so this only ever has to carry the short
/// ones.
const _common = {
  'i', 'a', 'an', 'the', 'my', 'me', 'we', 'our', 'you', 'your',
  'to', 'of', 'in', 'on', 'at', 'for', 'with', 'and', 'or', 'is',
  'am', 'be', 'have', 'has', 'want', 'wants', 'wish', 'need', 'get',
  'live', 'living', 'own', 'home', 'life', 'love', 'find', 'make',
  'become', 'more', 'every', 'day', 'year', 'new', 'big',
  'dog', 'cat', 'car', 'house', 'job', 'work', 'money', 'peace',
};

bool looksMeaningful(String input) {
  final words = _wordish
      .allMatches(input)
      .map((match) => match[0]!.toLowerCase())
      .toList();

  // One word is not a wish. "Millionaire" on its own is a noun; "I want to be
  // a millionaire" is something to write about — and, usefully, a single run of
  // mashed keys is the commonest kind of nonsense there is.
  if (words.toSet().length < 2) return false;

  // Long enough to be a phrase, *or* built from words English actually uses.
  //
  // Length alone was wrong: "my own home" is nine letters and a wish, while
  // "qwer tyui" is eight and a mash. The common-word check separates them
  // without a dictionary, because almost every real wish somebody types
  // contains one of these — and a keyboard mash contains none.
  final letters = words.fold<int>(0, (sum, word) => sum + word.length);
  if (letters < 10 && !words.any(_common.contains)) return false;

  for (final word in words) {
    // Every English word of any length has a vowel in it, counting y. A word
    // without one is either an acronym or a mash, and neither is a wish.
    if (word.length >= 3 && !_vowel.hasMatch(word)) return false;
  }

  // And nothing that reads as a fistful of keys.
  if (_consonantRun.hasMatch(input)) return false;

  return true;
}
