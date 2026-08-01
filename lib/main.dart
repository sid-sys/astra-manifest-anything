import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final prefs = await SharedPreferences.getInstance();

  // Firebase is used for backup and sync only. If it can't start — no network,
  // a misconfigured build — the app still runs entirely on local storage.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    // Restores an existing session; it never creates one. A launch that
    // silently made an anonymous account would have taken the choice the
    // sign-in screen is about to offer.
    AuthService().restoreSession();
  } catch (error) {
    debugPrint('Astra: Firebase unavailable, running local-only — $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const AstraApp(),
    ),
  );
}
