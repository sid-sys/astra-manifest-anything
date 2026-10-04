import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/affirmation_set.dart';
import 'callable_errors.dart';

/// Raised when the account is out of sets for the month, or has no plan.
class AffirmQuotaExceeded implements Exception {
  const AffirmQuotaExceeded(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Raised when a set could not be written. Carries the server's own sentence.
class AffirmFailed implements Exception {
  const AffirmFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Writes affirmation sets, and reads the ones already written.
///
/// The same shape as [ManifestService] on purpose: one goal typed by the user,
/// optionally coloured by whichever onboarding answers they left switched on.
/// The difference is what comes back — five lines of text and no audio, which
/// is why these are cheap enough to have a much larger monthly allowance.
class AffirmationService {
  AffirmationService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('affirmationSets');
  }

  /// Writes five, and returns them.
  ///
  /// [include] names which onboarding answers to write from. An empty set means
  /// none of them — written from the goal alone — and null means all of them.
  /// The two are deliberately distinct: collapsing them would make the toggle
  /// silently do the opposite of what it says.
  Future<AffirmationSet> write(
    String goal, {
    Set<String>? include,

    /// What the user picked from the four questions written for this desire.
    List<String>? answers,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'writeAffirmations',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call<Map<Object?, Object?>>({
            'goal': goal.trim(),
            if (include != null) 'include': include.toList(),
            'answers': ?answers,
          });

      return AffirmationSet.fromMap(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw AffirmQuotaExceeded(
          error.message ?? 'You have used this month\'s affirmations.',
        );
      }

      debugPrint('Mayow: affirmations failed — ${error.code} ${error.message}');
      throw AffirmFailed(
        humanMessage(
          error,
          fallback: 'Those did not come through. Try again in a moment.',
        ),
      );
    }
  }

  /// Everything this account has written, newest first.
  Future<List<AffirmationSet>> all() async {
    final collection = _collection;
    if (collection == null) return const [];

    // Not caught. An empty list and a denied read are different things, and
    // making them look the same is how a missing Firestore rule stayed hidden
    // through a whole release of the manifestations list.
    final snapshot = await collection
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => AffirmationSet.fromMap(doc.data()))
        .toList();
  }

  Future<void> delete(String id) async {
    try {
      await _collection?.doc(id).delete();
    } catch (error) {
      // Rethrown, not swallowed — see the same note on
      // ManifestService.delete.
      debugPrint('Mayow: could not delete an affirmation set — $error');
      rethrow;
    }
  }
}
