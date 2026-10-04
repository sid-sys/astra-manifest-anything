import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/manifest_service.dart';
import 'generating_screen.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';

/// Writes one manifestation and takes the user to it.
///
/// Home and the Manifest tab both start this, so the waiting screen, the
/// cancel, the paywall handoff and the error message are written once. Returns
/// true if something was made.
///
/// Takes a [navigator] and a [container] rather than a `BuildContext` and a
/// `WidgetRef`, for the same reason [weaveStory] does: this is called across
/// the moment the app decides a user is onboarded, and that swap disposes the
/// widget that started it. A `WidgetRef` belongs to that widget and throws the
/// instant it is gone. The navigator and the container both outlive it.
///
/// [dream] is optional. With one, the manifestation is about that; without, it
/// is written from the desire given during onboarding — which is what lets Home
/// be a single tap.
Future<bool> weaveManifestation(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  ProviderContainer container, {
  required String dream,

  /// Which onboarding answers to write from. Null means all of them.
  Set<String>? include,
}) async {
  // Cancelling closes the waiting screen and stops this function caring about
  // the result. It does not stop the server: the script is already written and
  // the audio already rendered by the time most people press it, so it is
  // allowed to finish and land in the list rather than being thrown away.
  var cancelled = false;

  final waiting = MaterialPageRoute<void>(
    builder: (_) => GeneratingScreen(
      onCancel: () {
        cancelled = true;
        navigator.pop();
      },
    ),
  );
  unawaited(navigator.push(waiting));

  try {
    final made = await container
        .read(manifestServiceProvider)
        .write(dream, include: include);

    // Refreshed before anything opens, so the list behind the player is
    // already right when the user comes back out of it.
    container.invalidate(manifestationsProvider);

    if (cancelled) return true;

    navigator.removeRoute(waiting);
    await container.read(playbackProvider).open(made.asStory());
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
      ),
    );
    return true;
  } on ManifestQuotaExceeded catch (error) {
    // Out of allowance, or not subscribed. Neither is a failure, so neither
    // gets an error — they get the plans.
    if (!cancelled) navigator.removeRoute(waiting);
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    return false;
  } on ManifestFailed catch (error) {
    if (!cancelled) navigator.removeRoute(waiting);
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  } catch (error) {
    if (cancelled) return false;
    navigator.removeRoute(waiting);
    debugPrint('Mayow: manifestation failed — $error');
    messenger.showSnackBar(
      const SnackBar(
        content: Text("That didn't come through. Try again in a moment."),
      ),
    );
    return false;
  }
}
