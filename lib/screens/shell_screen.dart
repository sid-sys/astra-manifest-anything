import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/starfield.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'journal_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'profile_screen.dart';

/// The five-tab frame, with a mini player docked above the bar whenever
/// something is loaded so playback survives navigation.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _tab = 0;

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);

    final screens = [
      HomeScreen(onCreate: () => _goTo(2), onLibrary: () => _goTo(1)),
      LibraryScreen(onCreate: () => _goTo(2)),
      const CreateScreen(),
      const JournalScreen(),
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
          if (playback.state.hasStory) const _MiniPlayer(),
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
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: 'Create',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'Journal',
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

class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final story = playback.state.story!;

    return Material(
      color: AstraColors.card,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
        ),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: playback.state.progress,
              minHeight: 2,
              backgroundColor: AstraColors.line,
              valueColor: const AlwaysStoppedAnimation(AstraColors.gold),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    story.intention.glyph,
                    style: TextStyle(color: story.intention.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      story.title,
                      style: AstraTextStyles.body.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      playback.state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AstraColors.gold,
                    ),
                    onPressed: playback.toggle,
                    tooltip: playback.state.playing ? 'Pause' : 'Play',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
