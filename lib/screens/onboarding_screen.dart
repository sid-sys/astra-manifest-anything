import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story_preferences.dart';
import '../models/user_profile.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'paywall_screen.dart';
import 'proof_screen.dart';
import 'story_flow.dart';

/// Eleven questions, one to a page, and then the story.
///
/// One question per screen rather than a form: a page with a single thing on it
/// reads as a conversation, and a page with four fields reads as an account
/// signup. It is also the only honest way to ask eleven things — nobody scrolls
/// a wall of them, but nearly everybody taps through eleven cards.
///
/// It no longer asks for a name, an age or a gender. None of them were needed:
/// the stories are first person, so nobody is addressed by name inside one, and
/// the generator is under standing instructions to write no gender it was not
/// given. Three questions removed from the front of a flow are three chances to
/// close the app, and the ones left are the ones that change the writing.
///
/// Only the desire is required. Every other page opens with Continue already
/// enabled, because a question you cannot skip is a question people quit on,
/// and a blank is handled honestly — the brief omits the line rather than
/// inventing an answer.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepNames = [
    'THE AREA',
    'THE DESIRE',
    'WHEN',
    'WHO',
    'WHERE',
    'HOW IT FEELS',
    'YOUR LIFE THEN',
    'THE STYLE',
    'HOW REAL',
    'ANYTHING ELSE',
    'WHAT MATTERS',
  ];

  static final _stepCount = _stepNames.length;

  /// The plans come straight after the desire is written.
  ///
  /// By then the user has said the one thing the app is for and has not spent
  /// anything, which is the moment the offer is about them rather than about
  /// us. "Not now" carries on to the free story either way.
  static const _offerAfterStep = 1;

  final _desireController = TextEditingController();
  final _placeController = TextEditingController();
  final _personController = TextEditingController();
  final _extrasController = TextEditingController();

  var _preferences = StoryPreferences.empty;
  int _step = 0;
  bool _weaving = false;

  /// Steps whose plans have already been offered, so going back and forward
  /// again does not show the price a second time.
  bool _offered = false;

  @override
  void dispose() {
    _desireController.dispose();
    _placeController.dispose();
    _personController.dispose();
    _extrasController.dispose();
    super.dispose();
  }

  void _edit(StoryPreferences Function(StoryPreferences) change) =>
      setState(() => _preferences = change(_preferences));

  Future<void> _offerPlans() async {
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

  // Only the desire is compulsory. Everything else can be walked past.
  bool get _canAdvance =>
      _step == 1 ? _desireController.text.trim().length > 3 : !_weaving;

  void _back() {
    if (_step == 0 || _weaving) return;
    setState(() => _step--);
  }

  Future<void> _advance() async {
    if (_step < _stepCount - 1) {
      if (_step == _offerAfterStep && !_offered) {
        _offered = true;
        await _offerPlans();
      }
      if (!mounted) return;
      setState(() => _step++);
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);

    final desire = _desireController.text.trim();
    final preferences = _preferences.copyWith(
      desire: desire,
      placeDetail: _placeController.text.trim(),
      personName: _personController.text.trim(),
      extras: _extrasController.text.trim(),
    );

    // Anything the paywall already wrote — a subscription taken nine steps ago
    // — lives on the stored profile. Building this one from `empty()` without
    // carrying it would silently un-subscribe someone who had just paid.
    final existing = container.read(profileProvider);

    final profile = UserProfile.empty().copyWith(
      intentions: {preferences.category.intention},
      isSubscribed: existing.isSubscribed,
      subscribedAt: existing.subscribedAt,
      paywallSeen: true,
      preferences: preferences,
      // Kept in step with `preferences.desire` so anything still reading the
      // old field — the affirmation writer does — sees the same sentence.
      aspiration: desire,
    );

    setState(() => _weaving = true);

    // Order matters, and it is the whole bug this went through twice.
    //
    // Putting the profile into state is what flips `isOnboarded`, which
    // rebuilds the app onto the shell and tears this screen down mid-flight.
    // So the profile is written to storage first — that is all the generator
    // needs, since the server reads the mirrored document — and the state is
    // only committed once the story is home.
    await container.read(repositoryProvider).saveProfile(profile);

    try {
      await weaveStory(
        navigator,
        messenger,
        container,
        intention: preferences.category.intention,
        scene: desire,
        profile: profile,
      );
    } finally {
      // Even if the story failed, the answers were given and saved — sending
      // the user back through eleven questions would be a second insult.
      await container.read(profileProvider.notifier).update(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AstraSpacing.sm),

                // Back sits above the progress bar, on every page but the
                // first. Eleven questions without a way back is eleven chances
                // to be stuck with a mistap, and the answers are all one tap
                // each — going back to change one should be one tap too.
                // Back on the left, wordmark centred by a matching gap on the
                // right — a Stack rather than Spacers so the title stays
                // centred on the page rather than on what is left of it.
                SizedBox(
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Wordmark('Astra'),
                      if (_step > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _BackButton(onTap: _weaving ? null : _back),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AstraSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _stepNames[_step],
                        style: AstraTextStyles.eyebrow,
                      ),
                    ),
                    Text(
                      '${_step + 1} OF $_stepCount',
                      style: AstraTextStyles.eyebrow.copyWith(
                        color: AstraColors.dim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AstraSpacing.sm),
                AstraProgressBar(value: (_step + 1) / _stepCount, height: 6),
                const SizedBox(height: AstraSpacing.xl),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      child: _page(),
                    ),
                  ),
                ),

                AstraButton(
                  label: _step == _stepCount - 1
                      ? 'Write my first story'
                      : 'Continue',
                  busy: _weaving,
                  onPressed: _canAdvance ? _advance : null,
                ),
                const SizedBox(height: AstraSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _page() => switch (_step) {
    0 => _CategoryPage(
      selected: _preferences.category,
      onPick: (value) => _edit((p) => p.copyWith(category: value)),
    ),
    1 => _DesirePage(
      controller: _desireController,
      onChanged: () => setState(() {}),
    ),
    2 => _ChoicePage<Timeframe>(
      question: 'When do you imagine this happening?',
      hint:
          'Your story opens on a real date. This is what decides which one, '
          'so the moment has somewhere to sit.',
      options: Timeframe.values,
      label: (t) => t.label,
      selected: _preferences.timeframe,
      onPick: (value) => _edit((p) => p.copyWith(timeframe: value)),
    ),
    3 => _CastPage(
      selected: _preferences.cast,
      personController: _personController,
      onToggle: _toggleCast,
    ),
    4 => _PlacePage(
      selected: _preferences.place,
      detailController: _placeController,
      onPick: (value) => _edit((p) => p.copyWith(place: value)),
    ),
    5 => _FeelingsPage(
      selected: _preferences.feelings,
      onToggle: _toggleFeeling,
    ),
    6 => _ChoicePage<FutureShape>(
      question: 'What would your future life look like?',
      hint:
          'How much of the world around the moment has moved. It is most of '
          'what makes a story believable.',
      options: FutureShape.values,
      label: (s) => s.label,
      selected: _preferences.futureShape,
      onPick: (value) => _edit((p) => p.copyWith(futureShape: value)),
    ),
    7 => _ChoicePage<StoryStyle>(
      question: 'What kind of story do you want?',
      hint: 'The register it is written in.',
      options: StoryStyle.values,
      label: (s) => s.label,
      selected: _preferences.style,
      onPick: (value) => _edit((p) => p.copyWith(style: value)),
    ),
    8 => _ChoicePage<Realism>(
      question: 'How realistic should the story feel?',
      hint: 'How close it stays to an ordinary day.',
      options: Realism.values,
      label: (r) => r.label,
      selected: _preferences.realism,
      onPick: (value) => _edit((p) => p.copyWith(realism: value)),
    ),
    9 => _ExtrasPage(controller: _extrasController),
    _ => _ChoicePage<Authenticity>(
      question: 'What would make you think, “this is exactly my life”?',
      hint:
          'The most useful answer here. It tells Astra which kind of detail '
          'to spend its words on.',
      options: Authenticity.values,
      label: (a) => a.label,
      selected: _preferences.authenticity,
      onPick: (value) => _edit((p) => p.copyWith(authenticity: value)),
    ),
  };

  /// "Just me" is exclusive: a story cannot be both alone and with your family.
  void _toggleCast(StoryCast who) => _edit((p) {
    if (who == StoryCast.alone) {
      return p.copyWith(cast: const {StoryCast.alone});
    }

    final next = {...p.cast, who}..remove(StoryCast.alone);
    if (p.cast.contains(who)) next.remove(who);

    return p.copyWith(cast: next.isEmpty ? const {StoryCast.alone} : next);
  });

  /// Up to three. The fourth tap is ignored rather than silently dropping the
  /// oldest — a limit that quietly rewrites your answer is worse than one that
  /// holds.
  void _toggleFeeling(Feeling feeling) => _edit((p) {
    final next = {...p.feelings};
    if (!next.remove(feeling) && next.length < 3) next.add(feeling);
    return p.copyWith(feelings: next);
  });
}

// ------------------------------------------------------------------- pieces

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AstraColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AstraColors.line),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: AstraColors.text,
        ),
      ),
    ),
  );
}

/// The question and the line under it, identical on every page.
class _Ask extends StatelessWidget {
  const _Ask({required this.question, this.hint});

  final String question;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(question, style: AstraTextStyles.display(28)),
      if (hint != null) ...[
        const SizedBox(height: AstraSpacing.sm),
        Text(hint!, style: AstraTextStyles.bodyDim),
      ],
      const SizedBox(height: AstraSpacing.xl),
    ],
  );
}

/// A column of full-width radio rows.
///
/// A column rather than a wrap of chips because these options are sentences,
/// and sentences inside chips wrap into an unreadable staircase.
class _ChoiceList<T> extends StatelessWidget {
  const _ChoiceList({
    required this.options,
    required this.label,
    required this.selected,
    required this.onPick,
  });

  final List<T> options;
  final String Function(T) label;
  final T? selected;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final option in options) ...[
        AstraCard(
          onTap: () => onPick(option),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(
                option == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: option == selected
                    ? AstraColors.accent
                    : AstraColors.dim,
              ),
              const SizedBox(width: AstraSpacing.md),
              Expanded(
                child: Text(
                  label(option),
                  style: AstraTextStyles.body.copyWith(
                    fontWeight: option == selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.sm),
      ],
    ],
  );
}

/// A whole page that is one question with one answer.
class _ChoicePage<T> extends StatelessWidget {
  const _ChoicePage({
    required this.question,
    required this.options,
    required this.label,
    required this.selected,
    required this.onPick,
    this.hint,
  });

  final String question;
  final String? hint;
  final List<T> options;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Ask(question: question, hint: hint),
      _ChoiceList<T>(
        options: options,
        label: label,
        selected: selected,
        onPick: onPick,
      ),
    ],
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.lines = 1,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;
  final int lines;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: TextField(
      controller: controller,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      maxLines: lines,
      textCapitalization: capitalization,
      style: AstraTextStyles.body.copyWith(fontSize: 16),
      cursorColor: AstraColors.accent,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: hint,
        hintStyle: AstraTextStyles.bodyDim,
      ),
    ),
  );
}

// -------------------------------------------------------------------- pages

class _CategoryPage extends StatelessWidget {
  const _CategoryPage({required this.selected, required this.onPick});

  final DesireCategory selected;
  final ValueChanged<DesireCategory> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'What kind of desire do you want to visualise?',
        hint: 'Pick the one that matters most right now.',
      ),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in DesireCategory.values)
            TagChip(
              label: '${option.glyph}  ${option.label}',
              selected: option == selected,
              onTap: () => onPick(option),
            ),
        ],
      ),
    ],
  );
}

/// The one answer the app cannot write a story without.
class _DesirePage extends StatelessWidget {
  const _DesirePage({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  /// Openers, not examples. A blank box is the hardest thing in the app to
  /// answer, and three words of a sentence is enough to get someone moving.
  static const _openers = [
    'I want to ',
    'My dream is to ',
    'I want my life to ',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'What is your desire?',
        hint: 'Say it in your own words, as if it has already happened.',
      ),
      _Input(
        controller: controller,
        hint: 'I want to…',
        onChanged: onChanged,
        lines: 4,
      ),
      const SizedBox(height: AstraSpacing.md),

      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final opener in _openers)
            TagChip(
              label: '${opener.trim()}…',
              selected: controller.text.startsWith(opener),
              onTap: () {
                controller.text = opener;
                controller.selection = TextSelection.collapsed(
                  offset: opener.length,
                );
                onChanged();
              },
            ),
        ],
      ),
      const SizedBox(height: AstraSpacing.lg),

      // The single highest-leverage instruction in the app. A generator can
      // only be as specific as the sentence it was given, and "more money"
      // produces a story about nobody.
      AstraCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: AstraColors.accent,
            ),
            const SizedBox(width: AstraSpacing.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Be specific. ',
                      style: AstraTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text:
                          'Amounts, places, names, dates. '
                          '“₹4 lakh a month from my studio in Goa by March” '
                          'writes a story you can picture. “More money” '
                          'writes one about nobody.',
                    ),
                  ],
                ),
                style: AstraTextStyles.bodyDim,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CastPage extends StatelessWidget {
  const _CastPage({
    required this.selected,
    required this.personController,
    required this.onToggle,
  });

  final Set<StoryCast> selected;
  final TextEditingController personController;
  final ValueChanged<StoryCast> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'Who should be in your story?',
        hint: 'Choose as many as fit. Conversations are what make it real.',
      ),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in StoryCast.values)
            TagChip(
              label: option.label,
              selected: selected.contains(option),
              onTap: () => onToggle(option),
            ),
        ],
      ),

      if (selected.contains(StoryCast.someone)) ...[
        const SizedBox(height: AstraSpacing.lg),
        Text('THEIR NAME', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),
        _Input(
          controller: personController,
          hint: 'The name you would actually use',
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          'Just the name. Your stories call them by it rather than he or she, '
          'because a name is not evidence of anything and guessing wrong '
          'breaks the spell in one word.',
          style: AstraTextStyles.small,
        ),
      ],
    ],
  );
}

class _PlacePage extends StatelessWidget {
  const _PlacePage({
    required this.selected,
    required this.detailController,
    required this.onPick,
  });

  final StoryPlace selected;
  final TextEditingController detailController;
  final ValueChanged<StoryPlace> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'Where should your future story happen?',
        hint:
            'A named place beats a described one. “The café near the '
            'waterfront in Kochi” is somewhere you have stood.',
      ),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in StoryPlace.values)
            TagChip(
              label: option.label,
              selected: option == selected,
              onTap: () => onPick(option),
            ),
        ],
      ),
      const SizedBox(height: AstraSpacing.lg),

      Text('CITY OR PLACE', style: AstraTextStyles.eyebrow),
      const SizedBox(height: AstraSpacing.sm),
      _Input(
        controller: detailController,
        hint: 'Optional — Kochi, my parents’ house, the office in Bandra',
        capitalization: TextCapitalization.words,
      ),
    ],
  );
}

class _FeelingsPage extends StatelessWidget {
  const _FeelingsPage({required this.selected, required this.onToggle});

  final Set<Feeling> selected;
  final ValueChanged<Feeling> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'How do you want to feel when it is real?',
        hint: 'Up to three. This is what the ending is built to land on.',
      ),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in Feeling.values)
            TagChip(
              label: '${option.glyph}  ${option.label}',
              selected: selected.contains(option),
              onTap: () => onToggle(option),
            ),
        ],
      ),
      const SizedBox(height: AstraSpacing.md),
      Text(
        selected.length >= 3
            ? 'Three chosen. Tap one to swap it out.'
            : '${3 - selected.length} more if you want them.',
        style: AstraTextStyles.small,
      ),
    ],
  );
}

class _ExtrasPage extends StatelessWidget {
  const _ExtrasPage({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'Anything special you want included?',
        hint:
            'Someone saying a particular thing, a place, a date, a song, a '
            'dish, an outfit. Small specific things are what a memory is '
            'made of.',
      ),
      _Input(
        controller: controller,
        hint: 'Optional — she calls me by my full name when she is teasing',
        lines: 5,
      ),
    ],
  );
}
