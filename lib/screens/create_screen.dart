import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../services/wish_prompts.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/starfield.dart';
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
  String? _suggestion;
  bool _weaving = false;

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
                        _suggestion = null;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        AstraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What do you want?', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.sm),
              TextField(
                controller: _sceneController,
                maxLines: 4,
                style: AstraTextStyles.body,
                cursorColor: AstraColors.gold,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'In your own words…',
                  hintStyle: AstraTextStyles.bodyDim,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.sm),

        WishSuggestion(
          intention: active,
          suggestion: _suggestion,
          onRotate: _rotateSuggestion,
          onUse: (wish) => setState(() {
            _sceneController.text = wish;
            _sceneController.selection = TextSelection.collapsed(
              offset: wish.length,
            );
          }),
        ),

        const SizedBox(height: AstraSpacing.md),
        Text(
          profile.canGenerateFreely
              ? 'Five minutes, written from your own details so it sounds like '
                  'your life and not a template. Narrated by an AI voice.'
              : 'Astra Plus writes 15 stories a month, and your library '
                  'replays without limit.',
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.xl),

        AstraButton(
          label: _weaving ? 'Writing…' : 'Weave my story',
          icon: Icons.auto_awesome,
          busy: _weaving,
          onPressed: _weave,
        ),
      ],
    );
  }
}

/// A starter wish plus the button that swaps it for another.
///
/// Shared with Home so both boxes offer the same help. Tapping the wish fills
/// the field rather than submitting it — it is a starting point to edit, not a
/// choice to make.
class WishSuggestion extends StatelessWidget {
  const WishSuggestion({
    super.key,
    required this.intention,
    required this.suggestion,
    required this.onRotate,
    required this.onUse,
  });

  final Intention intention;
  final String? suggestion;
  final VoidCallback onRotate;
  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context) {
    final wish = suggestion ?? WishPrompts.next(intention);

    return Row(
      children: [
        Expanded(
          child: AstraCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            onTap: () => onUse(wish),
            child: Row(
              children: [
                Text(
                  intention.glyph,
                  style: TextStyle(fontSize: 14, color: intention.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    wish,
                    style: AstraTextStyles.bodyDim.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AstraSpacing.sm),
        Tooltip(
          message: 'Another idea',
          child: InkWell(
            onTap: onRotate,
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AstraColors.cardRaised,
                border: Border.all(color: AstraColors.line),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 19,
                color: AstraColors.gold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// [CreateScreen] as a pushable route, with its own background and a way back.
class CreateRoute extends StatelessWidget {
  const CreateRoute({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Starfield(
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
