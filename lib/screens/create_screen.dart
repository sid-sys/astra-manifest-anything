import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../services/story_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/starfield.dart';
import 'story_flow.dart';

const _moods = ['Calm', 'Cinematic', 'Tender'];
const _lengths = [5, 7, 10];

/// Where a story gets made. Everything on this screen is a knob the generator
/// actually reads — intention, the scene in the user's words, length, voice
/// and mood.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _sceneController = TextEditingController();

  Intention? _intention;
  int _lengthMinutes = 7;
  String _voice = astraVoices.first;
  String _mood = _moods.first;
  bool _weaving = false;

  @override
  void dispose() {
    _sceneController.dispose();
    super.dispose();
  }

  Future<void> _weave() async {
    if (_weaving) return;
    setState(() => _weaving = true);

    final profile = ref.read(profileProvider);
    final made = await weaveStory(
      context,
      ref,
      intention: _intention ??
          (profile.intentions.isEmpty ? Intention.career : profile.intentions.first),
      scene: _sceneController.text,
      mood: _mood,
      length: Duration(minutes: _lengthMinutes),
      voice: _voice,
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
                      onTap: () => setState(() => _intention = intention),
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
              Text('A moment you want to live', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.sm),
              TextField(
                controller: _sceneController,
                maxLines: 4,
                style: AstraTextStyles.body,
                cursorColor: AstraColors.gold,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText:
                      'The morning my studio signs its first big client — '
                      'walking in with my team…',
                  hintStyle: AstraTextStyles.bodyDim,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        Row(
          children: [
            Expanded(
              child: _Picker<int>(
                label: 'Length',
                value: _lengthMinutes,
                options: _lengths,
                display: (m) => '$m min',
                onChanged: (m) => setState(() => _lengthMinutes = m),
              ),
            ),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(
              child: _Picker<String>(
                label: 'Voice',
                value: _voice,
                options: astraVoices,
                display: voiceLabel,
                onChanged: (v) => setState(() => _voice = v),
              ),
            ),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(
              child: _Picker<String>(
                label: 'Mood',
                value: _mood,
                options: _moods,
                display: (m) => m,
                onChanged: (m) => setState(() => _mood = m),
              ),
            ),
          ],
        ),

        const SizedBox(height: AstraSpacing.md),
        Text(
          profile.canGenerateFreely
              ? 'Written from your profile details, so it sounds like your '
                  'life and not a template. Narrated by an AI voice. Writing '
                  'and recording takes about a minute.'
              : 'Astra Plus writes as many stories as you want, whenever you want.',
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.xl),

        AstraButton(
          label: _weaving ? 'Writing and recording…' : 'Weave my story',
          icon: Icons.auto_awesome,
          busy: _weaving,
          onPressed: _weave,
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

/// Compact tap-to-cycle control. Three of these fit a row where three
/// dropdowns would not.
class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.options,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) display;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => AstraCard(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    onTap: () {
      final next = options[(options.indexOf(value) + 1) % options.length];
      onChanged(next);
    },
    child: Column(
      children: [
        Text(label, style: AstraTextStyles.small),
        const SizedBox(height: 2),
        Text(
          display(value),
          style: AstraTextStyles.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
