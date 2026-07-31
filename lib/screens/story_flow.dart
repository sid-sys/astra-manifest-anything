import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../services/story_service.dart';
import 'generating_screen.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';

/// Generates a story and takes the user to it.
///
/// Home and Create both start this, so the waiting screen, the paywall
/// handoff and the error message are written once. Returns true if a story was
/// made.
Future<bool> weaveStory(
  BuildContext context,
  WidgetRef ref, {
  required Intention intention,
  required String scene,
  String mood = 'Calm',
  Duration length = const Duration(minutes: 7),
  String? voice,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  // Ask for money before spending a minute of the user's time, not after.
  if (!ref.read(profileProvider).canGenerateFreely) {
    final subscribed = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (subscribed != true) return false;
  }

  final waiting = MaterialPageRoute<void>(
    builder: (_) => const GeneratingScreen(),
  );
  unawaited(navigator.push(waiting));

  try {
    final story = await ref
        .read(storyComposerProvider)
        .compose(
          intention: intention,
          scene: scene,
          mood: mood,
          length: length,
          voice: voice,
        );

    navigator.removeRoute(waiting);
    ref.read(playbackProvider).play(story);
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => const PlayerScreen())),
    );
    return true;
  } on StoryQuotaExceeded catch (error) {
    // The server holds the real clock, so its refusal overrides whatever the
    // local profile believed a moment ago.
    navigator.removeRoute(waiting);
    await ref.read(profileProvider.notifier).noteTrialOver();
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    return false;
  } catch (error) {
    navigator.removeRoute(waiting);
    messenger.showSnackBar(
      SnackBar(content: Text("That story didn't come through. Try again — $error")),
    );
    return false;
  }
}
