import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/manifestation.dart';
import 'callable_errors.dart';

/// Raised when the account has used its manifestations for the month, or has
/// no subscription at all.
///
/// Its own type, like `StoryQuotaExceeded`, so the caller can show the plans
/// rather than an error — being out of allowance is not a failure.
class ManifestQuotaExceeded implements Exception {
  const ManifestQuotaExceeded(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Raised when a manifestation could not be written or narrated.
///
/// Carries the server's own sentence rather than the exception. Everything the
/// server refuses for has a reason it can state plainly, and none of those
/// reasons are improved by a stack trace on the user's screen.
class ManifestFailed implements Exception {
  const ManifestFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Writes manifestations, and reads the ones already written.
///
/// One server call does everything: the script and the narration come back
/// together. Stories split those in two because a story's text is worth reading
/// while the audio records; a manifestation is four hundred words that only
/// make sense spoken, so there is nothing to show in between.
class ManifestService {
  ManifestService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('manifestations');
  }

  /// Writes one, narrated and stored, and returns it ready to play.
  ///
  /// Slow — the script and an ElevenLabs render, back to back — so the timeout
  /// is generous. A caller that gave up early would leave the user paying for
  /// audio they never heard.
  Future<Manifestation> write(
    String dream, {
    /// Which onboarding answers to write from. Null means all of them.
    Set<String>? include,

    /// What the user picked from the four questions written for this desire.
    /// The stronger signal by far — given seconds ago, about this wish — so
    /// the brief puts them ahead of anything left from onboarding.
    List<String>? answers,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'writeManifest',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
          )
          .call<Map<Object?, Object?>>({
            'dream': dream.trim(),
            if (include != null) 'include': include.toList(),
            'answers': ?answers,
          });

      return Manifestation.fromMap(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw ManifestQuotaExceeded(
          error.message ?? 'You have used this month\'s manifestations.',
        );
      }
      debugPrint('Maya: manifest failed — ${error.code} ${error.message}');

      // The server writes a plain sentence for every case it understands.
      // Passing that through beats rethrowing, which reaches the screen as
      // `[firebase_functions/internal] INTERNAL` over eight frames of Flutter
      // stack — a wall of text that tells the user nothing and tells me only
      // what the logs already say.
      throw ManifestFailed(
        humanMessage(
          error,
          fallback: 'That one did not come through. Try again in a moment.',
        ),
      );
    }
  }

  /// Everything this account has written, newest first.
  ///
  /// Read straight from Firestore rather than cached on the device. They are
  /// few — ten a month at most — and always fetched fresh means a phone that
  /// has been signed out cannot show a stale or a previous account's list.
  Future<List<Manifestation>> all() async {
    final collection = _collection;
    if (collection == null) return const [];

    try {
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => Manifestation.fromMap(doc.data()))
          .toList();
    } catch (error) {
      // Rethrown, not swallowed. Returning an empty list here made a denied
      // read look exactly like an empty library — which is how a missing
      // Firestore rule hid for a whole release. The screen has an error state;
      // let it use it.
      debugPrint('Maya: could not read manifestations — $error');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final collection = _collection;
    if (collection == null) return;

    try {
      await collection.doc(id).delete();
    } catch (error) {
      // Rethrown, not swallowed. Silently eating this made a denied or
      // failed delete look exactly like a successful one: the item stayed in
      // the list with no explanation, and it looked like the app had simply
      // ignored the tap.
      debugPrint('Maya: could not delete a manifestation — $error');
      rethrow;
    }
  }
}
