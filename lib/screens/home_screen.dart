import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../demo/demo_data.dart';
import '../models/intention.dart';
import '../models/plan.dart';
import '../models/wish_text.dart';
import '../models/story.dart';
import '../providers.dart';
import '../services/wish_prompts.dart';
import '../theme/astra_theme.dart';
import '../widgets/allowance_ring.dart';
import '../widgets/trial_countdown.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/streak_card.dart';
import 'desire_flow_screen.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';

/// The daily ritual, arranged as one question.
///
/// Everything above the fold serves a single ask — the question, the box, and
/// a row of things other people are asking for. The library, the streak and
/// the stats live below it, because they are evidence that the practice is
/// working rather than the thing you came to do.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.onLibrary,
    required this.onProfile,
  });

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
  /// Which onboarding answers this manifestation is written from.
  ///
  /// Everything, until the user says otherwise. The answers were given for
  /// exactly this and leaving them off by default would make four questions
  /// a thing that happened once and never mattered.
  ///
  /// Filled on first build rather than in `initState`, because the profile it
  /// depends on is still being restored from Firestore at that point.

  /// The selection, seeded with every answer the first time it is needed.




  @override
  void initState() {
    super.initState();
    _suggestion = WishPrompts.next(_intention);

    // The store frame for Home is "a wish already typed into the box", so the
    // demo starts with one in it. The hint text underneath is grey placeholder
    // and photographs as an empty box, which is the one thing that frame is
    // not allowed to be.
    if (Demo.on) _wishController.text = Demo.wish;

    // Nothing writes itself here any more.
    //
    // Arriving on Home used to start a manifestation unasked, on the reasoning
    // that somebody who has answered twelve questions and paid should not have
    // to press one more button. What that actually produced was a person who
    // had just paid staring at a locked writing screen for ninety seconds,
    // unable to look at the thing they had bought — and the same again for a
    // returning subscriber who only wanted their library.
    //
    // The button is one tap and it is theirs.
  }

  /// The life area this account is about, for the prompt suggestions.
  Intention get _intention {
    final chosen = ref.read(profileProvider).intentions;
    return chosen.isEmpty ? Intention.career : chosen.first;
  }

  /// Opens the four questions written for whatever was just typed.
  ///
  /// Nothing is generated from this screen any more. The desire goes to the
  /// server, four questions come back about *that* desire, and the answers to
  /// those are what the writer actually works from — which is the whole reason
  /// onboarding could be deleted rather than shortened.
  Future<void> _weaveToday() async {
    if (_weaving) return;

    final desire = _wishController.text.trim();
    if (!looksMeaningful(desire)) return;
    unawaited(ref.read(trackingProvider).log('wish_typed', wish: desire));

    // The subscription is checked here, at the button, and not at the door.
    //
    // Signing up no longer lands on a price — see [AstraApp]. So this is where
    // the ask happens, and it happens after the wish is typed, which is the
    // only moment the person knows what they would be paying for. The wish
    // stays in the box while they decide, and pressing Continue again writes
    // it.
    //
    // The server checks the same thing. This is here so the answer arrives
    // before a minute of waiting rather than after it.
    // Debug builds only: a test guest skips the paywall so the questions that
    // follow can be seen. The server still refuses to write anything for an
    // account that has not paid, so this opens a screen and nothing more.
    final testGuest =
        kDebugMode && (FirebaseAuth.instance.currentUser?.isAnonymous ?? false);

    if (!testGuest && !ref.read(isSubscribedProvider)) {
      final bought = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (!mounted || bought != true) return;
    }

    setState(() => _weaving = true);

    final made = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DesireFlowScreen(desire: desire),
      ),
    );

    if (!mounted) return;
    if (made == true) _wishController.clear();
    setState(() => _weaving = false);
  }


  @override
  Widget build(BuildContext context) {

    final profile = ref.watch(profileProvider);

    // Manifestations and old stories in one row, newest first — the same list
    // the Library shows, for the same reason. Nothing new is written as a
    // story any more, but every story ever written still plays, and to the
    // person listening they are the same thing. Home showed only the stories,
    // so somebody whose whole library was manifestations opened the app to
    // "nothing written yet" with eight of them in the Library.
    final stories = ref.watch(everythingWrittenProvider);
    final streak = ref.watch(streakProvider);
    final minutes = ref.watch(minutesInLibraryProvider);
    final keptCount = ref.watch(tasteProvider).liked.length;
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
        const _Inset(child: Wordmark('Mayow', align: TextAlign.left)),
        const SizedBox(height: AstraSpacing.xxl),

        // The daily ritual, in one object: open, choose or don't, generate,
        // read. A story that arrived by itself every morning would be a
        // notification; a story you press a button for is something you came
        // to do.
        _Inset(
          child: _TodayCard(
            name: profile.name,
            busy: _weaving,
            controller: _wishController,
            hint: _suggestion,
            // Zero for anyone not paying, which reads as "you have none" —
            // true, and the button then opens the plans rather than refusing.
            left: ref.watch(manifestsLeftProvider),
            subscribed: ref.watch(isSubscribedProvider),
            trialLockedUntil: ref.watch(trialLockProvider),
            onTrialElapsed: () => ref.invalidate(trialLockProvider),
            onGenerate: _weaveToday,
            // The grey suggestion in the empty box looks like a typed wish. One
            // tap on the button makes it one, instead of doing nothing.
            onUseHint: () => _wishController.text = _suggestion,
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

        // What used to sit here: a row of "trending manifestations", and an
        // "Edit desires" pill next to the heading below.
        //
        // The chips were other people's wishes offered as a shortcut, on a
        // screen whose whole argument is that the story is about *your* life —
        // and the app already holds twelve answers about that life, so a chip
        // reading "Marry her" was a worse prompt than the one on file. The
        // edit pill pointed at a screen the Profile tab already reaches, which
        // is the same objection the avatar and the two icons above it lost to.
        _Inset(child: Text('For you', style: AstraTextStyles.display(22))),
        const SizedBox(height: AstraSpacing.md),

        if (stories.isEmpty)
          const _Inset(child: _FirstStoryCard())
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
                child: _Stat(label: 'Written', value: '${stories.length}'),
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
    final stories = ref.read(everythingWrittenProvider);
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
/// What Mayow will write, and what it will write it from.
///
/// The wish is typed here every time rather than answered once at signup. A
/// person manifests a different thing in March than they did in January, and a
/// desire saved during onboarding quietly became the answer to every question
/// they ever asked afterwards.
///
/// The chips underneath are the onboarding answers, and they are a multi-select
/// rather than a switch: somebody writing about their career this week may want
/// the people and the feelings but not the place, and that is a per-manifest
/// decision. The name has no chip because there is no version of this that
/// works without one — the script opens by saying it.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.name,
    required this.busy,
    required this.controller,
    required this.hint,
    required this.left,
    required this.subscribed,
    required this.onGenerate,
    this.trialLockedUntil,
    this.onTrialElapsed,
    this.onUseHint,
  });

  /// Fills the box with the suggestion shown in it.
  final VoidCallback? onUseHint;

  /// Set once the free trial's ten are used: the moment it ends, and the
  /// screen shows a countdown to it instead of the button.
  final DateTime? trialLockedUntil;
  final VoidCallback? onTrialElapsed;

  final String name;
  final bool busy;
  final TextEditingController controller;
  final String hint;

  /// Manifestations still available this month. Zero without a subscription.
  final int left;

  /// Whether this account is paying. Kept apart from [left] because zero means
  /// two different things: nothing bought yet, or everything used up.
  final bool subscribed;

  /// Used up, as opposed to never started. Only this one greys the button out
  /// — there is nothing a person can do about it until the 1st, so offering
  /// them a live button would be offering a refusal.
  bool get _spent => subscribed && left <= 0 && trialLockedUntil == null;

  final VoidCallback onGenerate;

  /// Whether there is a wish in the box, rather than enough characters in it.
  bool _ready() => looksMeaningful(controller.text);

  /// The line under the box.
  ///
  /// Ordered by what the person most needs to know: that they cannot write
  /// one right now, then that the box is empty, then how many they have left.
  String _underline(bool ready) {
    if (_spent) {
      return 'All ${PricingCatalog.manifestMonthly} written this month. '
          'Affirmations are free and still work, and everything replays.';
    }
    if (trialLockedUntil != null) {
      return 'You have used your ${PricingCatalog.trialManifests} free-trial '
          'manifestations. Affirmations and replays stay open.';
    }
    if (!ready) return 'Write it in your own words — "I want a place of my own"';
    if (!subscribed) return 'Mayow will ask you four things, then write it';
    return '$left of ${PricingCatalog.manifestMonthly} left this month';
  }

  @override
  Widget build(BuildContext context) => AstraCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TODAY’S MANIFESTATION', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: name.isEmpty
                    ? 'Say it like it is '
                    : '$name, say it like it is ',
              ),
              TextSpan(
                text: 'already',
                style: AstraTextStyles.displayItalic(26),
              ),
              const TextSpan(text: ' done.'),
            ],
          ),
          style: AstraTextStyles.display(26),
        ),
        const SizedBox(height: AstraSpacing.lg),

        TextField(
          controller: controller,
          style: AstraTextStyles.body,
          cursorColor: AstraColors.accent,
          minLines: 3,
          maxLines: 6,
          enabled: !busy,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AstraTextStyles.bodyDim,
            filled: true,
            fillColor: AstraColors.canvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AstraColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AstraColors.line),
            ),
          ),
        ),
        const SizedBox(height: AstraSpacing.xs),

        // Rebuilt on every keystroke, because these two are the only things on
        // the screen that answer to what is in the box.
        //
        // This card is a StatelessWidget with the controller handed in, which
        // means nothing here redraws unless something above it does. The button
        // stayed grey while a perfectly good wish sat in the box, and only came
        // alive after a trip to another tab forced a rebuild. Listening to the
        // controller is what makes the button track the typing.
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final ready = _ready();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One line, and it says whichever thing is currently true:
                // how many are left, why the button is dead, or what to type.
                // Says what is missing, not how much — a character count told
                // people to pad a finished wish out to length, and what is
                // actually needed is words.
                Text(
                  _underline(ready),
                  style: AstraTextStyles.small.copyWith(color: AstraColors.dim),
                ),
                const SizedBox(height: AstraSpacing.lg),
                if (trialLockedUntil != null)
                  TrialCountdown(
                    endsAt: trialLockedUntil!,
                    onElapsed: onTrialElapsed,
                  )
                else
                  AstraButton(
                    label: _spent
                        ? 'Used up this month'
                        : ready
                        ? '✨  Continue'
                        : '✨  Use this idea',
                    busy: busy,
                    onPressed: busy || _spent
                        ? null
                        : ready
                        ? onGenerate
                        : onUseHint,
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
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
                        Icon(
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
                      const AstraIcon('ui_play', size: 30),
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
              Icon(
                Icons.library_music_outlined,
                color: AstraColors.accent,
                size: 24,
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text('See all', style: AstraTextStyles.small),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What "For you" shows before there is anything to show.
class _FirstStoryCard extends StatelessWidget {
  const _FirstStoryCard();

  @override
  Widget build(BuildContext context) => AstraCard(
    raised: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR FIRST ONE', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          'Nothing written yet',
          style: AstraTextStyles.label.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          'Say what you want in the box above. Mayow asks four questions '
          'about it, then writes. Your first one is free.',
          style: AstraTextStyles.small,
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
