import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/affirmation_set.dart';
import '../models/wish_text.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import 'desire_flow_screen.dart';
import 'player_screen.dart';

/// Five lines a person can actually believe, written for one goal.
///
/// The same shape as the manifestation box on Home — type the goal, decide
/// whether Maya should use what it knows about you, press the button — because
/// they are the same decision and two different arrangements of it would be two
/// things to learn.
///
/// What differs is the writing. A manifestation is a scene to listen to; these
/// are sentences to say. The brief behind them is built around believability
/// rather than vividness: an affirmation that overshoots does not inspire, it
/// produces resistance, because the person saying it knows it is not true.
class AffirmationsScreen extends ConsumerStatefulWidget {
  const AffirmationsScreen({super.key});

  @override
  ConsumerState<AffirmationsScreen> createState() => _AffirmationsScreenState();
}

class _AffirmationsScreenState extends ConsumerState<AffirmationsScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  /// Whether there is a goal in the box, rather than enough characters in it.
  bool get _ready => looksMeaningful(_controller.text);

  /// Opens the four questions written for whatever was just typed.
  ///
  /// The same flow Home uses, entered on affirmations rather than on a
  /// manifestation. Both come out of the same four answers, and the last step
  /// lets either be swapped for the other — or for both — so asking the
  /// questions twice never happens.
  Future<void> _write() async {
    if (!_ready || _busy) return;

    final goal = _controller.text.trim();
    unawaited(ref.read(trackingProvider).log('wish_typed', wish: goal));

    // No paywall here, and no cap. Affirmations are free to everybody.
    //
    // They are the habit rather than the product: five lines somebody says in
    // the morning, costing well under a cent to write. Charging for those was
    // charging for the part that brings people back, while the thing that
    // actually costs money — a four-minute narration — stays behind the plan.
    // The server agrees; it stopped checking too.

    setState(() => _busy = true);

    final made = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DesireFlowScreen(
          desire: goal,
          initialChoice: MakeChoice.affirmations,
        ),
      ),
    );

    if (!mounted) return;
    if (made == true) _controller.clear();
    setState(() => _busy = false);
  }


  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final sets = ref.watch(affirmationSetsProvider);

    return ListView(
      padding: AstraSpacing.screenPadding,
      children: [
        const SizedBox(height: AstraSpacing.lg),
        Text('AFFIRMATIONS', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.xs),
        Text(
          profile.name.isEmpty
              ? 'What are you working towards?'
              : '${profile.name}, what are you working towards?',
          style: AstraTextStyles.display(26),
        ),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          'Five lines you can say and believe.',
          style: AstraTextStyles.bodyDim,
        ),
        const SizedBox(height: AstraSpacing.lg),

        AstraCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                style: AstraTextStyles.body,
                cursorColor: AstraColors.accent,
                minLines: 3,
                maxLines: 6,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'I want to become a millionaire…',
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
              Text(
                _ready
                    ? 'Maya will ask you four things about this'
                    : 'Write it in your own words — "I want to feel calm"',
                style: AstraTextStyles.small.copyWith(color: AstraColors.dim),
              ),


              const SizedBox(height: AstraSpacing.lg),
              AstraButton(
                label: '✨  Continue',
                busy: _busy,
                onPressed: _busy || !_ready ? null : _write,
              ),
            ],
          ),
        ),

        const SizedBox(height: AstraSpacing.xxl),
        Text('YOURS', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.sm),

        sets.when(
          loading: () => Text('Loading…', style: AstraTextStyles.small),
          error: (error, _) => Text(
            'Could not load your affirmations — $error',
            style: AstraTextStyles.small,
          ),
          data: (list) => list.isEmpty
              ? Text(
                  'Nothing yet. Write your first five above — they arrive on '
                  'your phone each morning and night.',
                  style: AstraTextStyles.small,
                )
              : Column(
                  children: [
                    for (final set in list) ...[
                      _SetCard(
                        set: set,
                        onPlay: () async {
                          final playback = ref.read(playbackProvider);
                          final navigator = Navigator.of(context);
                          // Opened, not started: pressing play is the user's
                          // call. Loop is switched on because a set is meant to
                          // be heard again and again.
                          await playback.open(set.asStory());
                          if (!playback.state.looping) {
                            await playback.toggleLoop();
                          }
                          unawaited(
                            navigator.push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PlayerScreen(),
                              ),
                            ),
                          );
                        },
                        onDelete: () async {
                          final sure = await confirmDelete(
                            context,
                            'Delete these affirmations?',
                          );
                          if (!sure || !mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(affirmationServiceProvider)
                                .delete(set.id);
                            ref.invalidate(affirmationSetsProvider);
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not delete — try again ($error).',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: AstraSpacing.sm),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AstraSpacing.xxl),
      ],
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({
    required this.set,
    required this.onDelete,
    required this.onPlay,
  });

  final AffirmationSet set;
  final Future<void> Function() onPlay;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                set.goal,
                style: AstraTextStyles.small,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (set.hasAudio)
              IconButton(
                onPressed: onPlay,
                tooltip: 'Play and loop',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 24,
                  color: AstraColors.accent,
                ),
              ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AstraColors.dim,
              ),
            ),
          ],
        ),
        const SizedBox(height: AstraSpacing.sm),
        for (final line in set.lines) ...[
          Text(line, style: AstraTextStyles.body),
          const SizedBox(height: AstraSpacing.sm),
        ],
      ],
    ),
  );
}
