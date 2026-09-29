import 'package:astra/services/callable_errors.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the user is shown when a server call fails.
///
/// Written after a real one: a rejected request schema broke every
/// manifestation and every affirmation, and the whole app could say about it
/// was a screen reading "That did not work / INTERNAL".
void main() {
  FirebaseFunctionsException failure(String code, String message) =>
      FirebaseFunctionsException(code: code, message: message);

  test('a machine code is never put on screen', () {
    expect(
      humanMessage(failure('internal', 'INTERNAL'), fallback: 'Try again.'),
      'Try again.',
    );
    expect(
      humanMessage(failure('unavailable', 'UNAVAILABLE'), fallback: 'Try again.'),
      'Try again.',
    );
    expect(
      humanMessage(failure('unknown', 'UNKNOWN'), fallback: 'Try again.'),
      'Try again.',
    );
  });

  test('a sentence the server wrote on purpose is kept word for word', () {
    const written = "You have used this month's manifestations.";
    expect(
      humanMessage(failure('resource-exhausted', written), fallback: 'Try again.'),
      written,
    );

    const asked = 'Tell Maya what you want, in your own words.';
    expect(
      humanMessage(failure('invalid-argument', asked), fallback: 'Try again.'),
      asked,
    );
  });

  test('an empty message falls back', () {
    expect(
      humanMessage(failure('invalid-argument', '   '), fallback: 'Try again.'),
      'Try again.',
    );
  });
}
