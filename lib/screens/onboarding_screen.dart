import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/user_profile.dart';
import '../providers.dart';
import '../services/trending_manifestations.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'story_flow.dart';

/// Name, then what you are calling in, then the wish — and then the story.
///
/// The last step used to save the wish and drop the user on the home screen
/// with an empty box, so the first thing the app did with the sentence someone
/// had just typed was forget it. Onboarding now ends in the thing it was
/// selling: the wish goes straight into a story, free, before any price is
/// mentioned.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 3;

  final _nameController = TextEditingController();
  final _wishController = TextEditingController();

  Intention? _intention;
  int _step = 0;
  bool _weaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _wishController.dispose();
    super.dispose();
  }

  bool get _canAdvance => switch (_step) {
    0 => _nameController.text.trim().isNotEmpty,
    1 => _intention != null,
    _ => _wishController.text.trim().length > 3 && !_weaving,
  };

  Future<void> _advance() async {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final intention = _intention ?? Intention.career;
    final wish = _wishController.text.trim();

    final profile = UserProfile.empty().copyWith(
      name: _nameController.text.trim(),
      intentions: {intention},
      // The wish is the profile's aspiration too — it is the one line that
      // makes every later story sound like this person.
      aspiration: wish,
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
        intention: intention,
        scene: wish,
        // The provider is still empty; hand the generator the profile
        // directly rather than letting it read one that has not landed.
        profile: profile,
      );
    } finally {
      // Even if the story failed, the answers were given and saved — sending
      // the user back through three questions to try again would be a second
      // insult.
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
                const SizedBox(height: AstraSpacing.lg),
                const Wordmark('Astra'),
                const SizedBox(height: AstraSpacing.xl),
                AstraProgressBar(value: (_step + 1) / _stepCount),
                const SizedBox(height: AstraSpacing.xl),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => _NameStep(
                          controller: _nameController,
                          onChanged: () => setState(() {}),
                        ),
                        1 => _IntentionStep(
                          selected: _intention,
                          onPick: (intention) =>
                              setState(() => _intention = intention),
                        ),
                        _ => _WishStep(
                          controller: _wishController,
                          name: _nameController.text.trim(),
                          intention: _intention ?? Intention.career,
                          onChanged: () => setState(() {}),
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
                if (_step == _stepCount - 1) ...[
                  const SizedBox(height: AstraSpacing.sm),
                  Text(
                    'Free. No card, no account needed.',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small,
                  ),
                ],
                const SizedBox(height: AstraSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('What should Astra call you?', style: AstraTextStyles.display(30)),
      const SizedBox(height: AstraSpacing.sm),
      Text(
        'Your name is spoken inside your stories, so they land as yours.',
        style: AstraTextStyles.bodyDim,
      ),
      const SizedBox(height: AstraSpacing.xl),
      AstraCard(
        child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          textCapitalization: TextCapitalization.words,
          style: AstraTextStyles.body.copyWith(fontSize: 16),
          cursorColor: AstraColors.accent,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: 'First name',
            hintStyle: AstraTextStyles.bodyDim,
          ),
        ),
      ),
    ],
  );
}

/// One choice, not several.
///
/// It used to take a set, which made the next step's examples ambiguous — show
/// the ones for love, or for money, or a shuffle of both? A single pick makes
/// the third step obvious, and more intentions can be added later from Edit
/// desires without anyone having to decide about it here.
class _IntentionStep extends StatelessWidget {
  const _IntentionStep({required this.selected, required this.onPick});

  final Intention? selected;
  final ValueChanged<Intention> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('What are you calling in?', style: AstraTextStyles.display(30)),
      const SizedBox(height: AstraSpacing.sm),
      Text(
        'Pick the one that matters most right now. You can add more later.',
        style: AstraTextStyles.bodyDim,
      ),
      const SizedBox(height: AstraSpacing.xl),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final intention in Intention.values)
            TagChip(
              label: '${intention.glyph}  ${intention.label}',
              selected: intention == selected,
              accent: intention.accent,
              onTap: () => onPick(intention),
            ),
        ],
      ),
    ],
  );
}

/// The wish, with worked examples for the chosen intention and the one piece
/// of advice that changes the output more than anything else.
class _WishStep extends StatelessWidget {
  const _WishStep({
    required this.controller,
    required this.name,
    required this.intention,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String name;
  final Intention intention;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final examples = TrendingManifestations.all
        .where((wish) => wish.intention == intention)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'In your own words' : 'In your own words, $name',
          style: AstraTextStyles.display(30),
        ),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          'Say what you want as if it has already happened. This becomes your '
          'first story.',
          style: AstraTextStyles.bodyDim,
        ),
        const SizedBox(height: AstraSpacing.lg),

        AstraCard(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            maxLines: 4,
            style: AstraTextStyles.body,
            cursorColor: AstraColors.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: examples.isEmpty
                  ? 'I want to lead my own design studio…'
                  : examples.first.wish,
              hintStyle: AstraTextStyles.bodyDim,
            ),
          ),
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
                            'Amounts, places, names, models, dates. '
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

        if (examples.isNotEmpty) ...[
          const SizedBox(height: AstraSpacing.lg),
          Text(
            'POPULAR IN ${intention.label.toUpperCase()}',
            style: AstraTextStyles.eyebrow,
          ),
          const SizedBox(height: AstraSpacing.sm),
          Wrap(
            spacing: AstraSpacing.sm,
            runSpacing: AstraSpacing.sm,
            children: [
              for (final example in examples)
                TagChip(
                  label: example.label,
                  accent: intention.accent,
                  selected: controller.text == example.wish,
                  onTap: () {
                    controller.text = example.wish;
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
