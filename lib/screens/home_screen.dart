import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/affirmations.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import 'player_screen.dart';

/// The daily ritual: tonight's story, today's affirmation, and the evidence
/// that the practice is adding up.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onCreate, required this.onLibrary});

  final VoidCallback onCreate;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final daily = ref.watch(dailyStoryProvider);
    final streak = ref.watch(streakProvider);
    final storyCount = ref.watch(storiesProvider).length;
    final minutes = ref.watch(minutesListenedProvider);
    final journalCount = ref.watch(journalProvider).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Expanded(child: Wordmark('Astra', align: TextAlign.left)),
            if (streak > 0)
              TagChip(label: '🔥  $streak-day streak', selected: true),
          ],
        ),
        const SizedBox(height: AstraSpacing.lg),
        Text(
          '${_greeting()}, ${profile.name}',
          style: AstraTextStyles.display(28),
        ),
        const SizedBox(height: AstraSpacing.xl),

        if (daily != null)
          AstraCard(
            raised: true,
            onTap: () => _openPlayer(context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TONIGHT'S STORY", style: AstraTextStyles.eyebrow),
                const SizedBox(height: AstraSpacing.sm),
                Text(daily.title, style: AstraTextStyles.label.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  '${daily.durationLabel} · written for your '
                  '${daily.intention.label.toLowerCase()} intention',
                  style: AstraTextStyles.small,
                ),
                const SizedBox(height: AstraSpacing.md),
                AstraButton(
                  label: 'Listen',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _openPlayer(context, ref),
                ),
              ],
            ),
          )
        else
          AstraCard(
            raised: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR FIRST STORY', style: AstraTextStyles.eyebrow),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  'Nothing written yet',
                  style: AstraTextStyles.label.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'It takes about a minute, and this one is free.',
                  style: AstraTextStyles.small,
                ),
                const SizedBox(height: AstraSpacing.md),
                AstraButton(
                  label: 'Weave my first story',
                  icon: Icons.auto_awesome,
                  onPressed: onCreate,
                ),
              ],
            ),
          ),

        const SizedBox(height: AstraSpacing.md),
        AstraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Affirmation of the day', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                '“${Affirmations.forDay(DateTime.now(), profile.intentions)}”',
                style: AstraTextStyles.quote,
              ),
            ],
          ),
        ),

        const SizedBox(height: AstraSpacing.md),
        Row(
          children: [
            Expanded(child: _Stat(label: 'Stories', value: '$storyCount')),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(child: _Stat(label: 'Minutes', value: '$minutes')),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(child: _Stat(label: 'Journal', value: '$journalCount')),
          ],
        ),

        if (storyCount > 1) ...[
          const SizedBox(height: AstraSpacing.md),
          AstraGhostButton(label: 'Open your library', onPressed: onLibrary),
        ],
      ],
    );
  }

  void _openPlayer(BuildContext context, WidgetRef ref) {
    final stories = ref.read(storiesProvider);
    if (stories.isEmpty) return;

    ref
        .read(playbackProvider)
        .play(stories.first, queue: stories.skip(1).toList());
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AstraCard(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        Text(label, style: AstraTextStyles.small),
        const SizedBox(height: 2),
        Text(
          value,
          style: AstraTextStyles.price.copyWith(fontSize: 19),
        ),
      ],
    ),
  );
}
