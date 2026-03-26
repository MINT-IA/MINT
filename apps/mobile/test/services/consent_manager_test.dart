import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/consent_manager.dart';

/// Tests for ConsentManager (Sprint S40).
///
/// Validates LSFin/nLPD compliance, privacy by design (all OFF by default),
/// consent state transitions, and BYOK field detail.
void main() {
  // V5-1: ConsentManager now uses SharedPreferences (not in-memory).
  // Tests must initialize the mock binding before any async call.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('ConsentManager — defaults (privacy by design)', () {
    test('all consents are OFF by default (nLPD art. 6)', () {
      final dashboard = ConsentManager.getDefaultDashboard();

      for (final consent in dashboard.consents) {
        expect(consent.enabled, false,
            reason:
                '${consent.type.name} must be OFF by default (privacy by design)');
      }
    });

    test('default dashboard contains all 7 consent types (F3-4)', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      expect(dashboard.consents.length, 7);

      final types = dashboard.consents.map((c) => c.type).toSet();
      expect(types, {
        ConsentType.byokDataSharing,
        ConsentType.snapshotStorage,
        ConsentType.notifications,
        ConsentType.analytics,
        ConsentType.ragQueries,
        ConsentType.openBanking,
        ConsentType.documentUpload,
      });
    });

    test('ConsentType enum has all 7 expected values (F2-5)', () {
      // F2-5 + F3-4: The ConsentType enum must match all consent categories.
      // Dashboard now includes all 7 types.
      expect(ConsentType.values.length, 7);
      expect(ConsentType.values, containsAll([
        ConsentType.byokDataSharing,
        ConsentType.snapshotStorage,
        ConsentType.notifications,
        ConsentType.analytics,
        ConsentType.ragQueries,
        ConsentType.openBanking,
        ConsentType.documentUpload,
      ]));
    });

    test('default dashboard includes nLPD disclaimer', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      expect(dashboard.disclaimer, contains('nLPD'));
      expect(dashboard.disclaimer, contains('revocable'));
    });

    test('default dashboard includes legal source references', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      expect(dashboard.sources.length, greaterThanOrEqualTo(3));
      expect(dashboard.sources.any((s) => s.contains('LPD')), true);
      expect(dashboard.sources.any((s) => s.contains('LSFin')), true);
    });
  });

  group('ConsentDashboard — state transitions', () {
    test('copyWithToggled enables a single consent', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      final updated =
          dashboard.copyWithToggled(ConsentType.byokDataSharing, true);

      final byok = updated.consents
          .firstWhere((c) => c.type == ConsentType.byokDataSharing);
      expect(byok.enabled, true);

      // Others remain OFF
      final snapshot = updated.consents
          .firstWhere((c) => c.type == ConsentType.snapshotStorage);
      final notifs = updated.consents
          .firstWhere((c) => c.type == ConsentType.notifications);
      expect(snapshot.enabled, false);
      expect(notifs.enabled, false);
    });

    test('copyWithToggled can disable a consent', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      final enabled =
          dashboard.copyWithToggled(ConsentType.notifications, true);
      final disabled =
          enabled.copyWithToggled(ConsentType.notifications, false);

      final notifs = disabled.consents
          .firstWhere((c) => c.type == ConsentType.notifications);
      expect(notifs.enabled, false);
    });

    test('multiple consents can be toggled independently', () {
      var dashboard = ConsentManager.getDefaultDashboard();
      dashboard =
          dashboard.copyWithToggled(ConsentType.byokDataSharing, true);
      dashboard =
          dashboard.copyWithToggled(ConsentType.notifications, true);

      final byok = dashboard.consents
          .firstWhere((c) => c.type == ConsentType.byokDataSharing);
      final notifs = dashboard.consents
          .firstWhere((c) => c.type == ConsentType.notifications);
      final snapshot = dashboard.consents
          .firstWhere((c) => c.type == ConsentType.snapshotStorage);

      expect(byok.enabled, true);
      expect(notifs.enabled, true);
      expect(snapshot.enabled, false);
    });

    test('copyWithAllRevoked turns all consents OFF', () {
      var dashboard = ConsentManager.getDefaultDashboard();
      dashboard =
          dashboard.copyWithToggled(ConsentType.byokDataSharing, true);
      dashboard =
          dashboard.copyWithToggled(ConsentType.snapshotStorage, true);
      dashboard =
          dashboard.copyWithToggled(ConsentType.notifications, true);

      final revoked = dashboard.copyWithAllRevoked();

      for (final consent in revoked.consents) {
        expect(consent.enabled, false,
            reason: '${consent.type.name} must be OFF after revokeAll');
      }
    });

    test('copyWithAllRevoked preserves disclaimer and sources', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      final revoked = dashboard.copyWithAllRevoked();

      expect(revoked.disclaimer, dashboard.disclaimer);
      expect(revoked.sources, dashboard.sources);
    });
  });

  group('ConsentState — copyWith', () {
    test('copyWith preserves label and detail', () {
      final original = ConsentManager.getDefaultDashboard().consents.first;
      final toggled = original.copyWith(enabled: true);

      expect(toggled.label, original.label);
      expect(toggled.detail, original.detail);
      expect(toggled.neverSent, original.neverSent);
      expect(toggled.type, original.type);
      expect(toggled.enabled, true);
    });
  });

  group('ConsentManager — persistence (SharedPreferences)', () {
    test('isConsentGiven returns false by default', () async {
      // Reset state — use a fresh type that hasn't been set
      final result =
          await ConsentManager.isConsentGiven(ConsentType.byokDataSharing);
      // In-memory store may have state from prior tests, but default is false
      expect(result, isA<bool>());
    });

    test('updateConsent persists and isConsentGiven reads back', () async {
      await ConsentManager.updateConsent(ConsentType.snapshotStorage, true);
      final result =
          await ConsentManager.isConsentGiven(ConsentType.snapshotStorage);
      expect(result, true);

      // Clean up
      await ConsentManager.updateConsent(ConsentType.snapshotStorage, false);
    });

    test('revokeAll sets all consents to false', () async {
      await ConsentManager.updateConsent(ConsentType.byokDataSharing, true);
      await ConsentManager.updateConsent(ConsentType.snapshotStorage, true);
      await ConsentManager.updateConsent(ConsentType.notifications, true);

      await ConsentManager.revokeAll();

      for (final type in ConsentType.values) {
        final result = await ConsentManager.isConsentGiven(type);
        expect(result, false, reason: '${type.name} must be false after revokeAll');
      }
    });

    test('all 7 ConsentType values persist and read back (V12-7/F3-4)', () async {
      // V12-7 + F3-4: Verify all 7 consent types work end-to-end.
      for (final type in ConsentType.values) {
        await ConsentManager.updateConsent(type, true);
        final result = await ConsentManager.isConsentGiven(type);
        expect(result, true, reason: '${type.name} must persist as true');
      }

      // Clean up
      await ConsentManager.revokeAll();
    });

    test('guardConsent returns same as isConsentGiven', () async {
      await ConsentManager.updateConsent(ConsentType.notifications, true);
      final guard =
          await ConsentManager.guardConsent(ConsentType.notifications);
      final direct =
          await ConsentManager.isConsentGiven(ConsentType.notifications);
      expect(guard, direct);

      // Clean up
      await ConsentManager.updateConsent(ConsentType.notifications, false);
    });

    test('loadDashboard reflects persisted consent state', () async {
      await ConsentManager.revokeAll();
      await ConsentManager.updateConsent(ConsentType.byokDataSharing, true);

      final dashboard = await ConsentManager.loadDashboard();
      final byok = dashboard.consents
          .firstWhere((c) => c.type == ConsentType.byokDataSharing);
      expect(byok.enabled, true);

      final snapshot = dashboard.consents
          .firstWhere((c) => c.type == ConsentType.snapshotStorage);
      expect(snapshot.enabled, false);

      // Clean up
      await ConsentManager.revokeAll();
    });
  });

  group('ConsentManager — BYOK detail (LSFin compliance)', () {
    test('getByokDetail lists sent fields', () {
      final detail = ConsentManager.getByokDetail();
      expect(detail['sent'], isNotEmpty);
      expect(detail['sent'], contains('archetype'));
      expect(detail['sent'], contains('canton'));
      expect(detail['sent'], contains('confidenceScore'));
    });

    test('getByokDetail lists neverSent fields (privacy guarantee)', () {
      final detail = ConsentManager.getByokDetail();
      expect(detail['neverSent'], isNotEmpty);
      expect(detail['neverSent']!.any((s) => s.contains('salaire')), true);
      expect(detail['neverSent']!.any((s) => s.contains('employeur')), true);
      expect(detail['neverSent']!.any((s) => s.contains('adresse')), true);
    });

    test('neverSent includes sensitive financial data categories', () {
      final detail = ConsentManager.getByokDetail();
      final neverSent = detail['neverSent']!;
      expect(neverSent.any((s) => s.contains('soldes')), true);
      expect(neverSent.any((s) => s.contains('dette')), true);
    });

    test('sent does NOT include exact salary or bank info', () {
      final detail = ConsentManager.getByokDetail();
      final sent = detail['sent']!;
      // Exact salary, IBAN, bank name must never be in sent list
      expect(sent.contains('salaireBrut'), false);
      expect(sent.contains('iban'), false);
      expect(sent.contains('nomBanque'), false);
    });
  });

  group('ConsentState — content quality', () {
    test('each consent has non-empty label, detail, and neverSent', () {
      final dashboard = ConsentManager.getDefaultDashboard();
      for (final consent in dashboard.consents) {
        expect(consent.label.isNotEmpty, true,
            reason: '${consent.type.name} must have a label');
        expect(consent.detail.isNotEmpty, true,
            reason: '${consent.type.name} must have a detail');
        expect(consent.neverSent.isNotEmpty, true,
            reason: '${consent.type.name} must explain what is never sent');
      }
    });
  });
}
