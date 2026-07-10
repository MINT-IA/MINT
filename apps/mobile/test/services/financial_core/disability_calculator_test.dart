import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/disability_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';

void main() {
  group('DisabilityCalculator', () {
    test('computes the three disability income acts from salary and IJM', () {
      const grossMonthly = 10000.0;

      expect(
        DisabilityCalculator.employerMonthlyIncome(grossMonthly),
        closeTo(8000, 0.01),
      );
      expect(
        DisabilityCalculator.ijmMonthlyIncome(
          grossMonthly,
          hasIjm: true,
        ),
        closeTo(8000, 0.01),
      );
      expect(
        DisabilityCalculator.ijmMonthlyIncome(
          grossMonthly,
          hasIjm: false,
        ),
        equals(0),
      );
      expect(
        DisabilityCalculator.act3MonthlyIncome(grossMonthly),
        closeTo(aiRenteEntiere + (lppSalaireCoordMax * 0.40 / 12), 0.01),
      );
    });

    test('computes act 3 income for uncapped and below-threshold salaries', () {
      const uncappedGrossMonthly = 5000.0;
      final uncappedCoordinated = LppCalculator.computeSalaireCoordonne(
        DisabilityCalculator.annualGross(uncappedGrossMonthly),
      );
      expect(uncappedCoordinated, lessThan(lppSalaireCoordMax));
      expect(
        DisabilityCalculator.act3MonthlyIncome(uncappedGrossMonthly),
        closeTo(aiRenteEntiere + (uncappedCoordinated * 0.40 / 12), 0.01),
      );

      const belowThresholdGrossMonthly = 1500.0;
      expect(
        LppCalculator.computeSalaireCoordonne(
          DisabilityCalculator.annualGross(belowThresholdGrossMonthly),
        ),
        equals(0),
      );
      expect(
        DisabilityCalculator.act3MonthlyIncome(belowThresholdGrossMonthly),
        equals(aiRenteEntiere),
      );
    });

    test('treats zero savings as a valid reserve with F grade', () {
      expect(
        DisabilityCalculator.monthsReserve(
          savings: 0,
          grossMonthly: 10000,
        ),
        equals(0),
      );
      expect(DisabilityCalculator.savingsReserveGrade(0), equals('F'));
      expect(
        DisabilityCalculator.overallGrade(
          hasIjm: true,
          grossMonthly: 10000,
          savings: 0,
        ),
        equals('C+'),
      );
    });

    test('computes LPP reset capital before and after reduced salary', () {
      final before = DisabilityCalculator.lppCapitalBeforeDisability(
        grossMonthly: 10000,
        age: 45,
      );
      final after = DisabilityCalculator.lppCapitalAfterDisability(
        grossMonthly: 10000,
        age: 45,
      );

      expect(before, greaterThan(0));
      expect(after, greaterThanOrEqualTo(0));
      expect(after, lessThan(before));
    });

    test('uses the LPP minimum coordinated salary after disability', () {
      const grossMonthly = 4500.0;
      const age = 45;
      final expected = lppSalaireCoordMin *
          getLppBonificationRate(age) *
          (65 - age) *
          DisabilityCalculator.lppCapitalGrowthFactor;

      expect(
        DisabilityCalculator.lppCapitalAfterDisability(
          grossMonthly: grossMonthly,
          age: age,
        ),
        closeTo(expected, 0.01),
      );
    });

    test('computes life drop percent from act 3 income', () {
      final drop = DisabilityCalculator.lifeDropPercent(10000);

      expect(drop, closeTo(53.38, 0.1));
      expect(DisabilityCalculator.lifeDropPercent(0), equals(0));
    });
  });
}
