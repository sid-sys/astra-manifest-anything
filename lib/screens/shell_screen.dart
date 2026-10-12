import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../demo/demo_data.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'affirmations_screen.dart';
import 'desire_flow_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'profile_screen.dart';

/// The four-tab frame.
///
/// There is no mini player. Playback lives and dies with the player screen —
/// closing it stops the audio, rather than tucking it into a bar that keeps
/// playing after the screen that owned it is gone.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _tab = 0;
  StreamSubscription<String>? _tokenRefresh;

  /// Which tab the demo asked for in the URL. Always 0 in a real build.
  static const _demoTabs = {
    'home': 0,
    'library': 1,
    'affirm': 2,
    'profile': 3,
  };

  @override
  void initState() {
    super.initState();

    if (Demo.on) {
      _tab = _demoTabs[Demo.screen] ?? 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDemoScreen());
    }

    // Re-registers this device for the morning push. Tokens rotate on
    // reinstall and restore, and a rotated token nobody told the server about
    // is a user whose reminders quietly stop arriving.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(refreshPushRegistration(ref));

      _tokenRefresh = ref
          .read(notificationServiceProvider)
          .tokenRefreshes
          .listen((token) {
            final profile = ref.read(profileProvider);
            if (!profile.remindersOn) return;
            unawaited(
              ref
                  .read(profileProvider.notifier)
                  .update(profile.copyWith(fcmToken: token)),
            );
          });
    });
  }

  /// The two screenshots that are not tabs: the four questions, and the player.
  ///
  /// Pushed after the first frame rather than routed to, because both sit on
  /// top of the shell in the real app — a screenshot of either one taken any
  /// other way would show a screen the user cannot actually reach from there.
  Future<void> _openDemoScreen() async {
    if (!mounted) return;

    switch (Demo.screen) {
      case 'questions':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DesireFlowScreen(desire: Demo.wish),
          ),
        );

      case 'player':
        final made = Demo.manifestations.first.asStory();
        await ref.read(playbackProvider).open(made);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
        );

    }
  }

  @override
  void dispose() {
    _tokenRefresh?.cancel();
    super.dispose();
  }

  // Nothing offers the plans here. Onboarding shows them itself, between
  // choosing an area of life and writing the first wish, and marks them seen
  // on the way past. Opening them again on arrival would be the second price
  // screen in a minute — and the app already knows the answer, because "Not
  // now" was one tap ago. After that the plans appear where they answer a
  // question: on the allowance card, and when the free stories run out.

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onLibrary: () => _goTo(1),
        onProfile: () => _goTo(3),
      ),
      // Writing starts on Home, and now only there. The old "New story" route
      // is gone with the story feature it belonged to.
      LibraryScreen(onWrite: () => _goTo(0)),
      const AffirmationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _tab, children: screens),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            // White, floating on the wash by shadow rather than divided from
            // it by a rule. A hairline across the bottom of a gradient reads
            // as a seam.
            decoration: BoxDecoration(
              // Opaque deep indigo, not the translucent card colour: a bar
              // that let the gradient through put pink behind the labels.
              color: AstraColors.canvasRaised,
              border: const Border(top: BorderSide(color: AstraColors.line)),
              boxShadow: AstraColors.liftedShadow,
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: AstraColors.accent.withValues(alpha: 0.22),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: states.contains(WidgetState.selected)
                        ? AstraColors.accent
                        : AstraColors.dim,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 21,
                    color: states.contains(WidgetState.selected)
                        ? AstraColors.accent
                        : AstraColors.dim,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _goTo,
                height: 72,
                elevation: 0,
                // Full colour when selected and larger; faded and smaller when
                // not. The pictures cannot be tinted, so fade is the only way
                // left to say "not this one".
                destinations: const [
                  NavigationDestination(
                    icon: AstraIcon('nav_home', size: 28, opacity: 0.55),
                    selectedIcon: AstraIcon('nav_home', size: 36),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: AstraIcon('nav_library', size: 28, opacity: 0.55),
                    selectedIcon: AstraIcon('nav_library', size: 36),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: AstraIcon('nav_affirm', size: 28, opacity: 0.55),
                    selectedIcon: AstraIcon('nav_affirm', size: 36),
                    label: 'Affirm',
                  ),
                  NavigationDestination(
                    icon: AstraIcon('nav_profile', size: 28, opacity: 0.55),
                    selectedIcon: AstraIcon('nav_profile', size: 36),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

