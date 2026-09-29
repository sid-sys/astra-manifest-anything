import 'package:astra/services/billing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// A subscription with a free trial is not one product to Play.
///
/// It is one product with several *offers* — the bare base plan, and the base
/// plan with three days free in front of it — and `queryProductDetails` hands
/// back a separate [ProductDetails] for each, all sharing the same `id`.
///
/// That is the whole reason this file exists. The obvious way to hold those
/// results is a map keyed by id, and the obvious way is wrong twice over: it
/// drops every offer but one, in an order Play does not document, and the entry
/// it keeps reports the price of its *first* pricing phase — which for a trial
/// is zero.
///
/// Both failures are silent, and both are about money.

/// The two offers Play returns for a product with an active trial, in the order
/// the base plan happens to come first.
List<ProductDetails> _offers({required bool trial}) {
  final wrapper = ProductDetailsWrapper(
    description: 'Maya Plus',
    name: 'Maya Plus',
    productId: 'astra_plus_monthly',
    productType: ProductType.subs,
    title: 'Maya Plus (Maya)',
    subscriptionOfferDetails: [
      const SubscriptionOfferDetailsWrapper(
        basePlanId: 'astra-plus-monthly',
        offerTags: [],
        offerIdToken: 'token-base-plan',
        pricingPhases: [
          PricingPhaseWrapper(
            billingCycleCount: 0,
            billingPeriod: 'P1M',
            formattedPrice: '₹649.00',
            priceAmountMicros: 649000000,
            priceCurrencyCode: 'INR',
            recurrenceMode: RecurrenceMode.infiniteRecurring,
          ),
        ],
      ),
      if (trial)
        const SubscriptionOfferDetailsWrapper(
          basePlanId: 'astra-plus-monthly',
          offerId: 'monthly-trial-3day',
          offerTags: [],
          offerIdToken: 'token-with-trial',
          pricingPhases: [
            // Three days at nothing...
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P3D',
              formattedPrice: 'Free',
              priceAmountMicros: 0,
              priceCurrencyCode: 'INR',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            // ...then the base plan price, forever.
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1M',
              formattedPrice: '₹649.00',
              priceAmountMicros: 649000000,
              priceCurrencyCode: 'INR',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
    ],
  );

  return GooglePlayProductDetails.fromProductDetails(wrapper);
}

void main() {
  test('Play returns one entry per offer, all under the same id', () {
    // The premise everything below rests on. If this ever stops being true the
    // rest of these tests are checking nothing.
    final offers = _offers(trial: true);

    expect(offers, hasLength(2));
    expect(offers.map((offer) => offer.id).toSet(), {'astra_plus_monthly'});
  });

  test('the offer with the free phase is the one that gets bought', () {
    final chosen = BillingService.resolveOffer(_offers(trial: true));

    // Not the first in the list, which is the bare base plan. Picking by
    // position — or by last-write-wins in a map — takes the user's money on
    // the spot under a button that said "start my free trial".
    expect(
      (chosen.product as GooglePlayProductDetails).offerToken,
      'token-with-trial',
    );
    expect(chosen.hasIntroPhase, isTrue);
  });

  test('the price shown is what recurs, not the free phase', () {
    final chosen = BillingService.resolveOffer(_offers(trial: true));

    // ProductDetails.price for a trial offer is its first phase: zero. The
    // paywall prints this straight into "After that ___, unless you cancel",
    // so reading it off the wrong phase promises a subscription that is free
    // forever.
    expect(chosen.product.price, anyOf('Free', '₹0.00'));
    expect(chosen.price, '₹649.00');
  });

  test('no trial offer means the copy has to stop promising one', () {
    // What the app sees when the offer is still a draft in the Console, when
    // it does not cover the user's country, or when the user has already spent
    // their trial — Play simply withholds it in all three.
    final chosen = BillingService.resolveOffer(_offers(trial: false));

    expect(chosen.hasIntroPhase, isFalse);
    expect(chosen.price, '₹649.00');
    expect(
      (chosen.product as GooglePlayProductDetails).offerToken,
      'token-base-plan',
    );
  });

  test('a store with no pricing phases still yields something buyable', () {
    // StoreKit models trials differently and never populates these, so the
    // resolution has to degrade to "the only thing on offer" rather than
    // throwing on an empty phase list.
    final chosen = BillingService.resolveOffer([
      ProductDetails(
        id: 'astra_plus_monthly',
        title: 'Maya Plus',
        description: 'Maya Plus',
        price: r'$7.99',
        rawPrice: 7.99,
        currencyCode: 'USD',
      ),
    ]);

    expect(chosen.price, r'$7.99');
    expect(chosen.hasIntroPhase, isFalse);
  });
}
