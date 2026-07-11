/// Normalizes LAMal premiums to the CHF 300 franchise baseline.
///
/// The LAMal franchise comparison engine expects the monthly premium at the
/// CHF 300 franchise. When the user ledger stores an actual premium from a
/// higher current franchise, this calculator lifts it back to the CHF 300
/// baseline before scenario comparison.
///
/// Non-current franchise rows remain modelled estimates: they apply
/// market-average savings rates to the inferred baseline, not insurer quotes.
class LamalPremiumNormalizer {
  LamalPremiumNormalizer._();

  static double toFranchise300MonthlyPremium({
    required double monthlyPremium,
    required int? currentFranchise,
    required bool isChild,
    required Map<int, double> premiumSavingsVs300,
  }) {
    if (monthlyPremium <= 0 || isChild || currentFranchise == null) {
      return monthlyPremium;
    }

    final savingsRate = premiumSavingsVs300[currentFranchise];
    if (savingsRate == null) return monthlyPremium;

    final factor = 1 - savingsRate;
    if (factor <= 0) return monthlyPremium;

    return monthlyPremium / factor;
  }
}
