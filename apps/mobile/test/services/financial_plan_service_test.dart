import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────────────────
//  FinancialPlanService tests
//  Covers D-04: SharedPreferences CRUD, max-3 eviction, corruption resilience
// ────────────────────────────────────────────────────────────────────────

FinancialPlan _makePlan(String id, {DateTime? generatedAt}) {
  return FinancialPlan(
    id: id,
    goalDescription: 'Plan $id',
    goalCategory: 'goal_house',
    monthlyTarget: 1000.0,
    milestones: const [],
    projectedOutcome: 80000.0,
    targetDate: DateTime(2028, 6, 1),
    generatedAt: generatedAt ?? DateTime(2026, 1, 1),
    profileHashAtGeneration: 'hash_$id',
    coachNarrative: 'Narrative.',
    confidenceLevel: 70.0,
    sources: const ['LPP art. 14'],
    disclaimer: 'Outil éducatif.',
  );
}

void main() {
  group('FinancialPlanService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Test 1: save() then loadAll() returns the saved plan', () async {
      final plan = _makePlan('plan-001');

      await FinancialPlanService.save(plan);
      final plans = await FinancialPlanService.loadAll();

      expect(plans.length, equals(1));
      expect(plans.first.id, equals('plan-001'));
    });

    test('Test 2: save() with same id overwrites (upsert), not duplicates', () async {
      final plan1 = _makePlan('plan-001');
      final plan2 = _makePlan('plan-001'); // same id

      await FinancialPlanService.save(plan1);
      await FinancialPlanService.save(plan2);

      final plans = await FinancialPlanService.loadAll();
      expect(plans.length, equals(1)); // not duplicated
      expect(plans.first.id, equals('plan-001'));
    });

    test('Test 3: save() with 4th plan evicts the oldest (max 3)', () async {
      final oldest = _makePlan('plan-oldest', generatedAt: DateTime(2026, 1, 1));
      final p2 = _makePlan('plan-002', generatedAt: DateTime(2026, 2, 1));
      final p3 = _makePlan('plan-003', generatedAt: DateTime(2026, 3, 1));
      final newest = _makePlan('plan-newest', generatedAt: DateTime(2026, 4, 1));

      // Save oldest first (will be at tail after 3 saves)
      await FinancialPlanService.save(oldest);
      await FinancialPlanService.save(p2);
      await FinancialPlanService.save(p3);
      // 4th save triggers eviction of oldest
      await FinancialPlanService.save(newest);

      final plans = await FinancialPlanService.loadAll();
      expect(plans.length, equals(3));
      expect(plans.any((p) => p.id == 'plan-oldest'), isFalse);
      expect(plans.any((p) => p.id == 'plan-newest'), isTrue);
    });

    test('Test 4: loadAll() with corrupted SharedPreferences JSON returns empty list', () async {
      // Inject corrupted JSON directly
      SharedPreferences.setMockInitialValues({
        'financial_plan_v1': 'NOT VALID JSON {{{{',
      });

      expect(() async => FinancialPlanService.loadAll(), returnsNormally);
      final plans = await FinancialPlanService.loadAll();
      expect(plans, isEmpty);
    });

    test('Test 5: loadCurrent() returns the first (newest) plan', () async {
      final oldest = _makePlan('plan-oldest');
      final newest = _makePlan('plan-newest');

      await FinancialPlanService.save(oldest);
      await FinancialPlanService.save(newest);

      final current = await FinancialPlanService.loadCurrent();
      expect(current, isNotNull);
      expect(current!.id, equals('plan-newest'));
    });

    test('Test 6: delete() removes plan by id, loadAll() no longer contains it', () async {
      final p1 = _makePlan('plan-001');
      final p2 = _makePlan('plan-002');

      await FinancialPlanService.save(p1);
      await FinancialPlanService.save(p2);

      await FinancialPlanService.delete('plan-001');

      final plans = await FinancialPlanService.loadAll();
      expect(plans.any((p) => p.id == 'plan-001'), isFalse);
      expect(plans.any((p) => p.id == 'plan-002'), isTrue);
    });
  });
}
