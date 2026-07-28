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
class PricingCatalog {
  const PricingCatalog._();

  static const _countryToCurrency = <String, String>{'IN': 'INR'};

  static const _defaultCurrency = 'USD';

  static const _plansByCurrency = <String, List<Plan>>{
    'INR': [
      Plan(
        id: 'astra_plus_monthly_inr',
        period: BillingPeriod.month,
        amount: 299,
        currencyCode: 'INR',
        popular: true,
      ),
      Plan(
        id: 'astra_plus_yearly_inr',
        period: BillingPeriod.year,
        amount: 1999,
        currencyCode: 'INR',
        badge: 'Save 44%',
      ),
    ],
    'USD': [
      Plan(
        id: 'astra_plus_monthly_usd',
        period: BillingPeriod.month,
        amount: 6.99,
        currencyCode: 'USD',
        popular: true,
      ),
      Plan(
        id: 'astra_plus_yearly_usd',
        period: BillingPeriod.year,
        amount: 44.99,
        currencyCode: 'USD',
        badge: 'Save 46%',
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
