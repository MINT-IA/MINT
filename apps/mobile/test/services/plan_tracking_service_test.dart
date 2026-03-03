import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';

// ────────────────────────────────────────────────────────────
//  PLAN TRACKING SERVICE — Tests (Phase 5 fix)
// ────────────────────────────────────────────────────────────

MonthlyCheckIn _checkIn(Map<String, double> versements) => MonthlyCheckIn(
      month: DateTime(2026, 1),
      versements: versements,
      completedAt: DateTime(2026, 1, 15),
    );

PlannedMonthlyContribution _contrib(String id, double amount, String cat) =>
    PlannedMonthlyContribution(
      id: id,
      label: '$cat ($id)',
      amount: amount,
      category: cat,
    );

void main() {
  group('PlanTrackingService.evaluate', () {
    test('empty contributions returns zero score', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [],
        contributions: [],
      );
      expect(status.score, 0);
      expect(status.completedActions, 0);
      expect(status.totalActions, 0);
      expect(status.adherenceRate, 0);
      expect(status.monthlyGapChf, 0);
    });

    test('no check-ins with planned contributions returns 0% adherence', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [],
        contributions: [
          _contrib('3a_julien', 604.83, '3a'),
          _contrib('lpp_buyback', 500, 'lpp_buyback'),
        ],
      );
      expect(status.score, 0);
      expect(status.completedActions, 0);
      expect(status.totalActions, 2);
      expect(status.adherenceRate, 0);
      expect(status.totalMonthlyPlanned, closeTo(1104.83, 0.01));
      expect(status.averageMonthlyActual, 0);
      expect(status.monthlyGapChf, closeTo(1104.83, 0.01));
      expect(status.nextActions.length, 2);
    });

    test('partial completion: one contribution met, one not', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          _checkIn({'3a_julien': 604.83}), // meets 3a plan
        ],
        contributions: [
          _contrib('3a_julien', 604.83, '3a'),
          _contrib('lpp_buyback', 500, 'lpp_buyback'),
        ],
      );
      expect(status.completedActions, 1);
      expect(status.totalActions, 2);
      expect(status.adherenceRate, 0.5);
      expect(status.score, 50);
      expect(status.averageMonthlyActual, closeTo(604.83, 0.01));
      expect(status.monthlyGapChf, closeTo(500, 0.01)); // lpp gap
    });

    test('full completion: all contributions >= 80%', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          _checkIn({'3a_julien': 604.83, 'lpp_buyback': 450}),
        ],
        contributions: [
          _contrib('3a_julien', 604.83, '3a'),
          _contrib('lpp_buyback', 500, 'lpp_buyback'), // 450/500 = 90% >= 80%
        ],
      );
      expect(status.completedActions, 2);
      expect(status.adherenceRate, 1.0);
      expect(status.score, 100);
      expect(status.nextActions, isEmpty);
    });

    test('80% threshold: contribution at exactly 80% counts as completed', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          _checkIn({'3a_julien': 483.86}), // 80% of 604.83
        ],
        contributions: [
          _contrib('3a_julien', 604.83, '3a'),
        ],
      );
      expect(status.completedActions, 1);
      expect(status.score, 100);
    });

    test('79% of target does NOT count as completed', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          _checkIn({'3a_julien': 477.81}), // ~79% of 604.83
        ],
        contributions: [
          _contrib('3a_julien', 604.83, '3a'),
        ],
      );
      expect(status.completedActions, 0);
      expect(status.score, 0);
    });

    test('multi-month average: 2 check-ins averaged', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [
          _checkIn({'3a_julien': 300}),
          _checkIn({'3a_julien': 900}),
        ],
        contributions: [
          _contrib('3a_julien', 604.83, '3a'), // avg = 600 ≈ 99% → completed
        ],
      );
      expect(status.completedActions, 1);
      expect(status.averageMonthlyActual, closeTo(600, 0.01));
    });

    test('nextActions capped at 3', () {
      final status = PlanTrackingService.evaluate(
        checkIns: [],
        contributions: [
          _contrib('a', 100, '3a'),
          _contrib('b', 200, '3a'),
          _contrib('c', 300, 'lpp_buyback'),
          _contrib('d', 400, 'epargne'),
          _contrib('e', 500, 'investissement'),
        ],
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
        totalMonthlyPlanned: 1000,
        averageMonthlyActual: 500,
      );
      expect(
        PlanTrackingService.compoundProjectedImpact(
          status: status,
          monthsToRetirement: 0,
        ),
        0,
      );
    });

    test('returns 0 when gap is zero (all planned = all actual)', () {
      final status = PlanStatus(
        score: 100,
        completedActions: 2,
        totalActions: 2,
        nextActions: [],
        totalMonthlyPlanned: 1000,
        averageMonthlyActual: 1000,
      );
      expect(
        PlanTrackingService.compoundProjectedImpact(
          status: status,
          monthsToRetirement: 180,
        ),
        0,
      );
    });

    test('positive impact with real CHF gap', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 1,
        totalActions: 2,
        nextActions: ['Action'],
        totalMonthlyPlanned: 1104.83,
        averageMonthlyActual: 604.83,
      );
      // Gap = 500 CHF/month, 15 years, 2% real
      final impact = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 180,
        annualReturn: 0.02,
      );
      expect(impact, greaterThan(0));
      // 500 × 180 = 90k linear, compound adds ~5-10%
      expect(impact, greaterThan(90000));
      expect(impact, lessThan(120000));
    });

    test('zero return produces linear accumulation', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 1,
        totalActions: 2,
        nextActions: ['Action'],
        totalMonthlyPlanned: 1000,
        averageMonthlyActual: 800,
      );
      // Gap = 200 CHF/month, 120 months, 0% return
      final impact = PlanTrackingService.compoundProjectedImpact(
        status: status,
        monthsToRetirement: 120,
        annualReturn: 0,
      );
      expect(impact, closeTo(24000, 0.01)); // 200 × 120
    });

    test('compound exceeds linear with positive return', () {
      final status = PlanStatus(
        score: 50,
        completedActions: 1,
        totalActions: 2,
        nextActions: ['Action'],
        totalMonthlyPlanned: 1000,
        averageMonthlyActual: 800,
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

    test('monthlyGapChf never negative', () {
      const status = PlanStatus(
        score: 100,
        completedActions: 1,
        totalActions: 1,
        nextActions: [],
        totalMonthlyPlanned: 500,
        averageMonthlyActual: 600, // over-contributed
      );
      expect(status.monthlyGapChf, 0);
    });
  });
}
