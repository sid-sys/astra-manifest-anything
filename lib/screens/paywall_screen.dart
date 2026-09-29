import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/plan.dart';
import '../models/story_preferences.dart';
import '../providers.dart';
import '../services/billing_service.dart';
import '../services/legal_links.dart';
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
  const PaywallScreen({super.key, this.hard = false});

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
        debugPrint('Maya: could not load store prices — $error');
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

  Future<void> _subscribe(Plan plan) async {
    final billing = ref.read(billingServiceProvider);
    final tracker = ref.read(trackingProvider);
    unawaited(tracker.log('subscribe_tap'));

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
            'This is the web build. Purchases only work in the Maya app on '
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
            'Google Play has your subscription, but we could not confirm it '
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

    // The answers are saved before this screen opens, so on the hard paywall
    // the category is the one the user picked a minute ago. Everywhere else it
    // is whatever their profile holds, and `other` when there is nothing yet.
    final category = ref.watch(profileProvider).preferences.category;

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
    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AstraSpacing.sm),

                // Back, but only where there is something behind this screen.
                //
                // Drawn from `canPop` rather than from `hard`, because the same
                // widget is both a pushed route and the app's root depending on
                // how it was reached, and a back button on the root is a button
                // that blanks the app. Where there is no way back, the way out
                // is to sign out — offered below.
                SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Navigator.of(context).canPop()
                        ? _Close(onTap: _busy ? null : () => _leave(false))
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: AstraSpacing.sm),
                const Wordmark('Maya Plus'),

                // Everything between the wordmark and the button scrolls, and
                // the button never does.
                //
                // This was a plain Column with the samples in an Expanded at
                // the end, which meant the samples were given whatever height
                // the plans had not already taken — on a laptop browser, about
                // a card and a half, with the second one sliced off mid-word.
                // Sizing content by subtraction only works while the content
                // above it is fixed, and a paywall's is not: the blurb grows
                // when a trial is live, the error line appears, the disclosure
                // wraps differently in every currency.
                //
                // So the offer scrolls as one object and the CTA is pinned
                // under it. On a tall screen nothing scrolls at all; on a
                // short one everything is reachable instead of some of it
                // being clipped.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AstraSpacing.md),
                    children: [
                const SizedBox(height: AstraSpacing.xl),
                Text(
                  widget.hard
                      ? 'Your manifestation is ready to write.'
                      : 'Keep writing.',
                  style: AstraTextStyles.display(26),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  _trialLive(selected)
                      ? '${PricingCatalog.trialDays} days free, then your plan. '
                            'Maya Plus writes '
                            '${PricingCatalog.manifestMonthly} manifestations a '
                            'month, and everything you make replays forever.'
                      : 'Maya Plus writes '
                            '${PricingCatalog.manifestMonthly} manifestations a '
                            'month, and everything you already have replays for '
                            'nothing, forever.',
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
                  // Affirmations are deliberately not sold here. They are free
                  // to everybody, so listing them as a benefit of paying would
                  // be selling something the app gives away.
                  '${PricingCatalog.manifestMonthly} manifestations a month · '
                  'unlimited listening · everything you keep, kept',
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

                      const SizedBox(height: AstraSpacing.xl),
                      Text('WHAT YOURS WILL SOUND LIKE',
                          style: AstraTextStyles.eyebrow),
                      const SizedBox(height: AstraSpacing.md),
                      for (final (index, line)
                          in [..._previewLines(category), _listeningLine]
                              .indexed) ...[
                        _PreviewLine(line, tilt: _tilts[index % _tilts.length]),
                        const SizedBox(height: AstraSpacing.sm),
                      ],
                      const SizedBox(height: AstraSpacing.xs),
                      Text(
                        // Says out loud that these are examples. They are
                        // written to show the shape of a scene rather than to
                        // stand in for a person — a made-up sentence presented
                        // as somebody's result is a fake testimonial, which is
                        // both a lie and the Misleading Claims section of
                        // Play's policy.
                        'Examples of how Maya writes. Yours are written from '
                        'the answers you just gave.',
                        style: AstraTextStyles.small,
                      ),
                    ],
                  ),
                ),

                AstraButton(
                  label: _trialLive(selected)
                      ? 'Start my ${PricingCatalog.trialDays}-day free trial'
                      : 'Start Maya Plus — '
                            '${_storePrices[_productIdFor(selected)]?.price ?? selected.headline}',
                  busy: _busy,
                  onPressed: _busy ? null : () => _subscribe(selected),
                ),


                // What happens after the trial, on the screen that starts it,
                // in the same size type as everything else. Play requires the
                // disclosure and a trial that hides its own end date is the
                // thing users file chargebacks over.
                ...[
                  const SizedBox(height: AstraSpacing.sm),
                  Text(
                    _trialLive(selected)
                        ? 'Free for ${PricingCatalog.trialDays} days. After '
                              'that ${_storePrices[_productIdFor(selected)]?.price ?? selected.headline}, '
                              'unless you cancel in Google Play before it ends.'
                        : '${_storePrices[_productIdFor(selected)]?.price ?? selected.headline} '
                              '${selected.periodLabel == 'year' ? 'a year' : 'a month'}, '
                              'billed now. Cancel any time in Google Play.',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small,
                  ),
                ],
                if (!widget.hard) ...[
                  const SizedBox(height: AstraSpacing.sm),
                  AstraGhostButton(
                    // The way out, worded as what the user keeps rather than
                    // as a refusal. Routed through [_leave] like every other
                    // exit, so it cannot blank the app on the one screen this
                    // widget is the root of.
                    label: 'Not now',
                    onPressed: _busy ? null : () => _leave(false),
                  ),
                ],

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

                // Sign out, but only on the root paywall.
                //
                // That screen has no back button, by necessity — there is
                // nothing behind it — which would otherwise leave somebody who
                // does not want to pay with no way to reach any other part of
                // the app, including the account they are signed in as. They
                // could not even switch to the account that *is* subscribed.
                //
                // It gets nobody in for free: signing out returns to the login
                // screen, and signing back in runs the same subscription check
                // this screen is the result of.
                if (!Navigator.of(context).canPop())
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : () => _logOut(),
                      child: Text(
                        'Sign out',
                        style: AstraTextStyles.small.copyWith(
                          color: AstraColors.dim,
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

/// Example opening lines, chosen to match what the user said they want.
///
/// Not testimonials, and the label under them says so. Nobody said these; they
/// are there to show the *shape* of a scene — first person, past tense, one
/// small concrete moment — because "ten manifestations a month" describes a
/// quantity and tells you nothing about what arrives.
///
/// Written from the user's own category so the samples are about their life
/// rather than a stranger's. A person who answered "Money" should not be shown
/// three lines about a wedding.
List<String> _previewLines(DesireCategory category) => switch (category) {
  DesireCategory.love => const [
    'Rachel texted first. She said she had not stopped thinking about me.',
    'Clara said yes before I finished asking.',
    'He put his phone face down and said he was not going anywhere. Ever.',
  ],
  DesireCategory.money => const [
    'The transfer landed while I was making coffee. Twice what I asked for.',
    'I checked the balance three times before I let myself believe it.',
    'I paid it off in one go, and nobody had to know how close it had been.',
  ],
  DesireCategory.career => const [
    'My manager asked me to stay behind, and the role was mine.',
    'The offer came in writing before I got home.',
    'They introduced me to the room as the person who runs it now.',
  ],
  DesireCategory.studies => const [
    'I got home and my professor called to say I had won the competition.',
    'My name was on the list. Third from the top.',
    'I read it twice, then sat down on the stairs and let it land.',
  ],
  DesireCategory.health => const [
    'I finished the whole run without stopping, and stood there laughing.',
    'The doctor looked at the numbers and said to keep doing what I was doing.',
    'I caught myself in the mirror and liked what was there.',
  ],
  DesireCategory.family => const [
    'Mum saw the flat and just stood in the doorway, smiling.',
    'We were all at one table again, talking over each other.',
    'My dad said he was proud of me, out loud, in front of everyone.',
  ],
  DesireCategory.home => const [
    'I turned the key and the place was actually mine.',
    'The light came through the kitchen window and I stayed there a while.',
    'I put my things down, and nothing about it felt temporary.',
  ],
  DesireCategory.travel => const [
    'The plane tilted and the coast came up under the wing.',
    'I woke up somewhere I had only ever seen in photographs.',
    'We missed the last train, and it did not matter at all.',
  ],
  DesireCategory.growth => const [
    'I said no, and did not apologise for it.',
    'I noticed I had not checked my phone all morning.',
    'Someone asked how I was, and I meant it when I said good.',
  ],
  DesireCategory.other => const [
    'Clara said yes before I finished asking.',
    'I got home and my professor called to say I had won the competition.',
    'The transfer landed while I was making coffee. Twice what I asked for.',
  ],
};

/// How far each card leans, in degrees, top to bottom.
///
/// Small on purpose. The tilt says "loose pages, not a specification" — past
/// about two degrees the text reads as broken layout instead of deliberate.
const _tilts = <double>[-1.6, 1.1, -0.8, 1.4];

/// The last card, the same for everyone.
///
/// The other three are the writing; this one is the listening, which is the part
/// a paywall otherwise never shows. Written as a scene and not as a result —
/// "it worked" is a claim about what Maya does to a life, and dressed up as
/// somebody's quote it would be a fabricated review. All this says is that a
/// person listened to their own manifestation and felt different for a few
/// minutes,
/// which is what the app actually does.
const _listeningLine =
    'I played mine on the walk home. By the time I got in, it had stopped '
    'feeling like a maybe.';

/// One example line, set as a scene rather than as a quotation.
class _PreviewLine extends StatelessWidget {
  const _PreviewLine(this.line, {required this.tilt});

  final String line;

  /// Degrees. Negative leans left.
  final double tilt;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: tilt * math.pi / 180,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AstraColors.card, AstraColors.accentWash],
        ),
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
        border: Border.all(color: AstraColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        line,
        style: AstraTextStyles.bodyDim.copyWith(
          color: AstraColors.text,
          fontStyle: FontStyle.italic,
          height: 1.35,
        ),
      ),
    ),
  );
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
        child: Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: AstraColors.text,
        ),
      ),
    ),
  );
}
