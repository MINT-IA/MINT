import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/subscription_service.dart';

/// Unit tests for SubscriptionService (Sprint C9 — Paywall + Subscription).
///
/// Tests cover:
///   - Initial state
///   - Feature access control per tier
///   - Upgrade flow
///   - Trial lifecycle (start, duration, expiry)
///   - Restore purchases
///   - Mock helpers for testing
///   - Edge cases (double trial, expired subscription)
void main() {
  setUp(() {
    // Reset to a known state before each test
    SubscriptionService.setMockTier(SubscriptionTier.free);
  });

  tearDown(() {
    // Reset to dev default after each test
    SubscriptionService.resetToDefault();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. INITIAL STATE
  // ═══════════════════════════════════════════════════════════════════════

  group('Initial state', () {
    test('setMockTier(free) sets tier to free', () {
      SubscriptionService.setMockTier(SubscriptionTier.free);
      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.free);
    });

    test('default dev state is coach', () {
      SubscriptionService.resetToDefault();
      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.coach);
    });

    test('free state has source mock', () {
      final state = SubscriptionService.currentState();
      expect(state.source, SubscriptionSource.mock);
    });

    test('free state has no trial active', () {
      final state = SubscriptionService.currentState();
      expect(state.isTrialActive, isFalse);
      expect(state.trialDaysRemaining, 0);
    });

    test('free state has no expiry', () {
      final state = SubscriptionService.currentState();
      expect(state.expiresAt, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. FEATURE ACCESS
  // ═══════════════════════════════════════════════════════════════════════

  group('Feature access', () {
    test('free tier cannot access any coach feature', () {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      for (final feature in CoachFeature.values) {
        expect(
          SubscriptionService.hasAccess(feature),
          isFalse,
          reason: 'Free tier should not have access to $feature',
        );
      }
    });

    test('coach tier can access all coach features', () {
      SubscriptionService.setMockTier(SubscriptionTier.coach);

      for (final feature in CoachFeature.values) {
        expect(
          SubscriptionService.hasAccess(feature),
          isTrue,
          reason: 'Coach tier should have access to $feature',
        );
      }
    });

    test('expired coach subscription denies access', () {
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.coach,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: SubscriptionSource.mock,
      ));

      expect(
        SubscriptionService.hasAccess(CoachFeature.dashboard),
        isFalse,
      );
    });

    test('active coach subscription with future expiry allows access', () {
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.coach,
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        source: SubscriptionSource.mock,
      ));

      expect(
        SubscriptionService.hasAccess(CoachFeature.dashboard),
        isTrue,
      );
    });

    test('all 10 CoachFeature values exist', () {
      expect(CoachFeature.values.length, 10);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. UPGRADE
  // ═══════════════════════════════════════════════════════════════════════

  group('Upgrade', () {
    test('upgradeTo coach changes tier to coach', () async {
      final success = await SubscriptionService.upgradeTo(
        SubscriptionTier.coach,
      );

      expect(success, isTrue);

      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.coach);
    });

    test('upgrade sets 30-day expiry', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.coach);

      final state = SubscriptionService.currentState();
      expect(state.expiresAt, isNotNull);
      // Expiry should be approximately 30 days from now
      final diff = state.expiresAt!.difference(DateTime.now()).inDays;
      expect(diff, inInclusiveRange(29, 30));
    });

    test('upgrade does not set trial active', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.coach);

      final state = SubscriptionService.currentState();
      expect(state.isTrialActive, isFalse);
    });

    test('upgradeTo free resets to free tier', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.coach);
      await SubscriptionService.upgradeTo(SubscriptionTier.free);

      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.free);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. TRIAL
  // ═══════════════════════════════════════════════════════════════════════

  group('Trial', () {
    test('startTrial sets coach tier with trial active', () async {
      final success = await SubscriptionService.startTrial();

      expect(success, isTrue);

      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.coach);
      expect(state.isTrialActive, isTrue);
    });

    test('trial sets 14-day duration', () async {
      await SubscriptionService.startTrial();

      final state = SubscriptionService.currentState();
      expect(state.trialDaysRemaining, 14);

      final diff = state.expiresAt!.difference(DateTime.now()).inDays;
      expect(diff, inInclusiveRange(13, 14));
    });

    test('cannot start trial if already on trial', () async {
      await SubscriptionService.startTrial();
      final secondAttempt = await SubscriptionService.startTrial();

      expect(secondAttempt, isFalse);
    });

    test('trial grants access to all coach features', () async {
      await SubscriptionService.startTrial();

      for (final feature in CoachFeature.values) {
        expect(
          SubscriptionService.hasAccess(feature),
          isTrue,
          reason: 'Trial should grant access to $feature',
        );
      }
    });

    test('expired trial denies access', () async {
      // Simulate expired trial
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.coach,
        isTrialActive: true,
        trialDaysRemaining: 0,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: SubscriptionSource.mock,
      ));

      expect(
        SubscriptionService.hasAccess(CoachFeature.forecast),
        isFalse,
      );
    });

    test('trialDurationDays constant is 14', () {
      expect(SubscriptionService.trialDurationDays, 14);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. RESTORE PURCHASES
  // ═══════════════════════════════════════════════════════════════════════

  group('Restore purchases', () {
    test('restore with no prior purchases returns free', () async {
      final state = await SubscriptionService.restorePurchases();

      expect(state.tier, SubscriptionTier.free);
    });

    test('restore resets state to free (mock)', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.coach);
      await SubscriptionService.restorePurchases();

      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.free);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. MOCK HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  group('Mock helpers', () {
    test('setMockTier sets tier directly', () {
      SubscriptionService.setMockTier(SubscriptionTier.coach);
      expect(SubscriptionService.currentState().tier, SubscriptionTier.coach);

      SubscriptionService.setMockTier(SubscriptionTier.free);
      expect(SubscriptionService.currentState().tier, SubscriptionTier.free);
    });

    test('setMockState sets full state', () {
      final customState = SubscriptionState(
        tier: SubscriptionTier.coach,
        isTrialActive: true,
        trialDaysRemaining: 7,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        source: SubscriptionSource.mock,
      );

      SubscriptionService.setMockState(customState);
      final state = SubscriptionService.currentState();

      expect(state.tier, SubscriptionTier.coach);
      expect(state.isTrialActive, isTrue);
      expect(state.trialDaysRemaining, 7);
    });

    test('resetToDefault sets coach tier (dev mode)', () {
      SubscriptionService.setMockTier(SubscriptionTier.free);
      SubscriptionService.resetToDefault();

      expect(SubscriptionService.currentState().tier, SubscriptionTier.coach);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. SUBSCRIPTION STATE
  // ═══════════════════════════════════════════════════════════════════════

  group('SubscriptionState', () {
    test('isActive is false for free tier', () {
      const state = SubscriptionState(tier: SubscriptionTier.free);
      expect(state.isActive, isFalse);
    });

    test('isActive is true for coach tier without expiry', () {
      const state = SubscriptionState(tier: SubscriptionTier.coach);
      expect(state.isActive, isTrue);
    });

    test('isActive is false for expired coach', () {
      final state = SubscriptionState(
        tier: SubscriptionTier.coach,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(state.isActive, isFalse);
    });

    test('copyWith preserves values when no changes specified', () {
      const original = SubscriptionState(
        tier: SubscriptionTier.coach,
        isTrialActive: true,
        trialDaysRemaining: 10,
      );
      final copy = original.copyWith();

      expect(copy.tier, original.tier);
      expect(copy.isTrialActive, original.isTrialActive);
      expect(copy.trialDaysRemaining, original.trialDaysRemaining);
    });

    test('copyWith changes specified values', () {
      const original = SubscriptionState(tier: SubscriptionTier.free);
      final copy = original.copyWith(tier: SubscriptionTier.coach);

      expect(copy.tier, SubscriptionTier.coach);
    });

    test('toString contains tier info', () {
      const state = SubscriptionState(tier: SubscriptionTier.free);
      expect(state.toString(), contains('free'));
    });

    test('equality works correctly', () {
      const a = SubscriptionState(tier: SubscriptionTier.free);
      const b = SubscriptionState(tier: SubscriptionTier.free);
      const c = SubscriptionState(tier: SubscriptionTier.coach);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('monthlyPriceCHF is 4.90', () {
      expect(SubscriptionService.monthlyPriceCHF, 4.90);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. ENUMS
  // ═══════════════════════════════════════════════════════════════════════

  group('Enums', () {
    test('SubscriptionTier has 2 values', () {
      expect(SubscriptionTier.values.length, 2);
      expect(SubscriptionTier.values, contains(SubscriptionTier.free));
      expect(SubscriptionTier.values, contains(SubscriptionTier.coach));
    });

    test('SubscriptionSource has 2 values', () {
      expect(SubscriptionSource.values.length, 2);
      expect(SubscriptionSource.values, contains(SubscriptionSource.mock));
      expect(
          SubscriptionSource.values, contains(SubscriptionSource.revenueCat));
    });

    test('CoachFeature enum contains all expected features', () {
      final features = CoachFeature.values.map((f) => f.name).toSet();
      expect(features, containsAll([
        'dashboard',
        'forecast',
        'checkin',
        'scoreEvolution',
        'alertesProactives',
        'historique',
        'profilCouple',
        'coachLlm',
        'scenariosEtSi',
        'exportPdf',
      ]));
    });
  });
}
