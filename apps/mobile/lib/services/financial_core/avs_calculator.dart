import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

// ALL AVS calculations MUST use AvsCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateAvs() or similar methods.

/// AVS pension calculator — pure static functions.
///
/// Legal basis: LAVS art. 21-29, 34, 35, 39, 40.
/// All computations are deterministic and stateless.
class AvsCalculator {
  AvsCalculator._();

  /// Compute individual AVS monthly rente.
  ///
  /// Takes into account:
  /// - Contribution duration (lacunes, arrivalAge) — LAVS art. 29
  /// - Income level via RAMD proxy — LAVS art. 34, echelle 44
  /// - Early retirement penalty (6.8%/yr from 63) — LAVS art. 40
  /// - Deferral bonus (up to +31.5% at 70) — LAVS art. 39
  /// - Gender-aware reference age for AVS21 (LAVS art. 21 al. 1)
  /// - Divorce income splitting — LAVS art. 29quinquies
  /// - Child-raising credits (bonifications éducatives) — LAVS art. 29sexies
  ///
  /// [isFemale] and [birthYear] are optional — when provided, the
  /// reference age accounts for AVS21 transitional cohorts (women
  /// born 1961-1963). When omitted, defaults to 65 (male/unknown).
  static double computeMonthlyRente({
    required int currentAge,
    required int retirementAge,
    int lacunes = 0,
    int? anneesContribuees,
    int? arrivalAge,
    double grossAnnualSalary = 0,
    bool? isFemale,
    int? birthYear,
    bool isDivorced = false,
    double? exSpouseAnnualSalary,
    int marriageYears = 0,
    int childRaisingYears = 0,
    int totalContributionYears = avsDureeCotisationComplete,
  }) {
    // Determine gender-aware reference age (AVS21, LAVS art. 21 al. 1)
    final refAge = (isFemale != null && birthYear != null)
        ? avsReferenceAge(birthYear: birthYear, isFemale: isFemale)
        : reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();

    // 1. Contribution years
    final fullYears = reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();

    int currentYears;
    if (anneesContribuees != null) {
      currentYears = anneesContribuees;
    } else if (arrivalAge != null && arrivalAge > 20) {
      currentYears =
          (currentAge - arrivalAge).clamp(0, fullYears);
    } else {
      currentYears =
          (currentAge - 20).clamp(0, fullYears);
    }
    final futureYears = (retirementAge - currentAge).clamp(0, 50);
    final totalYears =
        (currentYears + futureYears).clamp(0, fullYears);
    final effectiveYears =
        (totalYears - lacunes).clamp(0, fullYears);
    final gapFactor = fullYears > 0 ? effectiveYears / fullYears : 0.0;

    // 2. Effective salary (RAMD) with divorce splitting + child credits
    double effectiveSalary = grossAnnualSalary;

    // 2a. Divorce income splitting (LAVS art. 29quinquies)
    // During marriage years, combined income is split 50/50.
    // Remaining years use individual salary.
    if (isDivorced &&
        exSpouseAnnualSalary != null &&
        marriageYears > 0) {
      final combinedDuringMarriage =
          (grossAnnualSalary + exSpouseAnnualSalary) / 2;
      final marriageRatio = marriageYears / totalContributionYears;
      final singleRatio = 1.0 - marriageRatio;
      effectiveSalary = (combinedDuringMarriage * marriageRatio) +
          (grossAnnualSalary * singleRatio);
    }

    // 2b. Child-raising credits / bonifications éducatives (LAVS art. 29sexies)
    // Annual credit = 3× minimum annual AVS pension.
    // Added to RAMD prorated over total contribution years.
    if (childRaisingYears > 0) {
      const bonificationAnnuelle = 3 * avsRenteMinMensuelle * 12;
      final bonificationRAMD =
          (bonificationAnnuelle * childRaisingYears) / totalContributionYears;
      effectiveSalary += bonificationRAMD;
      effectiveSalary = effectiveSalary.clamp(0, avsRAMDMax);
    }

    // 2c. RAMD-based rente (LAVS art. 34, echelle 44)
    final baseRente = renteFromRAMD(effectiveSalary);
    double rente = baseRente * gapFactor;

    // 3. Early/late retirement adjustments relative to gender-aware refAge
    if (retirementAge < 63) {
      // AVS anticipation only possible from 63 (LAVS art. 40)
      return 0.0;
    } else if (retirementAge < refAge) {
      final yearsEarly = refAge - retirementAge;
      rente *= (1.0 - reg('avs.anticipation_reduction', avsReductionAnticipation) * yearsEarly);
    } else if (retirementAge > refAge) {
      final yearsLate = (retirementAge - refAge).clamp(1, 5);
      final bonus = avsDeferralBonus[yearsLate] ?? avsDeferralBonus[5]!;
      rente *= (1.0 + bonus);
    }

    return rente;
  }

  /// Round to nearest 5 centimes (Swiss standard for social insurance amounts).
  /// OAVS art. 53 — applied at display level, not computation level,
  /// to avoid cascading rounding effects in couple/optimizer calculations.
  static double roundTo5Centimes(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  /// AVS rente based on RAMD using Echelle 44 (LAVS art. 34).
  ///
  /// Concave lookup + linear interpolation between table points.
  /// Source: Memento 6.01 — Tables des rentes AVS/AI (OFAS 2025).
  /// RAMD <= 0 → 0 (no salary data).
  /// RAMD <= 14'700 → 1'260/mois (minimum).
  /// RAMD >= 88'200 → 2'520/mois (maximum).
  /// Between table points: linear interpolation within the bracket.
  /// gapFactor in computeMonthlyRente already handles contribution years.
  static double renteFromRAMD(double grossAnnualSalary) {
    if (grossAnnualSalary <= 0) return 0;
    const table = avsEchelle44;
    if (grossAnnualSalary <= table.first[0]) return table.first[1];
    if (grossAnnualSalary >= table.last[0]) return table.last[1];
    for (int i = 0; i < table.length - 1; i++) {
      final lower = table[i];
      final upper = table[i + 1];
      if (grossAnnualSalary >= lower[0] && grossAnnualSalary <= upper[0]) {
        final ratio = (grossAnnualSalary - lower[0]) / (upper[0] - lower[0]);
        return lower[1] + ratio * (upper[1] - lower[1]);
      }
    }
    return table.last[1];
  }

  /// Couple AVS with married cap (LAVS art. 35).
  ///
  /// Married couples: total capped at 150% of individual max (3780 CHF).
  /// Concubins: each gets individual rente, no cap.
  static ({double user, double conjoint, double total}) computeCouple({
    required double avsUser,
    required double avsConjoint,
    required bool isMarried,
  }) {
    final total = avsUser + avsConjoint;
    final coupleMax = reg('avs.couple_max_monthly', avsRenteCoupleMaxMensuelle);
    if (isMarried && total > coupleMax) {
      final ratio = coupleMax / total;
      return (user: avsUser * ratio, conjoint: avsConjoint * ratio, total: coupleMax);
    }
    // No rounding on couple — rounding is applied on individual computeMonthlyRente()
    return (user: avsUser, conjoint: avsConjoint, total: total);
  }

  /// Bridge pension (rente-pont) estimate for early retirees.
  ///
  /// When retiring before the AVS reference age, there is an income gap
  /// where neither AVS nor LPP rente is paid. Some employers/caisses offer
  /// a bridge pension to cover this gap.
  ///
  /// Returns the estimated monthly gap and total bridge cost.
  /// - [retirementAge]: actual retirement age (e.g. 60)
  /// - [referenceAge]: AVS reference age (e.g. 65)
  /// - [estimatedAvsMonthly]: what the AVS rente would be at reference age
  /// - [estimatedLppMonthly]: what the LPP rente would be (if annuity chosen)
  static ({double monthlyGap, double totalBridgeCost, int gapYears}) computeBridgePension({
    required int retirementAge,
    required int referenceAge,
    required double estimatedAvsMonthly,
    double estimatedLppMonthly = 0,
  }) {
    final gapYears = (referenceAge - retirementAge).clamp(0, 10);
    if (gapYears <= 0) {
      return (monthlyGap: 0, totalBridgeCost: 0, gapYears: 0);
    }
    // During the gap: no AVS, potentially no LPP rente either
    final monthlyGap = estimatedAvsMonthly + estimatedLppMonthly;
    final totalBridgeCost = monthlyGap * 12 * gapYears;
    return (
      monthlyGap: monthlyGap,
      totalBridgeCost: totalBridgeCost,
      gapYears: gapYears,
    );
  }

  /// Convert monthly AVS rente to annual, including the 13th rente if active.
  ///
  /// From December 2026 onwards, AVS pays 13 monthly rentes per year
  /// instead of 12 (initiative populaire, LAVS art. 34 nouveau).
  ///
  /// The 13th rente applies ONLY to vieillesse pensions, NOT to AI,
  /// survivors, or children's pensions.
  ///
  /// [monthlyRente] — individual monthly pension (output of computeMonthlyRente).
  /// [include13eme] — override: false to get the traditional 12-month total.
  static double annualRente(
    double monthlyRente, {
    bool include13eme = avs13emeRenteActive,
  }) {
    if (include13eme) {
      return monthlyRente * avsNombreRentesParAn;
    }
    return monthlyRente * 12;
  }

  /// Returns the AVS rente reduction percentage for a given gap in contribution years.
  ///
  /// Example: gap=4 → 9.09% reduction (4/44 × 100).
  /// Use this instead of inline `gap / 44 * 100` calculations.
  static double reductionPercentageFromGap(int gap) {
    if (gap <= 0) return 0.0;
    final fullYears = reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();
    return (gap / fullYears * 100);
  }

  /// Returns the estimated monthly AVS rente loss for a given gap.
  ///
  /// Example: gap=4 → ~229 CHF/mois (2520 × 4/44).
  /// Use this instead of inline `2520 * gap / 44` calculations.
  static double monthlyLossFromGap(int gap) {
    if (gap <= 0) return 0.0;
    final renteMax = reg('avs.max_monthly_pension', avsRenteMaxMensuelle);
    final fullYears = reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();
    return renteMax * gap / fullYears;
  }
}
