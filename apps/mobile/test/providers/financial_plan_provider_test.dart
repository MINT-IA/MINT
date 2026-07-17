import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/models/financial_plan.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FinancialPlanProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('Test 7: hasPlan is false initially', () {
      final provider = FinancialPlanProvider();
      addTearDown(provider.dispose);
      expect(provider.hasPlan, isFalse);
      expect(provider.currentPlan, isNull);
    });

    test(
        'Test 8: After loadFromPersistence(), hasPlan is true and currentPlan is populated',
        () async {
      final plan = _makePlan();
      await FinancialPlanService.save(plan);

      final provider = FinancialPlanProvider();
      addTearDown(provider.dispose);
      await provider.loadFromPersistence();

      expect(provider.hasPlan, isTrue);
      expect(provider.currentPlan, isNotNull);
      expect(provider.currentPlan!.id, equals('plan-001'));
    });

    test('Test 11: clearPlan() sets hasPlan to false', () async {
      final plan = _makePlan();
      await FinancialPlanService.save(plan);

      final provider = FinancialPlanProvider();
      addTearDown(provider.dispose);
      await provider.loadFromPersistence();

      expect(provider.hasPlan, isTrue);

      provider.clearPlan();

      expect(provider.hasPlan, isFalse);
      expect(provider.currentPlan, isNull);
    });
  });
}
