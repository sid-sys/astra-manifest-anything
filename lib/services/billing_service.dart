import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// One purchasable option for a product, chosen out of everything Play offers.
///
/// A subscription with a free trial is not one product to the store — it is one
/// product with several *offers*, and `queryProductDetails` returns a separate
/// entry for each. They all carry the same `id`, so they cannot be told apart
/// by id, and the one that gets bought is whichever the caller happens to hold.
class StoreOffer {
  const StoreOffer({
    required this.product,
    required this.price,
    required this.hasIntroPhase,
  });

  /// The exact object to hand to [BillingService.buy]. Its offer token is what
  /// decides whether Play opens the sheet with a trial or with a charge.
  final ProductDetails product;

  /// What is charged once any free phase has run out.
  ///
  /// Not [ProductDetails.price], which for an offer is the price of its *first*
  /// pricing phase — zero, for a free trial. Showing that as the price of the
  /// plan would tell the user a subscription costs nothing.
  final String price;

  /// Whether this offer opens with a free phase — the trial actually existing
  /// in the Console rather than merely being promised by the app's copy.
  final bool hasIntroPhase;
}

/// Play took the purchase; the server could not confirm it.
///
/// This is its own type because it is the one billing outcome that must never
/// be reported as a failed purchase. Play has a receipt, the user has an email
/// about it, and the subscription exists on their Google account — telling
/// them "that did not go through, you have not been charged" is a lie that
/// sends them to buy it a second time, which Play then refuses with "you're
/// already subscribed" and leaves them stuck behind a paywall they have paid
/// for.
///
/// Recoverable, always, and that is the other reason it is separate: the
/// purchase is durable on Play's side, so re-presenting it later — the Restore
/// button, or the restore that runs on every sign-in — grants the entitlement
/// the moment whatever broke is fixed. Nothing is lost while it is broken.
class PurchaseNotVerified implements Exception {
  const PurchaseNotVerified(this.cause);

  final Object cause;

  @override
  String toString() => 'PurchaseNotVerified: $cause';
}

/// Buying Maya Plus.
///
/// The store is the only thing that takes money and the server is the only
/// thing that grants access. This class sits between them and does neither: it
/// asks the store to open its sheet, waits for a receipt, hands that receipt to
/// `verifyPurchase`, and reports what came back.
///
/// Nothing here decides whether someone is subscribed. That question is
/// answered by a document only the Cloud Function writes — a client that could
/// answer it would be a client that could grant it.
///
/// `in_app_purchase` rather than a Play-only package on purpose: the same API
/// covers StoreKit, so shipping on iOS later is configuration rather than a
/// second implementation of the most security-sensitive flow in the app.
class BillingService {
  BillingService({InAppPurchase? store, FirebaseFunctions? functions})
    : _injected = store,
      _injectedFunctions = functions;

  final InAppPurchase? _injected;
  final FirebaseFunctions? _injectedFunctions;

  /// Resolved on use, and never in the constructor.
  ///
  /// Returns null only where there is genuinely nothing to sell with, which is
  /// decided by [hasStore] rather than by whether this getter throws — see the
  /// note there, which is the part that was wrong for a while.
  InAppPurchase? get _maybeStore {
    if (_injected != null) return _injected;
    return hasStore ? InAppPurchase.instance : null;
  }

  /// The store, for the paths that cannot proceed without one.
  InAppPurchase get _store {
    final store = _maybeStore;
    if (store == null) {
      throw StateError('No in-app purchase implementation on this platform.');
    }
    return store;
  }

  /// Resolved on use rather than in the constructor.
  ///
  /// Reaching for `FirebaseFunctions.instanceFor` before `initializeApp`
  /// throws, and building this object must not: the paywall reads it in
  /// `initState` to fetch live prices, so on a build where Firebase never
  /// started — no network at launch, a widget test — opening the plans threw
  /// instead of falling back to the local price table.
  ///
  /// Null means there is nothing to verify a receipt against, which is caught
  /// where it matters: no verification, no entitlement.
  FirebaseFunctions? get _functions {
    if (_injectedFunctions != null) return _injectedFunctions;
    try {
      // Must match the deployed region; the default would 404 against a
      // function that lives in asia-south1.
      return FirebaseFunctions.instanceFor(region: 'asia-south1');
    } catch (error) {
      debugPrint('Maya: no functions available for billing — $error');
      return null;
    }
  }

  /// Subscription ids as created in the Play Console. Must match
  /// `PLAY_SUBSCRIPTIONS` in `functions/index.js`.
  static const monthlyId = 'astra_plus_monthly';
  static const yearlyId = 'astra_plus_yearly';
  static const productIds = <String>{monthlyId, yearlyId};

  StreamSubscription<List<PurchaseDetails>>? _watch;

  /// True when a store is present *and* prepared to sell right now. False on
  /// web, on a device with no Play Services, and while Play is updating.
  Future<bool> get isAvailable async {
    final store = _maybeStore;
    if (store == null) return false;

    try {
      return await store.isAvailable();
    } catch (error) {
      debugPrint('Maya: store would not answer — $error');
      return false;
    }
  }

  /// Whether this platform has a store implementation at all.
  ///
  /// The distinction from [isAvailable] is "you have not bought this" versus
  /// "there is nothing here that could have sold it to you", which is the
  /// whole content of what the paywall says when a restore comes back empty.
  ///
  /// The probe is `purchaseStream` rather than `InAppPurchase.instance`, and
  /// that is the entire point of this getter existing. `InAppPurchase.instance`
  /// constructs a facade on **every** platform, web included — it never throws
  /// and it is never null. The `late` platform field behind it is only touched
  /// once a method or a stream getter reaches through for it, and *that* is
  /// what throws `LateInitializationError` where no plugin registered one.
  ///
  /// Guarding on the constructor instead reported a live store on the web:
  /// every sign-in threw into the console from `restore`, the paywall
  /// explained a browser's failure as "that did not go through", and the two
  /// affordances that key off this — the web sign-out and the debug
  /// pass-through — were dead code that could never run.
  ///
  /// Reading the stream getter has no side effects; the subscription is what
  /// costs something, and nothing here subscribes.
  /// Cached after the first probe. Whether a plugin registered itself is
  /// settled before `main` runs and cannot change while the app is alive, and
  /// this is read on every build of the paywall and of Home — unmemoised, the
  /// web console filled with the same line a dozen times a screen.
  bool? _storePresent;

  bool get hasStore {
    if (_injected != null) return true;

    final known = _storePresent;
    if (known != null) return known;

    try {
      InAppPurchase.instance.purchaseStream;
      return _storePresent = true;
    } catch (error) {
      debugPrint('Maya: no store on this platform — $error');
      return _storePresent = false;
    }
  }

  /// What the store says these cost, in the user's own currency.
  ///
  /// Worth using over the local price table wherever it arrives in time: it is
  /// the number that will actually be charged, already formatted for the
  /// user's region, including any tax the store adds.
  Future<List<ProductDetails>> loadProducts() async {
    final response = await _store.queryProductDetails(productIds);

    if (response.notFoundIDs.isNotEmpty) {
      // Normal before the products are published in the Console, and a
      // permanent misconfiguration after. Either way the paywall falls back to
      // the local price table rather than showing nothing.
      debugPrint('Maya: store has no record of ${response.notFoundIDs}');
    }

    return response.productDetails;
  }

  /// The one offer to buy for each product, and the price to show for it.
  ///
  /// [loadProducts] returns one entry per *offer*, not per product, and every
  /// entry for a subscription carries the same `id`. Keying them by id — which
  /// is the obvious thing to do, and what this used to do — silently drops all
  /// but one, and Play does not document the order, so which survived was a
  /// coin flip between "starts a free trial" and "charges immediately".
  ///
  /// So the choice is made here, explicitly: the offer with a free phase wins,
  /// because that is the one the paywall's copy promises.
  Future<Map<String, StoreOffer>> loadOffers() async {
    final byId = <String, List<ProductDetails>>{};
    for (final product in await loadProducts()) {
      byId.putIfAbsent(product.id, () => []).add(product);
    }

    return byId.map((id, offers) => MapEntry(id, resolveOffer(offers)));
  }

  /// Picks the trial offer if Play has one, and reads the recurring price off
  /// whichever offer that turns out to be.
  @visibleForTesting
  static StoreOffer resolveOffer(List<ProductDetails> offers) {
    ProductDetails? free;
    for (final offer in offers) {
      if (_phasesOf(offer).any((phase) => phase.priceAmountMicros == 0)) {
        free = offer;
        break;
      }
    }

    // No free phase anywhere means no trial offer is live in the Console yet
    // — or this is StoreKit, which models trials differently and needs no
    // picking. Either way the base plan is the only thing to buy.
    final chosen = free ?? offers.first;
    final phases = _phasesOf(chosen);

    return StoreOffer(
      product: chosen,
      // The last phase, not the first: phases run in order and the base plan
      // is what follows them, so the final one is the price that recurs.
      price: phases.isEmpty ? chosen.price : phases.last.formattedPrice,
      hasIntroPhase: free != null,
    );
  }

  /// The pricing phases behind one offer, or empty off Android.
  static List<PricingPhaseWrapper> _phasesOf(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return const [];

    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) {
      return const [];
    }

    return offers[index].pricingPhases;
  }

  /// Starts a purchase and completes when the server has verified it.
  ///
  /// Returns true only if the Cloud Function confirmed the receipt with Google.
  /// A cancelled sheet returns false; a failure throws with something the user
  /// can act on.
  Future<bool> buy(ProductDetails product) async {
    final completer = Completer<bool>();

    await _watch?.cancel();
    _watch = _store.purchaseStream.listen(
      (purchases) => _handle(purchases, completer),
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );

    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );

    if (!started) {
      await _watch?.cancel();
      return false;
    }

    try {
      // The sheet is the user's to take as long as they like over; the timeout
      // exists so a stream that never speaks again cannot hang the button
      // forever.
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      await _watch?.cancel();
      _watch = null;
    }
  }

  Future<void> _handle(
    List<PurchaseDetails> purchases,
    Completer<bool> completer,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Slow payment methods — a bank transfer, a parent's approval. The
          // sheet stays up and the stream speaks again later.
          continue;

        case PurchaseStatus.canceled:
          if (!completer.isCompleted) completer.complete(false);

        case PurchaseStatus.error:
          if (!completer.isCompleted) {
            completer.completeError(
              purchase.error ??
                  PlatformException(code: 'purchase_failed'),
            );
          }

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // The purchase can legitimately happen before there is an account:
          // the hard paywall sells the trial first and asks for a sign-up
          // straight after, because a stranger will pay before they will make
          // an account. `verifyPurchase` needs a uid, so there is nothing to
          // verify against yet.
          //
          // Reporting failure here would be the worst possible outcome —
          // Play has taken the purchase, and the user would be told it did
          // not go through. So this reports success, still acknowledges to
          // Play, and leaves the entitlement to be written by the `restore()`
          // that runs the moment they sign in (see `providers.dart`).
          if (FirebaseAuth.instance.currentUser == null) {
            if (!completer.isCompleted) completer.complete(true);
          } else {
            try {
              final granted = await _verify(purchase);
              if (!completer.isCompleted) completer.complete(granted);
            } catch (error) {
              // Wrapped rather than passed through. Everything above this line
              // succeeded — Play charged, Play sent a receipt, Play recorded
              // the subscription — and only the server's confirmation failed,
              // which is a different thing to tell the user than "the purchase
              // failed". See [PurchaseNotVerified].
              debugPrint('Maya: purchase verification failed — $error');
              if (!completer.isCompleted) {
                completer.completeError(PurchaseNotVerified(error));
              }
            }
          }
      }

      // Always acknowledge. Play refunds any purchase left uncompleted for
      // three days, which would take the money back from a user who is
      // happily using the app — and the entitlement is already recorded
      // server-side by this point.
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verify(PurchaseDetails purchase) async {
    final functions = _functions;
    if (functions == null) {
      // Nothing to check the receipt with, so nothing is granted. Failing
      // closed is the only safe direction: the alternative is handing out a
      // subscription because a network call could not be made.
      throw StateError('Purchases cannot be verified on this build.');
    }

    final result = await functions
        .httpsCallable(
          'verifyPurchase',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>({
          'productId': purchase.productID,
          'purchaseToken': purchase.verificationData.serverVerificationData,
        });

    return result.data['isSubscribed'] == true;
  }

  /// Re-presents whatever the store already knows about this device.
  ///
  /// Needed on a reinstall or a new phone: the subscription is on the Google
  /// account, not the device, and without this a paying user reinstalls into a
  /// free tier. Restored purchases arrive on the same stream and are verified
  /// exactly like new ones.
  Future<void> restore() async {
    // Nothing to restore from where there is no store. This runs on every
    // sign-in, so on the web it threw a LateInitializationError into the
    // console on each one — noise that looked like a billing fault and was
    // only ever "this platform has no Play".
    final store = _maybeStore;
    if (store == null) return;

    await _watch?.cancel();
    final done = Completer<bool>();

    _watch = store.purchaseStream.listen(
      (purchases) async {
        await _handle(purchases, done);

        // Play answers a restore even when the account owns nothing — an
        // empty batch. `_handle` finds no purchase to finish the completer
        // with, so without this the wait below would always run to its full
        // timeout for the commonest case there is.
        if (!done.isCompleted) done.complete(false);
      },
      onError: (Object error) {
        debugPrint('Maya: restore failed — $error');
        if (!done.isCompleted) done.complete(false);
      },
    );

    try {
      await store.restorePurchases();

      // The wait is the whole fix.
      //
      // `restorePurchases` returns as soon as the *request* is sent. The
      // purchases themselves arrive later, on the stream, and are only worth
      // anything once the server has verified them. Returning here without
      // waiting meant the caller asked "is this user subscribed?" a
      // millisecond after asking Play to look — always before the answer
      // existed — so a user with a live subscription was told "no previous
      // purchase found for this account", and the entitlement then landed
      // quietly a second later with the message still on screen.
      await done.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      debugPrint('Maya: restore timed out waiting for Play');
    } catch (error) {
      debugPrint('Maya: restore failed — $error');
    } finally {
      await _watch?.cancel();
      _watch = null;
    }
  }

  void dispose() {
    unawaited(_watch?.cancel());
  }
}
