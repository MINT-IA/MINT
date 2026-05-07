// Regression: P4 walkthrough 2026-05-07 — « Depuis la galerie » silent fail
// in mode local because `ConsentService.list()` threw on /consents 401 →
// uncaught propagation through `_onGalleryPressed` → file picker never
// opens.
//
// Asserts the local-fallback contract:
//   * `LocalConsentStoreForTests.grant(p)` persists a `ConsentReceipt` to
//     SharedPreferences with the current policy version.
//   * `LocalConsentStoreForTests.load()` returns the persisted receipts on
//     a fresh instance (cross-restart durability).
//   * `ConsentReceipt.toJson` / `fromJson` round-trip is symmetric so the
//     same deserializer can read both backend + local payloads.
//
// HTTP-level fallback (401 → local) is verified at the sim walker layer
// (G1 gate, PERIMETERS.md). A proper unit test for the 401 path requires
// `ApiService` to accept an injectable `http.Client`, which is its own
// follow-up PR — out of scope for P4.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/consent/consent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConsentService — local fallback (P4 walkthrough fix)', () {
    test('grant() persists locally + load() returns it', () async {
      await LocalConsentStoreForTests.grant(ConsentPurpose.visionExtraction);
      final loaded = await LocalConsentStoreForTests.load();

      expect(loaded.length, 1);
      expect(loaded.first.purpose, ConsentPurpose.visionExtraction);
      expect(loaded.first.policyVersion, ConsentService.currentPolicyVersion);
      expect(loaded.first.isActive, isTrue);
      expect(loaded.first.receiptId, startsWith('local-'));
    });

    test('grant() of same purpose replaces prior local receipt', () async {
      final first =
          await LocalConsentStoreForTests.grant(ConsentPurpose.visionExtraction);
      await Future<void>.delayed(const Duration(microseconds: 1));
      final second =
          await LocalConsentStoreForTests.grant(ConsentPurpose.visionExtraction);

      final loaded = await LocalConsentStoreForTests.load();
      expect(loaded.length, 1, reason: 'Should not duplicate same purpose');
      expect(loaded.first.receiptId, isNot(equals(first.receiptId)));
      expect(loaded.first.receiptId, second.receiptId);
    });

    test('grant() of different purposes accumulates', () async {
      await LocalConsentStoreForTests.grant(ConsentPurpose.visionExtraction);
      await LocalConsentStoreForTests.grant(ConsentPurpose.persistence365d);
      await LocalConsentStoreForTests.grant(ConsentPurpose.transferUsAnthropic);

      final loaded = await LocalConsentStoreForTests.load();
      expect(loaded.length, 3);
      expect(
        loaded.map((r) => r.purpose).toSet(),
        {
          ConsentPurpose.visionExtraction,
          ConsentPurpose.persistence365d,
          ConsentPurpose.transferUsAnthropic,
        },
      );
    });

    test('clear() empties the local store', () async {
      await LocalConsentStoreForTests.grant(ConsentPurpose.visionExtraction);
      await LocalConsentStoreForTests.clear();
      final loaded = await LocalConsentStoreForTests.load();
      expect(loaded, isEmpty);
    });

    test('load() returns empty list when SharedPreferences is fresh', () async {
      final loaded = await LocalConsentStoreForTests.load();
      expect(loaded, isEmpty);
    });

    test('ConsentReceipt round-trips through toJson/fromJson', () {
      final ts = DateTime.utc(2026, 5, 7, 12, 0);
      final receipt = ConsentReceipt(
        receiptId: 'r1',
        purpose: ConsentPurpose.transferUsAnthropic,
        policyVersion: 'v2.3.0',
        consentTimestamp: ts,
      );
      final restored = ConsentReceipt.fromJson(receipt.toJson());
      expect(restored.receiptId, 'r1');
      expect(restored.purpose, ConsentPurpose.transferUsAnthropic);
      expect(restored.policyVersion, 'v2.3.0');
      expect(restored.consentTimestamp.toUtc(), ts);
      expect(restored.isActive, isTrue);
      expect(restored.toJson()['revokedAt'], isNull);
    });

    test('ConsentReceipt with revokedAt round-trips', () {
      final ts = DateTime.utc(2026, 5, 7, 12, 0);
      final revoked = DateTime.utc(2026, 5, 7, 13, 0);
      final receipt = ConsentReceipt(
        receiptId: 'r2',
        purpose: ConsentPurpose.coupleProjection,
        policyVersion: 'v2.3.0',
        consentTimestamp: ts,
        revokedAt: revoked,
      );
      final restored = ConsentReceipt.fromJson(receipt.toJson());
      expect(restored.isActive, isFalse);
      expect(restored.revokedAt?.toUtc(), revoked);
    });
  });
}
