import 'dart:math' show max;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

// ── FRI computation defaults ────────────────────────────────────
// Values documented here for traceability. When real data is available
// from LPP certificates, these defaults are not used.

/// Fallback monthly expense ratio when no depenses data is available.
/// Applied to gross monthly salary (not net). Approximate.
const double kFriDefaultExpenseRatioGross = 0.85;

/// Conservative disability gap ratio when no LPP certificate data.
/// LPP AI covers ~40-60% of insured salary; gap ≈ 30%.
const double kFriDefaultDisabilityGapRatio = 0.30;

/// Conservative death protection gap ratio without certificate data.
const double kFriDefaultDeathProtectionGapRatio = 0.40;

/// FINMA theoretical mortgage rate (Tragbarkeitsrechnung).
/// Source: FINMA circular 2008/21, ASB guidelines.
const double kFriMortgageTauxTheorique = 0.05;

/// Annual mortgage amortization rate (ASB standard: 1%/year).
const double kFriMortgageAmortissementRate = 0.01;

/// Annual accessory costs rate on property value (ASB standard: 1%/year).
const double kFriMortgageFraisAccessoires = 0.01;

/// Employer dependency ratio for salaried workers.
const double kFriEmployerDependencySalarie = 0.9;

/// Employer dependency ratio for non-salaried workers.
const double kFriEmployerDependencyAutre = 0.5;

// ────────────────────────────────────────────────────────────
//  FRI COMPUTATION SERVICE — Phase 5 fix (CRIT-3)
// ────────────────────────────────────────────────────────────
//
// Bridges CoachProfile + ProjectionResult → FriInput → FriCalculator.
//
// Populates FriInput from real financial data:
//   L: liquid assets vs monthly costs
//   F: actual 3a, rachat LPP, amort indirect
//   R: replacement ratio from ForecasterService
//   S: disability gap, mortgage stress, concentration
//
// FRI ≠ FFS. FRI measures financial resilience (structural).
// FFS measures behavioral adherence (habits, check-ins).
// They are complementary, not interchangeable.
//
// Sources: LAVS art. 21-29, LPP art. 14-16, LIFD art. 38,
//          FINMA circ. 2008/21.
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

/// Service to compute FRI from CoachProfile + ProjectionResult.
class FriComputationService {
  FriComputationService._();

  /// Compute FRI breakdown from real financial data.
  ///
  /// [profile]: CoachProfile with financial data.
  /// [projection]: ForecasterService projection result.
  /// [confidenceScore]: projection confidence (0-100).
  static FriBreakdown compute({
    required CoachProfile profile,
    required ProjectionResult projection,
    double confidenceScore = 0,
  }) {
    final input = _buildInput(profile, projection);
    return FriCalculator.compute(input, confidenceScore: confidenceScore);
  }

  /// Build FriInput from real CoachProfile data.
  static FriInput _buildInput(
    CoachProfile profile,
    ProjectionResult projection,
  ) {
    // ── L: Liquidity ─────────────────────────────────
    final liquidAssets = profile.patrimoine.epargneLiquide;
    final monthlyGross = profile.salaireBrutMensuel;
    // Approximate monthly fixed costs from depenses or estimated from gross
    final monthlyFixedCosts = profile.depenses.totalMensuel > 0
        ? profile.depenses.totalMensuel
        : monthlyGross * kFriDefaultExpenseRatioGross;
    final totalDebt = profile.dettes.totalDettes;
    final annualIncome = monthlyGross * profile.nombreDeMois;
    final shortTermDebtRatio =
        annualIncome > 0 ? totalDebt / annualIncome : 0.0;
    final incomeVolatility = profile.employmentStatus == 'independant'
        ? 'high'
        : profile.employmentStatus == 'chomage'
            ? 'high'
            : 'low';

    // ── F: Fiscal efficiency ─────────────────────────
    // 3a: sum of planned 3a contributions (annualized)
    final actual3a = profile.total3aMensuel * 12;
    final isIndependantNoLpp =
        profile.employmentStatus == 'independant' &&
            (profile.prevoyance.avoirLppTotal ?? 0) <= 0;
    final max3a = isIndependantNoLpp ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;
    // Rachat: use rachatMaximum (total buyback gap) and rachatEffectue
    final potentielRachat = profile.prevoyance.rachatMaximum ?? 0.0;
    final rachatEffectue = profile.prevoyance.rachatEffectue ?? 0.0;
    // Marginal tax rate from centralized RetirementTaxCalculator
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final tauxMarginal = RetirementTaxCalculator.estimateMarginalRate(
      monthlyGross * profile.nombreDeMois,
      profile.canton,
      isMarried: isMarried,
      children: profile.nombreEnfants,
    );
    final isPropertyOwner =
        (profile.patrimoine.immobilier ?? 0) > 0 ||
            (profile.patrimoine.propertyMarketValue ?? 0) > 0;
    // Amort indirect: approximated from 3a contributions if property owner
    // (real data would come from mortgage advisor documents)
    final amortIndirect =
        isPropertyOwner && actual3a > 0 ? actual3a : 0.0;

    // ── R: Retirement readiness ──────────────────────
    final replacementRatio = projection.tauxRemplacementBase;

    // ── S: Structural risk ───────────────────────────
    // Disability gap: estimated from LPP coverage vs income.
    // LPP AI covers ~40-60% of insured salary. Without detailed
    // certificate data, use conservative 30% gap default.
    const disabilityGapRatio = kFriDefaultDisabilityGapRatio;
    final hasDependents = profile.nombreEnfants > 0 ||
        profile.etatCivil == CoachCivilStatus.marie;
    // Death protection gap: similar conservative default.
    // Real value would come from LPP certificate parsing.
    const deathProtectionGapRatio = kFriDefaultDeathProtectionGapRatio;
    // Mortgage stress = mortgage payments / gross income
    final mortgageBalance =
        profile.patrimoine.mortgageBalance ?? 0;
    final mortgageRate = profile.patrimoine.mortgageRate ?? kFriMortgageTauxTheorique;
    final propertyValue =
        profile.patrimoine.propertyMarketValue ?? 0;
    final annualMortgageCost = mortgageBalance * mortgageRate +
        mortgageBalance * kFriMortgageAmortissementRate + // amortissement 1%
        propertyValue * kFriMortgageFraisAccessoires; // frais accessoires 1%
    final mortgageStressRatio =
        annualIncome > 0 ? annualMortgageCost / annualIncome : 0.0;
    // Concentration: largest single asset / total patrimoine
    final totalPatrimoine = profile.patrimoine.totalPatrimoine;
    final largestAsset = [
      profile.patrimoine.epargneLiquide,
      profile.patrimoine.investissements,
      profile.patrimoine.immobilier ?? 0,
    ].reduce(max);
    final concentrationRatio =
        totalPatrimoine > 0 ? largestAsset / totalPatrimoine : 0.0;
    // Employer dependency: salary as % of total income (simplified at 1.0 for salariés)
    final employerDependencyRatio =
        profile.employmentStatus == 'salarie' ? kFriEmployerDependencySalarie : kFriEmployerDependencyAutre;

    return FriInput(
      liquidAssets: liquidAssets,
      monthlyFixedCosts: monthlyFixedCosts,
      shortTermDebtRatio: shortTermDebtRatio,
      incomeVolatility: incomeVolatility,
      actual3a: actual3a,
      max3a: max3a,
      potentielRachatLpp: potentielRachat,
      rachatEffectue: rachatEffectue,
      tauxMarginal: tauxMarginal,
      isPropertyOwner: isPropertyOwner,
      amortIndirect: amortIndirect,
      replacementRatio: replacementRatio,
      disabilityGapRatio: disabilityGapRatio,
      hasDependents: hasDependents,
      deathProtectionGapRatio: deathProtectionGapRatio,
      mortgageStressRatio: mortgageStressRatio,
      concentrationRatio: concentrationRatio,
      employerDependencyRatio: employerDependencyRatio,
      archetype: detectArchetype(profile),
      age: profile.age,
      canton: profile.canton,
    );
  }

  /// EU/EFTA country codes for bilateral convention detection.
  static const _euEftaCodes = <String>{
    'de', 'fr', 'it', 'at', 'be', 'bg', 'hr', 'cy', 'cz', 'dk', 'ee',
    'fi', 'gr', 'hu', 'ie', 'lv', 'lt', 'lu', 'mt', 'nl', 'pl', 'pt',
    'ro', 'sk', 'si', 'es', 'se', // EU-27
    'is', 'li', 'no', // EFTA (hors CH)
    'uk', 'gb', // UK: conventions bilaterales maintenues post-Brexit
  };

  /// Detect archetype from CoachProfile fields.
  /// See ADR-20260223-archetype-driven-retirement.md.
  /// All 8 archetypes from CLAUDE.md are handled.
  static String detectArchetype(CoachProfile profile) {
    final nat = profile.nationality?.toLowerCase() ?? '';
    final emp = profile.employmentStatus;
    final permit = profile.residencePermit?.toUpperCase() ?? '';

    // 1. Independent (check first — overrides nationality)
    if (emp == 'independant') {
      return (profile.prevoyance.avoirLppTotal ?? 0) > 0
          ? 'independent_with_lpp'
          : 'independent_no_lpp';
    }

    // 2. Cross-border (permit G)
    if (permit == 'G') return 'cross_border';

    // 3. US/FATCA
    if (nat == 'us' || nat == 'usa') return 'expat_us';

    // 4. Swiss national
    if (nat == 'ch' || nat == 'suisse' || nat == 'schweiz') {
      // Returning Swiss: CH national who lived abroad (arrivalAge set + libre passage)
      if (profile.arrivalAge != null && profile.arrivalAge! > 20) {
        return 'returning_swiss';
      }
      return 'swiss_native';
    }

    // 5. Foreign national with late arrival
    if (profile.arrivalAge != null && profile.arrivalAge! > 20) {
      // EU/EFTA → bilateral conventions apply (totalisation periods)
      if (_euEftaCodes.contains(nat)) {
        return 'expat_eu';
      }
      // Non-EU → no bilateral convention
      return 'expat_non_eu';
    }

    // 6. Foreign national arrived young (< 20) → treated as swiss_native
    return 'swiss_native';
  }

}
