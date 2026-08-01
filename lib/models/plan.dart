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
/// Every plan is priced so that a subscriber who uses their entire monthly
/// allowance still leaves an 80% gross margin on the list price:
///
///     list price ≥ stories × 12 (if yearly) × $0.105 / 0.20
///
/// which is $5.25 a month and $63.00 a year at ten stories.
///
/// The margin is measured *before* the store's cut, not after. Google Play's
/// 15% (30% above $1M of annual revenue) is a distribution cost taken out of
/// what is left, not a cost of producing the story, so it does not enter the
/// floor. Useful to keep in view anyway: at 15% these plans land in the
/// low-70s net of Play, and at 30% the yearly ones land around 59%.
///
/// The yearly plan is what binds. A steep annual discount at a fixed
/// allowance forces either a much higher list price or a much smaller
/// allowance, so the discount is held at two months free rather than the ~45%
/// it was — at the old ₹1,999 the yearly margin was 18% even on this looser
/// basis, and negative once Play took its share.
///
/// Current prices clear the floor with room to spare: the thinnest is the
/// rupee yearly plan at 83.2%. That headroom is worth about one more story a
/// month (eleven is still above 80%) or a cheaper yearly tile — spend it
/// deliberately, in one place, rather than letting it drift.
class PricingCatalog {
  const PricingCatalog._();

  /// Stories per month on Plus. Set by the margin arithmetic above, not by
  /// feel: the cheapest yearly plan supports 11 at the 80% floor, and 10
  /// leaves room for the cost of a story to drift before the price has to
  /// move.
  static const plusMonthlyStories = 10;

  static const _countryToCurrency = <String, String>{'IN': 'INR'};

  static const _defaultCurrency = 'USD';

  static const _plansByCurrency = <String, List<Plan>>{
    'INR': [
      // ₹649 ≈ $7.50 → 86.0% margin at 10 stories.
      Plan(
        id: 'astra_plus_monthly_inr',
        period: BillingPeriod.month,
        amount: 649,
        currencyCode: 'INR',
        popular: true,
      ),
      // ₹6,499 ≈ $75.13 → 83.2% margin at 10 stories a month. The thinnest
      // plan in the catalogue, so the one to check when anything moves.
      Plan(
        id: 'astra_plus_yearly_inr',
        period: BillingPeriod.year,
        amount: 6499,
        currencyCode: 'INR',
        badge: 'Save 17%',
      ),
    ],
    'USD': [
      // $7.99 → 86.9% margin at 10 stories.
      Plan(
        id: 'astra_plus_monthly_usd',
        period: BillingPeriod.month,
        amount: 7.99,
        currencyCode: 'USD',
        popular: true,
      ),
      // $79.99 → 84.2% margin at 10 stories a month.
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
