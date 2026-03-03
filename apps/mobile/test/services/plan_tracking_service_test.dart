import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';

// ────────────────────────────────────────────────────────────
//  PLAN TRACKING SERVICE — Tests (Phase 5)
// ────────────────────────────────────────────────────────────

void main() {
  group('PlanTrackingService.evaluate', () {
    test('empty planned actions returns zero score', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [],
        plannedActions: [],
      );
      expect(status.score, 0);
      expect(status.completedActions, 0);
      expect(status.totalActions, 0);
      expect(status.adherenceRate, 0);
    });

    test('no check-ins with planned actions returns 0% adherence', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [],
        plannedActions: ['Versement 3a', 'Rachat LPP'],
      );
      expect(status.score, 0);
      expect(status.completedActions, 0);
      expect(status.totalActions, 2);
      expect(status.adherenceRate, 0);
      expect(status.nextActions.length, 2);
    });

    test('partial completion returns correct adherence', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          {
            'completed': true,
            'actions': ['Versement 3a'],
          }
        ],
        plannedActions: ['Versement 3a', 'Rachat LPP'],
      );
      expect(status.completedActions, 1);
      expect(status.totalActions, 2);
      expect(status.adherenceRate, 0.5);
      expect(status.score, 50);
      expect(status.nextActions, contains('Rachat LPP'));
    });

    test('full completion returns 100% adherence', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          {
            'completed': true,
            'actions': ['Versement 3a', 'Rachat LPP'],
          }
        ],
        plannedActions: ['Versement 3a', 'Rachat LPP'],
      );
      expect(status.completedActions, 2);
      expect(status.adherenceRate, 1.0);
      expect(status.score, 100);
      expect(status.nextActions, isEmpty);
    });

    test('nextActions capped at 3', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [],
        plannedActions: ['A', 'B', 'C', 'D', 'E'],
      );
      expect(status.nextActions.length, 3);
    });
  });

  group('PlanTrackingService.compoundProjectedImpact', () {
    test('returns 0 when monthsToRetirement <= 0', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 1,
        totalActions: 2,
        nextActions: ['Do something'],
      );
      final impact = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 0,
      );
      expect(impact, 0);
    });

    test('returns 0 when no next actions', () {
      final status = PlanStatus(
        score: 100,
        completedActions: 2,
        totalActions: 2,
        nextActions: [],
      );
      final impact = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 180,
      );
      expect(impact, 0);
    });

    test('positive impact with valid inputs', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 1,
        totalActions: 2,
        nextActions: ['Versement 3a'],
      );
      final impact = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 180, // 15 years
        annualReturn: 0.02,
      );
      expect(impact, greaterThan(0));
      // With 100 CHF/month, 2% annual, 15 years: ~20'897 CHF
      expect(impact, greaterThan(18000));
    });

    test('zero return produces linear accumulation', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 2,
        totalActions: 4,
        nextActions: ['Action'],
      );
      final impact = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 120,
        annualReturn: 0,
      );
      // PMT = completedActions * 100 = 200
      // Linear: 200 * 120 = 24000
      expect(impact, 24000);
    });

    test('compound exceeds linear with positive return', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 2,
        totalActions: 4,
        nextActions: ['Action'],
      );
      final linear = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 120,
        annualReturn: 0,
      );
      final compound = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 120,
        annualReturn: 0.04,
      );
      expect(compound, greaterThan(linear));
    });
  });

  group('PlanStatus', () {
    test('adherenceRate handles division by zero', () {
      const status = PlanStatus(
        score: 0,
        completedActions: 0,
        totalActions: 0,
        nextActions: [],
      );
      expect(status.adherenceRate, 0);
    });
  });
}
