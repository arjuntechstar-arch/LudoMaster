import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'api_client.dart';

/// Completes store transactions only after the API has granted verified rewards.
class BillingService extends ChangeNotifier {
  BillingService._();
  static final instance = BillingService._();
  static bool get supportsGooglePlay =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  ApiClient? _api;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _processing = Future.value();
  final Map<String, ProductDetails> products = {};
  final Map<String, IapProductModel> _catalog = {};
  bool available = false;
  bool busy = false;
  int completedPurchases = 0;
  String? notice;

  Future<void> initialize(ApiClient api) async {
    _api = api;
    if (!supportsGooglePlay) return;
    // Load consumption rules before pending purchases can arrive on the stream.
    try {
      final catalog = await api.getIapProducts();
      _catalog.clear();
      _catalog.addEntries(
        catalog.map((product) => MapEntry(product.id, product)),
      );
    } catch (_) {
      available = false;
      notice = 'Purchases are currently unavailable';
      notifyListeners();
      return;
    }
    _subscription ??= InAppPurchase.instance.purchaseStream.listen(
      (purchases) {
        _processing = _processing.then((_) => _handleUpdates(purchases));
      },
      onError: (Object error) {
        busy = false;
        notice = 'Google Play could not complete this purchase';
        notifyListeners();
      },
    );
    try {
      final config = await api.getPurchaseConfiguration();
      if (config['google_play_enabled'] != true ||
          !await InAppPurchase.instance.isAvailable()) {
        available = false;
        notifyListeners();
        return;
      }
      final result = await InAppPurchase.instance.queryProductDetails(
        _catalog.keys.toSet(),
      );
      products.clear();
      products.addEntries(
        result.productDetails.map((product) => MapEntry(product.id, product)),
      );
      available = result.error == null && products.isNotEmpty;
      if (!available) notice = 'Purchases are currently unavailable';
      notifyListeners();
    } catch (_) {
      available = false;
      notice = 'Purchases are currently unavailable';
      notifyListeners();
    }
  }

  String? priceFor(String productId) =>
      available ? products[productId]?.price : null;

  Future<void> purchase(IapProductModel product) async {
    final api = _api;
    final details = products[product.id];
    if (!available || details == null || api?.userId == null) {
      throw Exception('This product is currently unavailable');
    }
    if (busy) return;
    busy = true;
    notice = null;
    notifyListeners();
    try {
      final accountId = sha256.convert(utf8.encode(api!.userId!)).toString();
      final parameter = PurchaseParam(
        productDetails: details,
        applicationUserName: accountId,
      );
      final started = product.consumable
          ? await InAppPurchase.instance.buyConsumable(
              purchaseParam: parameter,
              autoConsume: false,
            )
          : await InAppPurchase.instance.buyNonConsumable(
              purchaseParam: parameter,
            );
      if (!started) throw Exception('Google Play checkout could not be opened');
    } catch (_) {
      busy = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    if (!supportsGooglePlay || !available) return;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _handleUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) {
          busy = true;
          notice = 'Payment pending. Items appear after payment is confirmed.';
          notifyListeners();
          continue;
        }
        if (purchase.status == PurchaseStatus.error ||
            purchase.status == PurchaseStatus.canceled) {
          busy = false;
          notice = purchase.status == PurchaseStatus.canceled
              ? 'Purchase cancelled'
              : 'Purchase could not be completed';
          notifyListeners();
          continue;
        }
        if (purchase.status != PurchaseStatus.purchased &&
            purchase.status != PurchaseStatus.restored) {
          continue;
        }
        final api = _api;
        if (api?.userId == null) {
          throw Exception('Sign in to finish your purchase');
        }
        final result = await api!.verifyIapReceipt(
          productId: purchase.productID,
          transactionId: purchase.purchaseID ?? purchase.productID,
          platform: 'GOOGLE_PLAY',
          rawReceipt: purchase.verificationData.serverVerificationData,
        );
        if (result.status != 'SUCCESS') {
          throw Exception('Purchase verification is pending');
        }
        final catalogProduct = _catalog[purchase.productID];
        if (catalogProduct == null) {
          throw Exception(
            'This product is unavailable. Please refresh the Store.',
          );
        }
        if (catalogProduct.consumable) {
          final consumed = await InAppPurchase.instance
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
              .consumePurchase(purchase);
          if (consumed.responseCode != BillingResponse.ok) {
            throw Exception(
              'Purchase delivered. Reopen the Store to finish processing.',
            );
          }
        }
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        busy = false;
        completedPurchases++;
        notice =
            'Purchase complete! Your wallet and inventory have been updated.';
        notifyListeners();
      } catch (_) {
        busy = false;
        notice = 'Could not finish verifying your purchase. Reopen the Store or restore purchases to retry.';
        notifyListeners();
      }
    }
  }
}
