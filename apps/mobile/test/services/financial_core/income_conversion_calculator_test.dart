import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/income_conversion_calculator.dart';

void main() {
  test('exposes shared fallback Swiss social charge rate', () {
    expect(IncomeConversionCalculator.fallbackSwissSocialChargesRate, 0.13);
  });

  test('normalizes and converts income values', () {
    expect(IncomeConversionCalculator.clampEmploymentRatePercent(null), 100);
    expect(IncomeConversionCalculator.clampEmploymentRatePercent(-10), 0);
    expect(IncomeConversionCalculator.clampEmploymentRatePercent(80), 80);
    expect(IncomeConversionCalculator.clampEmploymentRatePercent(140), 100);
    expect(IncomeConversionCalculator.normalizeAnnualSalaryMonths(null), 12);
    expect(IncomeConversionCalculator.normalizeAnnualSalaryMonths(0), 12);
    expect(IncomeConversionCalculator.normalizeAnnualSalaryMonths(13), 13);

    final annualGross = IncomeConversionCalculator.annualGrossFromMonthly(
      monthlyGross: 10000,
      months: 12,
    );

    expect(annualGross, 120000);
    expect(IncomeConversionCalculator.monthlyAmountFromAnnual(144000), 12000);
    expect(
      IncomeConversionCalculator.monthlyAmountFromAnnual(130000, months: 13),
      10000,
    );
    expect(
        IncomeConversionCalculator.annualBonusFromPercentage(
            annualGross: annualGross, bonusPercentage: 10),
        12000);
    expect(
        IncomeConversionCalculator.bonusPercentageFromAnnualBonus(
            annualBonus: 12000, annualBaseSalary: annualGross),
        10);
    expect(
        IncomeConversionCalculator.annualGrossFromMonthly(
            monthlyGross: 10000, months: 0),
        0);
    expect(
        IncomeConversionCalculator.bonusPercentageFromAnnualBonus(
            annualBonus: 12000, annualBaseSalary: 0),
        isNull);
  });
}
