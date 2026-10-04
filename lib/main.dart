import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'demo/demo_data.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'services/astra_repository.dart';
import 'services/auth_service.dart';
import 'services/maya_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Gives the player a lock-screen/notification-center card with play and
  // pause, and lets it keep playing with the app backgrounded.
  //
  // Talks to `audio_service` directly rather than through
  // `just_audio_background` — see [MayaAudioHandler] for why: that package
  // hard-caps the app at one `AudioPlayer`, and this app always runs two.
  // [PlaybackController] reads the global `mayaAudioHandler` defensively, so
  // a platform without the pieces for this still gets a fully working
  // player, just without the notification.
  try {
    mayaAudioHandler = await AudioService.init(
      builder: MayaAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.astraapp.astra.playback',
        androidNotificationChannelName: 'Mayow playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (error) {
    debugPrint('Mayow: notification playback controls unavailable — $error');
  }

  final prefs = await SharedPreferences.getInstance();

  // A furnished account with no server behind it, for store screenshots.
  //
  // Off unless the app was started with `--dart-define=ASTRA_DEMO=true`, so it
  // cannot reach a Play build: the flag is typed at a terminal by hand and the
  // release bundle is built without it.
  //
  // Firebase is skipped entirely rather than signed into. That is not a
  // shortcut — it is the same path the app already takes when Firebase cannot
  // start, so the demo runs through code that ships rather than through a
  // branch invented for it. See [AstraApp]: no Firebase means no account
  // question, straight to the app.
  if (Demo.on) {
    await AstraRepository(prefs).clearLocal();
    await runDemo(prefs);
    return;
  }

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
    final auth = AuthService();
    auth.restoreSession();

    // And drops it again if the account behind it is gone. Awaited, because
    // the first frame routes on whether somebody is signed in, and answering
    // that question wrongly for a second sends the user to the wrong screen.
    if (await auth.dropDeadSession()) {
      // The account is gone; its answers must not outlive it on this device,
      // or the next person to sign in here inherits them.
      await AstraRepository(prefs).clearLocal();
    }
  } catch (error) {
    debugPrint('Mayow: Firebase unavailable, running local-only — $error');
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

/// Starts the app on [Demo] content, with nothing behind it.
///
/// Everything here is an override rather than a fork in the app's own code, so
/// no screen knows it is in demo mode and none of them can behave differently
/// because of it. What is on screen is what a real account with this much
/// writing in it would show.
Future<void> runDemo(SharedPreferences prefs) async {
  final repository = AstraRepository(prefs);

  // Written to storage rather than overridden, because these two are held by
  // notifiers that load from the repository at construction — an override
  // would be replaced by the first save the app makes.
  await repository.saveProfile(Demo.profile);
  await repository.saveStories(Demo.stories);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // No Firebase. The app already handles this — it is the offline path.
        firebaseReadyProvider.overrideWithValue(false),

        // These three read Firestore and would come back empty with no
        // account, which is exactly the empty app the screenshots are for
        // avoiding.
        manifestationsProvider.overrideWith((ref) async => Demo.manifestations),
        affirmationSetsProvider.overrideWith((ref) async => Demo.affirmationSets),

        // Paid, so the allowance card shows a real number and Continue opens
        // the questions instead of the price.
        isSubscribedProvider.overrideWithValue(true),

        // The one server call between typing a wish and seeing the four
        // questions.
        planServiceProvider.overrideWithValue(const DemoPlanService()),
      ],
      child: const AstraApp(),
    ),
  );
}
