import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/plan.dart';
import '../providers.dart';
import '../services/billing_service.dart';
import '../services/legal_links.dart';
import '../services/store_name.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// The plans, and the one place the app asks for money.
///
/// Prices come from [plansProvider], which resolves the user's region — India
/// sees rupees, everywhere else sees dollars. Every amount is printed with the
/// period it bills on, and the yearly option prints its own monthly equivalent
/// so no comparison requires arithmetic.
///
/// [hard] removes the way out. It is set when the screen is the only route
/// forward — after onboarding, before the first story — and left false
/// wherever the screen is reached from a place the user can simply leave, like
/// the plan row in Profile. Restore stays on the screen in both modes: a
/// paying user who reinstalls has to be able to get back in, and on a hard
/// paywall that button is the *only* thing standing between them and a second
/// subscription.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.hard = false, this.onBack});

  /// Shown as a back arrow when there is no route underneath to pop to — the
  /// paywall that stops a new account. It leads back to the questions and
  /// never forward to the app.
  final VoidCallback? onBack;

  /// No "Not now", and no back — the screen cannot be dismissed without
  /// subscribing or restoring.
  final bool hard;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Plan? _chosen;
  bool _busy = false;
  String? _error;

  /// Whether the "your trial ends tomorrow" notice can reach this phone.
  bool _remind = false;

  /// Guards the exits against each other. A purchase pops, and the entitlement
  /// arriving pops, and those are the same event seen from two sides.
  bool _left = false;

  /// Leaves the screen, if there is anywhere to leave to.
  ///
  /// Every exit goes through here, and the `canPop` check is the whole reason
  /// it exists. This screen has two lives: pushed on top of onboarding or
  /// Profile, where popping is right — and installed as the app's *root* by
  /// the subscription check in `app.dart`, where there is nothing underneath
  /// it at all. Popping the root empties the navigator and leaves a black
  /// screen with only the phone's own navigation bar on it, which is exactly
  /// what a successful payment did: the purchase went through, the app popped,
  /// and the user was left staring at nothing.
  ///
  /// Nothing is lost by not popping in that case. The root paywall is shown by
  /// a `ref.watch` on the entitlement, so the moment the subscription lands
  /// that check re-runs on its own and swaps this screen for Home.
  void _leave(bool result) {
    if (_left || !mounted) return;

    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;

    _left = true;
    if (!result) unawaited(ref.read(trackingProvider).log('paywall_close'));
    navigator.pop(result);
  }

  /// What the store will actually charge, keyed by product id. Empty until the
  /// store answers, and empty forever on web or a device without Play — the
  /// local table in [PricingCatalog] renders the tiles either way, so the
  /// screen is never blank waiting on a network call.
  ///
  /// One [StoreOffer] per product rather than one [ProductDetails], because a
  /// product with a trial has several offers and they all share an id. The
  /// service picks between them; this screen only ever sees the winner.
  Map<String, StoreOffer> _storePrices = const {};

  @override
  void initState() {
    super.initState();
    _remind = ref.read(profileProvider).trialPushToken != null;
    unawaited(_loadPrices());
  }

  Future<void> _loadPrices() async {
    try {
      final billing = ref.read(billingServiceProvider);
      if (!await billing.isAvailable) return;

      try {
        final offers = await billing.loadOffers();
        if (!mounted) return;
        setState(() => _storePrices = offers);
      } catch (error) {
        debugPrint('Mayow: could not load store prices — $error');
      }
    } finally {
      // Reported once the store has answered or failed to, so the panel can
      // say whether the trial was actually on screen.
      if (mounted) {
        final plans = ref.read(plansProvider);
        unawaited(
          ref.read(trackingProvider).log(
                'paywall_view',
                storeAnswered: _storePrices.isNotEmpty,
                trialShown: plans.any(_trialLive),
              ),
        );
      }
    }
  }

  /// Whether the store is really offering a trial on this plan right now.
  ///
  /// Not a constant, because three separate things can make the promise false
  /// while the app still believes it: the offer sitting unactivated in the
  /// Console, the offer not covering the user's country, and the user having
  /// spent their trial already — Play withholds the offer in all three, and
  /// charges full price the moment the sheet opens.
  ///
  /// False until the store says otherwise, and the direction matters.
  ///
  /// This defaulted to true, on the reasoning that the tiles render before
  /// prices arrive and it is kinder to correct downward a beat later. That was
  /// written while a trial offer existed. There is none configured now, so the
  /// default was the app promising "3 days free" to everybody — during the
  /// wait on every cold open, and permanently anywhere the store never
  /// answers at all, like the web build.
  ///
  /// A free trial the user is then charged through is the Misleading Claims
  /// section of Play policy, not a cosmetic slip. So the claim waits for Play
  /// to confirm it: say nothing, then say "3 days free" once there is a free
  /// phase in the offer actually returned.
  bool _trialLive(Plan plan) =>
      _storePrices[_productIdFor(plan)]?.hasIntroPhase ?? false;

  /// The store id for a plan from the local catalogue.
  String _productIdFor(Plan plan) => plan.period == BillingPeriod.year
      ? BillingService.yearlyId
      : BillingService.monthlyId;

  /// Asks to send the "your trial ends tomorrow" notice. It is the message
  /// that tells somebody how to cancel before they are charged, so it is asked
  /// for here, where the reason is on screen, and not buried in settings.
  Future<void> _allowReminder() async {
    final ok = await enableTrialNotice(ref);
    if (!mounted) return;
    setState(() => _remind = ok);
    unawaited(ref.read(trackingProvider).log(ok ? 'trial_push_on' : 'trial_push_denied'));
  }

  Future<void> _subscribe(Plan plan) async {
    final billing = ref.read(billingServiceProvider);
    final tracker = ref.read(trackingProvider);
    unawaited(tracker.log('subscribe_tap'));

    // Last chance to be warned before the charge: ask now if it has not been
    // allowed yet. Declining does not block the trial.
    if (!_remind) await _allowReminder();
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!await billing.isAvailable) {
        throw const _BillingUnavailable();
      }

      final offer = _storePrices[_productIdFor(plan)];
      if (offer == null) {
        throw const _BillingUnavailable();
      }

      final bought = await billing.buy(offer.product);
      if (!mounted) return;

      unawaited(tracker.log(bought ? 'purchase_ok' : 'purchase_cancelled'));

      if (bought) {
        // Nothing is written here. The server has already recorded the
        // entitlement from the receipt, and `entitlementProvider` is watching
        // that document — by the time this leaves, the app already knows.
        _leave(true);
        if (mounted) setState(() => _busy = false);
        return;
      }

      setState(() => _busy = false);
    } catch (error) {
      unawaited(
        tracker.log('purchase_failed', detail: error.runtimeType.toString()),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error) {
          // No store implementation at all — a browser. Worth its own words
          // rather than the generic failure, because nothing the user does
          // here will ever work and "that did not go through" invites them to
          // keep tapping.
          _ when !billing.hasStore =>
            'This is the web build. Purchases only work in the Mayow app on '
                'Android.',
          _BillingUnavailable() =>
            'Purchases are not available on this device yet.',

          // Play succeeded and only our confirmation of it failed. The generic
          // message below is actively false here — it told a user who had just
          // been sent a Play receipt that they had not been charged, so they
          // bought again, and Play refused the second purchase with "you're
          // already subscribed" and left them on this screen with a
          // subscription they could not use.
          //
          // Says what is true instead: Play has it, we do not have it yet, and
          // the button that fixes it is directly below.
          PurchaseNotVerified() =>
            '$storeNameCap has your subscription, but we could not confirm it '
                'yet. Do not buy again — tap "Restore a purchase" below in a '
                'moment and it will come through.',

          _ => 'That did not go through. You have not been charged.',
        };
      });
    }
  }

  /// Ends the session and clears this device, in that order.
  ///
  /// Both halves, always — the same pairing Profile uses. `signOut` alone
  /// leaves the last account's name, stories and streak in local storage for
  /// whoever signs in next.
  Future<void> _logOut() async {
    setState(() => _busy = true);
    // Taken before the sign-out — see [forgetEverythingLocal].
    final container = ProviderScope.containerOf(context);
    await container.read(accountServiceProvider).signOut();
    await forgetEverythingLocal(container);
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final billing = ref.read(billingServiceProvider);

    try {
      await billing.restore();
      if (!mounted) return;

      // The server's answer, not the store's. A restore is the store handing
      // its receipts to `verifyPurchase`, and what comes back is a document
      // this app only reads — so on a platform with no store at all, this
      // still reports an entitlement that already exists.
      final restored = ref.read(isSubscribedProvider);

      // On the hard paywall this is the only exit that is not a purchase, so
      // it has to actually take it. Leaving the user on the screen after a
      // successful restore would read as "that did nothing" and the next tap
      // is a second subscription.
      if (restored && widget.hard) {
        _leave(true);
        if (mounted) setState(() => _busy = false);
        return;
      }

      setState(() {
        _busy = false;
        _error = switch ((restored, billing.hasStore)) {
          (true, _) => null,
          (false, true) => 'No previous purchase found for this account.',
          // Web, or a device without Play Services. "No purchase found" reads
          // as an account problem and sends people to support over something
          // that was never going to work on this platform.
          (false, false) => 'Purchases are not available on this device.',
        };
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

    // The entitlement is a live document, and it can turn true without anybody
    // touching this screen: a purchase verified from the other side, a Play
    // restore that resolves late, an entitlement granted from the admin panel.
    // Only the hard paywall acts on it — it is the one that traps somebody who
    // is already paying, and leaving them to guess that the way out is a
    // button labelled "Restore a purchase" is how a subscriber ends up buying
    // a second subscription.
    ref.listen(isSubscribedProvider, (_, subscribed) {
      if (!subscribed || !widget.hard || _left) return;

      // Two ways to arrive here, and they need opposite things.
      //
      // Pushed from onboarding, that screen is underneath waiting on this
      // one's result, and it writes the first story itself. Popping is the
      // whole handover.
      //
      // As the app's root — reached by someone who closed the app on the
      // paywall and reopened it — there is nothing underneath and nothing
      // waiting. Doing only what the routing does on its own would drop them
      // on Home with no story, having just paid for one. So this writes it.
      _leave(true);
    });

    // The screen can always be left now, hard or not.
    //
    // It used to trap the user, on the reasoning that a paywall with an exit
    // is a paywall nobody pays at. What that actually produced was a dead end:
    // no back, no dismiss, and — before the entitlement gate on Home — an app
    // whose only escape was to force-quit it, which then let the user in for
    // free. The lock is now where it belongs, on Home, so this screen does not
    // have to be a cage to do its job.
    final trial = _trialLive(selected);
    // Without the period: Play's string is just the amount, but the local
    // fallback reads "$7.99 / month", and the sentences below add their own
    // "per month" — which printed it twice.
    final price =
        (_storePrices[_productIdFor(selected)]?.price ?? selected.headline)
            .split(' / ')
            .first;
    final per = selected.periodLabel;

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              children: [
                // Back, but only where there is something behind this screen.
                //
                // Drawn from `canPop` rather than from `hard`, because the same
                // widget is both a pushed route and the app's root depending on
                // how it was reached, and a back button on the root blanks the
                // app. Where there is no way back, the way out is to sign out.
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Navigator.of(context).canPop()
                        ? _Close(onTap: _busy ? null : () => _leave(false))
                        : widget.onBack != null
                        ? _Close(onTap: _busy ? null : widget.onBack)
                        : const SizedBox.shrink(),
                  ),
                ),

                // Everything above the button scrolls and the button never
                // does, so a short screen or a long currency string cannot push
                // the call to action off the bottom.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AstraSpacing.md),
                    children: [
                      Center(
                        child: AstraMascot(
                          trial ? 'mascot_gift' : 'mascot_cheer',
                          size: 104,
                        ),
                      ),
                      const SizedBox(height: AstraSpacing.sm),
                      Text(
                        trial
                            ? 'Try Mayow free for ${PricingCatalog.trialDays} days'
                            : 'Make it real with Mayow Plus',
                        textAlign: TextAlign.center,
                        style: AstraTextStyles.display(28),
                      ),
                      const SizedBox(height: AstraSpacing.lg),

                      for (final plan in plans) ...[
                        _PlanTile(
                          plan: plan,
                          selected: plan.id == selected.id,
                          trial: _trialLive(plan),
                          // The store's price when it has answered, the local
                          // table when it has not. Play's number is the one
                          // that will be charged — right currency, right tax,
                          // right country — so it wins wherever it exists.
                          storePrice: _storePrices[_productIdFor(plan)]?.price,
                          onTap: _busy
                              ? null
                              : () => setState(() => _chosen = plan),
                        ),
                        const SizedBox(height: AstraSpacing.md),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AstraIcon('ui_check', size: 22),
                          const SizedBox(width: 8),
                          Text(
                            trial
                                ? 'No payment due now'
                                : 'Cancel any time in $storeName',
                            style: AstraTextStyles.label,
                          ),
                        ],
                      ),

                      const SizedBox(height: AstraSpacing.xl),

                      // What happens, and when. The trial's whole risk is the
                      // day it turns into a charge, so that day is printed
                      // with the others instead of left to the small print.
                      if (trial) ...[
                        _Step(
                          icon: Icons.lock_open_rounded,
                          colour: AstraColors.accent,
                          title: 'Today',
                          body:
                              'Write up to ${PricingCatalog.trialManifests} '
                              'personal manifestations in your own words, '
                              'in a voice you will want to close your eyes '
                              'to.',
                        ),
                        _Step(
                          icon: Icons.notifications_active_rounded,
                          colour: AstraColors.accent,
                          title: 'In ${PricingCatalog.trialDays - 1} days',
                          body:
                              'We send you a reminder the day before your '
                              'trial ends, so you can cancel in $storeName '
                              'if it is not for you.',
                        ),
                        _Step(
                          icon: Icons.workspace_premium_rounded,
                          colour: AstraColors.cta,
                          title: 'In ${PricingCatalog.trialDays} days',
                          body:
                              'Your plan starts at $price a $per, with up to '
                              '${PricingCatalog.manifestMonthly} manifestations '
                              'a month. Cancel before then in $storeName and '
                              'you pay nothing.',
                          last: true,
                        ),
                      ] else ...[
                        _Step(
                          icon: Icons.auto_awesome_rounded,
                          colour: AstraColors.accent,
                          title: 'Today',
                          body:
                              'Write up to ${PricingCatalog.manifestMonthly} '
                              'personal manifestations a month, in your own '
                              'words.',
                        ),
                        _Step(
                          icon: Icons.headphones_rounded,
                          colour: AstraColors.accent,
                          title: 'Always',
                          body:
                              'Replay everything you have made as often as you '
                              'like. Affirmations stay free for everyone.',
                        ),
                        _Step(
                          icon: Icons.favorite_rounded,
                          colour: AstraColors.cta,
                          title: 'Any time',
                          body:
                              'Cancel in $storeName whenever you want. No '
                              'questions asked.',
                          last: true,
                        ),
                      ],
                      if (trial) ...[
                        const SizedBox(height: AstraSpacing.md),
                        _ReminderCard(on: _remind, onTap: _busy ? null : _allowReminder),
                      ],
                      const SizedBox(height: AstraSpacing.lg),

                      if (_error != null) ...[
                        const SizedBox(height: AstraSpacing.md),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AstraTextStyles.small.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                AstraButton(
                  label: trial
                      ? 'Start my ${PricingCatalog.trialDays}-day free trial'
                      : 'Continue — $price',
                  busy: _busy,
                  onPressed: _busy ? null : () => _subscribe(selected),
                ),

                // What happens after the trial, on the screen that starts it.
                // Play requires the disclosure, and a trial that hides its own
                // end date is the thing people file chargebacks over.
                Text(
                  trial
                      ? '${PricingCatalog.trialDays} days free, then $price '
                            'per $per. Renews automatically unless you cancel '
                            'in $storeName before the trial ends.'
                      : '$price per $per. Renews automatically until you '
                            'cancel in $storeName. Cancelling stops the next '
                            'payment and you keep Plus until the period you '
                            'have paid for ends.',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.small,
                ),

                if (!widget.hard) ...[
                  const SizedBox(height: AstraSpacing.sm),
                  AstraGhostButton(
                    // The way out, routed through [_leave] like every other
                    // exit so it cannot blank the app on the one screen this
                    // widget is the root of.
                    label: 'Not now',
                    onPressed: _busy ? null : () => _leave(false),
                  ),
                ],

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Required by Play, and needed regardless: a subscription
                    // lives on the Google account, not the phone, so without
                    // this a paying user who reinstalls lands in the free tier.
                    TextButton(
                      onPressed: _busy ? null : _restore,
                      child: Text(
                        'Restore purchase',
                        style: AstraTextStyles.small.copyWith(
                          color: AstraColors.accent,
                        ),
                      ),
                    ),
                    Text('·', style: AstraTextStyles.small),
                    TextButton(
                      onPressed: () =>
                          LegalLinks.open(context, LegalLinks.terms),
                      child: Text('Terms', style: AstraTextStyles.small),
                    ),
                    Text('·', style: AstraTextStyles.small),
                    TextButton(
                      onPressed: () =>
                          LegalLinks.open(context, LegalLinks.privacy),
                      child: Text('Privacy', style: AstraTextStyles.small),
                    ),
                    // Sign out, but only on the root paywall, which has no back
                    // button. It gets nobody in for free: signing out returns
                    // to login, and signing back in runs the same check.
                    if (!Navigator.of(context).canPop()) ...[
                      Text('·', style: AstraTextStyles.small),
                      TextButton(
                        onPressed: _busy ? null : () => _logOut(),
                        child: Text('Sign out', style: AstraTextStyles.small),
                      ),
                    ],
                  ],
                ),
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

/// One row of the "what happens, and when" timeline.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.colour,
    required this.title,
    required this.body,
    this.last = false,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String body;

  /// The final step has no rail running down out of it.
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                child: Icon(
                  icon,
                  size: 22,
                  color: colour == AstraColors.cta
                      ? AstraColors.onCta
                      : AstraColors.onAccent,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 6,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: AstraColors.accent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AstraSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : AstraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AstraTextStyles.display(19)),
                const SizedBox(height: 2),
                Text(body, style: AstraTextStyles.bodyDim),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A plan, as a big tappable card. The chosen one gets a thick yellow edge, a
/// tick, and — if it carries a trial — a banner across the top saying so.
class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
    this.trial = false,
    this.storePrice,
  });

  final Plan plan;
  final bool selected;
  final bool trial;
  final VoidCallback? onTap;

  /// Play's own formatted price, when the store has answered.
  final String? storePrice;

  @override
  Widget build(BuildContext context) {
    final yearly = plan.period == BillingPeriod.year;
    final price = storePrice ?? plan.headline.split(' / ').first;
    final title = yearly
        ? (plan.badge == null
              ? 'Yearly'
              : 'Yearly · ${plan.badge!.toLowerCase()}')
        : 'Monthly';
    final sub = yearly ? 'Billed once a year' : 'Billed every month';

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? AstraColors.cardRaised : AstraColors.card,
            borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
            border: Border.all(
              color: selected ? AstraColors.accent : AstraColors.line,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Column(
            children: [
              if (trial)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: selected ? AstraColors.accent : AstraColors.line,
                  child: Text(
                    '${PricingCatalog.trialDays} DAYS FREE',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.eyebrow.copyWith(
                      color: selected ? AstraColors.onAccent : AstraColors.text,
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    selected
                        ? const AstraIcon('ui_check', size: 34)
                        : Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AstraColors.line,
                                width: 2.5,
                              ),
                            ),
                          ),
                    const SizedBox(width: AstraSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AstraTextStyles.label),
                          Text(sub, style: AstraTextStyles.small),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(price, style: AstraTextStyles.price),
                        Text(
                          yearly ? 'per year' : 'per month',
                          style: AstraTextStyles.small,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for notifications for one reason, said out loud: the reminder that
/// arrives the day before the free trial ends and how to cancel it.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.on, required this.onTap});

  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: Row(
      children: [
        const AstraIcon('ui_bell', size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            on
                ? 'Reminder is on. We will tell you the day before your '
                      'trial ends.'
                : 'Get a reminder the day before your trial ends, with a '
                      'way to cancel. Needs notifications.',
            style: AstraTextStyles.small,
          ),
        ),
        if (!on) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            child: Text(
              'Allow',
              style: AstraTextStyles.small.copyWith(color: AstraColors.accent),
            ),
          ),
        ],
      ],
    ),
  );
}

/// The way out, top-left, on every paywall.
class _Close extends StatelessWidget {
  const _Close({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AstraColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AstraColors.line),
        ),
        child: const Center(child: AstraIcon('ui_back', size: 26)),
      ),
    ),
  );
}
