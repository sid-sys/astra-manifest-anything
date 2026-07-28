import 'package:astra/models/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

      expect(monthly.headline, '₹299 / month');
      expect(monthly.subline, 'billed monthly · cancel anytime');
      expect(yearly.headline, '₹1,999 / year');
      // The yearly tile does the division so the user doesn't have to.
      expect(yearly.subline, '₹167 / month · billed once yearly');
    });

    test('dollar plans keep their cents', () {
      final plans = PricingCatalog.plansForCountry('US');
      final monthly = plans.firstWhere((p) => p.period == BillingPeriod.month);
      final yearly = plans.firstWhere((p) => p.period == BillingPeriod.year);

      expect(monthly.headline, r'$6.99 / month');
      expect(yearly.headline, r'$44.99 / year');
      expect(yearly.subline, r'$3.75 / month · billed once yearly');
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
