import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// "4D:21H:22M:20S" — the time left, as the trial counts down to its end.
String formatCountdown(Duration left) {
  final total = left.isNegative ? Duration.zero : left;
  final days = total.inDays;
  final hours = total.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${days}D:${hours}H:${minutes}M:${seconds}S';
}

/// Shown in place of the Continue button once the ten free-trial
/// manifestations are used. It runs down to the moment the trial ends, and
/// calls [onElapsed] there so the screen can unlock itself.
class TrialCountdown extends StatefulWidget {
  const TrialCountdown({super.key, required this.endsAt, this.onElapsed});

  final DateTime endsAt;
  final VoidCallback? onElapsed;

  @override
  State<TrialCountdown> createState() => _TrialCountdownState();
}

class _TrialCountdownState extends State<TrialCountdown> {
  Timer? _ticker;
  late Duration _left;

  Duration _remaining() => widget.endsAt.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _remaining();
      if (!mounted) return;
      setState(() => _left = left);
      if (left <= Duration.zero) {
        _ticker?.cancel();
        widget.onElapsed?.call();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Next manifestation unlocks in ${formatCountdown(_left)}',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AstraColors.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AstraColors.line),
      ),
      child: Column(
        children: [
          Text(
            'NEXT MANIFESTATION UNLOCKS IN',
            textAlign: TextAlign.center,
            style: AstraTextStyles.eyebrow,
          ),
          const SizedBox(height: 8),
          Text(
            formatCountdown(_left),
            style: AstraTextStyles.display(30).copyWith(
              color: AstraColors.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}
