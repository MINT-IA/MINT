import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:mint_mobile/services/api_service.dart';

/// Callback type for server-side receipt verification.
typedef VerifyApplePurchaseFn = Future<Map<String, dynamic>> Function({
  required String productId,
  required String transactionId,
  String? originalTransactionId,
  String? signedPayload,
});

class IosIapService {
  static const String coachMonthlyProductId = String.fromEnvironment(
    'APPLE_IAP_COACH_MONTHLY',
    defaultValue: 'ch.mint.coach.monthly',
  );

  /// Platform-level IAP interface. Overridable for testing.
  /// In production this delegates to InAppPurchasePlatform.instance which is
  /// registered by the in_app_purchase plugin.
  static InAppPurchasePlatform? _platformOverrideIap;

  static InAppPurchasePlatform get _platform =>
      _platformOverrideIap ?? InAppPurchasePlatform.instance;

  /// Override the [InAppPurchasePlatform] used by this service.
  @visibleForTesting
  static set platformInstance(InAppPurchasePlatform value) =>
      _platformOverrideIap = value;

  static bool _platformCheckOverride = false;
  static bool _platformCheckOverrideValue = false;

  /// Override the platform check for tests.
  @visibleForTesting
  static void overridePlatformCheck(bool value) {
    _platformCheckOverride = true;
    _platformCheckOverrideValue = value;
  }

  /// Reset the platform check to its default (dart:io) behaviour.
  @visibleForTesting
  static void resetPlatformCheck() {
    _platformCheckOverride = false;
    _platformCheckOverrideValue = false;
  }

  static VerifyApplePurchaseFn _verifyFn = _defaultVerify;

  static Future<Map<String, dynamic>> _defaultVerify({
    required String productId,
    required String transactionId,
    String? originalTransactionId,
    String? signedPayload,
  }) =>
      ApiService.verifyApplePurchase(
        productId: productId,
        transactionId: transactionId,
        originalTransactionId: originalTransactionId,
        signedPayload: signedPayload,
      );

  /// Override the receipt-verification function for tests.
  @visibleForTesting
  static set verifyFn(VerifyApplePurchaseFn fn) => _verifyFn = fn;

  /// Reset overrides to production defaults.
  @visibleForTesting
  static void resetOverrides() {
    _platformOverrideIap = null;
    _verifyFn = _defaultVerify;
    resetPlatformCheck();
  }

  static bool get isSupportedPlatform =>
      _platformCheckOverride ? _platformCheckOverrideValue : Platform.isIOS;

  static Future<bool> purchaseCoachMonthly() async {
    if (!isSupportedPlatform) return false;
    final available = await _platform.isAvailable();
    if (!available) return false;

    final productResp =
        await _platform.queryProductDetails({coachMonthlyProductId});
    if (productResp.productDetails.isEmpty) return false;
    final product = productResp.productDetails.first;

    final completer = Completer<bool>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _platform.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != coachMonthlyProductId) continue;
          if (purchase.status == PurchaseStatus.pending) continue;

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            try {
              await _verifyFn(
                productId: purchase.productID,
                transactionId:
                    purchase.purchaseID ?? purchase.hashCode.toString(),
                originalTransactionId: purchase.purchaseID,
                signedPayload:
                    purchase.verificationData.serverVerificationData,
              );
              if (purchase.pendingCompletePurchase) {
                await _platform.completePurchase(purchase);
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
    final launched = await _platform.buyNonConsumable(purchaseParam: param);
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
    final available = await _platform.isAvailable();
    if (!available) return false;

    final completer = Completer<bool>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _platform.purchaseStream.listen(
      (purchases) async {
        bool restoredAny = false;
        for (final purchase in purchases) {
          if (purchase.status != PurchaseStatus.restored &&
              purchase.status != PurchaseStatus.purchased) {
            continue;
          }
          restoredAny = true;
          try {
            await _verifyFn(
              productId: purchase.productID,
              transactionId:
                  purchase.purchaseID ?? purchase.hashCode.toString(),
              originalTransactionId: purchase.purchaseID,
              signedPayload:
                  purchase.verificationData.serverVerificationData,
            );
            if (purchase.pendingCompletePurchase) {
              await _platform.completePurchase(purchase);
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

    await _platform.restorePurchases();
    final ok = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    );
    await sub.cancel();
    return ok;
  }
}
