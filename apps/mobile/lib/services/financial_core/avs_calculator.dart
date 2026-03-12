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
  static double computeMonthlyRente({
    required int currentAge,
    required int retirementAge,
    int lacunes = 0,
    int? anneesContribuees,
    int? arrivalAge,
    double grossAnnualSalary = 0,
  }) {
    // 1. Contribution years
    int currentYears;
    if (anneesContribuees != null) {
      currentYears = anneesContribuees;
    } else if (arrivalAge != null && arrivalAge > 20) {
      currentYears =
          (currentAge - arrivalAge).clamp(0, avsDureeCotisationComplete);
    } else {
      currentYears =
          (currentAge - 20).clamp(0, avsDureeCotisationComplete);
    }
    final futureYears = (retirementAge - currentAge).clamp(0, 50);
    final totalYears =
        (currentYears + futureYears).clamp(0, avsDureeCotisationComplete);
    final effectiveYears =
        (totalYears - lacunes).clamp(0, avsDureeCotisationComplete);
    final gapFactor = effectiveYears / avsDureeCotisationComplete;

    // 2. RAMD-based rente (LAVS art. 34, echelle 44)
    final baseRente = renteFromRAMD(grossAnnualSalary);
    double rente = baseRente * gapFactor;

    // 3. Early/late retirement adjustments
    if (retirementAge < 63) {
      // AVS anticipation only possible from 63 (LAVS art. 40)
      return 0.0;
    } else if (retirementAge < 65) {
      final yearsEarly = 65 - retirementAge;
      rente *= (1.0 - avsReductionAnticipation * yearsEarly);
    } else if (retirementAge > 65) {
      final yearsLate = (retirementAge - 65).clamp(1, 5);
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
    if (grossAnnualSalary >= avsRAMDMax) return avsRenteMaxMensuelle;
    if (grossAnnualSalary <= avsRAMDMin) return avsRenteMinMensuelle;
    final fraction =
        (grossAnnualSalary - avsRAMDMin) / (avsRAMDMax - avsRAMDMin);
    return avsRenteMinMensuelle +
        (avsRenteMaxMensuelle - avsRenteMinMensuelle) * fraction;
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
    if (isMarried && total > avsRenteCoupleMaxMensuelle) {
      final ratio = avsRenteCoupleMaxMensuelle / total;
      return (
        user: avsUser * ratio,
        conjoint: avsConjoint * ratio,
        total: avsRenteCoupleMaxMensuelle,
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
    return (gap / avsDureeCotisationComplete * 100);
  }

  /// Returns the estimated monthly AVS rente loss for a given gap.
  ///
  /// Example: gap=4 → ~229 CHF/mois (2520 × 4/44).
  /// Use this instead of inline `2520 * gap / 44` calculations.
  static double monthlyLossFromGap(int gap) {
    if (gap <= 0) return 0.0;
    return avsRenteMaxMensuelle * gap / avsDureeCotisationComplete;
  }
}
