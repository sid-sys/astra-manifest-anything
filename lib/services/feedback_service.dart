import 'package:cloud_functions/cloud_functions.dart';

import '../app_build.dart';

/// Sends a note or a bug report to the person who runs Mayow.
class FeedbackService {
  FeedbackService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Throws [FirebaseFunctionsException] with a plain message when refused.
  Future<void> send({required String text, required bool bug}) async {
    await _functions.httpsCallable('submitFeedback').call<Object?>({
      'text': text.trim(),
      'kind': bug ? 'bug' : 'feedback',
      'appBuild': kAppBuild,
    });
  }
}
