import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/disability_insurance_calculator.dart';

void main() {
  test('computes emergency reserve months from gross salary and liquid savings',
      () {
    expect(
      DisabilityInsuranceCalculator.emergencyReserveMonths(
        grossMonthlySalary: 8000,
        liquidSavings: 42000,
      ),
      closeTo(7.5, 0.001),
    );
    expect(
      DisabilityInsuranceCalculator.emergencyReserveMonths(
        grossMonthlySalary: 0,
        liquidSavings: 42000,
      ),
      0,
    );
  });

  test('estimates LPP invalidity income with Swiss coordinated salary caps',
      () {
    expect(
      DisabilityInsuranceCalculator.hasLppInvalidityCoverage(
        grossMonthlySalary: 8000,
      ),
      isTrue,
    );
    expect(
      DisabilityInsuranceCalculator.lppInvalidityMonthlyIncome(
        grossMonthlySalary: 8000,
      ),
      closeTo(2142, 0.001),
    );
    expect(
      DisabilityInsuranceCalculator.hasLppInvalidityCoverage(
        grossMonthlySalary: 1800,
      ),
      isFalse,
    );
    expect(
      DisabilityInsuranceCalculator.lppInvalidityMonthlyIncome(
        grossMonthlySalary: 1800,
      ),
      0,
    );
  });

  test('computes life drop percentage from AI plus estimated LPP income', () {
    expect(
      DisabilityInsuranceCalculator.lifeDropPercent(grossMonthlySalary: 8000),
      closeTo(41.725, 0.001),
    );
    expect(
      DisabilityInsuranceCalculator.lifeDropPercent(grossMonthlySalary: 0),
      0,
    );
  });
}
