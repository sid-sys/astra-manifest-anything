import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Every way into Astra, and the rules about moving between them.
///
/// The app is usable before anyone signs in — a guest gets an anonymous
/// account, which is a real Firebase user with a real uid and a real place to
/// sync to. That matters more than it sounds: because a guest already has a
/// uid, signing up later can *link* credentials onto that same account rather
/// than creating a second one, and the stories they wrote as a guest stay
/// theirs. Every path below that could link, does.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _injected = auth;

  final FirebaseAuth? _injected;

  /// Resolved on use rather than in the constructor, so that building the
  /// object is safe in a test or on a build where Firebase never started.
  /// Reaching for `FirebaseAuth.instance` before `initializeApp` throws, and
  /// that should happen when someone tries to sign in — not when a screen is
  /// laid out.
  FirebaseAuth get _auth => _injected ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authState() => _auth.authStateChanges();

  /// Whether the signed-in user is a guest — an anonymous account with nothing
  /// to sign back in with.
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  /// Restores an existing session without creating one.
  ///
  /// Deliberately not signing anyone in: the sign-in screen is the first thing
  /// a new user sees, and an app that quietly made an anonymous account at
  /// launch would have made the "Continue as guest" button a lie about a choice
  /// that had already been taken.
  User? restoreSession() {
    try {
      return _auth.currentUser;
    } catch (error) {
      debugPrint('Astra: no auth available, running local-only — $error');
      return null;
    }
  }

  // ------------------------------------------------------------------- guest

  Future<UserCredential> continueAsGuest() => _auth.signInAnonymously();

  // -------------------------------------------------------- email + password

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  /// Creates an account, upgrading the current guest in place when there is
  /// one so nothing they already made is stranded under an abandoned uid.
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );

    final guest = _auth.currentUser;
    if (guest != null && guest.isAnonymous) {
      try {
        return await guest.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        // The address already belongs to someone. Falling through to a plain
        // sign-in is right — it is their account — but it does mean the guest
        // work stays behind, which is why the UI warns before it gets here.
        if (error.code != 'email-already-in-use' &&
            error.code != 'credential-already-in-use' &&
            error.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }

    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends the reset link. Firebase hosts the page the link opens.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Completes a reset from the code in the emailed link.
  ///
  /// Only reachable when the app itself handles the action URL. With the
  /// default Firebase-hosted page the reset finishes in the browser and this
  /// is never called — it exists so switching to a custom action URL is a
  /// configuration change rather than a code change.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) => _auth.confirmPasswordReset(code: code, newPassword: newPassword);

  /// Changes the password of the signed-in user by emailing them a link.
  ///
  /// Not `updatePassword`: that needs a recent sign-in and fails with
  /// `requires-recent-login` often enough to be a bad button. The email round
  /// trip also proves the address still belongs to whoever is holding the
  /// phone.
  Future<void> sendPasswordResetForCurrentUser() async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'This account has no email address to send a link to.',
      );
    }
    await sendPasswordReset(email);
  }

  // -------------------------------------------------------------- federated

  Future<UserCredential> signInWithGoogle() =>
      _federated(GoogleAuthProvider()..addScope('email'));

  // Sign in with Apple is not offered. If this app is ever submitted to the App
  // Store while Google sign-in exists, Apple's guidelines require it — adding
  // it back is `_federated(AppleAuthProvider())` plus the Service ID and key in
  // the Apple developer portal.

  /// One path for every OAuth provider, on every platform.
  ///
  /// Web opens a popup; everything else hands off to the platform's own
  /// browser flow. Neither needs a provider-specific plugin, which is the
  /// reason this app has no `google_sign_in` dependency: firebase_auth already
  /// speaks both, and one code path cannot drift from the other.
  ///
  /// Links onto the current guest when there is one, for the same reason
  /// [signUpWithEmail] does.
  Future<UserCredential> _federated(AuthProvider provider) async {
    final guest = _auth.currentUser;

    if (guest != null && guest.isAnonymous) {
      try {
        return kIsWeb
            ? await guest.linkWithPopup(provider)
            : await guest.linkWithProvider(provider);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use' &&
            error.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }

    return kIsWeb
        ? _auth.signInWithPopup(provider)
        : _auth.signInWithProvider(provider);
  }

  Future<void> signOut() => _auth.signOut();
}

/// Turns a [FirebaseAuthException] into something worth showing someone.
///
/// Firebase's own messages leak implementation ("There is no user record
/// corresponding to this identifier") and, worse, distinguish a wrong password
/// from an unknown address — which tells anyone with a login form which of
/// your users exist. Both of those collapse into one message here.
String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }

  return switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'That email and password do not match.',
    'invalid-email' => 'That does not look like an email address.',
    'email-already-in-use' =>
      'There is already an account with that email. Try logging in.',
    'weak-password' => 'Use at least six characters.',
    'user-disabled' => 'That account has been disabled.',
    'too-many-requests' =>
      'Too many attempts. Wait a minute and try again.',
    'network-request-failed' =>
      'No connection. Check your network and try again.',
    'popup-closed-by-user' || 'web-context-canceled' || 'canceled' =>
      'Sign-in was cancelled.',
    'operation-not-allowed' =>
      'That sign-in method is not enabled for this app yet.',
    _ => 'Something went wrong. Please try again.',
  };
}
