import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/plan.dart';
import '../providers.dart';
import '../services/wish_prompts.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'story_flow.dart';

/// Where a story gets made.
///
/// One field. Length, voice and mood used to sit here as pickers; they were
/// three taps of friction in front of the only input that changes the story,
/// and every story is five minutes now.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _sceneController = TextEditingController();

  Intention? _intention;
  late String _suggestion;
  bool _weaving = false;

  @override
  void initState() {
    super.initState();
    _suggestion = WishPrompts.next(_activeIntention);
  }

  @override
  void dispose() {
    _sceneController.dispose();
    super.dispose();
  }

  Intention get _activeIntention {
    if (_intention != null) return _intention!;
    final chosen = ref.read(profileProvider).intentions;
    return chosen.isEmpty ? Intention.career : chosen.first;
  }

  void _rotateSuggestion() => setState(() {
    _suggestion = WishPrompts.next(_activeIntention, previous: _suggestion);
  });

  Future<void> _weave() async {
    if (_weaving) return;
    setState(() => _weaving = true);

    final made = await weaveStory(
      context,
      ref,
      intention: _activeIntention,
      scene: _sceneController.text,
    );

    if (!mounted) return;
    if (made) _sceneController.clear();
    setState(() => _weaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final intentions = profile.intentions.isEmpty
        ? Intention.values.toSet()
        : profile.intentions;
    final active = _intention ?? intentions.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Wordmark('New Story'),
        const SizedBox(height: AstraSpacing.lg),
        Text('Set the scene', style: AstraTextStyles.display(28)),
        const SizedBox(height: AstraSpacing.xl),

        AstraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Intention', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.md),
              Wrap(
                spacing: AstraSpacing.sm,
                runSpacing: AstraSpacing.sm,
                children: [
                  for (final intention in intentions)
                    TagChip(
                      label: intention.label,
                      selected: intention == active,
                      accent: intention.accent,
                      onTap: () => setState(() {
                        _intention = intention;
                        // The old suggestion belonged to the old intention.
                        _suggestion = WishPrompts.next(intention);
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        WishField(
          controller: _sceneController,
          label: 'What do you want?',
          suggestion: _suggestion,
          onRotate: _rotateSuggestion,
        ),

        const SizedBox(height: AstraSpacing.md),
        Text(
          profile.canGenerateFreely
              ? 'Five minutes, written from your own details so it sounds like '
                  'your life and not a template. Narrated by an AI voice.'
              : 'Astra Plus writes ${PricingCatalog.plusMonthlyStories} stories a month, and your '
                  'library replays without limit.',
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.xl),

        AstraButton(
          label: _weaving ? 'Writing…' : 'Generate',
          icon: Icons.auto_awesome,
          busy: _weaving,
          onPressed: _weave,
        ),
      ],
    );
  }
}

/// The wish box, with a rotating example as its placeholder.
///
/// The example lives in the field rather than in a card beneath it: a
/// suggestion sitting next to the input is one more thing to read and decide
/// about, while a placeholder answers "what goes here?" at the moment the
/// question is asked and vanishes the instant it stops being useful.
class WishField extends StatelessWidget {
  const WishField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestion,
    required this.onRotate,
  });

  final TextEditingController controller;
  final String label;

  /// The example shown when the field is empty. Owned by the caller rather
  /// than picked here: a fallback chosen inside build is not stored anywhere,
  /// so the rotate button cannot know what it is rotating away from.
  final String suggestion;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AstraTextStyles.small)),
            Tooltip(
              message: 'Another idea',
              child: InkWell(
                onTap: onRotate,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AstraColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          style: AstraTextStyles.body,
          cursorColor: AstraColors.accent,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: suggestion,
            hintStyle: AstraTextStyles.bodyDim,
          ),
        ),
      ],
    ),
  );
}

/// [CreateScreen] as a pushable route, with its own background and a way back.
class CreateRoute extends StatelessWidget {
  const CreateRoute({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AstraColors.dim,
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                ),
                const Spacer(),
              ],
            ),
            const Expanded(child: CreateScreen()),
          ],
        ),
      ),
    ),
  );
}
