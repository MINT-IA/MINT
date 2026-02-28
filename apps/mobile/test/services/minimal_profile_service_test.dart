import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';

/// Tests for MinimalProfileService (Sprint S31 — Onboarding Redesign).
///
/// Validates parity with backend compute_minimal_profile():
/// - Clamp: totalMonthlyRetirement >= 0 when debt > AVS+LPP
/// - Replacement ratio: retirement / grossMonthlySalary (not expenses)
/// - Retirement gap: grossMonthlySalary - retirement (not expenses)
/// - Debt priority: monthlyDebtService wins over totalDebts
void main() {
  group('MinimalProfileService', () {
    test('clamp: totalMonthlyRetirement >= 0 when debt exceeds AVS+LPP', () {
      // Debt of 5000/month far exceeds projected AVS+LPP for a 30yo at 50k
      final result = MinimalProfileService.compute(
        age: 30,
        grossSalary: 50000,
        canton: 'ZH',
        monthlyDebtService: 5000,
      );

      expect(result.totalMonthlyRetirement, greaterThanOrEqualTo(0.0),
          reason: 'Retirement income must be clamped to >= 0 (parity backend)');
      expect(result.replacementRate, greaterThanOrEqualTo(0.0),
          reason: 'Replacement rate must be >= 0 when income is clamped');
      expect(result.retirementGapMonthly, greaterThanOrEqualTo(0.0),
          reason: 'Gap must be >= 0');
      // Gap should equal full gross salary when retirement is 0
      if (result.totalMonthlyRetirement == 0.0) {
        expect(result.retirementGapMonthly, closeTo(50000 / 12, 0.01));
      }
    });

    test('replacementRate uses grossMonthlySalary as denominator', () {
      final result = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
      );

      final expectedRate =
          result.totalMonthlyRetirement / result.grossMonthlySalary;
      expect(result.replacementRate, closeTo(expectedRate, 0.001),
          reason: 'Standard Swiss taux de remplacement = retirement / salary');
    });

    test('retirementGapMonthly = grossMonthlySalary - retirement', () {
      final result = MinimalProfileService.compute(
        age: 45,
        grossSalary: 80000,
        canton: 'VD',
      );

      final expectedGap =
          result.grossMonthlySalary - result.totalMonthlyRetirement;
      expect(result.retirementGapMonthly,
          closeTo(expectedGap < 0 ? 0 : expectedGap, 0.01));
    });

    test('monthlyDebtImpact reflects debt subtracted from retirement', () {
      final withDebt = MinimalProfileService.compute(
        age: 45,
        grossSalary: 60000,
        canton: 'ZH',
        monthlyDebtService: 500,
      );
      final withoutDebt = MinimalProfileService.compute(
        age: 45,
        grossSalary: 60000,
        canton: 'ZH',
        monthlyDebtService: 0,
      );

      expect(withDebt.monthlyDebtImpact, equals(500.0));
      expect(withoutDebt.monthlyDebtImpact, equals(0.0));
      expect(
        withoutDebt.totalMonthlyRetirement - withDebt.totalMonthlyRetirement,
        closeTo(500.0, 0.01),
        reason: 'Debt subtracts from retirement income, not added to expenses',
      );
    });

    test('debt priority: monthlyDebtService wins over totalDebts', () {
      final result = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
        totalDebts: 100000, // would give 100k * 0.005 = 500
        monthlyDebtService: 200, // should win
      );

      // monthlyDebtService=200 should take priority
      final resultOnlyTotal = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
        totalDebts: 100000, // 100k * 0.005 = 500
      );

      // The difference between "both provided" and "only total" shows which won
      expect(
        result.totalMonthlyRetirement,
        greaterThan(resultOnlyTotal.totalMonthlyRetirement),
        reason:
            'monthlyDebtService=200 < totalDebts estimate=500, so retirement should be higher',
      );
    });
  });
}
