import 'dart:math' as math;

/// Emergency-fund heuristic used only for legacy migration and estimate labels.
///
/// This must never be treated as declared cash. Explicit liquid cash is
/// `q_cash_total`; this helper only reconstructs the old `q_emergency_fund`
/// bucket estimate so stale persisted values can be quarantined.
class EmergencyFundHeuristic {
  static double cashForWizardBucket({
    required String emergencyFundBucket,
    required double housingCost,
    required double monthlyLamalPremium,
    String? housingPayFrequency,
  }) {
    final months = switch (emergencyFundBucket.toLowerCase()) {
      'yes_6months' => 6,
      'yes_3months' => 3,
      _ => 0,
    };
    if (months <= 0) return 0;

    final monthlyHousing =
        housingPayFrequency == 'yearly' || housingPayFrequency == 'annuel'
            ? housingCost / 12
            : housingCost;
    final monthlyExpenses = monthlyHousing + monthlyLamalPremium;
    if (monthlyExpenses <= 0) return 0;
    return monthlyExpenses * months;
  }
}

/// Legacy smart-flow cash estimate used only to quarantine pre-fix data.
class LegacyCashEstimateHeuristic {
  static double smartFlowSavingsEstimate({
    required int age,
    required double grossSalary,
  }) {
    return math.max(0.0, (age - 25) * grossSalary * 0.05);
  }
}
