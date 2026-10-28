import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../theme/astra_theme.dart';

/// Everything the admin panel needs that is a number, an address or a rule, in
/// one place. Nothing in a screen should hard-code an email, a price, a cost or
/// a decision about who counts as a real person. Edit this file instead.
class AdminConfig {
  const AdminConfig._();

  // --------------------------------------------------------------- who is who

  /// The only account that sees the panel.
  ///
  /// Hiding the entry is not security: the server (the `adminOverview` Cloud
  /// Function and every admin function) checks this same address again. See
  /// `lib/admin/README.md`.
  static const adminEmail = 'sidharthbabu9@gmail.com';

  // -------------------------------------------- "Real users only" filter rules

  /// The store review team's login. Hidden as "Play review login".
  static const reviewEmails = <String>['playreview@coreinteractive.live'];

  /// Test robots run by Google (Firebase Test Lab and Play pre-launch
  /// reports). Their addresses end with one of these. Hidden as "Google test
  /// robot".
  static const testRobotDomains = <String>['cloudtestlabaccounts.com'];

  /// An address that looks like an automated sign-up, for example
  /// `testuser12345@example.com`. Hidden as "Automated test".
  static final automatedEmailPatterns = <RegExp>[
    RegExp(r'^testuser\d+@', caseSensitive: false),
    // Google's robots: `name.12345@gmail.com`. The weekly `cleanBotAccounts`
    // function deletes the idle ones; this hides any that are left.
    RegExp(r'^[a-zA-Z]+\.[0-9]{5}@gmail\.com$'),
  ];

  /// Nobody can read and answer the onboarding questions faster than this.
  /// Anyone who finishes in less is hidden as "Looks like a robot".
  static const minOnboardingSeconds = 25;

  // ------------------------------------------------------------------ prices

  /// The store prices, taken from [PricingCatalog] so a price change there
  /// changes the revenue here.
  static double get monthlyPrice => _price(BillingPeriod.month);
  static double get yearlyPrice => _price(BillingPeriod.year);

  static double _price(BillingPeriod period) =>
      PricingCatalog.plansForCurrency('USD')
          .firstWhere((plan) => plan.period == period)
          .amount;

  /// Days of free trial before the first charge. Payments here start after it.
  static int get trialDays => PricingCatalog.trialDays;

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

  /// The first thing a person does that shows they understood the app.
  static const keyStepLabel = 'Typed a wish';

  /// How many days the two charts show.
  static const chartDays = 30;
}

/// The panel's colours, taken from the app's own palette: the pink button
/// colour is the primary, the yellow is the highlight, and cards are a shade
/// off the violet background.
class AdminColors {
  const AdminColors._();

  /// Buttons, active chips, chart bars.
  static const primary = AstraColors.cta;

  /// Links and small pink text: a lighter pink, so it reads on a dark card.
  static const link = Color(0xFFFF9BBE);

  /// Highlights (today, the best row).
  static const highlight = AstraColors.accent;

  /// Card fill: a shade off the background.
  static const card = Color(0xFF2B2090);
  static const cardEdge = Color(0x40FFFFFF);

  static const good = Color(0xFF7BE0A8);
  static const bad = Color(0xFFFF8A8A);
  static const text = AstraColors.text;
  static const dim = Color(0xFFD9CCF5);
}
