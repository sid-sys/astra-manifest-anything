import 'package:astra/models/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _marginTests();

  group('region resolves currency', () {
    test('India is priced in rupees', () {
      expect(PricingCatalog.currencyForCountry('IN'), 'INR');
      expect(PricingCatalog.currencyForCountry('in'), 'INR');
    });

    test('everywhere else falls back to dollars', () {
      for (final country in ['US', 'GB', 'AU', 'ZZ', '']) {
        expect(PricingCatalog.currencyForCountry(country), 'USD');
      }
    });
  });

  group('every price states the period it bills on', () {
    test('rupee plans print whole rupees', () {
      final plans = PricingCatalog.plansForCountry('IN');
      final monthly = plans.firstWhere((p) => p.period == BillingPeriod.month);
      final yearly = plans.firstWhere((p) => p.period == BillingPeriod.year);

      expect(monthly.headline, '₹649 / month');
      expect(monthly.subline, 'billed monthly · cancel anytime');
      expect(yearly.headline, '₹6,499 / year');
      // The yearly tile does the division so the user doesn't have to.
      expect(yearly.subline, '₹542 / month · billed once yearly');
    });

    test('dollar plans keep their cents', () {
      final plans = PricingCatalog.plansForCountry('US');
      final monthly = plans.firstWhere((p) => p.period == BillingPeriod.month);
      final yearly = plans.firstWhere((p) => p.period == BillingPeriod.year);

      expect(monthly.headline, r'$7.99 / month');
      expect(yearly.headline, r'$79.99 / year');
      expect(yearly.subline, r'$6.67 / month · billed once yearly');
    });

    test('no headline can be read without its billing period', () {
      for (final currency in ['INR', 'USD']) {
        for (final plan in PricingCatalog.plansForCurrency(currency)) {
          expect(plan.headline, contains('/ ${plan.periodLabel}'));
        }
      }
    });
  });

  test('each region offers exactly one monthly and one yearly plan', () {
    for (final currency in ['INR', 'USD']) {
      final plans = PricingCatalog.plansForCurrency(currency);
      expect(plans.where((p) => p.period == BillingPeriod.month).length, 1);
      expect(plans.where((p) => p.period == BillingPeriod.year).length, 1);
      expect(plans.where((p) => p.popular).length, 1);
    }
  });

  test('a yearly plan never costs more than twelve monthly payments', () {
    for (final currency in ['INR', 'USD']) {
      final plans = PricingCatalog.plansForCurrency(currency);
      final monthly = plans.firstWhere((p) => p.period == BillingPeriod.month);
      final yearly = plans.firstWhere((p) => p.period == BillingPeriod.year);
      expect(yearly.amount, lessThan(monthly.amount * 12));
    }
  });
}

/// The margin floors, asserted rather than remembered.
///
/// There are two, because the allowance is a ceiling rather than a forecast.
/// The 80% target is measured at expected usage; the cap only has to keep the
/// worst case bounded. If a price, the cap, or the usage assumption moves
/// without the others, one of these fails.
void _marginTests() {
  // Measured, not estimated: a 5-minute story is 915 words at 183 wpm and
  // 5.34 chars/word — narration $0.059, script $0.037, infrastructure $0.004.
  // Planning uses a 10% buffer over the $0.100 measured cost.
  const costPerStory = 0.105;

  const targetMargin = 0.80;

  // What the heaviest possible subscriber is allowed to cost. Not a goal — a
  // bound. A plan that falls below this is one an automated client could bleed.
  const worstCaseFloor = 0.65;

  // Only used to check rupee plans against a dollar-denominated cost.
  const inrPerUsd = 86.5;

  /// Margin on the list price, before any store cut. Google Play's 15% (or 30%
  /// above $1M) comes out of what is left; it is a distribution cost, not a
  /// cost of making the story, so it is not netted off here.
  double marginAt(Plan plan, int storiesPerMonth) {
    final usd = plan.currencyCode == 'INR' ? plan.amount / inrPerUsd : plan.amount;
    final months = plan.period == BillingPeriod.year ? 12 : 1;
    final cogs = storiesPerMonth * months * costPerStory;
    return (usd - cogs) / usd;
  }

  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  group('every plan holds 80% at expected usage', () {
    for (final currency in ['INR', 'USD']) {
      for (final plan in PricingCatalog.plansForCurrency(currency)) {
        test('${plan.id} clears $targetMargin', () {
          final margin = marginAt(plan, PricingCatalog.expectedMonthlyStories);
          expect(
            margin,
            greaterThanOrEqualTo(targetMargin),
            reason:
                '${plan.headline} at ${PricingCatalog.expectedMonthlyStories} '
                'stories/month leaves ${pct(margin)} — raise the price, or '
                'lower expectedMonthlyStories if real usage says otherwise',
          );
        });
      }
    }
  });

  group('the cap keeps the worst case bounded', () {
    for (final currency in ['INR', 'USD']) {
      for (final plan in PricingCatalog.plansForCurrency(currency)) {
        test('${plan.id} survives a subscriber who maxes out', () {
          final margin = marginAt(plan, PricingCatalog.plusMonthlyStories);
          expect(
            margin,
            greaterThanOrEqualTo(worstCaseFloor),
            reason:
                '${plan.headline} at the ${PricingCatalog.plusMonthlyStories}-story '
                'cap leaves ${pct(margin)} — lower plusMonthlyStories or raise '
                'the price',
          );
        });
      }
    }
  });

  test('the allowance is a ceiling, not a forecast', () {
    // If these ever meet, the cap has stopped being a bound on the outlier and
    // started being the plan — at which point the 80% target has to be
    // measured against it, and the prices in the doc comment apply.
    expect(
      PricingCatalog.expectedMonthlyStories,
      lessThan(PricingCatalog.plusMonthlyStories),
    );
  });

  test('the yearly plan is the binding constraint', () {
    // Worth knowing: yearly always has the thinner margin, so it is the one to
    // check first when any of these numbers moves.
    for (final currency in ['INR', 'USD']) {
      final plans = PricingCatalog.plansForCurrency(currency);
      final monthly = plans.firstWhere((p) => p.period == BillingPeriod.month);
      final yearly = plans.firstWhere((p) => p.period == BillingPeriod.year);
      final at = PricingCatalog.plusMonthlyStories;
      expect(marginAt(yearly, at), lessThan(marginAt(monthly, at)));
    }
  });
}
