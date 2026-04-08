import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/subscription_service.dart';

/// Unit tests for SubscriptionService (Sprint C9 — Paywall + Subscription).
///
/// Tests cover:
///   - Initial state
///   - Feature access control per tier
///   - Upgrade flow (multi-tier)
///   - Trial lifecycle (start, duration, expiry)
///   - Restore purchases
///   - Mock helpers for testing
///   - Edge cases (double trial, expired subscription)
///   - TierFeatureMatrix
///   - IapProducts
///   - SubscriptionTier.fromString backward compat
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

    test('default state is free', () {
      SubscriptionService.resetToDefault();
      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.free);
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

    test('premium tier can access all coach features', () {
      SubscriptionService.setMockTier(SubscriptionTier.premium);

      for (final feature in CoachFeature.values) {
        expect(
          SubscriptionService.hasAccess(feature),
          isTrue,
          reason: 'Premium tier should have access to $feature',
        );
      }
    });

    test('starter tier has access to dashboard, forecast, checkin, alertes, profilCouple', () {
      SubscriptionService.setMockTier(SubscriptionTier.starter);

      expect(SubscriptionService.hasAccess(CoachFeature.dashboard), isTrue);
      expect(SubscriptionService.hasAccess(CoachFeature.forecast), isTrue);
      expect(SubscriptionService.hasAccess(CoachFeature.checkin), isTrue);
      expect(SubscriptionService.hasAccess(CoachFeature.alertesProactives), isTrue);
      expect(SubscriptionService.hasAccess(CoachFeature.profilCouple), isTrue);
    });

    test('starter tier does NOT have access to premium-only features', () {
      SubscriptionService.setMockTier(SubscriptionTier.starter);

      expect(SubscriptionService.hasAccess(CoachFeature.scoreEvolution), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.historique), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.coachLlm), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.scenariosEtSi), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.exportPdf), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.vault), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.monteCarlo), isFalse);
      expect(SubscriptionService.hasAccess(CoachFeature.arbitrageModules), isFalse);
    });

    test('expired premium subscription denies access', () {
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.premium,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: SubscriptionSource.mock,
      ));

      expect(
        SubscriptionService.hasAccess(CoachFeature.dashboard),
        isFalse,
      );
    });

    test('active premium subscription with future expiry allows access', () {
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.premium,
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        source: SubscriptionSource.mock,
      ));

      expect(
        SubscriptionService.hasAccess(CoachFeature.dashboard),
        isTrue,
      );
    });

    test('all 13 CoachFeature values exist', () {
      expect(CoachFeature.values.length, 13);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. UPGRADE
  // ═══════════════════════════════════════════════════════════════════════

  group('Upgrade', () {
    test('upgradeTo premium requires backend (returns false without API)', () async {
      // SECURITY: paid upgrades always require backend verification.
      // Without a backend, upgradeTo returns false.
      final success = await SubscriptionService.upgradeTo(
        SubscriptionTier.premium,
      );

      expect(success, isFalse);
    });

    test('upgradeTo starter requires backend (returns false without API)', () async {
      final success = await SubscriptionService.upgradeTo(
        SubscriptionTier.starter,
      );

      expect(success, isFalse);
    });

    test('upgrade without backend does not change state', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.premium);

      final state = SubscriptionService.currentState();
      // State unchanged — still free tier
      expect(state.tier, SubscriptionTier.free);
    });

    test('upgrade does not set trial active', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.premium);

      final state = SubscriptionService.currentState();
      expect(state.isTrialActive, isFalse);
    });

    test('upgradeTo free resets to free tier', () async {
      await SubscriptionService.upgradeTo(SubscriptionTier.premium);
      await SubscriptionService.upgradeTo(SubscriptionTier.free);

      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.free);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. TRIAL
  // ═══════════════════════════════════════════════════════════════════════

  group('Trial', () {
    test('startTrial sets premium tier with trial active', () async {
      final success = await SubscriptionService.startTrial();

      expect(success, isTrue);

      final state = SubscriptionService.currentState();
      expect(state.tier, SubscriptionTier.premium);
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

    test('trial grants access to all premium features', () async {
      await SubscriptionService.startTrial();

      for (final feature in CoachFeature.values) {
        if (TierFeatureMatrix.hasAccess(SubscriptionTier.premium, feature.name)) {
          expect(
            SubscriptionService.hasAccess(feature),
            isTrue,
            reason: 'Trial should grant access to $feature',
          );
        }
      }
    });

    test('expired trial denies access', () async {
      // Simulate expired trial
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.premium,
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
      await SubscriptionService.upgradeTo(SubscriptionTier.premium);
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
      SubscriptionService.setMockTier(SubscriptionTier.premium);
      expect(SubscriptionService.currentState().tier, SubscriptionTier.premium);

      SubscriptionService.setMockTier(SubscriptionTier.free);
      expect(SubscriptionService.currentState().tier, SubscriptionTier.free);
    });

    test('setMockState sets full state', () {
      final customState = SubscriptionState(
        tier: SubscriptionTier.premium,
        isTrialActive: true,
        trialDaysRemaining: 7,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        source: SubscriptionSource.mock,
      );

      SubscriptionService.setMockState(customState);
      final state = SubscriptionService.currentState();

      expect(state.tier, SubscriptionTier.premium);
      expect(state.isTrialActive, isTrue);
      expect(state.trialDaysRemaining, 7);
    });

    test('resetToDefault sets free tier', () {
      SubscriptionService.setMockTier(SubscriptionTier.premium);
      SubscriptionService.resetToDefault();

      expect(SubscriptionService.currentState().tier, SubscriptionTier.free);
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

    test('isActive is true for premium tier without expiry', () {
      const state = SubscriptionState(tier: SubscriptionTier.premium);
      expect(state.isActive, isTrue);
    });

    test('isActive is false for expired premium', () {
      final state = SubscriptionState(
        tier: SubscriptionTier.premium,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(state.isActive, isFalse);
    });

    test('copyWith preserves values when no changes specified', () {
      const original = SubscriptionState(
        tier: SubscriptionTier.premium,
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
      final copy = original.copyWith(tier: SubscriptionTier.premium);

      expect(copy.tier, SubscriptionTier.premium);
    });

    test('toString contains tier info', () {
      const state = SubscriptionState(tier: SubscriptionTier.free);
      expect(state.toString(), contains('free'));
    });

    test('equality works correctly', () {
      const a = SubscriptionState(tier: SubscriptionTier.free);
      const b = SubscriptionState(tier: SubscriptionTier.free);
      const c = SubscriptionState(tier: SubscriptionTier.premium);

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
    test('SubscriptionTier has 4 values', () {
      expect(SubscriptionTier.values.length, 4);
      expect(SubscriptionTier.values, contains(SubscriptionTier.free));
      expect(SubscriptionTier.values, contains(SubscriptionTier.starter));
      expect(SubscriptionTier.values, contains(SubscriptionTier.premium));
      expect(SubscriptionTier.values, contains(SubscriptionTier.couplePlus));
    });

    test('SubscriptionSource has 3 values', () {
      expect(SubscriptionSource.values.length, 3);
      expect(SubscriptionSource.values, contains(SubscriptionSource.mock));
      expect(SubscriptionSource.values, contains(SubscriptionSource.backend));
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
        'vault',
        'monteCarlo',
        'arbitrageModules',
      ]));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. TIER FEATURE MATRIX
  // ═══════════════════════════════════════════════════════════════════════

  group('TierFeatureMatrix', () {
    test('free tier has no access to any feature', () {
      for (final feature in CoachFeature.values) {
        expect(
          TierFeatureMatrix.hasAccess(SubscriptionTier.free, feature.name),
          isFalse,
          reason: 'Free tier should not access $feature',
        );
      }
    });

    test('starter tier has access to dashboard', () {
      expect(
        TierFeatureMatrix.hasAccess(SubscriptionTier.starter, 'dashboard'),
        isTrue,
      );
    });

    test('starter tier does not have access to coachLlm', () {
      expect(
        TierFeatureMatrix.hasAccess(SubscriptionTier.starter, 'coachLlm'),
        isFalse,
      );
    });

    test('premium tier has access to all features', () {
      for (final feature in CoachFeature.values) {
        expect(
          TierFeatureMatrix.hasAccess(SubscriptionTier.premium, feature.name),
          isTrue,
          reason: 'Premium tier should access $feature',
        );
      }
    });

    test('couplePlus tier has access to all features', () {
      for (final feature in CoachFeature.values) {
        expect(
          TierFeatureMatrix.hasAccess(SubscriptionTier.couplePlus, feature.name),
          isTrue,
          reason: 'CouplePlus tier should access $feature',
        );
      }
    });

    test('accessLevel returns correct level for profilCouple', () {
      expect(
        TierFeatureMatrix.accessLevel(SubscriptionTier.starter, 'profilCouple'),
        AccessLevel.basic,
      );
      expect(
        TierFeatureMatrix.accessLevel(SubscriptionTier.premium, 'profilCouple'),
        AccessLevel.full,
      );
    });

    test('featuresForTier returns correct count', () {
      final starterFeatures = TierFeatureMatrix.featuresForTier(SubscriptionTier.starter);
      final premiumFeatures = TierFeatureMatrix.featuresForTier(SubscriptionTier.premium);

      expect(starterFeatures.length, lessThan(premiumFeatures.length));
      expect(premiumFeatures.length, 13);
    });

    test('minimumTier returns correct tier', () {
      expect(TierFeatureMatrix.minimumTier('dashboard'), SubscriptionTier.starter);
      expect(TierFeatureMatrix.minimumTier('coachLlm'), SubscriptionTier.premium);
    });

    test('unknown feature returns none', () {
      expect(
        TierFeatureMatrix.hasAccess(SubscriptionTier.premium, 'nonexistent'),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. SUBSCRIPTION TIER
  // ═══════════════════════════════════════════════════════════════════════

  group('SubscriptionTier', () {
    test('fromString parses all valid values', () {
      expect(SubscriptionTier.fromString('free'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString('starter'), SubscriptionTier.starter);
      expect(SubscriptionTier.fromString('premium'), SubscriptionTier.premium);
      expect(SubscriptionTier.fromString('couple_plus'), SubscriptionTier.couplePlus);
      expect(SubscriptionTier.fromString('couplePlus'), SubscriptionTier.couplePlus);
    });

    test('fromString maps legacy coach to premium', () {
      expect(SubscriptionTier.fromString('coach'), SubscriptionTier.premium);
    });

    test('fromString returns free for unknown values', () {
      expect(SubscriptionTier.fromString('unknown'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString(''), SubscriptionTier.free);
    });

    test('apiValue returns correct strings', () {
      expect(SubscriptionTier.free.apiValue, 'free');
      expect(SubscriptionTier.starter.apiValue, 'starter');
      expect(SubscriptionTier.premium.apiValue, 'premium');
      expect(SubscriptionTier.couplePlus.apiValue, 'couple_plus');
    });

    test('rank ordering is correct', () {
      expect(SubscriptionTier.free.rank, 0);
      expect(SubscriptionTier.starter.rank, 1);
      expect(SubscriptionTier.premium.rank, 2);
      expect(SubscriptionTier.couplePlus.rank, 3);
    });

    test('isPaid is false for free, true for others', () {
      expect(SubscriptionTier.free.isPaid, isFalse);
      expect(SubscriptionTier.starter.isPaid, isTrue);
      expect(SubscriptionTier.premium.isPaid, isTrue);
      expect(SubscriptionTier.couplePlus.isPaid, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 11. IAP PRODUCTS
  // ═══════════════════════════════════════════════════════════════════════

  group('IapProducts', () {
    test('all contains 6 product IDs', () {
      expect(IapProducts.all.length, 6);
    });

    test('tierFromProductId maps correctly', () {
      expect(IapProducts.tierFromProductId('ch.mint.starter.monthly'), SubscriptionTier.starter);
      expect(IapProducts.tierFromProductId('ch.mint.premium.monthly'), SubscriptionTier.premium);
      expect(IapProducts.tierFromProductId('ch.mint.couple_plus.monthly'), SubscriptionTier.couplePlus);
      expect(IapProducts.tierFromProductId('ch.mint.starter.annual'), SubscriptionTier.starter);
      expect(IapProducts.tierFromProductId('ch.mint.premium.annual'), SubscriptionTier.premium);
      expect(IapProducts.tierFromProductId('ch.mint.couple_plus.annual'), SubscriptionTier.couplePlus);
    });

    test('tierFromProductId maps legacy coach to premium', () {
      expect(IapProducts.tierFromProductId('ch.mint.coach.monthly'), SubscriptionTier.premium);
    });

    test('tierFromProductId returns free for unknown', () {
      expect(IapProducts.tierFromProductId('unknown'), SubscriptionTier.free);
    });

    test('isAnnual detects annual products', () {
      expect(IapProducts.isAnnual('ch.mint.starter.annual'), isTrue);
      expect(IapProducts.isAnnual('ch.mint.starter.monthly'), isFalse);
    });
  });
}
