import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Signs the user in anonymously so their work has somewhere to sync to.
///
/// Anonymous sign-in is a convenience, not a gate: if it fails — the provider
/// is disabled in the console, or the device is offline — the app runs on
/// local storage alone and never blocks the user behind an account.
class AuthService {
  Future<String?> signInSilently() async {
    try {
      final auth = FirebaseAuth.instance;
      final existing = auth.currentUser;
      if (existing != null) return existing.uid;

      final credential = await auth.signInAnonymously();
      return credential.user?.uid;
    } catch (error) {
      debugPrint('Astra: anonymous sign-in unavailable, staying local — $error');
      return null;
    }
  }
}
