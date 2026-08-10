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

    // How many of the free stories are gone. This screen only ever opens
    // because someone ran out, but the number is still worth printing: it is
    // the difference between "you have hit a wall" and "you have used the
    // three you were given".
    final used = ref.watch(usageProvider).used;

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
                  used >= PricingCatalog.freeStories
                      ? "You've used your ${PricingCatalog.freeStories} free "
                            'stories.'
                      : 'Keep writing.',
                  style: AstraTextStyles.display(26),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  'No card was asked for, as promised. Astra Plus writes '
                  '${PricingCatalog.plusMonthlyStories} a month, and the '
                  'stories you already have replay for nothing, forever.',
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
                  // The way out stays visible, and it is worded as what the
                  // user keeps rather than as a refusal. It returns false:
                  // there is no free generation left to unlock, and a button
                  // that dismissed the screen and then wrote a story anyway
                  // would make the limit a suggestion.
                  label: 'Not now',
                  onPressed: () => Navigator.of(context).pop(false),
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
