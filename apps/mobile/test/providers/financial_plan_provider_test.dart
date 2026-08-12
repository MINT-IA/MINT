import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────────────────
//  FinancialPlanProvider tests
//  Covers D-05: reactivity, staleness detection, postFrameCallback safety
// ────────────────────────────────────────────────────────────────────────

FinancialPlan _makePlan({
  String id = 'plan-001',
  String profileHash = 'hash-abc',
}) {
  return FinancialPlan(
    id: id,
    goalDescription: 'Acheter un appartement',
    goalCategory: 'goal_house',
    monthlyTarget: 1200.0,
    milestones: const [],
    projectedOutcome: 85000.0,
    targetDate: DateTime(2028, 6, 1),
    generatedAt: DateTime(2026, 4, 1),
    profileHashAtGeneration: profileHash,
    coachNarrative: 'Voici ton plan.',
    confidenceLevel: 78.0,
    sources: const ['LPP art. 14'],
    disclaimer: 'Outil éducatif.',
  );
}

CoachProfile _makeProfile({
  double salary = 10000.0,
  String canton = 'VS',
  String? housingStatus,
}) {
  return CoachProfile(
    birthYear: 1977,
    canton: canton,
    salaireBrutMensuel: salary,
    housingStatus: housingStatus,
    goalA: GoalA(
      type: GoalAType.achatImmo,
      targetDate: DateTime(2028, 6, 1),
      label: 'Achat',
    ),
  );
}

void main() {
  group('FinancialPlanProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Test 7: hasPlan is false initially', () {
      final provider = FinancialPlanProvider();
      expect(provider.hasPlan, isFalse);
      expect(provider.currentPlan, isNull);
    });

    test('Test 8: After loadFromPersistence(), hasPlan is true and currentPlan is populated', () async {
      final plan = _makePlan();
      await FinancialPlanService.save(plan);

      final provider = FinancialPlanProvider();
      await provider.loadFromPersistence();

      expect(provider.hasPlan, isTrue);
      expect(provider.currentPlan, isNotNull);
      expect(provider.currentPlan!.id, equals('plan-001'));
    });

    test('Test 9: When profile hash changes, isPlanStale becomes true', () {
      final plan = _makePlan(profileHash: 'hash-original');
      final provider = FinancialPlanProvider();
      // Set the plan directly without persistence
      provider.setPlanDirect(plan);

      expect(provider.isPlanStale, isFalse);

      // Simulate a profile with a different hash
      final differentProfile = _makeProfile(salary: 99999.0); // different salary → different hash
      provider.checkStalenessForTest(differentProfile);

      expect(provider.isPlanStale, isTrue);
    });

    test('Test 10: When profile hash is unchanged, isPlanStale remains false', () {
      final profile = _makeProfile(salary: 10000.0, canton: 'VS');
      final hash = computeProfileHash(profile);
      final plan = _makePlan(profileHash: hash);

      final provider = FinancialPlanProvider();
      provider.setPlanDirect(plan);

      provider.checkStalenessForTest(profile);

      expect(provider.isPlanStale, isFalse);
    });

    test('Test 11: clearPlan() sets hasPlan to false', () async {
      final plan = _makePlan();
      await FinancialPlanService.save(plan);

      final provider = FinancialPlanProvider();
      await provider.loadFromPersistence();

      expect(provider.hasPlan, isTrue);

      provider.clearPlan();

      expect(provider.hasPlan, isFalse);
      expect(provider.currentPlan, isNull);
    });

    test('a housing status correction marks the current plan stale', () {
      final tenant = _makeProfile(housingStatus: 'tenant');
      final plan = _makePlan(profileHash: computeProfileHash(tenant));
      final provider = FinancialPlanProvider()..setPlanDirect(plan);

      expect(provider.isPlanStale, isFalse);

      provider.checkStalenessForTest(
        _makeProfile(housingStatus: 'owner_occupier'),
      );

      expect(provider.isPlanStale, isTrue);
    });

    test(
      'Test 12: attachProfileProvider is idempotent — repeat calls do '
      'not stack listeners',
      () {
        // Walker 2026-05-08 / Aujourdhui-wire fix: the ProxyProvider
        // `update` callback fires on every CoachProfile rebuild. Without
        // an idempotency guard inside attachProfileProvider, the listener
        // would stack and CoachProfileProvider.notifyListeners() would
        // trigger N independent _checkStaleness runs per change, scaling
        // to N² over a session.
        //
        // We bypass the heavy CoachProfileProvider (it pulls
        // ReportPersistenceService → flutter_secure_storage which needs
        // platform binding) and verify the guard with a CoachProfile-
        // shaped stub that only counts addListener calls.
        final provider = FinancialPlanProvider();
        final stub = _ListenerCountingProfileStub();

        // Attach 5 times — without the guard, 5 listeners stack.
        for (var i = 0; i < 5; i++) {
          provider.attachProfileProvider(stub);
        }

        expect(
          stub.addListenerCallCount,
          equals(1),
          reason: 'attachProfileProvider should add exactly 1 listener '
              'across N calls — guard is the contract',
        );
      },
    );
  });
}

/// Test stub that mimics [CoachProfileProvider.addListener] just enough
/// to count attach calls. Bypasses the real provider (which pulls
/// flutter_secure_storage and needs platform binding).
class _ListenerCountingProfileStub extends CoachProfileProvider {
  int addListenerCallCount = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCallCount++;
    // Don't actually wire — we only care about the call count.
  }
}
