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
/// ## How these numbers were derived
///
/// A manifestation costs **$0.161** to produce. Measured, not estimated: three
/// real ones ran to 2,230, 2,249 and 2,253 characters, and at ElevenLabs
/// Turbo's $0.05 per thousand that is $0.112 of narration. The script adds
/// $0.022, the four questions that precede it $0.017, and storage, traffic and
/// functions about $0.010. Narration is 70% of the total, which is why the
/// script model barely moves the answer and the voice model decides it.
///
/// Affirmations are uncapped and cost about $0.05 a month per active user, on
/// Haiku rather than Opus. They were $0.25 on Opus, which is a point and a
/// half of margin on the thinnest plan spent on the cheapest thing in the app.
///
/// ## The margin is measured on what actually arrives
///
/// Google Play takes 15%, so the dollar plans keep 85% and no more. The number
/// to design against is the one that reaches the bank.
///
///     margin at n = (net monthly − n × $0.161 − $0.05) / net monthly
///
///
/// | manifests/month | $7.99 mo | $79.99 yr |
/// |-----------------|----------|-----------|
/// | net to us       |    $6.79 |     $5.67 |
/// | 6 (expected)    |    85.0% |     82.1% |
/// | **10 (the cap)** | **75.6%** | **70.7%** |
/// | 12              |    70.8% |     65.0% |
///
/// Ten holds 70% to 76% across the catalogue, inside the 60–70% band the owner
/// asked for with room above it.
///
/// The yearly plan in the weaker currency always binds: twelve months of cost
/// against one payment, so any cost movement hits it twelve times as hard. It
/// is the first plan to check and the last place anyone looks.
///
/// ## The allowance is a ceiling, not a forecast
///
/// Ten a month is more than anyone is expected to use. It exists so the worst
/// case is known: without a cap, one automated client runs the margin
/// negative. At the six a month a real subscriber uses, every plan is near 88%.
///
/// Listening is not capped and never will be. Replaying a file that already
/// exists is free; making a new one is not. Capping the expensive half and
/// leaving the free half alone is both cheaper to honour and easier to explain
/// than the competitor who caps plays at three a day while advertising
/// unlimited generation.
///
class PricingCatalog {
  const PricingCatalog._();

  /// Stories per month on Plus — a ceiling on the heaviest user, not a
  /// forecast of the typical one. See the derivation above before changing it:
  /// past twelve, the yearly plans stop clearing 80% at expected usage and the
  /// price has to move with it.
  static const plusMonthlyStories = 20;

  /// Stories anyone gets without paying. Zero — the paywall is hard.
  ///
  /// This was three, and the reasoning against a trial is worth keeping
  /// because it is the risk the current design has to answer: a time-boxed
  /// trial with an uncapped generator is an unbounded cost, since three days
  /// of a motivated user is tens of stories at roughly ten cents each.
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


  /// Days of Maya Plus before the first charge.
  ///
  /// Honoured by **Play**, not by this app: the trial is an offer attached to
  /// the base plan in the Play Console, and this constant only exists so the
  /// paywall can print the same number Play will actually charge on. If the
  /// Console has no trial offer configured, the store charges immediately and
  /// this number becomes a lie — see `store/billing-setup.md`.
  static const trialDays = 3;

  /// Manifestations a month on Plus, counted apart from stories.
  ///
  /// Mirrors `MANIFEST_MONTHLY_LIMIT` in `functions/index.js`, which enforces
  /// it. Separate from the story allowance because the two cost different
  /// amounts to make — a manifestation is narrated by ElevenLabs at roughly
  /// twice a story's per-character rate over a third of the length — so one
  /// shared number would either starve the cheap one or give away the dear one.
  static const manifestMonthly = 10;

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
      // $7.99 → $6.79 after Play → 85.0% at six, 75.6% at the cap.
      Plan(
        id: 'astra_plus_monthly_usd',
        period: BillingPeriod.month,
        amount: 7.99,
        currencyCode: 'USD',
        popular: true,
      ),
      // $79.99 → $5.67 a month after Play → 82.1% at six, 70.7% at the cap.
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
