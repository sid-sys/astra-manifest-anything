import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Buying Astra Plus.
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
    : _store = store ?? InAppPurchase.instance,
      _injectedFunctions = functions;

  final InAppPurchase _store;
  final FirebaseFunctions? _injectedFunctions;

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
      debugPrint('Astra: no functions available for billing — $error');
      return null;
    }
  }

  /// Subscription ids as created in the Play Console. Must match
  /// `PLAY_SUBSCRIPTIONS` in `functions/index.js`.
  static const monthlyId = 'astra_plus_monthly';
  static const yearlyId = 'astra_plus_yearly';
  static const productIds = <String>{monthlyId, yearlyId};

  StreamSubscription<List<PurchaseDetails>>? _watch;

  /// True when a store is present at all. False on web and on a device with
  /// no Play Services, where the paywall has to say so rather than opening a
  /// sheet that will never appear.
  Future<bool> get isAvailable => _store.isAvailable();

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
      debugPrint('Astra: store has no record of ${response.notFoundIDs}');
    }

    return response.productDetails;
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
          try {
            final granted = await _verify(purchase);
            if (!completer.isCompleted) completer.complete(granted);
          } catch (error) {
            if (!completer.isCompleted) completer.completeError(error);
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
    await _watch?.cancel();
    final done = Completer<bool>();
    _watch = _store.purchaseStream.listen(
      (purchases) => _handle(purchases, done),
      onError: (Object error) => debugPrint('Astra: restore failed — $error'),
    );

    await _store.restorePurchases();
  }

  void dispose() {
    unawaited(_watch?.cancel());
  }
}
