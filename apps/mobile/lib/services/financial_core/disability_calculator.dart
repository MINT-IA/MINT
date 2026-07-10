import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';

/// Pure disability coverage calculations used by disability education screens.
///
/// This is an educational approximation, not an insurance quote. UI layers are
/// responsible for explaining assumptions and asking for missing ledger facts.
class DisabilityCalculator {
  DisabilityCalculator._();

  static const double employerContinuationRate = 0.80;
  static const double ijmCoverageRate = 0.80;
  static const double lppInvalidityRate = 0.40;
  static const double monthlyExpensesProxyRate = 0.70;
  static const double reducedWorkCapacityRate = 0.50;

  /// Simplified LPP capital growth proxy carried over from the original
  /// disability screen model. Educational estimate only; not caisse-specific.
  static const double lppCapitalGrowthFactor = 1.50;

  static double annualGross(double grossMonthly) => grossMonthly * 12;

  static double monthlyExpensesProxy(double grossMonthly) =>
      grossMonthly * monthlyExpensesProxyRate;

  static double reducedAnnualSalary(double grossMonthly) =>
      annualGross(grossMonthly) * reducedWorkCapacityRate;

  static double employerMonthlyIncome(double grossMonthly) =>
      grossMonthly * employerContinuationRate;

  static double ijmMonthlyIncome(double grossMonthly, {required bool hasIjm}) =>
      hasIjm ? grossMonthly * ijmCoverageRate : 0.0;

  static bool hasLppCoverage(double grossMonthly) =>
      annualGross(grossMonthly) >= lppSeuilEntree;

  static double lppInvalidityMonthly(double grossMonthly) {
    final coordinated =
        LppCalculator.computeSalaireCoordonne(annualGross(grossMonthly));
    return coordinated * lppInvalidityRate / 12;
  }

  static double act3MonthlyIncome(double grossMonthly) =>
      aiRenteEntiere + lppInvalidityMonthly(grossMonthly);

  static double monthlyGapAtAct3(double grossMonthly) =>
      grossMonthly - act3MonthlyIncome(grossMonthly);

  static double lppCapitalBeforeDisability({
    required double grossMonthly,
    required int age,
  }) {
    final yearsToRetirement = (65 - age).clamp(0, 40);
    final grossAnnual = annualGross(grossMonthly);
    if (grossAnnual < lppSeuilEntree) return 0;
    final coordinated = LppCalculator.computeSalaireCoordonne(grossAnnual);
    final rate = getLppBonificationRate(age);
    final annualContribution = coordinated * rate;
    return annualContribution * yearsToRetirement * lppCapitalGrowthFactor;
  }

  static double lppCapitalAfterDisability({
    required double grossMonthly,
    required int age,
  }) {
    final reducedGross = reducedAnnualSalary(grossMonthly);
    final yearsToRetirement = (65 - age).clamp(0, 40);
    if (reducedGross < lppSeuilEntree) return 0;
    final coordinated = LppCalculator.computeSalaireCoordonne(reducedGross);
    final rate = getLppBonificationRate(age);
    final annualContribution = coordinated * rate;
    return annualContribution * yearsToRetirement * lppCapitalGrowthFactor;
  }

  static double monthsReserve({
    required double savings,
    required double grossMonthly,
  }) {
    final expenses = monthlyExpensesProxy(grossMonthly);
    if (expenses <= 0) return 0;
    return savings / expenses;
  }

  static String savingsReserveGrade(double monthsReserve) {
    if (monthsReserve >= 6) return 'A';
    if (monthsReserve >= 3) return 'C+';
    if (monthsReserve >= 1) return 'D';
    return 'F';
  }

  static String overallGrade({
    required bool hasIjm,
    bool hasPrivateInsurance = false,
    required double grossMonthly,
    required double savings,
  }) {
    int score = 0;
    if (hasIjm || hasPrivateInsurance) score += 3;
    if (hasLppCoverage(grossMonthly)) score += 2;
    final reserveMonths = monthsReserve(
      savings: savings,
      grossMonthly: grossMonthly,
    );
    if (reserveMonths >= 3) score += 2;
    if (reserveMonths >= 6) score += 1;
    if (score >= 7) return 'B+';
    if (score >= 5) return 'C+';
    if (score >= 3) return 'C-';
    return 'D';
  }

  static double lifeDropPercent(double grossMonthly) {
    if (grossMonthly <= 0) return 0;
    final act3Income = act3MonthlyIncome(grossMonthly);
    return ((1 - act3Income / grossMonthly) * 100).clamp(0, 100);
  }
}
