import 'package:mint_mobile/constants/social_insurance.dart';

/// Pure disability-insurance estimates shared by health/protection screens.
class DisabilityInsuranceCalculator {
  DisabilityInsuranceCalculator._();

  static const double emergencyReserveChargeRatio = 0.70;
  static const double employerContinuationIncomeRate = 0.80;
  static const double ijmIncomeRate = 0.80;
  static const double lppInvalidityIncomeRate = 0.40;
  static const double reducedEarningCapacityRate = 0.50;
  static const double lppProjectionGrowthFactor = 1.50;
  static const int lppReferenceRetirementAge = 65;
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

  static double employerContinuationMonthlyIncome({
    required double grossMonthlySalary,
  }) {
    if (grossMonthlySalary <= 0) return 0;
    return grossMonthlySalary * employerContinuationIncomeRate;
  }

  static double ijmMonthlyIncome({
    required double grossMonthlySalary,
    required bool hasIjm,
  }) {
    if (!hasIjm || grossMonthlySalary <= 0) return 0;
    return grossMonthlySalary * ijmIncomeRate;
  }

  static double projectedLppCapitalBeforeDisability({
    required int currentAge,
    required double grossMonthlySalary,
  }) {
    return _projectedLppCapital(
      currentAge: currentAge,
      annualGrossSalary: grossMonthlySalary * monthsPerYear,
      minCoordinatedSalary: reg(
        'lpp.min_coordinated_salary',
        lppSalaireCoordMin,
      ),
    );
  }

  static double projectedLppCapitalAfterDisability({
    required int currentAge,
    required double grossMonthlySalary,
  }) {
    return _projectedLppCapital(
      currentAge: currentAge,
      annualGrossSalary:
          grossMonthlySalary * monthsPerYear * reducedEarningCapacityRate,
      minCoordinatedSalary: 0,
    );
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

  static double _projectedLppCapital({
    required int currentAge,
    required double annualGrossSalary,
    required double minCoordinatedSalary,
  }) {
    if (currentAge >= lppReferenceRetirementAge ||
        currentAge < 0 ||
        annualGrossSalary <= 0 ||
        !_hasLppCoverage(annualGrossSalary)) {
      return 0;
    }
    final yearsToRetirement =
        (lppReferenceRetirementAge - currentAge).clamp(0, 40);
    final coordinatedSalary = (annualGrossSalary -
            reg('lpp.coordination_deduction', lppDeductionCoordination))
        .clamp(
      minCoordinatedSalary,
      reg('lpp.max_coordinated_salary', lppSalaireCoordMax),
    );
    if (coordinatedSalary <= 0) return 0;
    final annualContribution =
        coordinatedSalary * getLppBonificationRate(currentAge);
    return annualContribution * yearsToRetirement * lppProjectionGrowthFactor;
  }
}
