class UnemploymentFinancialFacts {
  const UnemploymentFinancialFacts._();

  static double? monthlyInsuredEarningsFromAnnual(double annualGrossIncome) {
    if (annualGrossIncome <= 0) return null;
    return annualGrossIncome / 12;
  }

  static int withNearAvsExtraDays({
    required int baseDays,
    required int contributionMonths,
    required bool nearAvsReferenceAge,
  }) {
    return nearAvsReferenceAge && contributionMonths >= 22
        ? baseDays + 120
        : baseDays;
  }

  static int generalWaitingDays({
    required double annualInsuredEarnings,
    required bool hasMaintenanceDuty,
  }) {
    // OACI art. 6a / LACI art. 18; SECO/arbeit.swiss Directive LACI IC C110:
    // al. 2 exempts everyone up to CHF 36k/year; al. 3 also exempts
    // CHF 36'001-60k/year when there is maintenance duty for children <25.
    // Above those exemptions, C110 applies 5/10/15/20 days; for maintenance
    // duty, C110 caps the general wait at 5 days above CHF 60k/year.
    if (annualInsuredEarnings <= 36000) return 0;
    if (hasMaintenanceDuty) {
      return annualInsuredEarnings <= 60000 ? 0 : 5;
    }
    if (annualInsuredEarnings <= 60000) return 5;
    if (annualInsuredEarnings <= 90000) return 10;
    if (annualInsuredEarnings <= 125000) return 15;
    return 20;
  }

  static double estimatedNetMonthlyBenefitFromGross(double grossBenefit) {
    // Educational cash-flow approximation: Geneva unemployment guidance lists
    // 5.3% AVS/AI/APG + ~2.47% non-occupational accident deductions; LPP risk
    // premiums can vary, so Mint keeps a conservative rounded 10% haircut and
    // labels the result as estimated, before personal tax.
    if (grossBenefit <= 0) return 0;
    return grossBenefit * 0.90;
  }
}
