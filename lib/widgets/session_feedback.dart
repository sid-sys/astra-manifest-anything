import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';

/// How someone felt after listening.
enum SessionMood {
  anxious('Anxious', '😔'),
  stressed('Stressed', '😟'),
  calm('Calm', '😐'),
  confident('Confident', '🙂'),
  empowered('Empowered', '😄');

  const SessionMood(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Asks how the session landed — sometimes.
///
/// Shown after roughly one session in three rather than every time, and the
/// randomness is the whole design. A question asked after every listen stops
/// being a question: people learn the shape of it and tap the middle one to
/// make it go away, which is worse than no data because it looks like data.
///
/// It is also never in the way. It appears under the player after the audio
/// has finished, it can be ignored, and answering dismisses it. Nothing is
/// gated on it.
class SessionFeedback extends ConsumerStatefulWidget {
  const SessionFeedback({super.key, required this.about});

  /// What was listened to — a story id or a manifestation id. Stored with the
  /// answer so a mood can be traced back to the thing that produced it.
  final String about;

  /// The share of finished sessions that get asked. One in three.
  static const askRate = 0.34;

  /// Whether to ask at all this time.
  ///
  /// Rolled once per session by the caller, not read here, so a rebuild of the
  /// player cannot re-roll it and make the card flicker in and out.
  static bool shouldAsk([Random? random]) =>
      (random ?? Random()).nextDouble() < askRate;

  @override
  ConsumerState<SessionFeedback> createState() => _SessionFeedbackState();
}

class _SessionFeedbackState extends ConsumerState<SessionFeedback> {
  SessionMood? _chosen;

  Future<void> _answer(SessionMood mood) async {
    setState(() => _chosen = mood);
    await ref.read(repositoryProvider).recordSessionMood(
      about: widget.about,
      mood: mood.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chosen != null) {
      return AstraCard(
        child: Row(
          children: [
            Text(_chosen!.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(
              child: Text(
                'Noted. Thank you.',
                style: AstraTextStyles.bodyDim,
              ),
            ),
          ],
        ),
      );
    }

    return AstraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How do you feel after that?', style: AstraTextStyles.label),
          const SizedBox(height: 2),
          Text(
            'One tap. It shapes what Mayow writes you next.',
            style: AstraTextStyles.small,
          ),
          const SizedBox(height: AstraSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final mood in SessionMood.values)
                _MoodButton(mood: mood, onTap: () => _answer(mood)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.onTap});

  final SessionMood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: mood.label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mood.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(mood.label, style: AstraTextStyles.small),
          ],
        ),
      ),
    ),
  );
}
