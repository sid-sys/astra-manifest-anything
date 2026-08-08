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
/// Home, Create and the last step of onboarding all start this, so the waiting
/// screen, the paywall handoff and the error message are written once. Returns
/// true if a story was made.
///
/// Takes a [navigator] rather than a `BuildContext` because onboarding calls it
/// across the moment the app decides the user is onboarded: saving the profile
/// swaps the whole home widget out, so the context that started this is gone
/// before the story comes back. The navigator outlives that swap; a context
/// does not.
Future<bool> weaveStory(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  WidgetRef ref, {
  required Intention intention,
  required String scene,
}) async {
  // Ask for money before spending a minute of the user's time, not after —
  // and never before they have heard anything at all, which is what the first
  // free story is for.
  final written = ref.read(storiesProvider).length;
  if (!ref.read(profileProvider).canGenerate(storiesWritten: written)) {
    final unlocked = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (unlocked != true) return false;
  }

  final waiting = MaterialPageRoute<void>(
    builder: (_) => const GeneratingScreen(),
  );
  unawaited(navigator.push(waiting));

  final composer = ref.read(storyComposerProvider);

  try {
    final story = await composer.compose(intention: intention, scene: scene);

    // Straight to the story the moment the words exist. The narration is still
    // recording; it attaches itself to the open player when it lands.
    navigator.removeRoute(waiting);
    ref.read(playbackProvider).load(story);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
      ),
    );
    unawaited(composer.narrate(story));
    return true;
  } on StoryQuotaExceeded catch (error) {
    // The server holds the real clock, so its refusal overrides whatever the
    // local profile believed a moment ago.
    navigator.removeRoute(waiting);
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    return false;
  } catch (error) {
    navigator.removeRoute(waiting);
    messenger.showSnackBar(
      SnackBar(
        content: Text("That story didn't come through. Try again — $error"),
      ),
    );
    return false;
  }
}
