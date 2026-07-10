import 'dart:math' as math;

/// Compound future value for repeated annual contributions.
///
/// This is intentionally small and generic: product screens choose the
/// scenario, but compound-interest math stays in financial_core.
class CompoundContributionProjectionCalculator {
  CompoundContributionProjectionCalculator._();

  static const int defaultHorizonYears = 20;
  static const double defaultAnnualReturnRate = 0.04;

  static double futureValueOfAnnualContributions(
    double annualContribution, {
    int horizonYears = defaultHorizonYears,
    double annualReturnRate = defaultAnnualReturnRate,
  }) {
    if (annualContribution <= 0 || horizonYears <= 0) return 0;
    if (annualReturnRate <= 0) {
      return annualContribution * horizonYears;
    }

    final compoundFactor =
        (math.pow(1 + annualReturnRate, horizonYears) - 1) / annualReturnRate;
    return annualContribution * compoundFactor;
  }
}
