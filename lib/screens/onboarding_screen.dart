import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Nine questions, then the story.
///
/// It asks a lot more than it used to, and that is the point: the generator can
/// only be as specific as what it was told, and the difference between "a café"
/// and "the café near the waterfront in Kochi, on a Saturday evening" is the
/// difference between a story about someone and a story about you. Everything
/// asked here is stored once and sent with every story afterwards, so this is
/// the only time anyone answers it.
///
/// Only two answers are required — a name and a desire. Every other step opens
/// with Continue already enabled, because a question you cannot skip is a
/// question people close the app on, and a blank answer is honestly handled:
/// the brief simply omits it rather than inventing something.
///
/// It ends in the thing it was selling. The last step used to save the wish and
/// drop the user on the home screen with an empty box, so the first thing the
/// app did with the sentence someone had just typed was forget it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepNames = [
    'YOU',
    'YOUR DESIRE',
    'WHEN',
    'WHO',
    'WHERE',
    'HOW IT FEELS',
    'YOUR LIFE THEN',
    'THE TELLING',
    'ANYTHING ELSE',
  ];

  static final _stepCount = _stepNames.length;

  /// The step the plans follow: after the desire, before the seven questions
  /// about how to tell it. By then the user has said what they want and has
  /// not spent anything, which is the moment the offer is about them rather
  /// than about us.
  static const _offerAfterStep = 1;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _desireController = TextEditingController();
  final _placeController = TextEditingController();
  final _personController = TextEditingController();
  final _extrasController = TextEditingController();

  var _preferences = StoryPreferences.empty;
  String _gender = '';
  int _step = 0;
  bool _weaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _desireController.dispose();
    _placeController.dispose();
    _personController.dispose();
    _extrasController.dispose();
    super.dispose();
  }

  void _edit(StoryPreferences Function(StoryPreferences) change) =>
      setState(() => _preferences = change(_preferences));

  /// Shows the reviews, if there are any, and then the plans.
  ///
  /// Nothing is read from the result. Subscribing writes the profile itself,
  /// and "Not now" is a valid answer that continues to the free story — so
  /// this is an offer in the middle of a flow rather than a fork in it.
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

  bool get _canAdvance => switch (_step) {
    0 => _nameController.text.trim().isNotEmpty,
    1 => _desireController.text.trim().length > 3,
    // Everything from here is skippable. A blank answer means the story does
    // not lean on it, which is a real answer and better than a guess.
    _ => !_weaving,
  };

  Future<void> _advance() async {
    if (_step < _stepCount - 1) {
      if (_step == _offerAfterStep) await _offerPlans();
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

    // Anything the paywall already wrote — a subscription taken seven steps
    // ago — lives on the stored profile. Building this one from `empty()`
    // without carrying it would silently un-subscribe someone who had just
    // paid.
    final existing = container.read(profileProvider);

    final profile = UserProfile.empty().copyWith(
      name: _nameController.text.trim(),
      intentions: {preferences.category.intention},
      age: int.tryParse(_ageController.text.trim()),
      gender: _gender,
      isSubscribed: existing.isSubscribed,
      subscribedAt: existing.subscribedAt,
      paywallSeen: true,
      preferences: preferences,
      // Kept in step with `preferences.desire` so that anything still reading
      // the old field — the affirmation writer does — sees the same sentence.
      aspiration: desire,
    );

    setState(() => _weaving = true);

    // Order matters, and it is the whole bug this went through twice.
    //
    // Putting the profile into state is what flips `isOnboarded`, which
    // rebuilds the app onto the shell and tears this screen down mid-flight.
    // So the profile is written to storage first — that is all the generator
    // needs, since the server reads the mirrored document — and the state is
    // only committed once the story is home. Until then this widget stays
    // mounted and owns the flow, the way every other caller does.
    await container.read(repositoryProvider).saveProfile(profile);

    try {
      await weaveStory(
        navigator,
        messenger,
        container,
        intention: preferences.category.intention,
        // The first story is the desire itself becoming true. Every story
        // after it continues from there.
        scene: desire,
        profile: profile,
      );
    } finally {
      // Even if the story failed, the answers were given and saved — sending
      // the user back through nine questions to try again would be a second
      // insult.
      await container.read(profileProvider.notifier).update(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AstraSpacing.lg),
                const Wordmark('Astra'),
                const SizedBox(height: AstraSpacing.xl),

                // A bar on its own says "some of the way through". Naming the
                // step and counting it says how much is left, which is the
                // only question anyone actually has during a form.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _stepNames[_step],
                        style: AstraTextStyles.eyebrow,
                      ),
                    ),
                    Text(
                      'STEP ${_step + 1} OF $_stepCount',
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
                    duration: const Duration(milliseconds: 260),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => _AboutStep(
                          nameController: _nameController,
                          ageController: _ageController,
                          gender: _gender,
                          onChanged: () => setState(() {}),
                          onGender: (value) => setState(
                            () => _gender = _gender == value ? '' : value,
                          ),
                        ),
                        1 => _DesireStep(
                          controller: _desireController,
                          name: name,
                          category: _preferences.category,
                          onCategory: (category) =>
                              _edit((p) => p.copyWith(category: category)),
                          onChanged: () => setState(() {}),
                        ),
                        2 => _TimeframeStep(
                          selected: _preferences.timeframe,
                          onPick: (value) =>
                              _edit((p) => p.copyWith(timeframe: value)),
                        ),
                        3 => _CastStep(
                          selected: _preferences.cast,
                          personController: _personController,
                          personGender: _preferences.personGender,
                          onToggle: _toggleCast,
                          onPersonGender: (value) => _edit(
                            (p) => p.copyWith(
                              personGender: p.personGender == value
                                  ? ''
                                  : value,
                            ),
                          ),
                        ),
                        4 => _PlaceStep(
                          selected: _preferences.place,
                          detailController: _placeController,
                          onPick: (value) =>
                              _edit((p) => p.copyWith(place: value)),
                        ),
                        5 => _FeelingsStep(
                          selected: _preferences.feelings,
                          onToggle: _toggleFeeling,
                        ),
                        6 => _FutureStep(
                          selected: _preferences.futureShape,
                          onPick: (value) =>
                              _edit((p) => p.copyWith(futureShape: value)),
                        ),
                        7 => _TellingStep(
                          style: _preferences.style,
                          realism: _preferences.realism,
                          onStyle: (value) =>
                              _edit((p) => p.copyWith(style: value)),
                          onRealism: (value) =>
                              _edit((p) => p.copyWith(realism: value)),
                        ),
                        _ => _ExtrasStep(
                          controller: _extrasController,
                          authenticity: _preferences.authenticity,
                          onAuthenticity: (value) =>
                              _edit((p) => p.copyWith(authenticity: value)),
                        ),
                      },
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

  /// "Just me" is exclusive. Picking it clears the rest, and picking anyone
  /// else clears it — a story cannot be both alone and with your family.
  void _toggleCast(StoryCast who) => _edit((p) {
    if (who == StoryCast.alone) {
      return p.copyWith(cast: const {StoryCast.alone});
    }

    final next = {...p.cast, if (true) who}..remove(StoryCast.alone);
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

/// The heading and the sentence under it, repeated on every step.
class _Ask extends StatelessWidget {
  const _Ask({required this.question, required this.hint});

  final String question;
  final String hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(question, style: AstraTextStyles.display(28)),
      const SizedBox(height: AstraSpacing.sm),
      Text(hint, style: AstraTextStyles.bodyDim),
      const SizedBox(height: AstraSpacing.xl),
    ],
  );
}

/// A column of full-width choices, one selected.
///
/// A column rather than a wrap of chips because these options are sentences,
/// and sentences in chips wrap into an unreadable staircase.
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

/// A boxed text field, matching the rest of the app's cards.
class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.lines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.keyboardType,
    this.formatters,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;
  final int lines;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: TextField(
      controller: controller,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      maxLines: lines,
      textCapitalization: capitalization,
      keyboardType: keyboardType,
      inputFormatters: formatters,
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

// -------------------------------------------------------------------- steps

/// Name, age and gender. Only the name is required.
///
/// Age and gender exist because the app got gender wrong from a name once:
/// "Sid" was read as a man and the person in the wish as another man, and the
/// story fell apart in one pronoun. Asking is the fix — but asking is only
/// better than guessing if skipping is genuinely allowed, so an empty answer
/// simply means the stories never mention it.
class _AboutStep extends StatelessWidget {
  const _AboutStep({
    required this.nameController,
    required this.ageController,
    required this.gender,
    required this.onChanged,
    required this.onGender,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final String gender;
  final VoidCallback onChanged;
  final ValueChanged<String> onGender;

  static const _options = ['Woman', 'Man', 'Non-binary'];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'What should Astra call you?',
        hint:
            'Your name is spoken inside your stories, so they land as yours. '
            'Age and gender are optional, and nothing is guessed from a name.',
      ),
      _Input(
        controller: nameController,
        hint: 'First name',
        onChanged: onChanged,
        capitalization: TextCapitalization.words,
      ),
      const SizedBox(height: AstraSpacing.lg),

      Text('AGE', style: AstraTextStyles.eyebrow),
      const SizedBox(height: AstraSpacing.sm),
      _Input(
        controller: ageController,
        hint: 'Optional',
        keyboardType: TextInputType.number,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
      ),
      const SizedBox(height: AstraSpacing.lg),

      Text('GENDER', style: AstraTextStyles.eyebrow),
      const SizedBox(height: AstraSpacing.sm),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in _options)
            TagChip(
              label: option,
              selected: gender == option,
              // Tapping the selected one clears it, so "prefer not to say" is
              // the absence of an answer rather than a fourth chip that reads
              // like an answer.
              onTap: () => onGender(option),
            ),
        ],
      ),
    ],
  );
}

/// The category and the desire itself — the two halves of one question.
class _DesireStep extends StatelessWidget {
  const _DesireStep({
    required this.controller,
    required this.name,
    required this.category,
    required this.onCategory,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String name;
  final DesireCategory category;
  final ValueChanged<DesireCategory> onCategory;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Ask(
        question: name.isEmpty
            ? 'What do you want to visualise?'
            : 'What do you want to visualise, $name?',
        hint:
            'Pick the part of life it belongs to, then say it in your own '
            'words, as if it has already happened.',
      ),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in DesireCategory.values)
            TagChip(
              label: '${option.glyph}  ${option.label}',
              selected: option == category,
              onTap: () => onCategory(option),
            ),
        ],
      ),
      const SizedBox(height: AstraSpacing.lg),

      _Input(
        controller: controller,
        hint: 'I want to…',
        onChanged: onChanged,
        lines: 4,
      ),
      const SizedBox(height: AstraSpacing.md),

      // The single highest-leverage instruction in the app. A generator can
      // only be as specific as the sentence it was given, and "more money"
      // produces a story about nothing.
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

class _TimeframeStep extends StatelessWidget {
  const _TimeframeStep({required this.selected, required this.onPick});

  final Timeframe selected;
  final ValueChanged<Timeframe> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'When do you imagine this happening?',
        hint:
            'Your stories open on a real date. This decides which one, so the '
            'moment has somewhere to sit.',
      ),
      _ChoiceList<Timeframe>(
        options: Timeframe.values,
        label: (t) => t.label,
        selected: selected,
        onPick: onPick,
      ),
    ],
  );
}

class _CastStep extends StatelessWidget {
  const _CastStep({
    required this.selected,
    required this.personController,
    required this.personGender,
    required this.onToggle,
    required this.onPersonGender,
  });

  final Set<StoryCast> selected;
  final TextEditingController personController;
  final String personGender;
  final ValueChanged<StoryCast> onToggle;
  final ValueChanged<String> onPersonGender;

  static const _genders = ['Woman', 'Man', 'Non-binary'];

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
        const SizedBox(height: AstraSpacing.lg),

        Text('AND THEIR GENDER', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),
        Wrap(
          spacing: AstraSpacing.sm,
          runSpacing: AstraSpacing.sm,
          children: [
            for (final option in _genders)
              TagChip(
                label: option,
                selected: personGender == option,
                onTap: () => onPersonGender(option),
              ),
          ],
        ),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          'Optional, and asked rather than guessed — a name is not evidence. '
          'Left blank, your stories use their name instead of a pronoun.',
          style: AstraTextStyles.small,
        ),
      ],
    ],
  );
}

class _PlaceStep extends StatelessWidget {
  const _PlaceStep({
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
        question: 'Where should it happen?',
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

class _FeelingsStep extends StatelessWidget {
  const _FeelingsStep({required this.selected, required this.onToggle});

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

class _FutureStep extends StatelessWidget {
  const _FutureStep({required this.selected, required this.onPick});

  final FutureShape selected;
  final ValueChanged<FutureShape> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'What does your life look like then?',
        hint:
            'This sets how much of the world around the moment has moved, '
            'which is most of what makes a story believable.',
      ),
      _ChoiceList<FutureShape>(
        options: FutureShape.values,
        label: (s) => s.label,
        selected: selected,
        onPick: onPick,
      ),
    ],
  );
}

class _TellingStep extends StatelessWidget {
  const _TellingStep({
    required this.style,
    required this.realism,
    required this.onStyle,
    required this.onRealism,
  });

  final StoryStyle style;
  final Realism realism;
  final ValueChanged<StoryStyle> onStyle;
  final ValueChanged<Realism> onRealism;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'How should it be told?',
        hint: 'The register, and how close it stays to an ordinary day.',
      ),
      Text('THE KIND OF STORY', style: AstraTextStyles.eyebrow),
      const SizedBox(height: AstraSpacing.sm),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final option in StoryStyle.values)
            TagChip(
              label: option.label,
              selected: option == style,
              onTap: () => onStyle(option),
            ),
        ],
      ),
      const SizedBox(height: AstraSpacing.lg),

      Text('HOW REAL IT SHOULD FEEL', style: AstraTextStyles.eyebrow),
      const SizedBox(height: AstraSpacing.sm),
      _ChoiceList<Realism>(
        options: Realism.values,
        label: (r) => r.label,
        selected: realism,
        onPick: onRealism,
      ),
    ],
  );
}

class _ExtrasStep extends StatelessWidget {
  const _ExtrasStep({
    required this.controller,
    required this.authenticity,
    required this.onAuthenticity,
  });

  final TextEditingController controller;
  final Authenticity authenticity;
  final ValueChanged<Authenticity> onAuthenticity;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Ask(
        question: 'Anything you want written in?',
        hint:
            'A sentence someone says, a song, an outfit, a date, a dish. '
            'Small specific things are what a memory is made of.',
      ),
      _Input(
        controller: controller,
        hint: 'Optional — she calls me by my full name when she is teasing',
        lines: 4,
      ),
      const SizedBox(height: AstraSpacing.xl),

      Text(
        'WHAT WOULD MAKE IT FEEL LIKE YOUR LIFE',
        style: AstraTextStyles.eyebrow,
      ),
      const SizedBox(height: AstraSpacing.sm),
      // The most useful answer in the whole flow: it says which kind of
      // specificity to spend the words on.
      _ChoiceList<Authenticity>(
        options: Authenticity.values,
        label: (a) => a.label,
        selected: authenticity,
        onPick: onAuthenticity,
      ),
    ],
  );
}
