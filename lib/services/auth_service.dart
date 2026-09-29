import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Every way into Maya, and the rules about moving between them.
///
/// Two doors now: an email and password, or Google. The anonymous "continue as
/// guest" door was removed. It cost nothing to walk through and that was the
/// problem — an anonymous account has no password, so the library it held lived
/// on one handset and a reinstall destroyed it with nobody able to return it.
/// A door that quietly forfeits everything you wrote is not a kindness.
///
/// The linking machinery below is kept rather than deleted, because accounts
/// created through that door still exist. Anyone still holding one can sign up
/// or sign in with Google and their stories move onto the credentialed account
/// instead of being stranded beside it.
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
      debugPrint('Maya: no auth available, running local-only — $error');
      return null;
    }
  }

  /// Ends a session whose account no longer exists, and says whether it did.
  ///
  /// Firebase keeps a signed-in user cached on the device and does not check
  /// with the server until the token needs refreshing, which can be an hour
  /// away. So an account deleted from the Console — or by `deleteAccount` on
  /// another phone — stays signed in here, and the app cheerfully routes on a
  /// user that is not there any more. What that looked like in practice was an
  /// app opening straight onto the paywall: a live-looking session, a profile
  /// still in local storage, and an entitlement lookup that could only ever
  /// come back empty.
  ///
  /// `reload` is the cheapest way to ask. It is one round trip on launch, and
  /// only on launch.
  ///
  /// Returns true when a dead session was dropped, so the caller can clear the
  /// device as well — the local profile outlives the account otherwise, and the
  /// next person to sign in inherits it.
  Future<bool> dropDeadSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
      return false;
    } on FirebaseAuthException catch (error) {
      const gone = {
        'user-not-found',
        'user-disabled',
        'user-token-expired',
        'invalid-user-token',
      };
      if (!gone.contains(error.code)) {
        // Offline, or any other transient failure. Keeping the session is the
        // right guess: signing people out because their train went into a
        // tunnel would be far worse than the bug this fixes.
        debugPrint('Maya: could not check the session — ${error.code}');
        return false;
      }

      debugPrint('Maya: signing out a dead session — ${error.code}');
      await _auth.signOut();
      return true;
    } catch (error) {
      debugPrint('Maya: could not check the session — $error');
      return false;
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

  /// Whether [GoogleSignIn.instance] has been initialised in this process.
  ///
  /// `initialize` is a one-time platform call, and the sign-in button can be
  /// pressed more than once.
  static bool _googleReady = false;

  /// Signs in with Google, natively on Android and through a popup on the web.
  ///
  /// Android does **not** use [FirebaseAuth.signInWithProvider] here, and that
  /// is the whole point of this method. That call opens Google in a Chrome
  /// Custom Tab and finishes the handshake by redirecting back through the
  /// project's `firebaseapp.com` page — a redirect that needs `sessionStorage`
  /// to survive the round trip. On a real device it does not, and every
  /// attempt died on Firebase's own page reading:
  ///
  ///     Unable to process request due to missing initial state. This may
  ///     happen if browser sessionStorage is inaccessible or accidentally
  ///     cleared.
  ///
  /// That flow is meant for providers with no native SDK — GitHub, Microsoft,
  /// Yahoo. Google has one, and the supported path on Android is to ask it for
  /// an identity token and hand that to Firebase, which is what happens below.
  /// No browser, no redirect, nothing to lose between hops.
  ///
  /// This is also the first thing in the app that the SHA-1 fingerprints
  /// actually matter to: Google checks the calling package against the
  /// certificate it was signed with before it will issue a token. The old
  /// browser flow never looked at them, which is why months of adding and
  /// removing fingerprints changed nothing.
  ///
  /// The web keeps the popup, which has no such problem — a popup shares
  /// storage with the page that opened it.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _federated(GoogleAuthProvider()..addScope('email'));
    }

    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      // No `serverClientId` passed on purpose. The Android plugin falls back
      // to the `default_web_client_id` string resource, which the Google
      // Services Gradle plugin generates from `google-services.json` — so the
      // id follows that file instead of being copied into source, where it
      // would quietly go stale the next time the file is downloaded.
      await google.initialize();
      _googleReady = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (error) {
      // Backing out of the account picker is not a failure, and must not be
      // shown as one. Everything else keeps Google's own description, which
      // names the real problem — a missing fingerprint says so outright.
      throw FirebaseAuthException(
        code: error.code == GoogleSignInExceptionCode.canceled
            ? 'canceled'
            : 'google-sign-in-failed',
        message: error.description ?? error.code.name,
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Reached when Google authenticated the user but would not vouch for
      // them to anyone else, which in practice means the web client id behind
      // `default_web_client_id` is missing or does not belong to this project.
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google signed in but returned no identity token.',
      );
    }

    return _withCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

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

  /// One path for a credential that already exists, guest-linking and all.
  ///
  /// Same shape as [_federated] and for the same reason — an anonymous account
  /// that signs in with Google should carry its stories onto the real account
  /// rather than be abandoned next to it.
  Future<UserCredential> _withCredential(AuthCredential credential) async {
    final guest = _auth.currentUser;

    if (guest != null && guest.isAnonymous) {
      try {
        return await guest.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use' &&
            error.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    // Google is signed out first and separately. Firebase forgetting the
    // session does not make Google forget which account was chosen, so without
    // this the next "Continue with Google" silently reuses the last account
    // and never shows the picker — which looks like the sign-out failed.
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        // Never block a sign-out on this. Not having been signed into Google
        // is the common case, and it throws.
        debugPrint('Maya: Google sign-out skipped — $error');
      }
    }

    await _auth.signOut();
  }
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
    'google-sign-in-failed' =>
      'Google could not sign you in. Try again, or use your email and '
          'password.',
    'unverified-email' =>
      'Check your inbox and click the link before signing in.',
    _ => 'Something went wrong. Please try again.',
  };
}
