import 'package:mint_mobile/constants/social_insurance.dart';

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
    final gapFactor = effectiveYears / fullYears;

    // 2. RAMD-based rente (LAVS art. 34, echelle 44)
    final baseRente = renteFromRAMD(grossAnnualSalary);
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

  /// AVS rente based on RAMD (LAVS art. 34, echelle 44).
  ///
  /// Linear interpolation between min and max rente.
  /// RAMD <= 14'700 → 1'260/mois (minimum)
  /// RAMD >= 88'200 → 2'520/mois (maximum)
  /// No data (0) → return 0 (cannot estimate rente without salary data).
  /// gapFactor in computeMonthlyRente already handles contribution years.
  static double renteFromRAMD(double grossAnnualSalary) {
    if (grossAnnualSalary <= 0) return 0.0;
    final ramdMax = reg('avs.ramd_max', avsRAMDMax);
    final ramdMin = reg('avs.ramd_min', avsRAMDMin);
    final renteMax = reg('avs.max_monthly_pension', avsRenteMaxMensuelle);
    final renteMin = reg('avs.min_monthly_pension', avsRenteMinMensuelle);
    if (grossAnnualSalary >= ramdMax) return renteMax;
    if (grossAnnualSalary <= ramdMin) return renteMin;
    final fraction =
        (grossAnnualSalary - ramdMin) / (ramdMax - ramdMin);
    return renteMin + (renteMax - renteMin) * fraction;
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
      return (
        user: avsUser * ratio,
        conjoint: avsConjoint * ratio,
        total: coupleMax,
      );
    }
    return (user: avsUser, conjoint: avsConjoint, total: total);
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
