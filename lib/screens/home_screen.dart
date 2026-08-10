import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/story.dart';
import '../providers.dart';
import '../services/affirmations.dart';
import '../services/trending_manifestations.dart';
import '../services/wish_prompts.dart';
import '../theme/astra_theme.dart';
import '../widgets/allowance_ring.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/streak_card.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';
import 'profile_screen.dart';
import 'story_flow.dart';

/// The daily ritual, arranged as one question.
///
/// Everything above the fold serves a single ask — your face, your name, the
/// question, the box, and a row of things other people are asking for. The
/// library, the streak and the stats live below it, because they are evidence
/// that the practice is working rather than the thing you came to do.
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

  /// The one-line path: type a wish, get a story. Length, voice and mood keep
  /// their defaults, and Create exists for anyone who wants to set them.
  Future<void> _weaveFromWish() async {
    final wish = _wishController.text.trim();
    if (wish.isEmpty || _weaving) return;

    setState(() => _weaving = true);

    final made = await weaveStory(
      Navigator.of(context),
      ScaffoldMessenger.of(context),
      ProviderScope.containerOf(context),
      intention: _chipIntention ?? _intention,
      scene: wish,
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
        _Inset(
          child: _HomeHeader(
            onFavourites: widget.onProfile,
            onHistory: widget.onLibrary,
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),

        Center(child: ProfileAvatar(name: profile.name)),
        const SizedBox(height: AstraSpacing.lg),

        _Inset(child: _Question(name: profile.name)),
        const SizedBox(height: AstraSpacing.lg),

        _Inset(
          child: _WishBar(
            controller: _wishController,
            hint: _suggestion,
            busy: _weaving,
            onSubmit: _weaveFromWish,
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
                  '“${Affirmations.forDay(DateTime.now(), profile.intentions, ref.watch(tasteProvider))}”',
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onFavourites, required this.onHistory});

  final VoidCallback onFavourites;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Wordmark('Astra', align: TextAlign.left)),
      _HeaderIcon(
        icon: Icons.favorite_border,
        tooltip: 'Saved',
        onTap: onFavourites,
      ),
      const SizedBox(width: AstraSpacing.sm),
      _HeaderIcon(
        icon: Icons.history_rounded,
        tooltip: 'Your library',
        onTap: onHistory,
      ),
    ],
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AstraColors.card,
            boxShadow: AstraColors.softShadow,
          ),
          child: Icon(icon, size: 16, color: AstraColors.text),
        ),
      ),
    ),
  );
}

/// "Sid, what do you want to manifest?" — the verb set in italic serif, which
/// is the one flourish on the screen and the reason the question reads as a
/// question rather than a form label.
class _Question extends StatelessWidget {
  const _Question({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: name.isEmpty
              ? 'What do you want to '
              : '$name, what do you want to ',
        ),
        TextSpan(text: 'manifest', style: AstraTextStyles.displayItalic(30)),
        const TextSpan(text: '?'),
      ],
    ),
    textAlign: TextAlign.center,
    style: AstraTextStyles.display(30),
  );
}

/// The wish box: one rounded field with the submit button inside it.
///
/// The button lives in the field rather than under it so the whole ask is a
/// single object — and it is disabled until there is something to send, which
/// is what keeps an empty tap from reading as a broken button.
class _WishBar extends StatefulWidget {
  const _WishBar({
    required this.controller,
    required this.hint,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  State<_WishBar> createState() => _WishBarState();
}

class _WishBarState extends State<_WishBar> {
  @override
  Widget build(BuildContext context) {
    final ready = widget.controller.text.trim().isNotEmpty && !widget.busy;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
      decoration: BoxDecoration(
        color: AstraColors.card,
        boxShadow: AstraColors.softShadow,
        borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: AstraTextStyles.body,
              cursorColor: AstraColors.accent,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => widget.onSubmit(),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: widget.hint,
                hintStyle: AstraTextStyles.bodyDim.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(width: AstraSpacing.sm),
          Semantics(
            button: true,
            enabled: ready,
            label: 'Generate this story',
            child: InkWell(
              onTap: ready ? widget.onSubmit : null,
              customBorder: const CircleBorder(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: ready ? 1 : 0.45,
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AstraColors.accentGradient,
                  ),
                  child: widget.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AstraColors.onAccent,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: AstraColors.onAccent,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
/// No artwork: the app has no images and inventing stock photography for a
/// story about the user's own life would be a worse lie than a colour. The
/// intention's accent carries it instead, so the row still reads as distinct
/// cards at a glance.
class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = story.intention.accent;

    return SizedBox(
      width: 208,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.22),
                  AstraColors.card,
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(18),
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
                          '${story.intention.label.toUpperCase()} · '
                          '${story.durationLabel.toUpperCase()}',
                          style: AstraTextStyles.eyebrow.copyWith(color: accent),
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AstraColors.card,
            boxShadow: AstraColors.softShadow,
            borderRadius: BorderRadius.circular(18),
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
