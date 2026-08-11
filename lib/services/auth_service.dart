import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Every way into Astra: an email and password, or a Google account.
///
/// Guest accounts are gone. They were the friendliest door in the app and they
/// cost the thing the app is for — a library with no email attached lives and
/// dies with one phone, so a guest who changed handset lost every story they
/// had written, silently, with no way to get them back and nothing we could do
/// about it. An account is the only way the promise "your stories follow you"
/// is true.
///
/// The linking code below survives on purpose: an anonymous user created
/// before this change still has stories, and signing in on top of that account
/// keeps them rather than stranding them under an abandoned uid.
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

  /// Whether this account is waiting on an unclicked verification link.
  ///
  /// Only password accounts are ever in this state. Google hands back an
  /// address it has already verified, and a guest has no address at all —
  /// holding either of them at a "check your inbox" screen would be asking
  /// them to confirm something nobody doubts.
  static bool needsVerification(User? user) {
    if (user == null || user.isAnonymous || user.emailVerified) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  bool get isVerificationPending => needsVerification(_auth.currentUser);

  /// Sends the verification link. Safe to call again — Firebase rate-limits it
  /// itself, which is what the `too-many-requests` message is for.
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Re-reads the account from the server and returns true once the link has
  /// been clicked.
  ///
  /// `emailVerified` is a property of the cached user object, so it stays false
  /// on this device until something asks. The token is force-refreshed on
  /// success because the server checks the `email_verified` claim inside it,
  /// and a stale token would keep saying no long after the user said yes.
  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return false;

    await refreshed.getIdToken(true);
    return true;
  }

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

  // -------------------------------------------------------- email + password

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  /// Creates an account, upgrading the current guest in place when there is
  /// one so nothing they already made is stranded under an abandoned uid.
  ///
  /// Sends the verification link on the way out. The address is unproven until
  /// someone clicks it, and an unproven address is a password reset sent to a
  /// stranger's inbox.
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final result = await _createOrLink(email, password);
    await sendVerificationEmail();
    return result;
  }

  Future<UserCredential> _createOrLink(String email, String password) async {
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
    'unverified-email' =>
      'Check your inbox and click the link before signing in.',
    _ => 'Something went wrong. Please try again.',
  };
}
