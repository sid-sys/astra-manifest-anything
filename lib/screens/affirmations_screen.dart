import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/affirmations.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';

/// A deck of affirmations, kept or discarded one at a time.
///
/// Swipe right to keep, left to drop. Both answers feed back into the deck:
/// what gets kept decides which life areas come up next, and nothing already
/// decided on is offered again. A card at a time rather than a scrolling list
/// because an affirmation you skim past is one you did not read.
class AffirmationsScreen extends ConsumerStatefulWidget {
  const AffirmationsScreen({super.key});

  @override
  ConsumerState<AffirmationsScreen> createState() => _AffirmationsScreenState();
}

class _AffirmationsScreenState extends ConsumerState<AffirmationsScreen>
    with SingleTickerProviderStateMixin {
  /// How far the top card has been dragged, in pixels.
  Offset _drag = Offset.zero;

  /// Distance past which releasing counts as a decision rather than a nudge.
  static const _threshold = 96.0;

  void _decide(String line, {required bool liked}) {
    final taste = ref.read(tasteProvider.notifier);
    liked ? taste.like(line) : taste.pass(line);
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(affirmationDeckProvider);
    final taste = ref.watch(tasteProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark('Affirmations', align: TextAlign.left),
              const SizedBox(height: AstraSpacing.lg),
              Text('Keep what fits', style: AstraTextStyles.display(28)),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                deck.isEmpty
                    ? '${taste.liked.length} kept'
                    : 'Swipe right to keep, left to pass. '
                          '${deck.length} left.',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),

        Expanded(
          child: deck.isEmpty
              ? _DeckEmpty(
                  kept: taste.liked.length,
                  onReshuffle: ref.read(tasteProvider.notifier).reshuffle,
                )
              : _Deck(
                  deck: deck,
                  drag: _drag,
                  threshold: _threshold,
                  onDragUpdate: (delta) => setState(() => _drag += delta),
                  onDragEnd: () {
                    if (_drag.dx.abs() < _threshold) {
                      setState(() => _drag = Offset.zero);
                      return;
                    }
                    _decide(deck.first.line, liked: _drag.dx > 0);
                  },
                ),
        ),

        if (deck.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DecisionButton(
                  icon: Icons.close_rounded,
                  color: AstraColors.dim,
                  tooltip: 'Pass',
                  onTap: () => _decide(deck.first.line, liked: false),
                ),
                const SizedBox(width: AstraSpacing.xl),
                _DecisionButton(
                  icon: Icons.favorite_rounded,
                  color: AstraColors.accent,
                  tooltip: 'Keep',
                  onTap: () => _decide(deck.first.line, liked: true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The card stack. Only the top card moves; the one behind it sits slightly
/// smaller so the pile reads as a pile.
class _Deck extends StatelessWidget {
  const _Deck({
    required this.deck,
    required this.drag,
    required this.threshold,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final List<Affirmation> deck;
  final Offset drag;
  final double threshold;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final top = deck.first;
    final beneath = deck.length > 1 ? deck[1] : null;

    // Rotation follows the drag, capped so the card tilts rather than spins.
    final angle = (drag.dx / 1400).clamp(-0.12, 0.12);
    final decided = drag.dx.abs() / threshold;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AstraSpacing.lg, 20, AstraSpacing.lg),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (beneath != null)
            Transform.scale(
              scale: 0.94,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _Card(card: beneath, faded: true),
              ),
            ),
          GestureDetector(
            onPanUpdate: (details) => onDragUpdate(details.delta),
            onPanEnd: (_) => onDragEnd(),
            child: Transform.translate(
              offset: drag,
              child: Transform.rotate(
                angle: angle,
                child: _Card(
                  card: top,
                  // The verdict shows on the card itself while dragging, so
                  // the user knows which way they are committing before they
                  // let go rather than after.
                  verdict: decided < 0.35
                      ? null
                      : (drag.dx > 0 ? _Verdict.keep : _Verdict.pass),
                  verdictStrength: decided.clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Verdict { keep, pass }

class _Card extends StatelessWidget {
  const _Card({
    required this.card,
    this.faded = false,
    this.verdict,
    this.verdictStrength = 0,
  });

  final Affirmation card;
  final bool faded;
  final _Verdict? verdict;
  final double verdictStrength;

  @override
  Widget build(BuildContext context) {
    final accent = switch (verdict) {
      _Verdict.keep => AstraColors.accent,
      _Verdict.pass => AstraColors.dim,
      null => card.intention.accent.withValues(alpha: 0.35),
    };

    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AstraColors.cardRaised, AstraColors.card],
          ),
          border: Border.all(color: accent, width: verdict == null ? 1 : 2),
          borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    card.intention.glyph,
                    style: TextStyle(fontSize: 24, color: card.intention.accent),
                  ),
                  const Spacer(),
                  if (verdict != null)
                    Opacity(
                      opacity: verdictStrength,
                      child: Text(
                        verdict == _Verdict.keep ? 'KEEP' : 'PASS',
                        style: AstraTextStyles.eyebrow.copyWith(
                          color: verdict == _Verdict.keep
                              ? AstraColors.accent
                              : AstraColors.dim,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(
                    card.line,
                    style: AstraTextStyles.quote.copyWith(
                      fontSize: 21,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              Text(
                card.intention.label.toUpperCase(),
                style: AstraTextStyles.eyebrow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckEmpty extends StatelessWidget {
  const _DeckEmpty({required this.kept, required this.onReshuffle});

  final int kept;
  final VoidCallback onReshuffle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: AstraSpacing.screenPadding,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('✦', style: TextStyle(fontSize: 34, color: AstraColors.accent)),
        const SizedBox(height: AstraSpacing.lg),
        Text(
          kept == 0 ? 'Nothing kept yet' : 'You have been through them all',
          textAlign: TextAlign.center,
          style: AstraTextStyles.display(22),
        ),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          kept == 0
              ? 'Swipe through the deck and keep the ones that land.'
              : '$kept kept. They are in your profile, and the one on Home '
                    'comes from them.',
          textAlign: TextAlign.center,
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.xl),
        AstraGhostButton(label: 'Show the passed ones again', onPressed: onReshuffle),
      ],
    ),
  );
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AstraColors.cardRaised,
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Icon(icon, size: 26, color: color),
        ),
      ),
    ),
  );
}
