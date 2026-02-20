import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mint_mobile/services/api_service.dart';

class IosIapService {
  static const String coachMonthlyProductId = String.fromEnvironment(
    'APPLE_IAP_COACH_MONTHLY',
    defaultValue: 'ch.mint.coach.monthly',
  );

  static final InAppPurchase _iap = InAppPurchase.instance;

  static bool get isSupportedPlatform => Platform.isIOS;

  static Future<bool> purchaseCoachMonthly() async {
    if (!isSupportedPlatform) return false;
    final available = await _iap.isAvailable();
    if (!available) return false;

    final productResp = await _iap.queryProductDetails({coachMonthlyProductId});
    if (productResp.productDetails.isEmpty) return false;
    final product = productResp.productDetails.first;

    final completer = Completer<bool>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != coachMonthlyProductId) continue;
          if (purchase.status == PurchaseStatus.pending) continue;

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            try {
              await ApiService.verifyApplePurchase(
                productId: purchase.productID,
                transactionId: purchase.purchaseID ?? purchase.hashCode.toString(),
                originalTransactionId: purchase.purchaseID,
                signedPayload: purchase.verificationData.serverVerificationData,
              );
              if (purchase.pendingCompletePurchase) {
                await _iap.completePurchase(purchase);
              }
              if (!completer.isCompleted) completer.complete(true);
            } catch (_) {
              if (!completer.isCompleted) completer.complete(false);
            }
          } else if (purchase.status == PurchaseStatus.error ||
              purchase.status == PurchaseStatus.canceled) {
            if (!completer.isCompleted) completer.complete(false);
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    final param = PurchaseParam(productDetails: product);
    final launched = await _iap.buyNonConsumable(purchaseParam: param);
    if (!launched) {
      await sub.cancel();
      return false;
    }

    final ok = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => false,
    );
    await sub.cancel();
    return ok;
  }

  static Future<bool> restoreAndSync() async {
    if (!isSupportedPlatform) return false;
    final available = await _iap.isAvailable();
    if (!available) return false;

    final completer = Completer<bool>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen(
      (purchases) async {
        bool restoredAny = false;
        for (final purchase in purchases) {
          if (purchase.status != PurchaseStatus.restored &&
              purchase.status != PurchaseStatus.purchased) {
            continue;
          }
          restoredAny = true;
          try {
            await ApiService.verifyApplePurchase(
              productId: purchase.productID,
              transactionId: purchase.purchaseID ?? purchase.hashCode.toString(),
              originalTransactionId: purchase.purchaseID,
              signedPayload: purchase.verificationData.serverVerificationData,
            );
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
          } catch (_) {
            // Keep scanning remaining restored purchases.
          }
        }
        if (restoredAny && !completer.isCompleted) {
          completer.complete(true);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _iap.restorePurchases();
    final ok = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    );
    await sub.cancel();
    return ok;
  }
}
