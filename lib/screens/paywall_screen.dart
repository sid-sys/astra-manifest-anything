import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/plan.dart';
import '../providers.dart';
import '../services/billing_service.dart';
import '../services/legal_links.dart';
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
  bool _busy = false;
  String? _error;

  /// What the store says these cost, keyed by product id. Empty until the
  /// store answers, and empty forever on web or a device without Play — the
  /// local table in [PricingCatalog] renders the tiles either way, so the
  /// screen is never blank waiting on a network call.
  Map<String, ProductDetails> _storePrices = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrices());
  }

  Future<void> _loadPrices() async {
    final billing = ref.read(billingServiceProvider);
    if (!await billing.isAvailable) return;

    try {
      final products = await billing.loadProducts();
      if (!mounted) return;
      setState(() {
        _storePrices = {for (final p in products) p.id: p};
      });
    } catch (error) {
      debugPrint('Astra: could not load store prices — $error');
    }
  }

  /// The store id for a plan from the local catalogue.
  String _productIdFor(Plan plan) => plan.period == BillingPeriod.year
      ? BillingService.yearlyId
      : BillingService.monthlyId;

  Future<void> _subscribe(Plan plan) async {
    final billing = ref.read(billingServiceProvider);
    final navigator = Navigator.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!await billing.isAvailable) {
        throw const _BillingUnavailable();
      }

      final product = _storePrices[_productIdFor(plan)];
      if (product == null) {
        throw const _BillingUnavailable();
      }

      final bought = await billing.buy(product);
      if (!mounted) return;

      if (bought) {
        // Nothing is written here. The server has already recorded the
        // entitlement from the receipt, and `entitlementProvider` is watching
        // that document — by the time this pops, the app already knows.
        navigator.pop(true);
        return;
      }

      setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is _BillingUnavailable
            ? 'Purchases are not available on this device yet.'
            : 'That did not go through. You have not been charged.';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(billingServiceProvider).restore();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ref.read(isSubscribedProvider)
            ? null
            : 'No previous purchase found for this account.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reach the store. Try again in a moment.';
      });
    }
  }

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
                    // The store's price when it has answered, the local table
                    // when it has not. Play's number is the one that will be
                    // charged — right currency, right tax, right country — so
                    // it wins wherever it exists.
                    storePrice: _storePrices[_productIdFor(plan)]?.price,
                    onTap: _busy
                        ? null
                        : () => setState(() => _chosen = plan),
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                ],

                const SizedBox(height: AstraSpacing.sm),
                Text(
                  '${PricingCatalog.plusMonthlyStories} stories a month · unlimited listening · '
                  'all voices · everything you keep, kept',
                  style: AstraTextStyles.small,
                ),

                if (_error != null) ...[
                  const SizedBox(height: AstraSpacing.md),
                  Text(
                    _error!,
                    style: AstraTextStyles.small.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                const Spacer(),
                AstraButton(
                  label: 'Start Astra Plus — '
                      '${_storePrices[_productIdFor(selected)]?.price ?? selected.headline}',
                  busy: _busy,
                  onPressed: _busy ? null : () => _subscribe(selected),
                ),
                const SizedBox(height: AstraSpacing.sm),
                AstraGhostButton(
                  // The way out stays visible, and it is worded as what the
                  // user keeps rather than as a refusal. It returns false:
                  // there is no free generation left to unlock, and a button
                  // that dismissed the screen and then wrote a story anyway
                  // would make the limit a suggestion.
                  label: 'Not now',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Center(
                  child: TextButton(
                    // Required by Play, and needed regardless: a subscription
                    // lives on the Google account, not the phone, so without
                    // this a paying user who reinstalls lands in the free tier.
                    onPressed: _busy ? null : _restore,
                    child: Text(
                      'Restore a purchase',
                      style: AstraTextStyles.small.copyWith(
                        color: AstraColors.accent,
                      ),
                    ),
                  ),
                ),

                // The renewal terms, said plainly, on the screen that takes the
                // money — not buried in a policy page nobody opens. Play
                // requires the disclosure; the app this one is modelled on was
                // reviewed hardest for a price whose period was not obvious.
                Text(
                  'Renews automatically until you cancel in Google Play. '
                  'Cancelling stops the next payment and you keep Plus until '
                  'the period you have paid for ends.',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.small,
                ),
                const SizedBox(height: AstraSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () =>
                          LegalLinks.open(context, LegalLinks.terms),
                      child: Text(
                        'Terms',
                        style: AstraTextStyles.small.copyWith(
                          color: AstraColors.text,
                        ),
                      ),
                    ),
                    Text('·', style: AstraTextStyles.small),
                    TextButton(
                      onPressed: () =>
                          LegalLinks.open(context, LegalLinks.privacy),
                      child: Text(
                        'Privacy',
                        style: AstraTextStyles.small.copyWith(
                          color: AstraColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AstraSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Signals that the store is not there to sell anything — no Play Services,
/// a web build, or products that have not been published yet.
class _BillingUnavailable implements Exception {
  const _BillingUnavailable();
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
    this.storePrice,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback? onTap;

  /// Play's own formatted price, when the store has answered.
  final String? storePrice;

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
              Text(
                storePrice == null
                    ? plan.headline
                    : '$storePrice / ${plan.periodLabel}',
                style: AstraTextStyles.price,
              ),
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
