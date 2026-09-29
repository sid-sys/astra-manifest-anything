import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Tells the server what people do in the app, so the admin panel can show
/// where they stop.
///
/// Fire and forget: a failed report is dropped, never shown, and never allowed
/// to slow down or break the screen that made it.
class TrackingService {
  TrackingService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<void> log(
    String event, {
    String? wish,
    String? detail,
    bool? trialShown,
    bool? storeAnswered,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      await _functions.httpsCallable('trackEvent').call<Object?>({
        'event': event,
        'wish': ?wish,
        'detail': ?detail,
        'trialShown': ?trialShown,
        'storeAnswered': ?storeAnswered,
      });
    } catch (error) {
      debugPrint('Maya: could not report $event — $error');
    }
  }
}
