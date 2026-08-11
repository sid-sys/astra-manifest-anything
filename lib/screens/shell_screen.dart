import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';
import 'affirmations_screen.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
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

  @override
  void initState() {
    super.initState();

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

  /// Create is a route rather than a tab. Home already takes a wish in one
  /// line, so the full set of knobs is the exception, not the main path.
  void _openCreate() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CreateRoute()),
  );

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onCreate: _openCreate,
        onLibrary: () => _goTo(1),
        onProfile: () => _goTo(3),
      ),
      LibraryScreen(onCreate: _openCreate),
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
              color: AstraColors.card,
              boxShadow: AstraColors.liftedShadow,
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: AstraColors.accent.withValues(alpha: 0.12),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w600
                        : FontWeight.w400,
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
                height: 64,
                elevation: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.nights_stay_outlined),
                    selectedIcon: Icon(Icons.nights_stay),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite),
                    label: 'Affirm',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
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

