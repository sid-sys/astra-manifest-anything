import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/affirmations.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';

/// A deck of affirmations, swiped through one at a time.
///
/// A deck rather than a list on purpose: one line at a time is the whole point
/// of an affirmation, and a scrolling list invites skimming past all of them.
class AffirmationsScreen extends ConsumerStatefulWidget {
  const AffirmationsScreen({super.key});

  @override
  ConsumerState<AffirmationsScreen> createState() => _AffirmationsScreenState();
}

class _AffirmationsScreenState extends ConsumerState<AffirmationsScreen> {
  final _controller = PageController(viewportFraction: 0.86);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final cards = Affirmations.deck(profile.intentions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark('Affirmations', align: TextAlign.left),
              const SizedBox(height: AstraSpacing.lg),
              Text('Say one out loud', style: AstraTextStyles.display(28)),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                'Swipe through the deck. ${_index + 1} of ${cards.length}.',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),

        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _AffirmationCard(card: cards[index]),
            ),
          ),
        ),

        const SizedBox(height: AstraSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? AstraColors.gold : AstraColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),

        const SizedBox(height: AstraSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AstraGhostButton(
            label: 'Start over',
            onPressed: () => _controller.animateToPage(
              0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
            ),
          ),
        ),
      ],
    );
  }
}

class _AffirmationCard extends StatelessWidget {
  const _AffirmationCard({required this.card});

  final Affirmation card;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AstraColors.cardRaised, AstraColors.card],
      ),
      border: Border.all(color: card.intention.accent.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.intention.glyph,
            style: TextStyle(fontSize: 26, color: card.intention.accent),
          ),
          const SizedBox(height: AstraSpacing.lg),
          Expanded(
            child: Center(
              child: Text(
                card.line,
                style: AstraTextStyles.quote.copyWith(fontSize: 19, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AstraSpacing.lg),
          Text(
            card.intention.label.toUpperCase(),
            style: AstraTextStyles.eyebrow,
          ),
        ],
      ),
    ),
  );
}
