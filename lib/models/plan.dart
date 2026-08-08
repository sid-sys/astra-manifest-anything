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

  /// "₹299 / month", "$44.99 / year".
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
      // Rupee prices are whole numbers and read better without ".00";
      // dollar prices keep their cents.
      decimalDigits: currencyCode == 'INR' ? 0 : 2,
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
/// A five-minute story costs about $0.10 to produce, measured rather than
/// estimated: 915 words at the observed 183 wpm, 5.34 characters per word.
/// Narration is 59% of that ($12 per million characters), the script 37%
/// ($25 per million output tokens), infrastructure the rest. Planning uses
/// $0.105 to leave a 10% buffer.
///
/// The margin target is 80% on the list price, measured *before* the store's
/// cut. Google Play's 15% (30% above $1M of annual revenue) is a distribution
/// cost taken out of what is left, not a cost of producing the story, so it
/// does not enter the floor. Worth keeping in view anyway: net of Play's 15%,
/// these plans run about 12 points lower than the numbers below.
///
/// ## The allowance is a ceiling, not a forecast
///
/// Twenty stories a month is deliberately more than anyone is expected to
/// use. It is set against a competitor that caps *listening* at three plays a
/// day while advertising unlimited generation — the opposite of where the
/// cost actually is, since replaying a file that already exists is free and
/// making a new one is not. Capping the expensive half and leaving the free
/// half alone is both cheaper to honour and easier to explain.
///
/// This means the 80% target is measured at *expected* usage, not at the cap:
///
///     margin at n stories = (price − n × 12 (if yearly) × $0.105) / price
///
/// | stories/month | $7.99 mo | $79.99 yr | ₹649 mo | ₹6,499 yr |
/// |---------------|----------|-----------|---------|-----------|
/// | 6 (expected)  |    92.1% |     90.5% |   91.6% |     89.9% |
/// | 12            |    84.2% |     81.1% |   83.2% |     79.9% |
/// | 20 (the cap)  |    73.7% |     68.5% |   72.0% |     66.5% |
///
/// So a subscriber who maxes out every month is served at ~67% rather than
/// 80%, and that is accepted rather than overlooked: heavy users are rare,
/// they are the ones who renew, and the cap bounds the loss. What the cap buys
/// is a known worst case — without one, a single automated client could run
/// the margin negative.
///
/// If the median subscriber turns out to use more than twelve a month, this
/// stops being true and the price has to move: $10.99 / ₹949 monthly and
/// $129.99 / ₹11,499 yearly hold 80% at the full twenty. Check real usage
/// before assuming; the test below encodes the assumption so it fails loudly
/// if the constant is edited without the price.
///
/// The yearly plan always binds — a 12× cost against a 10× price — which is
/// why the annual discount is two months free rather than the ~45% it was. At
/// the old ₹1,999 the yearly margin was negative once Play took its share.
class PricingCatalog {
  const PricingCatalog._();

  /// Stories per month on Plus — a ceiling on the heaviest user, not a
  /// forecast of the typical one. See the derivation above before changing it:
  /// past twelve, the yearly plans stop clearing 80% at expected usage and the
  /// price has to move with it.
  static const plusMonthlyStories = 20;

  /// Stories on the free day, after the free first one.
  ///
  /// Mirrors `TRIAL_STORY_LIMIT` in `functions/index.js`. The server is the
  /// one that enforces it; this exists so the screens can say the number out
  /// loud instead of letting the user discover it by being refused.
  static const trialStories = 2;

  /// What a subscriber is assumed to actually use in a month.
  ///
  /// A guess, not a measurement — there is no usage data yet. It exists so the
  /// assumption is written down and testable instead of living in someone's
  /// head, and so the margin test fails the day it stops being defensible.
  /// Replace it with the real median once there is one.
  static const expectedMonthlyStories = 6;

  static const _countryToCurrency = <String, String>{'IN': 'INR'};

  static const _defaultCurrency = 'USD';

  static const _plansByCurrency = <String, List<Plan>>{
    'INR': [
      // ₹649 ≈ $7.50 → 91.6% expected, 72.0% at the cap.
      Plan(
        id: 'astra_plus_monthly_inr',
        period: BillingPeriod.month,
        amount: 649,
        currencyCode: 'INR',
        popular: true,
      ),
      // ₹6,499 ≈ $75.13 → 89.9% expected, 66.5% at the cap. The thinnest plan
      // in the catalogue, so the one to check when anything moves.
      Plan(
        id: 'astra_plus_yearly_inr',
        period: BillingPeriod.year,
        amount: 6499,
        currencyCode: 'INR',
        badge: 'Save 17%',
      ),
    ],
    'USD': [
      // $7.99 → 92.1% expected, 73.7% at the cap.
      Plan(
        id: 'astra_plus_monthly_usd',
        period: BillingPeriod.month,
        amount: 7.99,
        currencyCode: 'USD',
        popular: true,
      ),
      // $79.99 → 90.5% expected, 68.5% at the cap.
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
      _countryToCurrency[countryCode.toUpperCase()] ?? _defaultCurrency;

  static List<Plan> plansForCurrency(String currencyCode) =>
      _plansByCurrency[currencyCode] ?? _plansByCurrency[_defaultCurrency]!;

  static List<Plan> plansForCountry(String countryCode) =>
      plansForCurrency(currencyForCountry(countryCode));
}
