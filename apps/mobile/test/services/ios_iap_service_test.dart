import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:mint_mobile/services/ios_iap_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FAKE PLATFORM — extends InAppPurchasePlatform so PlatformInterface.verify
// accepts it when assigned to InAppPurchasePlatform.instance.
// All IAP interactions are recorded and controllable.
// ═══════════════════════════════════════════════════════════════════════════

class FakeInAppPurchasePlatform extends InAppPurchasePlatform {
  bool isAvailableReturn = true;
  ProductDetailsResponse? queryProductDetailsReturn;
  bool buyNonConsumableReturn = true;
  final List<PurchaseDetails> completedPurchases = [];
  bool restorePurchasesCalled = false;
  int queryProductDetailsCalls = 0;
  int buyNonConsumableCalls = 0;

  final StreamController<List<PurchaseDetails>> purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      purchaseStreamController.stream;

  @override
  Future<bool> isAvailable() async => isAvailableReturn;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queryProductDetailsCalls++;
    return queryProductDetailsReturn ??
        ProductDetailsResponse(
          productDetails: <ProductDetails>[],
          notFoundIDs: identifiers.toList(),
        );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyNonConsumableCalls++;
    return buyNonConsumableReturn;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  void dispose() {
    purchaseStreamController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

ProductDetails _coachProduct() => ProductDetails(
      id: IosIapService.coachMonthlyProductId,
      title: 'Coach Monthly',
      description: 'Monthly coaching subscription',
      price: 'CHF 4.90',
      rawPrice: 4.90,
      currencyCode: 'CHF',
    );

PurchaseDetails _makePurchase({
  required PurchaseStatus status,
  String? productId,
  String? purchaseId,
  bool pendingComplete = false,
}) {
  final pd = PurchaseDetails(
    purchaseID: purchaseId ?? 'txn_001',
    productID: productId ?? IosIapService.coachMonthlyProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local_receipt_data',
      serverVerificationData: 'server_signed_payload',
      source: 'app_store',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
  );
  pd.pendingCompletePurchase = pendingComplete;
  return pd;
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

/// Unit tests for IosIapService (iOS In-App Purchase integration).
///
/// Tests cover:
///   1.  Platform gate (non-iOS returns early)
///   2.  Product query (fetchProducts)
///   3.  Purchase initiation and StoreKit flow
///   4.  Purchase success updating state via receipt verification
///   5.  Purchase cancellation handling
///   6.  Purchase failure / error handling
///   7.  Receipt verification with backend
///   8.  Restore purchases (with and without history)
///   9.  StoreKit stream error resilience
///   10. Product ID constant correctness
///   11. completePurchase called when pendingCompletePurchase flag is set
///   12. Pending purchase status skipped until final status arrives
///   13. Ignores purchases for other product IDs
///   14. Transaction ID falls back to hashCode when purchaseID is null
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeInAppPurchasePlatform fakePlatform;

  // Tracks receipt verification calls from the service.
  final List<Map<String, String?>> verifyCalls = [];
  bool verifyThrows = false;

  setUp(() {
    verifyCalls.clear();
    verifyThrows = false;

    fakePlatform = FakeInAppPurchasePlatform();

    // Inject fake platform directly — avoids triggering InAppPurchase.instance
    // which would try to register platform-specific channels.
    IosIapService.platformInstance = fakePlatform;

    // Override platform check to simulate iOS.
    IosIapService.overridePlatformCheck(true);

    // Override the verify function to avoid real HTTP calls.
    IosIapService.verifyFn = ({
      required String productId,
      required String transactionId,
      String? originalTransactionId,
      String? signedPayload,
    }) async {
      verifyCalls.add({
        'productId': productId,
        'transactionId': transactionId,
        'originalTransactionId': originalTransactionId,
        'signedPayload': signedPayload,
      });
      if (verifyThrows) {
        throw Exception('Backend verification failed');
      }
      return {'status': 'ok'};
    };
  });

  tearDown(() {
    fakePlatform.dispose();
    IosIapService.resetOverrides();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. PLATFORM GATE
  // ═══════════════════════════════════════════════════════════════════════

  group('Platform gate', () {
    test('purchaseCoachMonthly returns false on non-iOS platform', () async {
      IosIapService.overridePlatformCheck(false);

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
      // Should never reach IAP — no query calls made.
      expect(fakePlatform.queryProductDetailsCalls, 0);
    });

    test('restoreAndSync returns false on non-iOS platform', () async {
      IosIapService.overridePlatformCheck(false);

      final result = await IosIapService.restoreAndSync();

      expect(result, isFalse);
      expect(fakePlatform.restorePurchasesCalled, isFalse);
    });

    test('isSupportedPlatform reflects override value', () {
      IosIapService.overridePlatformCheck(true);
      expect(IosIapService.isSupportedPlatform, isTrue);

      IosIapService.overridePlatformCheck(false);
      expect(IosIapService.isSupportedPlatform, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. PRODUCT QUERY
  // ═══════════════════════════════════════════════════════════════════════

  group('Product query', () {
    test('fetchProducts queries StoreKit with correct product ID', () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );
      // buyNonConsumable returns false so the flow exits early after query.
      fakePlatform.buyNonConsumableReturn = false;

      await IosIapService.purchaseCoachMonthly();

      expect(fakePlatform.queryProductDetailsCalls, 1);
    });

    test('purchaseCoachMonthly returns false when product not found', () async {
      // Empty product list — product not configured in App Store Connect.
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: [IosIapService.coachMonthlyProductId],
      );

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
      expect(fakePlatform.buyNonConsumableCalls, 0,
          reason: 'Should not attempt purchase if product was not found');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. PURCHASE FLOW INITIATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Purchase flow', () {
    test('purchaseCoachMonthly initiates purchase via buyNonConsumable',
        () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );
      fakePlatform.buyNonConsumableReturn = true;

      // The purchase will block on the completer; emit a purchased event.
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.purchased),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(fakePlatform.buyNonConsumableCalls, 1);
      expect(result, isTrue);
    });

    test('purchase returns false when buyNonConsumable launch fails', () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );
      fakePlatform.buyNonConsumableReturn = false;

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. PURCHASE SUCCESS + RECEIPT VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Purchase success', () {
    test('purchase success verifies receipt with backend and returns true',
        () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.purchased),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isTrue);
      expect(verifyCalls, hasLength(1));
      expect(verifyCalls.first['productId'],
          IosIapService.coachMonthlyProductId);
      expect(verifyCalls.first['signedPayload'], 'server_signed_payload');
    });

    test('completePurchase called when pendingCompletePurchase is true',
        () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(
            status: PurchaseStatus.purchased,
            pendingComplete: true,
          ),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isTrue);
      expect(fakePlatform.completedPurchases, hasLength(1));
    });

    test('restored status also triggers verification and returns true',
        () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.restored),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isTrue);
      expect(verifyCalls, hasLength(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. PURCHASE CANCELLED
  // ═══════════════════════════════════════════════════════════════════════

  group('Purchase cancelled', () {
    test('user cancel returns false without triggering verification',
        () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.canceled),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
      expect(verifyCalls, isEmpty,
          reason: 'No receipt verification on cancel');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. PURCHASE FAILURE / ERROR
  // ═══════════════════════════════════════════════════════════════════════

  group('Purchase failure', () {
    test('purchase error status returns false', () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.error),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
      expect(verifyCalls, isEmpty,
          reason: 'No receipt verification on error');
    });

    test('backend verification failure returns false', () async {
      verifyThrows = true;

      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.purchased),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
      expect(verifyCalls, hasLength(1),
          reason: 'Verification was attempted but threw');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. RESTORE PURCHASES
  // ═══════════════════════════════════════════════════════════════════════

  group('Restore purchases', () {
    test('restoreAndSync restores previous purchases', () async {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.restored),
        ]);
      });

      final result = await IosIapService.restoreAndSync();

      expect(result, isTrue);
      expect(fakePlatform.restorePurchasesCalled, isTrue);
      expect(verifyCalls, hasLength(1));
    });

    test('restoreAndSync with store unavailable returns false', () async {
      fakePlatform.isAvailableReturn = false;

      final result = await IosIapService.restoreAndSync();

      expect(result, isFalse);
      expect(fakePlatform.restorePurchasesCalled, isFalse);
    });

    test('restoreAndSync calls completePurchase for pending purchases',
        () async {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(
            status: PurchaseStatus.restored,
            pendingComplete: true,
          ),
        ]);
      });

      final result = await IosIapService.restoreAndSync();

      expect(result, isTrue);
      expect(fakePlatform.completedPurchases, hasLength(1));
    });

    test('restoreAndSync continues scanning even if one verify fails',
        () async {
      // First call throws, second succeeds.
      int callCount = 0;
      IosIapService.verifyFn = ({
        required String productId,
        required String transactionId,
        String? originalTransactionId,
        String? signedPayload,
      }) async {
        callCount++;
        if (callCount == 1) throw Exception('Temporary failure');
        return {'status': 'ok'};
      };

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(
            status: PurchaseStatus.restored,
            purchaseId: 'txn_first',
          ),
          _makePurchase(
            status: PurchaseStatus.restored,
            purchaseId: 'txn_second',
          ),
        ]);
      });

      final result = await IosIapService.restoreAndSync();

      expect(result, isTrue);
      expect(callCount, 2,
          reason: 'Both purchases should be verified despite first failure');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. STOREKIT ERROR RESILIENCE
  // ═══════════════════════════════════════════════════════════════════════

  group('StoreKit error resilience', () {
    test('purchaseCoachMonthly returns false when store is unavailable',
        () async {
      fakePlatform.isAvailableReturn = false;

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
      expect(fakePlatform.queryProductDetailsCalls, 0);
    });

    test('purchaseStream error completes with false', () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.addError(
          Exception('StoreKit connection lost'),
        );
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isFalse);
    });

    test('restoreAndSync stream error completes with false', () async {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        fakePlatform.purchaseStreamController.addError(
          Exception('StoreKit error during restore'),
        );
      });

      final result = await IosIapService.restoreAndSync();

      expect(result, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. PENDING STATUS HANDLING
  // ═══════════════════════════════════════════════════════════════════════

  group('Pending status', () {
    test('pending purchase is skipped; waits for final status', () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      // First emit pending, then purchased.
      Future<void>.delayed(const Duration(milliseconds: 30), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.pending),
        ]);
      });
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.purchased),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isTrue);
      expect(verifyCalls, hasLength(1),
          reason: 'Only the purchased event triggers verification');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. PRODUCT ID + CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════

  group('Constants', () {
    test('coachMonthlyProductId has correct default value', () {
      expect(
        IosIapService.coachMonthlyProductId,
        'ch.mint.coach.monthly',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 11. PRODUCT ID FILTERING
  // ═══════════════════════════════════════════════════════════════════════

  group('Product ID filtering', () {
    test('purchaseCoachMonthly ignores events for other product IDs',
        () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      // First emit a purchase for a different product, then the correct one.
      Future<void>.delayed(const Duration(milliseconds: 30), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(
            status: PurchaseStatus.purchased,
            productId: 'com.other.product',
          ),
        ]);
      });
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        fakePlatform.purchaseStreamController.add([
          _makePurchase(status: PurchaseStatus.purchased),
        ]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isTrue);
      // Only one verify call — the one for the correct product.
      expect(verifyCalls, hasLength(1));
      expect(verifyCalls.first['productId'],
          IosIapService.coachMonthlyProductId);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 12. TRANSACTION ID FALLBACK
  // ═══════════════════════════════════════════════════════════════════════

  group('Transaction ID fallback', () {
    test('uses hashCode string when purchaseID is null', () async {
      final product = _coachProduct();
      fakePlatform.queryProductDetailsReturn = ProductDetailsResponse(
        productDetails: [product],
        notFoundIDs: const [],
      );

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        final pd = PurchaseDetails(
          purchaseID: null,
          productID: IosIapService.coachMonthlyProductId,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local',
            serverVerificationData: 'server',
            source: 'app_store',
          ),
          transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
          status: PurchaseStatus.purchased,
        );
        fakePlatform.purchaseStreamController.add([pd]);
      });

      final result = await IosIapService.purchaseCoachMonthly();

      expect(result, isTrue);
      expect(verifyCalls, hasLength(1));
      // transactionId should be the hashCode string, not null.
      final txnId = verifyCalls.first['transactionId']!;
      expect(txnId, isNotEmpty);
      expect(txnId, isNot('null'));
      // originalTransactionId should be null since purchaseID was null.
      expect(verifyCalls.first['originalTransactionId'], isNull);
    });
  });
}
