import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';
import 'affirmations_screen.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'paywall_screen.dart';
import 'proof_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerPlus());
  }

  /// Shows the plans once, after the first story rather than before it.
  ///
  /// The timing is the whole point. Onboarding ends inside the player, so this
  /// waits until that route is closed — pushing a price over a story someone
  /// is still reading is how the app this one is modelled on earned its
  /// reviews. Once they are back on Home, they have heard the thing and the
  /// question "is this worth paying for" is one they are actually asking.
  ///
  /// It is a route, not a gate: "Not now" keeps the free plan and the
  /// remaining free stories. The seen flag is written before the screen opens,
  /// so a crash or a fast back-press cannot make it reappear.
  Future<void> _offerPlus() async {
    if (!mounted) return;

    final profile = ref.read(profileProvider);
    if (profile.paywallSeen || profile.isSubscribed) return;

    // Nothing to sell to someone who has not seen what it makes yet.
    if (ref.read(storiesProvider).isEmpty) return;

    // The player is still open on top of the shell. Try again when it closes.
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return _offerPlus();
    }

    await ref.read(profileProvider.notifier).markPaywallSeen();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (ProofScreen.hasProof) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ProofScreen(onContinue: () => navigator.pop()),
        ),
      );
      if (!mounted) return;
    }

    await navigator.push(
      MaterialPageRoute<bool>(builder: (_) => const PaywallScreen()),
    );
  }

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

