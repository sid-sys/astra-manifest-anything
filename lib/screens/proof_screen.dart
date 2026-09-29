import 'package:flutter/material.dart';

import '../services/testimonials.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// What other people got, shown between the first story and the price.
///
/// Skips itself when there are no reviews. That is the normal state today and
/// it is deliberate — see [testimonials] for why this list is empty and what
/// belongs in it. A proof screen with invented proof is worse than no proof
/// screen, so this one disappears rather than filling itself in.
class ProofScreen extends StatelessWidget {
  const ProofScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  /// Whether there is anything to show. Callers check this before pushing, so
  /// nobody gets a blank screen with a Continue button on it.
  static bool get hasProof => testimonials.isNotEmpty;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: Padding(
          padding: AstraSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AstraSpacing.lg),
              const Wordmark('Maya'),
              const SizedBox(height: AstraSpacing.xl),
              Text(
                'What people say',
                style: AstraTextStyles.display(28),
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                'From people who kept going after their free stories.',
                style: AstraTextStyles.bodyDim,
              ),
              const SizedBox(height: AstraSpacing.xl),

              Expanded(
                child: ListView.separated(
                  itemCount: testimonials.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AstraSpacing.md),
                  itemBuilder: (_, i) => _ReviewCard(review: testimonials[i]),
                ),
              ),

              AstraButton(label: 'Continue', onPressed: onContinue),
              const SizedBox(height: AstraSpacing.lg),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Testimonial review;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '★' * review.stars.clamp(0, 5),
                style: AstraTextStyles.small.copyWith(
                  color: AstraColors.accent,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text(review.quote, style: AstraTextStyles.body),
              const SizedBox(height: AstraSpacing.sm),
              Text(review.name, style: AstraTextStyles.small),
            ],
          ),
        ),
        const SizedBox(width: AstraSpacing.md),
        if (review.photoAsset != null)
          ClipOval(
            child: Image.asset(
              review.photoAsset!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          )
        else
          GlyphDot(
            glyph: review.name.isEmpty ? '★' : review.name[0].toUpperCase(),
            size: 44,
          ),
      ],
    ),
  );
}
