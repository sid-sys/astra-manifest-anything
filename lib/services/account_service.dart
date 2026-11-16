import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'astra_repository.dart';

/// Signing out and deleting, which are different promises.
///
/// Signing out leaves the cloud copy where it is; deleting removes it. Both
/// clear the device, because a device that still holds the stories of an
/// account nobody is signed into is the worst of both. Neither signs anyone
/// back in — the sign-in screen appears on its own the moment the auth stream
/// reports nobody, and choosing what to do next is the user's.
class AccountService {
  AccountService(this._repository, {FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'asia-south1');

  final AstraRepository _repository;
  final FirebaseFunctions _functions;

  /// Whether there is an account at all. False when Firebase never started, in
  /// which case nothing was ever synced and there is nothing to sign out of.
  bool get hasAccount => _repository.uid != null;

  /// Ends the session.
  ///
  /// Mayow signs people in anonymously, which makes this one-way: an anonymous
  /// account has no password, no email and no second device to get back in
  /// from, so signing out abandons the cloud copy rather than parking it. The
  /// confirmation screen has to say so — this method is not the place to
  /// soften it.
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      // Nothing to sign out of, or Firebase never started. The local wipe the
      // caller does next is the part the user actually asked for.
      debugPrint('Mayow: sign-out failed, clearing this device anyway — $error');
    }
  }

  /// Erases the account and everything under it, everywhere.
  ///
  /// The work happens in a Cloud Function: audio, Firestore documents and the
  /// auth user are all deleted with credentials the app does not hold and
  /// should not. Throws if that call fails, so the caller can tell the user
  /// their data is still there rather than showing a success screen over a
  /// failed delete.
  Future<void> deleteEverything() async {
    // Apple's rule: deleting an account that signed in with Apple must also
    // cancel Apple's sign-in token. It goes first, while the user still
    // exists, and a failure stops the delete so nothing is half done.
    await _revokeAppleIfNeeded();

    if (hasAccount) {
      await _functions
          .httpsCallable(
            'deleteAccount',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
          )
          .call<Map<String, dynamic>>();
    }

    // The auth user is gone at this point; this clears the local session that
    // still remembers it.
    await signOut();
  }

  /// Cancels the Apple sign-in token for an account that uses Apple.
  ///
  /// Firebase keeps no Apple token, so the user is asked to confirm with Apple
  /// once more. That gives a fresh authorization code, which Firebase then
  /// sends to Apple to revoke. Does nothing for any other kind of account.
  Future<void> _revokeAppleIfNeeded() async {
    if (kIsWeb) return;
    final user = FirebaseAuth.instance.currentUser;
    final usesApple =
        user?.providerData.any((info) => info.providerId == 'apple.com') ??
        false;
    if (user == null || !usesApple) return;

    final fresh = await user.reauthenticateWithProvider(
      AppleAuthProvider()..addScope('email'),
    );
    final code = fresh.additionalUserInfo?.authorizationCode;
    if (code == null || code.isEmpty) {
      throw FirebaseAuthException(
        code: 'apple-revoke-failed',
        message: 'Apple gave no authorization code.',
      );
    }
    await FirebaseAuth.instance.revokeTokenWithAuthorizationCode(code);
  }
}
