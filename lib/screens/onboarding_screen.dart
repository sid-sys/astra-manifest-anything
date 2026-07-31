import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/user_profile.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/starfield.dart';

/// Three questions, then the app. The free-story promise is stated on every
/// step so nobody hands over personal details without knowing what they get
/// before any payment screen appears.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 3;

  final _nameController = TextEditingController();
  final _aspirationController = TextEditingController();
  final _selected = <Intention>{};

  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _aspirationController.dispose();
    super.dispose();
  }

  bool get _canAdvance => switch (_step) {
    0 => _nameController.text.trim().isNotEmpty,
    1 => _selected.isNotEmpty,
    _ => true,
  };

  Future<void> _advance() async {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }

    final profile = UserProfile.empty().copyWith(
      name: _nameController.text.trim(),
      intentions: _selected,
      aspiration: _aspirationController.text.trim(),
    );
    await ref.read(profileProvider.notifier).update(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
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
                        0 => _NameStep(controller: _nameController,
                            onChanged: () => setState(() {})),
                        1 => _IntentionStep(
                            selected: _selected,
                            onToggle: (intention) => setState(() {
                              _selected.contains(intention)
                                  ? _selected.remove(intention)
                                  : _selected.add(intention);
                            }),
                          ),
                        _ => _AspirationStep(
                            controller: _aspirationController,
                            name: _nameController.text.trim(),
                          ),
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 15, color: AstraColors.good),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Your first day is free — before any payment screen.',
                        style: AstraTextStyles.small
                            .copyWith(color: AstraColors.good),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AstraSpacing.md),
                AstraButton(
                  label: _step == _stepCount - 1 ? 'Begin' : 'Continue',
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
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('What should Astra call you?', style: AstraTextStyles.display(28)),
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
          cursorColor: AstraColors.gold,
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

class _IntentionStep extends StatelessWidget {
  const _IntentionStep({required this.selected, required this.onToggle});

  final Set<Intention> selected;
  final ValueChanged<Intention> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('What are you calling in?', style: AstraTextStyles.display(28)),
      const SizedBox(height: AstraSpacing.sm),
      Text(
        'Pick what matters most right now. Your stories are written around it.',
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
              selected: selected.contains(intention),
              accent: intention.accent,
              onTap: () => onToggle(intention),
            ),
        ],
      ),
    ],
  );
}

class _AspirationStep extends StatelessWidget {
  const _AspirationStep({required this.controller, required this.name});

  final TextEditingController controller;
  final String name;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name.isEmpty ? 'In your own words' : 'In your own words, $name',
        style: AstraTextStyles.display(28),
      ),
      const SizedBox(height: AstraSpacing.sm),
      Text(
        'The more specific you are, the more your stories will sound like '
        'your actual life. You can change this any time.',
        style: AstraTextStyles.bodyDim,
      ),
      const SizedBox(height: AstraSpacing.xl),
      AstraCard(
        child: TextField(
          controller: controller,
          maxLines: 5,
          style: AstraTextStyles.body,
          cursorColor: AstraColors.gold,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText:
                'I want to lead my own design studio and feel calm about money…',
            hintStyle: AstraTextStyles.bodyDim,
          ),
        ),
      ),
    ],
  );
}
