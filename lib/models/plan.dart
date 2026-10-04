import 'package:intl/intl.dart';

enum BillingPeriod { month, year }

/// A subscription option, priced in one currency.
///
/// Every price the user sees is derived from this object, so a price is never
/// shown without the period it belongs to — the single loudest complaint about
/// the app this one is modelled on was a monthly price that billed weekly.
class Plan {
  const Plan({
    required this.id,
    required this.period,
    required this.amount,
    required this.currencyCode,
    this.badge,
    this.popular = false,
  });

  final String id;
  final BillingPeriod period;
  final double amount;
  final String currencyCode;

  /// e.g. "Save 44%" — omitted when there is nothing honest to claim.
  final String? badge;
  final bool popular;

  String get periodLabel => switch (period) {
    BillingPeriod.month => 'month',
    BillingPeriod.year => 'year',
  };

  /// "$7.99 / month", "$79.99 / year".
  String get headline => '${_format(amount)} / $periodLabel';

  /// Sub-line under the headline. Yearly plans show the monthly equivalent so
  /// the comparison is doable without arithmetic; monthly plans just restate
  /// the terms.
  String get subline => switch (period) {
    BillingPeriod.month => 'billed monthly · cancel anytime',
    BillingPeriod.year =>
      '${_format(amount / 12)} / month · billed once yearly',
  };

  String _format(double value) {
    final format = NumberFormat.simpleCurrency(
      name: currencyCode,
      decimalDigits: 2,
    );
    return format.format(value);
  }
}

/// Region → currency → plans.
///
/// Adding a region is a data change here, never a UI change. When Play Billing
/// goes live it returns its own localized price and that becomes the source of
/// truth; this table is the pre-billing default and the offline fallback.
///
/// The reasoning behind the prices and allowances below — what a
/// manifestation costs to produce, what a subscription actually pays after
/// the store's cut and tax, and where the margin floors sit — is kept in the
/// private pricing notes and enforced by the pricing test. Change a price or
/// an allowance there first: the test fails the day one moves without the
/// other.
///
class PricingCatalog {
  const PricingCatalog._();

  /// Stories per month on Plus — a ceiling on the heaviest user, not a
  /// forecast of the typical one. See the pricing notes before changing it: past a
  /// certain number the yearly plans stop clearing the margin floor, and the
  /// price has to move with it.
  static const plusMonthlyStories = 20;

  /// Stories anyone gets without paying. Zero — the paywall is hard.
  ///
  /// This was three, and the reasoning against a trial is worth keeping
  /// because it is the risk the current design has to answer: a time-boxed
  /// trial with an uncapped generator is an unbounded cost, since three days
  /// of a motivated user is tens of stories.
  ///
  /// A three-a-day cap used to bound that to about a dollar. It was removed at
  /// the owner's request — it was also stopping people who were simply enjoying
  /// the app — so what bounds the trial now is only the monthly allowance:
  /// twenty stories and ten manifestations, which a determined trial user can
  /// spend in one afternoon for roughly $3.50 before cancelling. That is the
  /// standing exposure, and it is a deliberate trade rather than an oversight.
  ///
  /// Mirrors `FREE_STORY_LIMIT` in `functions/index.js`. The server enforces
  /// it; this exists so the screens can say the number out loud instead of
  /// letting the user discover it by being refused.
  static const freeStories = 0;


  /// Days of Mayow Plus before the first charge.
  ///
  /// Honoured by **Play**, not by this app: the trial is an offer attached to
  /// the base plan in the Play Console, and this constant only exists so the
  /// paywall can print the same number Play will actually charge on. If the
  /// Console has no trial offer configured, the store charges immediately and
  /// this number becomes a lie — see `store/billing-setup.md`.
  static const trialDays = 7;

  /// Manifestations a month on Plus, counted apart from stories.
  ///
  /// Mirrors `MANIFEST_MONTHLY_LIMIT` in `functions/index.js`, which enforces
  /// it. Separate from the story allowance because the two cost different
  /// amounts to make, so one shared number would either starve the
  /// cheap one or give away the dear one.
  static const manifestMonthly = 60;

  /// Manifestations allowed during the free trial; the rest wait for the trial
  /// to end. Mirrors `TRIAL_MANIFEST_LIMIT` in `functions/index.js`.
  static const trialManifests = 10;

  /// What a subscriber is assumed to actually use in a month.
  ///
  /// A guess, not a measurement — there is no usage data yet. It exists so the
  /// assumption is written down and testable instead of living in someone's
  /// head, and so the margin test fails the day it stops being defensible.
  /// Replace it with the real median once there is one.
  static const expectedMonthlyStories = 6;

  static const _defaultCurrency = 'USD';

  static const _plansByCurrency = <String, List<Plan>>{
    'USD': [
      Plan(
        id: 'astra_plus_monthly_usd',
        period: BillingPeriod.month,
        amount: 7.99,
        currencyCode: 'USD',
        popular: true,
      ),
      // 1 − 79.99/(12 × 7.99) = 16.6%.
      Plan(
        id: 'astra_plus_yearly_usd',
        period: BillingPeriod.year,
        amount: 79.99,
        currencyCode: 'USD',
        badge: 'Save 17%',
      ),
    ],
  };

  static String currencyForCountry(String countryCode) =>
      _defaultCurrency;

  static List<Plan> plansForCurrency(String currencyCode) =>
      _plansByCurrency[currencyCode] ?? _plansByCurrency[_defaultCurrency]!;

  static List<Plan> plansForCountry(String countryCode) =>
      plansForCurrency(currencyForCountry(countryCode));
}
