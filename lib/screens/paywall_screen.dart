import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// Shown only after the user has heard a full story, never before.
///
/// Prices come from [plansProvider], which resolves the user's region — India
/// sees rupees, everywhere else sees dollars. Every amount is printed with the
/// period it bills on, and the yearly option prints its own monthly equivalent
/// so no comparison requires arithmetic.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Plan? _chosen;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);
    final selected = _chosen ??
        plans.firstWhere((p) => p.popular, orElse: () => plans.first);

    final profile = ref.watch(profileProvider);

    // Three states, not two: the free day is on offer, running, or spent.
    // Announcing a day that is already gone reads as bait, and announcing one
    // that is already running reads as an app that lost count.
    final trialOffered = !profile.trialStarted;
    final trialSpent = profile.trialStarted && !profile.trialActive;

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AstraSpacing.lg),
                const Wordmark('Astra Plus'),
                const SizedBox(height: AstraSpacing.xl),
                Text(
                  trialSpent
                      ? "You've had your free day. No card asked for, as promised."
                      : trialOffered
                          ? 'Take a free day first.'
                          : 'Your free day is running.',
                  style: AstraTextStyles.display(26),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  trialSpent
                      ? 'Pick a plan to keep writing them.'
                      : trialOffered
                          ? '${PricingCatalog.trialStories} more stories over '
                                'the next 24 hours, free, with no card and no '
                                'account. The day only starts when you say so.'
                          : '${_hoursLeft(profile.trialRemaining)} left on your '
                                'free day.',
                  style: AstraTextStyles.bodyDim,
                ),
                const SizedBox(height: AstraSpacing.xl),

                for (final plan in plans) ...[
                  _PlanTile(
                    plan: plan,
                    selected: plan.id == selected.id,
                    onTap: () => setState(() => _chosen = plan),
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                ],

                const SizedBox(height: AstraSpacing.sm),
                Text(
                  '${PricingCatalog.plusMonthlyStories} stories a month · unlimited listening · '
                  'all voices · everything you keep, kept',
                  style: AstraTextStyles.small,
                ),

                const Spacer(),
                AstraButton(
                  label: 'Start Astra Plus — ${selected.headline}',
                  onPressed: () async {
                    // Play Billing lands here; until then the plan is granted
                    // locally so the rest of the app can be exercised.
                    await ref.read(profileProvider.notifier).subscribe();
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: AstraSpacing.sm),
                AstraGhostButton(
                  // The way out is always visible, and it is worded as the
                  // thing the user actually gets rather than as a refusal.
                  //
                  // When the free day is still on offer this is the button
                  // most people should press, and pressing it returns true —
                  // it unlocks the generation they were trying to start, so
                  // starting the trial and using it are one tap, not two.
                  label: trialOffered
                      ? 'Start my free day'
                      : trialSpent
                          ? 'Maybe later'
                          : 'Keep going on my free day',
                  onPressed: () async {
                    if (trialOffered) {
                      await ref.read(profileProvider.notifier).startTrial();
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop(trialOffered || !trialSpent);
                    }
                  },
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

/// "18 hours" / "40 minutes" — whichever is the honest unit for what is left.
String _hoursLeft(Duration remaining) {
  if (remaining.inHours >= 1) {
    final hours = remaining.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  }
  final minutes = remaining.inMinutes;
  return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
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
              Text(plan.headline, style: AstraTextStyles.price),
              const SizedBox(height: 2),
              Text(plan.subline, style: AstraTextStyles.small),
            ],
          ),
        ),
        if (plan.badge != null)
          TagChip(label: plan.badge!, selected: selected)
        else if (plan.popular)
          TagChip(label: 'Popular', selected: selected),
      ],
    ),
  );
}
