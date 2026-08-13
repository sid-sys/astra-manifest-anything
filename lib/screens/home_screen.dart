import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/story.dart';
import '../models/story_preferences.dart';
import '../providers.dart';
import '../services/trending_manifestations.dart';
import '../services/wish_prompts.dart';
import '../theme/astra_theme.dart';
import '../widgets/allowance_ring.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/streak_card.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';
import 'profile_screen.dart';
import 'story_flow.dart';

/// The daily ritual, arranged as one question.
///
/// Everything above the fold serves a single ask — the question, the box, and
/// a row of things other people are asking for. The library, the streak and
/// the stats live below it, because they are evidence that the practice is
/// working rather than the thing you came to do.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.onCreate,
    required this.onLibrary,
    required this.onProfile,
  });

  final VoidCallback onCreate;
  final VoidCallback onLibrary;
  final VoidCallback onProfile;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _wishController = TextEditingController();
  late String _suggestion;
  bool _weaving = false;

  /// What today's story is about. Resets to the main storyline every launch,
  /// because "continue where we were" is the answer nearly every day and the
  /// other two are deliberate choices.
  StoryFocus _focus = StoryFocus.desire;

  /// Whether the moment box is open. Closed by default — the whole point is
  /// that a story costs one tap, and a text field sitting open is a text field
  /// that looks like it has to be filled in.
  bool _addingMoment = false;

  /// Set when a trending chip is tapped, so the story is written against that
  /// chip's intention rather than the user's default one — tapping "Marry her"
  /// under a Career profile should still produce a love story.
  Intention? _chipIntention;

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

  /// Today's story: one tap, with the moment optional.
  ///
  /// The box used to be required — every story started by retyping a desire
  /// the app already had written down. Now onboarding does that work once, and
  /// this is a button. What the field adds is today: "we went to the movies",
  /// "she called me", which the generator lays on top of the same life.
  Future<void> _weaveToday() async {
    if (_weaving) return;

    setState(() => _weaving = true);

    final made = await weaveStory(
      Navigator.of(context),
      ScaffoldMessenger.of(context),
      ProviderScope.containerOf(context),
      intention: _chipIntention ?? _intention,
      scene: _wishController.text.trim(),
      focus: _focus,
    );

    if (!mounted) return;
    if (made) {
      _wishController.clear();
      _chipIntention = null;
    }
    setState(() => _weaving = false);
  }

  /// Fills the box rather than generating immediately.
  ///
  /// A chip that spent a story on one tap would be a trap next to a text field
  /// — the user gets to read it, edit it, and press the button themselves.
  void _useTrending(TrendingWish trending) {
    setState(() {
      _wishController.text = trending.wish;
      _chipIntention = trending.intention;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final stories = ref.watch(storiesProvider);
    final streak = ref.watch(streakProvider);
    final minutes = ref.watch(minutesInLibraryProvider);
    final keptCount = ref.watch(tasteProvider).liked.length;
    final trending = TrendingManifestations.forDay(
      DateTime.now(),
      profile.intentions,
    );

    // The list pads nothing horizontally: the trending row and the story row
    // run to both edges so a card sitting half off-screen advertises the swipe.
    // Everything else asks for the inset it wants.
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        // Wordmark alone. The avatar and the two icons that were here — a
        // heart to favourites, a clock to the library — all pointed at places
        // the nav bar and the Profile tab already reach. Three ways to the
        // same screen is not three features.
        const _Inset(child: Wordmark('Astra', align: TextAlign.left)),
        const SizedBox(height: AstraSpacing.xxl),

        // The daily ritual, in one object: open, choose or don't, generate,
        // read. A story that arrived by itself every morning would be a
        // notification; a story you press a button for is something you came
        // to do.
        _Inset(
          child: _TodayCard(
            name: profile.name,
            focus: _focus,
            busy: _weaving,
            controller: _wishController,
            momentOpen: _addingMoment,
            hint: _suggestion,
            onFocus: (focus) => setState(() => _focus = focus),
            onToggleMoment: () =>
                setState(() => _addingMoment = !_addingMoment),
            onGenerate: _weaveToday,
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        // What is left, under the box that spends it. Without this the free
        // tier reads as unlimited right up until the moment it refuses, which
        // is the worst possible place to learn there was a limit. Tapping it
        // opens the plans, because "how many do I get" and "what would more
        // cost" are the same question.
        _Inset(
          child: AllowanceCard(
            usage: ref.watch(usageProvider),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(builder: (_) => const PaywallScreen()),
            ),
          ),
        ),
        const SizedBox(height: AstraSpacing.lg),

        _Inset(
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 6),
              Text('TRENDING MANIFESTATIONS', style: AstraTextStyles.eyebrow),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.sm),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: trending.length,
            separatorBuilder: (_, _) => const SizedBox(width: AstraSpacing.sm),
            itemBuilder: (_, i) => TagChip(
              label: trending[i].label,
              accent: trending[i].intention.accent,
              selected: _wishController.text == trending[i].wish,
              onTap: () => _useTrending(trending[i]),
            ),
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),

        _Inset(
          child: Row(
            children: [
              Expanded(
                child: Text('For you', style: AstraTextStyles.display(22)),
              ),
              _PillButton(
                label: 'Edit desires',
                icon: Icons.edit_outlined,
                onTap: () => editIntentions(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        if (stories.isEmpty)
          _Inset(child: _FirstStoryCard(onCreate: widget.onCreate))
        else
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: stories.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AstraSpacing.md),
              itemBuilder: (_, i) => i == stories.length
                  ? _SeeAllCard(onTap: widget.onLibrary)
                  : _StoryCard(
                      story: stories[i],
                      onTap: () => _open(stories[i]),
                    ),
            ),
          ),
        const SizedBox(height: AstraSpacing.xl),

        _Inset(
          child: AstraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Affirmation of the day', style: AstraTextStyles.small),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  '“${ref.watch(dailyAffirmationProvider)}”',
                  style: AstraTextStyles.quote,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AstraSpacing.md),
        _Inset(
          child: StreakCard(
            streak: streak,
            week: ref.watch(weekActivityProvider),
            name: profile.name,
            since: profile.joinedAt,
          ),
        ),

        const SizedBox(height: AstraSpacing.md),
        _Inset(
          child: Row(
            children: [
              Expanded(
                child: _Stat(label: 'Stories', value: '${stories.length}'),
              ),
              const SizedBox(width: AstraSpacing.sm),
              Expanded(child: _Stat(label: 'Minutes', value: '$minutes')),
              const SizedBox(width: AstraSpacing.sm),
              Expanded(child: _Stat(label: 'Kept', value: '$keptCount')),
            ],
          ),
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

/// The screen's horizontal margin, applied per-section so the two scrolling
/// rows can ignore it.
class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: AstraSpacing.screenPadding, child: child);
}


/// Today's story: the whole daily loop in one card.
///
/// This replaced a text field that had to be filled in before anything would
/// happen, which meant every story began by retyping a desire the app had
/// already written down. Onboarding does that once now, so the default path
/// here is a single tap and the typing is optional.
///
/// The three choices under the button are what stops the same story arriving
/// every day without turning it back into a form: continue the storyline, go
/// somewhere new in the same life, or hand the choice over. "Add a moment"
/// is folded away until asked for, because a field standing open reads as a
/// field that must be filled.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.name,
    required this.focus,
    required this.busy,
    required this.controller,
    required this.momentOpen,
    required this.hint,
    required this.onFocus,
    required this.onToggleMoment,
    required this.onGenerate,
  });

  final String name;
  final StoryFocus focus;
  final bool busy;
  final TextEditingController controller;
  final bool momentOpen;
  final String hint;
  final ValueChanged<StoryFocus> onFocus;
  final VoidCallback onToggleMoment;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => AstraCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TODAY’S STORY', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),
        // The one flourish on the screen: the verb in italic serif, which is
        // what makes this read as an invitation rather than a form label.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: name.isEmpty ? 'Your future is ' : '$name, your future is '),
              TextSpan(
                text: 'already',
                style: AstraTextStyles.displayItalic(26),
              ),
              const TextSpan(text: ' unfolding.'),
            ],
          ),
          style: AstraTextStyles.display(26),
        ),
        const SizedBox(height: AstraSpacing.lg),

        AstraButton(
          label: '✨  Generate today’s story',
          busy: busy,
          onPressed: busy ? null : onGenerate,
        ),
        const SizedBox(height: AstraSpacing.lg),

        Text('WHAT SHOULD IT BE ABOUT?', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),
        for (final option in StoryFocus.values) ...[
          InkWell(
            onTap: busy ? null : () => onFocus(option),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(
                    option == focus
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: option == focus
                        ? AstraColors.accent
                        : AstraColors.dim,
                  ),
                  const SizedBox(width: AstraSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.label,
                          style: AstraTextStyles.body.copyWith(
                            fontWeight: option == focus
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        Text(option.detail, style: AstraTextStyles.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: AstraSpacing.sm),
        InkWell(
          onTap: busy ? null : onToggleMoment,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(
                  momentOpen ? Icons.remove_rounded : Icons.add_rounded,
                  size: 18,
                  color: AstraColors.accent,
                ),
                const SizedBox(width: AstraSpacing.md),
                Text(
                  'Add a moment',
                  style: AstraTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (momentOpen) ...[
          const SizedBox(height: AstraSpacing.sm),
          TextField(
            controller: controller,
            style: AstraTextStyles.body,
            cursorColor: AstraColors.accent,
            minLines: 1,
            maxLines: 3,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: AstraTextStyles.bodyDim.copyWith(
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: AstraColors.canvas,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AstraColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AstraColors.accent),
              ),
            ),
          ),
          const SizedBox(height: AstraSpacing.sm),
          Text(
            'One thing that happened, in your words. “We went to the movies.” '
            '“She called me.” “I ran five kilometres.”',
            style: AstraTextStyles.small,
          ),
        ],
      ],
    ),
  );
}

/// Small bordered pill — "Edit desires" and anything else that sits beside a
/// section title.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AstraColors.card,
          boxShadow: AstraColors.softShadow,
          borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AstraColors.accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: AstraTextStyles.small.copyWith(color: AstraColors.text),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A story in the "For you" row.
///
/// White card, black type, one glyph. It used to be tinted with the
/// intention's colour, which was carrying the whole job of telling the cards
/// apart — with the palette gone that job falls to the title, which is what
/// anyone was actually reading anyway.
class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: AstraColors.card,
              borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
              boxShadow: AstraColors.softShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${story.intention.glyph}  '
                          '${story.intention.label.toUpperCase()} · '
                          '${story.durationLabel.toUpperCase()}',
                          style: AstraTextStyles.eyebrow.copyWith(
                            color: AstraColors.dim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (story.favorite)
                        const Icon(
                          Icons.favorite,
                          size: 13,
                          color: AstraColors.accent,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    story.title,
                    style: AstraTextStyles.display(17),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AstraSpacing.md),
                  Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 26,
                        color: AstraColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text('Listen', style: AstraTextStyles.small),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The last card in the row — the way into the full library, placed where the
/// scroll naturally ends rather than as a "see all" link nobody looks at.
class _SeeAllCard extends StatelessWidget {
  const _SeeAllCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: AstraColors.card,
            boxShadow: AstraColors.softShadow,
            borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.library_music_outlined,
                color: AstraColors.accent,
                size: 24,
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text('All stories', style: AstraTextStyles.small),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What "For you" shows before there is anything to show.
class _FirstStoryCard extends StatelessWidget {
  const _FirstStoryCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => AstraCard(
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
          'Say what you want above, or tap one of the manifestations. '
          'Your first story is free.',
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.md),
        AstraGhostButton(label: 'More options', onPressed: onCreate),
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
