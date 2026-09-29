import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/manifestation.dart';
import '../models/question_plan.dart';
import '../providers.dart';
import '../services/affirmation_service.dart';
import '../services/manifest_service.dart';
import '../services/plan_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_orb.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'generating_screen.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';

/// What the user asked for at the end.
enum MakeChoice {
  manifestation('A manifestation', 'A guided read, in your name, about 4 min'),
  affirmations('Five affirmations', 'Short lines to say, sent morning and night'),
  both('Both', 'The read and the five lines, from the same answers');

  const MakeChoice(this.label, this.detail);

  final String label;
  final String detail;

  bool get wantsManifest => this != MakeChoice.affirmations;
  bool get wantsAffirmations => this != MakeChoice.manifestation;
}

/// Desire in, four questions, then whatever they asked for.
///
/// One screen for the whole thing rather than a route per step: the four
/// questions arrive together in a single answer from the server, so paging
/// between them is a local index rather than navigation, and a back button that
/// unwinds real routes would let somebody arrive at question three with the
/// plan already thrown away.
class DesireFlowScreen extends ConsumerStatefulWidget {
  const DesireFlowScreen({
    super.key,
    required this.desire,
    this.initialChoice = MakeChoice.manifestation,
  });

  final String desire;

  /// What the entry point was for. Home opens on a manifestation, the Affirm
  /// tab on affirmations, and either can be changed on the last step — the two
  /// come from the same four answers, so making the second one afterwards
  /// would be asking the same questions twice.
  final MakeChoice initialChoice;

  @override
  ConsumerState<DesireFlowScreen> createState() => _DesireFlowScreenState();
}

class _DesireFlowScreenState extends ConsumerState<DesireFlowScreen> {
  QuestionPlan? _plan;
  String? _error;

  /// One answer per question, by index. Null until picked.
  final _answers = <int, String>{};

  int _step = 0;
  late MakeChoice _choice = widget.initialChoice;
  bool _busy = false;

  /// True while the four questions are being written.
  bool _planning = true;

  @override
  void initState() {
    super.initState();
    unawaited(_plan_());
  }

  Future<void> _plan_() async {
    try {
      final plan = await ref.read(planServiceProvider).forDesire(widget.desire);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _planning = false;
      });
    } on PlanFailed catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _planning = false;
      });
    }
  }

  bool get _onChoice => _plan != null && _step >= _plan!.questions.length;
  bool get _canAdvance => _onChoice || _answers[_step] != null;

  void _next() {
    if (!_canAdvance) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
  }

  /// The four answers, in order, as the writers want them.
  List<String> get _picked => [
    for (var i = 0; i < (_plan?.questions.length ?? 0); i++)
      if (_answers[i] != null) _answers[i]!,
  ];

  Future<void> _make() async {
    if (_busy) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final answers = _picked;

    // Captured before the first await. This screen is removed as soon as the
    // player opens, and a `ModalRoute.of(context)` read afterwards would be
    // asking a dead widget which route it was.
    final self = ModalRoute.of(context)!;

    setState(() => _busy = true);

    var cancelled = false;
    final waiting = MaterialPageRoute<void>(
      builder: (_) => GeneratingScreen(
        onCancel: () {
          cancelled = true;
          navigator.pop();
        },
      ),
    );
    unawaited(navigator.push(waiting));

    try {
      // Affirmations first when both were asked for. They take seconds against
      // the manifestation's minute and a half, so doing them first means the
      // slow half is the last thing waited on rather than the thing that
      // delays the quick one.
      //
      // Always written, even when only a manifestation was asked for. The
      // morning and evening notifications are sent from the newest set, so a
      // person who makes a manifestation should still get their own lines on
      // their phone, not generic ones. They cost a fraction of a cent.
      final tracker = ref.read(trackingProvider);
      if (_choice.wantsAffirmations) {
        unawaited(tracker.log('generate_start', detail: 'affirmations'));
        try {
          await ref
              .read(affirmationServiceProvider)
              .write(widget.desire, answers: answers);
        } catch (error) {
          unawaited(tracker.log('generate_failed', detail: 'affirmations: $error'));
          rethrow;
        }
        unawaited(tracker.log('generate_ok', detail: 'affirmations'));
        ref.invalidate(affirmationSetsProvider);
      } else {
        try {
          await ref
              .read(affirmationServiceProvider)
              .write(widget.desire, answers: answers);
          ref.invalidate(affirmationSetsProvider);
        } catch (error) {
          // The manifestation is what was asked for. Do not lose it over this.
          debugPrint('Maya: companion affirmations skipped — $error');
        }
      }

      if (_choice.wantsManifest) {
        unawaited(tracker.log('generate_start', detail: 'manifest'));
        final Manifestation made;
        try {
          made = await ref
              .read(manifestServiceProvider)
              .write(widget.desire, answers: answers);
        } catch (error) {
          unawaited(tracker.log('generate_failed', detail: 'manifest: $error'));
          rethrow;
        }
        unawaited(tracker.log('generate_ok', detail: 'manifest'));
        ref.invalidate(manifestationsProvider);

        if (cancelled) return;
        navigator.removeRoute(waiting);

        // Straight into it. Everything else pops back to where they started.
        await ref.read(playbackProvider).open(made.asStory());
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
          ),
        );
        navigator.removeRoute(self);
        return;
      }

      if (cancelled) return;
      navigator.removeRoute(waiting);
      navigator.pop(true);
    } on ManifestQuotaExceeded catch (error) {
      _refused(navigator, messenger, cancelled, error.message, waiting);
    } on AffirmQuotaExceeded catch (error) {
      _refused(navigator, messenger, cancelled, error.message, waiting);
    } on ManifestFailed catch (error) {
      if (!cancelled) navigator.removeRoute(waiting);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on AffirmFailed catch (error) {
      if (!cancelled) navigator.removeRoute(waiting);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!cancelled) navigator.removeRoute(waiting);
      debugPrint('Maya: making failed — $error');
      messenger.showSnackBar(
        const SnackBar(
          content: Text("That didn't come through. Try again in a moment."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refused(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    bool cancelled,
    String message,
    ModalRoute<Object?> waiting,
  ) {
    if (!cancelled) navigator.removeRoute(waiting);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    unawaited(
      navigator.push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (_plan?.questions.length ?? 4) + 1;

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AstraSpacing.sm),
                SizedBox(
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Wordmark('Maya'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _Back(onTap: _busy ? null : _back),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AstraSpacing.lg),

                if (!_planning && _error == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _onChoice ? 'ALMOST THERE' : 'ABOUT YOUR WISH',
                          style: AstraTextStyles.eyebrow,
                        ),
                      ),
                      Text(
                        '${_step + 1} OF $total',
                        style: AstraTextStyles.eyebrow.copyWith(
                          color: AstraColors.dim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                  AstraProgressBar(
                    value: (_step + 1) / total,
                    height: 6,
                  ),
                  const SizedBox(height: AstraSpacing.xl),
                ],

                Expanded(child: _body()),

                if (!_planning && _error == null)
                  AstraButton(
                    label: _onChoice ? '✨  Make it' : 'Continue',
                    busy: _busy,
                    onPressed: !_canAdvance || _busy
                        ? null
                        : (_onChoice ? _make : _next),
                  ),
                const SizedBox(height: AstraSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_planning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AstraOrb(size: 150),
            const SizedBox(height: AstraSpacing.xxl),
            Text(
              'Reading your wish…',
              style: AstraTextStyles.display(22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AstraSpacing.sm),
            Text(
              'Maya is working out what to ask you.',
              style: AstraTextStyles.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('That did not work', style: AstraTextStyles.display(24)),
            const SizedBox(height: AstraSpacing.sm),
            Text(_error!, style: AstraTextStyles.bodyDim),
            const SizedBox(height: AstraSpacing.xl),
            AstraGhostButton(
              label: 'Go back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    if (_onChoice) return _choicePage();

    final question = _plan!.questions[_step];
    return ListView(
      children: [
        Text(question.question, style: AstraTextStyles.display(24)),
        const SizedBox(height: AstraSpacing.lg),
        for (final option in question.options) ...[
          _Option(
            label: option,
            selected: _answers[_step] == option,
            onTap: () => setState(() => _answers[_step] = option),
          ),
          const SizedBox(height: AstraSpacing.sm),
        ],
      ],
    );
  }

  Widget _choicePage() => ListView(
    children: [
      Text('What should Maya make?', style: AstraTextStyles.display(24)),
      const SizedBox(height: AstraSpacing.sm),
      Text(
        'Both come from the same four answers, so making the second one later '
        'would only mean answering these again.',
        style: AstraTextStyles.bodyDim,
      ),
      const SizedBox(height: AstraSpacing.lg),
      for (final choice in MakeChoice.values) ...[
        _Option(
          label: choice.label,
          detail: choice.detail,
          selected: _choice == choice,
          onTap: () => setState(() => _choice = choice),
        ),
        const SizedBox(height: AstraSpacing.sm),
      ],
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AstraCard(
    onTap: onTap,
    borderColor: selected ? AstraColors.accent : AstraColors.line,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AstraTextStyles.body),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail!, style: AstraTextStyles.small),
              ],
            ],
          ),
        ),
        if (selected)
          Icon(Icons.check_circle_rounded, color: AstraColors.accent, size: 20),
      ],
    ),
  );
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});

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
        child: Icon(Icons.arrow_back_rounded, size: 18, color: AstraColors.text),
      ),
    ),
  );
}
