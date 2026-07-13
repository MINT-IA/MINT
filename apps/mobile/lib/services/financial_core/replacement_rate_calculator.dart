/// Canonical retirement replacement-rate calculation.
///
/// Invalid or incomplete inputs stay unknown rather than becoming a
/// misleading percentage. Valid results are expressed as a percentage and
/// capped at the report's display ceiling.
class ReplacementRateCalculator {
  ReplacementRateCalculator._();

  static const double maximumRatePercent = 150.0;
  static const double percentageFactor = 100.0;

  static double? calculate({
    required double? monthlyRetirementIncome,
    required double currentMonthlyIncome,
  }) {
    if (monthlyRetirementIncome == null ||
        !monthlyRetirementIncome.isFinite ||
        monthlyRetirementIncome < 0 ||
        !currentMonthlyIncome.isFinite ||
        currentMonthlyIncome <= 0) {
      return null;
    }

    return (monthlyRetirementIncome / currentMonthlyIncome * percentageFactor)
        .clamp(0.0, maximumRatePercent)
        .toDouble();
  }
}
