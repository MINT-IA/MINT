import 'package:mint_mobile/constants/social_insurance.dart';

/// Pure disability-insurance estimates shared by health/protection screens.
class DisabilityInsuranceCalculator {
  DisabilityInsuranceCalculator._();

  static const double emergencyReserveChargeRatio = 0.70;
  static const double lppInvalidityIncomeRate = 0.40;
  static const double monthsPerYear = 12.0;

  static double emergencyReserveMonths({
    required double grossMonthlySalary,
    required double liquidSavings,
    double chargeRatio = emergencyReserveChargeRatio,
  }) {
    if (grossMonthlySalary <= 0 || liquidSavings <= 0 || chargeRatio <= 0) {
      return 0;
    }
    return liquidSavings / (grossMonthlySalary * chargeRatio);
  }

  static double lppInvalidityMonthlyIncome({
    required double grossMonthlySalary,
  }) {
    if (grossMonthlySalary <= 0) return 0;
    final annualGross = grossMonthlySalary * monthsPerYear;
    if (!_hasLppCoverage(annualGross)) return 0;

    final coordinatedSalary = (annualGross -
            reg('lpp.coordination_deduction', lppDeductionCoordination))
        .clamp(
      reg('lpp.min_coordinated_salary', lppSalaireCoordMin),
      reg('lpp.max_coordinated_salary', lppSalaireCoordMax),
    );
    return coordinatedSalary * lppInvalidityIncomeRate / monthsPerYear;
  }

  static bool hasLppInvalidityCoverage({
    required double grossMonthlySalary,
  }) {
    if (grossMonthlySalary <= 0) return false;
    return _hasLppCoverage(grossMonthlySalary * monthsPerYear);
  }

  static double act3MonthlyIncome({
    required double grossMonthlySalary,
  }) {
    if (grossMonthlySalary <= 0) return 0;
    return reg('ai.full_monthly_pension', aiRenteEntiere) +
        lppInvalidityMonthlyIncome(grossMonthlySalary: grossMonthlySalary);
  }

  static double lifeDropPercent({
    required double grossMonthlySalary,
  }) {
    if (grossMonthlySalary <= 0) return 0;
    final act3Income =
        act3MonthlyIncome(grossMonthlySalary: grossMonthlySalary);
    return ((1 - act3Income / grossMonthlySalary) * 100).clamp(0, 100);
  }

  static bool _hasLppCoverage(double annualGrossSalary) {
    return annualGrossSalary >= reg('lpp.entry_threshold', lppSeuilEntree);
  }
}
