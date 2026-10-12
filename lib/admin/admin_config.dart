import '../models/plan.dart';

/// Everything the admin panel needs that is a number or an address, in one
/// place. Nothing in a widget should hard-code an email, a price or a cost.
class AdminConfig {
  const AdminConfig._();

  /// The only account that sees the panel in a real build.
  ///
  /// Hiding the entry is not security: the server (the `adminOverview` Cloud
  /// Function and every admin function) checks this same address again. See
  /// `lib/admin/README.md`.
  static const adminEmail = 'sidharthbabu9@gmail.com';

  // ------------------------------------------------------------------ prices

  /// The store prices, taken from [PricingCatalog] so a price change there
  /// changes the revenue here.
  static double get monthlyPrice => _price(BillingPeriod.month);
  static double get yearlyPrice => _price(BillingPeriod.year);

  static double _price(BillingPeriod period) =>
      PricingCatalog.plansForCurrency('USD')
          .firstWhere((plan) => plan.period == period)
          .amount;

  // ------------------------------------------------------------------- costs

  /// Google Play's share. 15% under $1M a year of revenue, 30% above it.
  static const storeCut = 0.15;

  /// What one AI manifestation costs: ElevenLabs Turbo narration ($0.112 for
  /// about 2,244 characters), the gpt-5.6-luna script ($0.002) and storage and
  /// traffic ($0.010). See `docs/pricing-model.md`.
  static const manifestationCost = 0.124;

  /// What one set of five affirmations costs to write (a short model call).
  static const affirmationsCost = 0.002;

  /// Fixed monthly bills, in dollars. **These are estimates: replace each with
  /// the figure on your real bill.**
  static const fixedMonthlyCosts = <String, double>{
    // Firebase (Blaze) sits inside the free tier at this size.
    'Firebase': 0.0,
    // The domain behind the support address, spread over twelve months.
    'Domain and email': 2.0,
    // Google Play's one-time $25 fee, spread over a year.
    'Play developer account': 2.1,
  };

  static double get fixedMonthlyTotal =>
      fixedMonthlyCosts.values.fold(0.0, (sum, cost) => sum + cost);

  // ---------------------------------------------------------------- the funnel

  /// The step between "finished onboarding" and "reached the paywall" that
  /// says somebody understood the product: they typed a wish.
  static const keyStepLabel = 'Typed a wish';

  /// How long a user stays "active" for the week count.
  static const activeWeekDays = 7;
}
