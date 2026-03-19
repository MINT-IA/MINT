import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ALL LPP calculations MUST use LppCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateLpp() or similar methods.

/// LPP (2nd pillar) projection calculator — pure static functions.
///
/// Legal basis: LPP art. 7, 8, 14, 15, 16 / LIFD art. 38.
/// All computations are deterministic and stateless.
class LppCalculator {
  LppCalculator._();

  /// Safe withdrawal rate (Trinity Study, 4%).
  static const double safeWithdrawalRate = 0.04;

  /// Horizon-adjusted Safe Withdrawal Rate (Trinity Study extension).
  ///
  /// The 4% rule assumes a 30-year retirement horizon.
  /// Shorter horizons allow higher rates; longer horizons require lower.
  /// Formula: 4% ± 0.1% per year deviation from 30, clamped [3%, 5%].
  ///
  /// Educational estimate — ne constitue pas un conseil (LSFin).
  static double adjustedSwr({
    required int retirementAge,
    int lifeExpectancy = 90,
  }) {
    final horizon = lifeExpectancy - retirementAge;
    if (horizon <= 0) return safeWithdrawalRate;
    final adjustment = (horizon - 30) * 0.001;
    return (safeWithdrawalRate - adjustment).clamp(0.03, 0.05);
  }

  /// Adjust LPP conversion rate for early retirement.
  ///
  /// Swiss caisses typically reduce the conversion rate by ~0.2 percentage
  /// points per year before the reference age (LPP art. 13 al. 2).
  /// Late retirement (> referenceAge) does not increase the rate.
  /// Returns the adjusted rate clamped to [3%, baseRate].
  ///
  /// Note: the actual rate varies by caisse — this is an educational estimate.
  static double adjustedConversionRate({
    required double baseRate,
    required int retirementAge,
    int referenceAge = 65,
    double reductionPerYear = lppEarlyRetirementRateReduction,
  }) {
    if (retirementAge >= referenceAge) return baseRate;
    final yearsEarly = referenceAge - retirementAge;
    return (baseRate - yearsEarly * reductionPerYear).clamp(0.03, baseRate);
  }

  /// Project LPP balance to retirement with bonifications.
  ///
  /// Returns the projected annual rente (balance × conversionRate).
  /// Bonifications by age (LPP art. 16): 7/10/15/18%.
  /// Below seuil entree (22'680): no bonifications, only return on existing capital.
  ///
  /// [bonificationRateOverride]: if set, overrides the age-based LPP bonification
  /// rate. Use for surobligatoire/enveloppant plans (e.g. CPE Plan Maxi 31.69%).
  /// This is the TOTAL rate (employee + employer combined).
  ///
  /// [salaireAssureOverride]: if set, uses this instead of computed salaire
  /// coordonné. Useful when the certificate declares a specific salaire assuré
  /// (e.g. 91'967 CHF for CPE vs standard coordonné calculation).
  static double projectToRetirement({
    required double currentBalance,
    required int currentAge,
    required int retirementAge,
    required double grossAnnualSalary,
    required double caisseReturn,
    required double conversionRate,
    double monthlyBuyback = 0,
    double buybackCap = 0,
    double? bonificationRateOverride,
    double? salaireAssureOverride,
  }) {
    final belowThreshold =
        salaireAssureOverride == null && grossAnnualSalary < lppSeuilEntree;
    final salaireBase = salaireAssureOverride ??
        (belowThreshold
            ? 0.0
            : (grossAnnualSalary - lppDeductionCoordination)
                .clamp(lppSalaireCoordMin, lppSalaireCoordMax));

    double balance = currentBalance;
    double buybackDone = 0;

    for (int a = currentAge; a < retirementAge && a < 70; a++) {
      balance *= (1 + caisseReturn);
      final bonifRate =
          bonificationRateOverride ?? getLppBonificationRate(a);
      balance += salaireBase * bonifRate;
      if (!belowThreshold && monthlyBuyback > 0 && buybackDone < buybackCap) {
        final yearly =
            (monthlyBuyback * 12).clamp(0, buybackCap - buybackDone);
        balance += yearly;
        buybackDone += yearly;
      }
    }

    final effectiveRate = adjustedConversionRate(
      baseRate: conversionRate,
      retirementAge: retirementAge,
    );
    return balance * effectiveRate;
  }

  /// Single month LPP projection step (for ForecasterService monthly loop).
  ///
  /// Returns new balance after one month of return + bonification.
  /// Use this inside a monthly loop to get intermediate projection points.
  ///
  /// [bonificationRateOverride] / [salaireAssureOverride]: same as
  /// [projectToRetirement] — for surobligatoire plan support.
  static double projectOneMonth({
    required double currentBalance,
    required int age,
    required double grossAnnualSalary,
    required double monthlyReturn,
    double? bonificationRateOverride,
    double? salaireAssureOverride,
  }) {
    double newBalance = currentBalance * (1 + monthlyReturn);
    if (salaireAssureOverride == null && grossAnnualSalary < lppSeuilEntree) {
      return newBalance;
    }
    final salaireBase = salaireAssureOverride ??
        (grossAnnualSalary - lppDeductionCoordination)
            .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    final bonifRate = bonificationRateOverride ?? getLppBonificationRate(age);
    return newBalance + salaireBase * bonifRate / 12;
  }

  /// Compute monthly LPP income blending rente and capital withdrawal.
  ///
  /// [lppCapitalPct]: 0.0 = 100% rente, 0.5 = mixte, 1.0 = 100% capital.
  /// Capital portion: withdrawal tax (LIFD art. 38) + 4% SWR (Trinity Study).
  /// Married couples get ~15% capital tax discount per cantonal rules.
  static double blendedMonthly({
    required double annualRente,
    required double conversionRate,
    required double lppCapitalPct,
    required String canton,
    bool isMarried = false,
    int? horizonYears,
    int retirementAge = 65,
  }) {
    if (lppCapitalPct <= 0 || annualRente <= 0) return annualRente / 12;

    // Back-calculate projected balance from annual rente
    final effectiveRate = conversionRate > 0 ? conversionRate : lppTauxConversionMinDecimal;
    final projectedBalance = annualRente / effectiveRate;

    // Rente portion
    final renteMonthly = annualRente * (1 - lppCapitalPct) / 12;

    // Capital portion: progressive withdrawal tax + SWR
    final capitalBrut = projectedBalance * lppCapitalPct;
    final cantonCode = canton.isNotEmpty ? canton.toUpperCase() : 'ZH';
    final baseRate = tauxImpotRetraitCapital[cantonCode] ?? 0.065;
    final effectiveBaseRate =
        isMarried ? baseRate * marriedCapitalTaxDiscount : baseRate;
    final tax = RetirementTaxCalculator.progressiveTax(
        capitalBrut, effectiveBaseRate);
    final capitalNet = capitalBrut - tax;
    final swr = horizonYears != null
        ? adjustedSwr(
            retirementAge: retirementAge,
            lifeExpectancy: retirementAge + horizonYears,
          )
        : safeWithdrawalRate;
    final capitalMonthly = capitalNet * swr / 12;

    return renteMonthly + capitalMonthly;
  }

  /// Compute salaire coordonne from gross annual salary (LPP art. 8).
  static double computeSalaireCoordonne(double grossAnnualSalary) {
    if (grossAnnualSalary < lppSeuilEntree) return 0;
    return (grossAnnualSalary - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
  }

  // ════════════════════════════════════════════════════════════════
  //  SURVIVOR PENSION — LPP art. 19-20
  // ════════════════════════════════════════════════════════════════

  /// Conjoint survivor pension rate (LPP art. 19 al. 1).
  /// 60% of the insured's projected annual rente.
  static const double survivorSpouseRate = 0.60;

  /// Orphan pension rate per child (LPP art. 20).
  /// 20% of the insured's projected annual rente.
  static const double survivorOrphanRate = 0.20;

  /// Compute survivor pensions (LPP art. 19-20).
  ///
  /// Returns monthly amounts for conjoint and orphans.
  /// The conjoint rente requires marriage or registered partnership
  /// (concubins have NO legal right to LPP survivor pension).
  ///
  /// **LPP art. 19 al. 2**: the surviving spouse receives a rente only if
  /// at least one condition is met:
  ///   (a) they have dependent children, OR
  ///   (b) they are aged >= 45 AND the marriage lasted >= 5 years.
  /// If neither condition is met, the spouse receives a lump sum equal to
  /// 3× the annual pension (returned in [conjointLumpSum]).
  ///
  /// **LPP art. 19 al. 3**: total survivor pensions are capped at 100%
  /// of the insured's projected rente.
  ///
  /// [projectedAnnualRente]: the insured's projected LPP annual rente at 65.
  /// [isMarried]: true for married/registered partnership only.
  /// [numberOfChildren]: dependent children under 18 (or 25 if in education).
  /// [conjointAge]: surviving spouse's age (for art. 19 al. 2 check).
  /// [marriageDurationYears]: years of marriage (for art. 19 al. 2 check).
  static ({
    double conjointMonthly,
    double conjointLumpSum,
    double orphanMonthlyPerChild,
    double orphanMonthlyTotal,
    double totalMonthly,
    bool conjointGetsRente,
  }) computeSurvivorPension({
    required double projectedAnnualRente,
    required bool isMarried,
    int numberOfChildren = 0,
    int? conjointAge,
    int? marriageDurationYears,
  }) {
    // LPP art. 19 al. 2: conjoint rente conditions
    final hasChildren = numberOfChildren > 0;
    final meetsAgeAndDuration =
        (conjointAge ?? 45) >= 45 && (marriageDurationYears ?? 5) >= 5;
    final conjointGetsRente =
        isMarried && (hasChildren || meetsAgeAndDuration);

    double conjointAnnual;
    double conjointLumpSum;
    if (!isMarried) {
      conjointAnnual = 0;
      conjointLumpSum = 0;
    } else if (conjointGetsRente) {
      conjointAnnual = projectedAnnualRente * survivorSpouseRate;
      conjointLumpSum = 0;
    } else {
      // LPP art. 19 al. 2: lump sum = 3× annual rente
      conjointAnnual = 0;
      conjointLumpSum = projectedAnnualRente * survivorSpouseRate * 3;
    }

    final orphanAnnualPerChild = projectedAnnualRente * survivorOrphanRate;
    final orphanAnnualTotal = orphanAnnualPerChild * numberOfChildren;

    // LPP art. 19 al. 3: cap total survivor pensions at 100% of rente
    var totalAnnual = conjointAnnual + orphanAnnualTotal;
    double scaleFactor = 1.0;
    if (totalAnnual > projectedAnnualRente && projectedAnnualRente > 0) {
      scaleFactor = projectedAnnualRente / totalAnnual;
      totalAnnual = projectedAnnualRente;
    }

    return (
      conjointMonthly: conjointAnnual * scaleFactor / 12,
      conjointLumpSum: conjointLumpSum,
      orphanMonthlyPerChild: numberOfChildren > 0
          ? orphanAnnualPerChild * scaleFactor / 12
          : 0.0,
      orphanMonthlyTotal: orphanAnnualTotal * scaleFactor / 12,
      totalMonthly: totalAnnual / 12,
      conjointGetsRente: conjointGetsRente,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  EPL REPAYMENT IMPACT — LPP art. 30d, OPP2 art. 5
  // ════════════════════════════════════════════════════════════════

  /// Compute the impact of an EPL (early withdrawal) on the projected
  /// LPP rente at retirement, and the effect of repaying the EPL.
  ///
  /// LPP art. 30d: repayment restores the insured's benefits.
  /// LPP art. 79b al. 3: buyback blocked for 3 years after EPL repayment.
  ///
  /// **Compound interest modeling**: `renteWithoutEpl` estimates what the
  /// rente would have been if the EPL was never taken (compound interest
  /// on the outstanding amount since [eplAge]). `renteIfFullyRepaid`
  /// estimates what happens if the outstanding is repaid NOW (compound
  /// interest lost during the gap period is gone). These differ when
  /// [eplAge] < [currentAge].
  ///
  /// [currentBalance]: current LPP balance (after EPL was taken).
  /// [eplAmount]: the EPL amount that was withdrawn.
  /// [eplRepaid]: how much of the EPL has been repaid so far.
  /// [eplAge]: age at which the EPL was originally taken. If null,
  ///   defaults to [currentAge] (conservative: no compound interest gap).
  /// [currentAge], [retirementAge], [grossAnnualSalary], [caisseReturn],
  /// [conversionRate]: same params as [projectToRetirement].
  ///
  /// Returns: rente without EPL (hypothetical), rente with EPL outstanding,
  /// rente if EPL fully repaid now, and the monthly gap.
  static ({
    double renteWithoutEpl,
    double renteWithEplOutstanding,
    double renteIfFullyRepaid,
    double monthlyGapFromEpl,
  }) computeEplImpact({
    required double currentBalance,
    required double eplAmount,
    required double eplRepaid,
    required int currentAge,
    required int retirementAge,
    required double grossAnnualSalary,
    required double caisseReturn,
    required double conversionRate,
    int? eplAge,
  }) {
    final outstanding = (eplAmount - eplRepaid).clamp(0.0, double.infinity);
    final effectiveEplAge = eplAge ?? currentAge;
    final yearsWithoutCapital = (currentAge - effectiveEplAge).clamp(0, 70);

    // Compound interest the outstanding would have earned inside the LPP
    // between eplAge and currentAge (lost forever, even if repaid now).
    double compoundGrowth = outstanding;
    for (int i = 0; i < yearsWithoutCapital; i++) {
      compoundGrowth *= (1 + caisseReturn);
    }

    // Rente with current balance (EPL already deducted)
    final renteWithEpl = projectToRetirement(
      currentBalance: currentBalance,
      currentAge: currentAge,
      retirementAge: retirementAge,
      grossAnnualSalary: grossAnnualSalary,
      caisseReturn: caisseReturn,
      conversionRate: conversionRate,
    );

    // Rente if EPL had never been taken: balance + outstanding WITH
    // compound interest from eplAge to now (the money would have grown).
    final renteWithoutEpl = projectToRetirement(
      currentBalance: currentBalance + compoundGrowth,
      currentAge: currentAge,
      retirementAge: retirementAge,
      grossAnnualSalary: grossAnnualSalary,
      caisseReturn: caisseReturn,
      conversionRate: conversionRate,
    );

    // Rente if EPL is fully repaid NOW: balance + outstanding (nominal),
    // but the compound interest from eplAge→now is lost.
    final renteIfRepaid = projectToRetirement(
      currentBalance: currentBalance + outstanding,
      currentAge: currentAge,
      retirementAge: retirementAge,
      grossAnnualSalary: grossAnnualSalary,
      caisseReturn: caisseReturn,
      conversionRate: conversionRate,
    );

    return (
      renteWithoutEpl: renteWithoutEpl,
      renteWithEplOutstanding: renteWithEpl,
      renteIfFullyRepaid: renteIfRepaid,
      monthlyGapFromEpl: (renteWithoutEpl - renteWithEpl) / 12,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  COUPLE RETIREMENT SEQUENCING — fiscal optimization
  // ════════════════════════════════════════════════════════════════

  /// Compare different retirement sequencing strategies for a couple.
  ///
  /// Swiss tax law taxes capital withdrawals progressively (LIFD art. 38).
  /// Splitting withdrawals across two different tax years reduces the
  /// effective rate. This method compares 3 strategies:
  ///
  /// 1. **Same year**: both retire and withdraw capital the same year
  /// 2. **Staggered**: withdrawals spread across 2+ tax years
  /// 3. **Optimal**: the strategy with the lowest total tax
  ///
  /// [userCapital], [conjointCapital]: LPP capital to withdraw.
  /// [canton]: for cantonal tax rate lookup.
  /// [isMarried]: affects married couple capital tax discount.
  static ({
    double taxSameYear,
    double taxStaggered,
    double taxSaving,
    String recommendation,
  }) compareRetirementSequencing({
    required double userCapital,
    required double conjointCapital,
    required String canton,
    required bool isMarried,
  }) {
    // Guard: no capital to withdraw → no tax optimization possible
    final combinedCapital = userCapital + conjointCapital;
    if (combinedCapital <= 0) {
      return (
        taxSameYear: 0,
        taxStaggered: 0,
        taxSaving: 0,
        recommendation: 'Aucun capital LPP à retirer dans cette configuration.',
      );
    }

    final cantonCode = canton.isNotEmpty ? canton.toUpperCase() : 'ZH';
    final baseRate = tauxImpotRetraitCapital[cantonCode] ?? 0.065;
    final effectiveRate =
        isMarried ? baseRate * marriedCapitalTaxDiscount : baseRate;

    // Strategy 1: same year — combined capital taxed together
    final taxSameYear =
        RetirementTaxCalculator.progressiveTax(combinedCapital, effectiveRate);

    // Strategy 2: staggered — each taxed separately in different years
    final taxUser =
        RetirementTaxCalculator.progressiveTax(userCapital, effectiveRate);
    final taxConjoint =
        RetirementTaxCalculator.progressiveTax(conjointCapital, effectiveRate);
    final taxStaggered = taxUser + taxConjoint;

    final saving = taxSameYear - taxStaggered;

    String recommendation;
    if (saving > 1000) {
      recommendation = 'Étaler les retraits sur 2 années fiscales '
          'pourrait réduire l\'impôt d\'environ CHF ${saving.round()}. '
          'Réf. : LIFD art. 38.';
    } else if (saving > 0) {
      recommendation = 'L\'écart fiscal entre les deux stratégies est '
          'faible (CHF ${saving.round()}). D\'autres facteurs pourraient '
          'être plus déterminants.';
    } else {
      recommendation = 'Dans cette configuration, le timing du retrait '
          'a peu d\'impact fiscal.';
    }

    return (
      taxSameYear: taxSameYear,
      taxStaggered: taxStaggered,
      taxSaving: saving.clamp(0, double.infinity),
      recommendation: recommendation,
    );
  }
}
