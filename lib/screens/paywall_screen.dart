import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/starfield.dart';

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

    return Scaffold(
      body: Starfield(
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
                  "You've heard your first story. Free, as promised.",
                  style: AstraTextStyles.display(26),
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
                  'Unlimited stories and listening · all voices · offline '
                  'downloads · journal insights',
                  style: AstraTextStyles.small,
                ),
                const SizedBox(height: AstraSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 15, color: AstraColors.good),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Prices are always shown per billing period. Nothing '
                        'monthly that charges weekly.',
                        style: AstraTextStyles.small
                            .copyWith(color: AstraColors.good),
                      ),
                    ),
                  ],
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
                  label: 'Keep the free plan',
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
    borderColor: selected ? AstraColors.gold : AstraColors.line,
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
