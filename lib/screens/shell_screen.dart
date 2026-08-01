import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/starfield.dart';
import 'affirmations_screen.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'paywall_screen.dart';
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

  /// Shows the plans once, immediately after onboarding.
  ///
  /// It is a route the user can dismiss, not a gate: the free day is the whole
  /// answer to the complaint that the app it is modelled on asked for money
  /// before anyone had heard anything. The seen flag is written before the
  /// screen opens, so a crash or a fast back-press cannot make it reappear.
  Future<void> _offerPlus() async {
    final profile = ref.read(profileProvider);
    if (profile.paywallSeen || profile.isSubscribed) return;

    await ref.read(profileProvider.notifier).markPaywallSeen();
    if (!mounted) return;

    await Navigator.of(context).push(
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
      HomeScreen(onCreate: _openCreate, onLibrary: () => _goTo(1)),
      LibraryScreen(onCreate: _openCreate),
      const AffirmationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Starfield(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _tab, children: screens),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AstraColors.inkRaised,
              border: Border(top: BorderSide(color: AstraColors.line)),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: AstraColors.gold.withValues(alpha: 0.12),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: states.contains(WidgetState.selected)
                        ? AstraColors.gold
                        : AstraColors.dim,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 21,
                    color: states.contains(WidgetState.selected)
                        ? AstraColors.gold
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

