import 'package:cloud_functions/cloud_functions.dart';

/// Codes whose message was written for a person to read.
///
/// The server raises these deliberately and puts a plain sentence in them —
/// "Tell Maya what you want, in your own words", "You have used this month's
/// manifestations". Those are worth showing exactly as written.
const _spoken = {
  'invalid-argument',
  'resource-exhausted',
  'failed-precondition',
  'permission-denied',
  'unauthenticated',
  'not-found',
};

/// The sentence to put on screen for a failed callable.
///
/// Every other code — `internal`, `unknown`, `unavailable`, `deadline-exceeded`
/// — carries a message that is not a message. It is the code again, shouted:
/// the user gets a screen reading "That did not work / INTERNAL", which tells
/// them nothing they cannot already see and tells me nothing the logs do not
/// already have.
///
/// It happened for real. A rejected request schema took down every
/// manifestation and every affirmation, and the only thing the app could say
/// about it was the word INTERNAL. The fix for the schema was one line; the
/// reason it was hard to find was this.
String humanMessage(
  FirebaseFunctionsException error, {
  required String fallback,
}) {
  final message = error.message?.trim() ?? '';
  if (message.isEmpty) return fallback;
  if (!_spoken.contains(error.code)) return fallback;
  return message;
}
