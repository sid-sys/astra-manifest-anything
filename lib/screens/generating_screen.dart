import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';
import '../widgets/astra_orb.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// Shown while a story is being written.
///
/// It gets a whole screen rather than a spinner on a button because the wait is
/// the better part of a minute — long enough that a button which merely looks
/// busy reads as a hang.
///
/// The bar is an *estimate*, not a measurement, and the class is honest about
/// that below. There is nothing to measure: the request is one call that either
/// returns a finished story or does not, with no progress reported along the
/// way. What the bar is really for is answering "is this thing still alive",
/// and for that a moving line beats a spinning circle, which looks identical at
/// five seconds and at five minutes.
class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({super.key, this.onCancel});

  /// Called when the user gives up. Null means no cancel button — used where
  /// there is nothing sensible to go back to.
  final VoidCallback? onCancel;

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> {
  /// What a story usually takes. Measured, not guessed: the script is around
  /// 900 words and lands in roughly this long on a normal connection.
  static const _expected = Duration(seconds: 90);

  Timer? _tick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 250));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Approaches 1 without ever reaching it.
  ///
  /// A bar that fills completely and then sits there is worse than no bar: it
  /// says the work is done when it plainly is not, and every extra second after
  /// that reads as a freeze. So the last stretch slows down instead — past the
  /// expected time it keeps creeping, and it only ever hits the end when the
  /// story actually arrives and this screen is removed.
  double get _progress {
    final ratio = _elapsed.inMilliseconds / _expected.inMilliseconds;
    if (ratio < 0.9) return ratio;

    // Beyond 90%, each further expected-duration's worth of waiting covers half
    // the remaining distance.
    final over = ratio - 0.9;
    return 0.9 + 0.1 * (1 - 1 / (1 + over));
  }

  String get _clock {
    final seconds = _elapsed.inSeconds;
    return seconds < 60
        ? '${seconds}s'
        : '${seconds ~/ 60}m ${(seconds % 60).toString().padLeft(2, '0')}s';
  }

  /// Changes twice, so a long wait does not look like a stuck one.
  String get _stage {
    if (_elapsed < const Duration(seconds: 12)) return 'Reading your answers';
    if (_elapsed < const Duration(seconds: 40)) return 'Writing your story';
    if (_elapsed < _expected) return 'Recording the narration';
    return 'Nearly there';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // The hardware back button stays off even now that there is a cancel.
    // Backing out by reflex mid-generation used to orphan the story — the
    // function keeps running and the writing is paid for either way — so
    // leaving is a decision made on the button below, not a swipe.
    canPop: false,
    child: Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              children: [
                const Spacer(),

                // The orb, during the wait it was made for.
                const AstraOrb(size: 170),
                const SizedBox(height: AstraSpacing.xxl),

                Text(
                  _stage,
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.display(26),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  'About a minute and a half. Maya writes the story, then '
                  'records it, and opens when it is ready to play.',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.small,
                ),
                const SizedBox(height: AstraSpacing.xl),

                AstraProgressBar(value: _progress.clamp(0.0, 1.0), height: 6),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  _clock,
                  style: AstraTextStyles.small.copyWith(
                    color: AstraColors.dim,
                  ),
                ),

                const Spacer(),

                if (widget.onCancel != null) ...[
                  AstraGhostButton(
                    label: 'Cancel',
                    onPressed: widget.onCancel,
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                  Text(
                    // Said plainly, because it is the one thing the user cannot
                    // see: the server does not stop when this screen closes.
                    'Cancelling closes this screen. The story finishes writing '
                    'and appears in your library.',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small,
                  ),
                  const SizedBox(height: AstraSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
