import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/story.dart';
import '../providers.dart';
import '../services/affirmations.dart';
import '../services/wish_prompts.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/streak_card.dart';
import 'create_screen.dart';
import 'player_screen.dart';
import 'story_flow.dart';

/// The daily ritual: today's story, a box to ask for a new one, everything
/// made so far, and the evidence that the practice is adding up.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onCreate, required this.onLibrary});

  final VoidCallback onCreate;
  final VoidCallback onLibrary;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _wishController = TextEditingController();
  late String _suggestion;
  bool _weaving = false;

  @override
  void initState() {
    super.initState();
    _suggestion = WishPrompts.next(_intention);
  }

  @override
  void dispose() {
    _wishController.dispose();
    super.dispose();
  }

  Intention get _intention {
    final chosen = ref.read(profileProvider).intentions;
    return chosen.isEmpty ? Intention.career : chosen.first;
  }

  /// The one-line path: type a wish, get a story. Length, voice and mood keep
  /// their defaults, and Create exists for anyone who wants to set them.
  Future<void> _weaveFromWish() async {
    final wish = _wishController.text.trim();
    if (wish.isEmpty || _weaving) return;

    setState(() => _weaving = true);

    final made = await weaveStory(
      context,
      ref,
      intention: _intention,
      scene: wish,
    );

    if (!mounted) return;
    if (made) _wishController.clear();
    setState(() => _weaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final stories = ref.watch(storiesProvider);
    final daily = ref.watch(dailyStoryProvider);
    final streak = ref.watch(streakProvider);
    final minutes = ref.watch(minutesListenedProvider);
    final keptCount = ref.watch(tasteProvider).liked.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Wordmark('Astra', align: TextAlign.left),
        const SizedBox(height: AstraSpacing.lg),
        Text(
          "Let's manifest, ${profile.name}",
          style: AstraTextStyles.display(28),
        ),
        const SizedBox(height: AstraSpacing.xl),

        if (daily != null)
          AstraCard(
            raised: true,
            onTap: () => _open(daily),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TODAY'S MOMENT", style: AstraTextStyles.eyebrow),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  daily.title,
                  style: AstraTextStyles.label.copyWith(fontSize: 16),
                ),
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
                  onPressed: () => _open(daily),
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
                  'Say what you want below and Astra writes it. '
                  'Your first day is free.',
                  style: AstraTextStyles.small,
                ),
              ],
            ),
          ),

        const SizedBox(height: AstraSpacing.md),

        WishField(
          controller: _wishController,
          label: 'What do you want to manifest today?',
          suggestion: _suggestion,
          onRotate: () => setState(() {
            _suggestion = WishPrompts.next(_intention, previous: _suggestion);
          }),
        ),
        const SizedBox(height: AstraSpacing.md),
        AstraButton(
          label: _weaving ? 'Writing…' : 'Generate',
          icon: Icons.auto_awesome,
          busy: _weaving,
          onPressed: _weaveFromWish,
        ),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          'Five minutes, narrated by an AI voice in your own words.',
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.sm),
        AstraGhostButton(label: 'More options', onPressed: widget.onCreate),

        if (stories.isNotEmpty) ...[
          const SizedBox(height: AstraSpacing.xl),
          Row(
            children: [
              Expanded(child: Text('Your stories', style: AstraTextStyles.label)),
              GestureDetector(
                onTap: widget.onLibrary,
                child: Text('See all', style: AstraTextStyles.small),
              ),
            ],
          ),
          const SizedBox(height: AstraSpacing.sm),
          for (final story in stories.take(4)) ...[
            _StoryRow(story: story, onTap: () => _open(story)),
            const SizedBox(height: AstraSpacing.sm),
          ],
        ],

        const SizedBox(height: AstraSpacing.md),
        AstraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Affirmation of the day', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                '“${Affirmations.forDay(DateTime.now(), profile.intentions, ref.watch(tasteProvider))}”',
                style: AstraTextStyles.quote,
              ),
            ],
          ),
        ),

        const SizedBox(height: AstraSpacing.md),
        StreakCard(
          streak: streak,
          week: ref.watch(weekActivityProvider),
          name: profile.name,
          since: profile.joinedAt,
        ),

        const SizedBox(height: AstraSpacing.md),
        Row(
          children: [
            Expanded(child: _Stat(label: 'Stories', value: '${stories.length}')),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(child: _Stat(label: 'Minutes', value: '$minutes')),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(child: _Stat(label: 'Kept', value: '$keptCount')),
          ],
        ),
      ],
    );
  }

  /// Plays [story] with everything else queued behind it, so the player never
  /// runs dry at the end of one track.
  void _open(Story story) {
    final stories = ref.read(storiesProvider);
    ref
        .read(playbackProvider)
        .play(story, queue: stories.where((s) => s.id != story.id).toList());
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
    );
  }
}

/// One story in the home list. Tapping it plays it.
class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AstraCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Text(
          story.intention.glyph,
          style: TextStyle(fontSize: 18, color: story.intention.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.title,
                style: AstraTextStyles.body.copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${story.durationLabel} · ${story.intention.label}',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        if (story.favorite)
          const Icon(Icons.favorite, size: 15, color: AstraColors.gold),
        const SizedBox(width: 8),
        const Icon(
          Icons.play_circle_outline_rounded,
          color: AstraColors.gold,
          size: 26,
        ),
      ],
    ),
  );
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
        Text(value, style: AstraTextStyles.price.copyWith(fontSize: 19)),
      ],
    ),
  );
}
