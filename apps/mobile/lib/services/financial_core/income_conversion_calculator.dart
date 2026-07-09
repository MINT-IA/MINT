/// Income unit conversions shared by profile hydration and persistence.
///
/// Keeps salary/bonus percentage math inside financial_core so profile code
/// only maps data keys and does not duplicate financial formulas.
class IncomeConversionCalculator {
  IncomeConversionCalculator._();

  static const double minimumEmploymentRatePercent = 0.0;
  static const double fullTimeEmploymentRatePercent = 100.0;
  static const double defaultAnnualSalaryMonths = 12.0;

  static double clampEmploymentRatePercent(double? value) {
    return (value ?? fullTimeEmploymentRatePercent)
        .clamp(minimumEmploymentRatePercent, fullTimeEmploymentRatePercent)
        .toDouble();
  }

  static double normalizeAnnualSalaryMonths(double? value) {
    if (value == null || value <= 0) return defaultAnnualSalaryMonths;
    return value;
  }

  static double monthlyGrossFromAnnualGross(
    double annualGross, {
    double months = defaultAnnualSalaryMonths,
  }) {
    if (annualGross <= 0 || months <= 0) return 0;
    return annualGross / months;
  }

  static double annualGrossFromMonthly({
    required double monthlyGross,
    required double months,
  }) {
    if (monthlyGross <= 0 || months <= 0) return 0;
    return monthlyGross * months;
  }

  static double annualBonusFromPercentage({
    required double annualGross,
    required double bonusPercentage,
  }) {
    if (annualGross <= 0 || bonusPercentage <= 0) return 0;
    return annualGross * bonusPercentage / fullTimeEmploymentRatePercent;
  }

  static double? bonusPercentageFromAnnualBonus({
    required double? annualBonus,
    required double annualBaseSalary,
  }) {
    if (annualBonus == null || annualBaseSalary <= 0) return null;
    return annualBonus / annualBaseSalary * fullTimeEmploymentRatePercent;
  }
}
