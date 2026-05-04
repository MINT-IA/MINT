import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT SERVICE — Sprint S21 / Retraite complete
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for Swiss retirement planning:
//   1. compareLpp     — LPP capital vs rente comparison
//   2. calculateBudget — Retirement budget reconciliation
//
// All constants match 2025/2026 legislation.
// No banned terms ("garanti", "certain", "assure", "sans risque").
// ────────────────────────────────────────────────────────────

class RetirementService {
  RetirementService._();

  // All constants delegated to social_insurance.dart.
  // Kept as static getters for backward compatibility with callers
  // using RetirementService.avsMaxRenteAnnuelle etc.
  /// 12-month annual maximum — kept for backward compatibility with
  /// legacy callers. Prefer [avsMaxRenteAnnuelleForYear] or the 13m
  /// variant for retirement-year-aware projections (AVS13 effective
  /// from 2026).
  static double get avsMaxRenteAnnuelle => reg('avs.max_annual_pension', avsRenteMaxAnnuelle);

  /// Year-aware AVS annual maximum — returns the 13-month figure
  /// (32'760) for years >= avs13emeRenteAnneeDebut (2026), otherwise
  /// the legacy 12-month cap (30'240). Use this for any projection
  /// that reports annual income at retirement.
  static double avsMaxRenteAnnuelleForYear(int year) {
    final base = avsMaxAnnualRenteForYear(year);
    // Respect backend overrides via the regulatory registry.
    return reg('avs.max_annual_pension_${year >= avs13emeRenteAnneeDebut ? "13m" : "12m"}', base);
  }
  static double get avsCoupleFactor => 1.50;
  static int get avsRetirementAge => reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
  static double get avsAnticipationPenaltyPerYear => reg('avs.early_retirement_reduction', avsReductionAnticipation);
  static int get maxContributionYears => reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();
  /// Minimum legal conversion rate — obligatoire part only (LPP art. 14).
  /// For full capital projections, use blended oblig/suroblig rates.
  static double get lppConversionRate => reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal);
  static Map<String, String> get cantonNames => cantonFullNames;

  /// Sorted canton codes (alphabetical). Delegates to social_insurance.dart.
  // Note: named differently to avoid shadowing top-level sortedCantonCodes.
  static List<String> get allCantonCodes => sortedCantonCodes;

  // ════════════════════════════════════════════════════════════
  //  1. LPP CAPITAL VS RENTE
  // ════════════════════════════════════════════════════════════

  /// Compare LPP capital vs rente withdrawal options.
  ///
  /// Note: applies [lppConversionRate] (6.8% minimum legal, part obligatoire)
  /// on the full capital. For profiles with a certificate showing
  /// oblig/suroblig split, callers should use the blended rate from
  /// ForecasterService instead. This is a simplified educational comparison.
  static Map<String, dynamic> compareLpp({
    required double capitalLpp,
    double? conversionRate,
    String canton = 'ZH',
    int ageRetraite = avsAgeReferenceHomme,
    int esperanceVie = 87,
  }) {
    // Rente — use provided blended rate or minimum legal fallback
    final effectiveRate = conversionRate ?? lppConversionRate;
    final renteAnnuelle = capitalLpp * effectiveRate;
    final renteMensuelle = renteAnnuelle / 12;

    // Capital tax
    final taux = tauxImpotRetraitCapital[canton.toUpperCase()] ?? 0.065;
    final impot = RetirementTaxCalculator.progressiveTax(capitalLpp, taux);
    final capitalNet = capitalLpp - impot;

    // Breakeven
    final duree = esperanceVie - ageRetraite;
    int breakeven = ageRetraite;
    double cumul = 0;
    if (duree > 0 && renteAnnuelle > 0) {
      for (int y = 0; y <= duree; y++) {
        cumul += renteAnnuelle;
        if (cumul >= capitalNet) {
          breakeven = ageRetraite + y;
          break;
        }
      }
    }

    return {
      'capitalTotal': capitalLpp,
      'renteMensuelle': renteMensuelle,
      'renteAnnuelle': renteAnnuelle,
      'capitalBrut': capitalLpp,
      'capitalImpot': impot,
      'capitalNet': capitalNet,
      'breakevenAge': breakeven,
      'tauxImpot': taux,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  2. RETIREMENT BUDGET
  // ════════════════════════════════════════════════════════════

  /// Retirement budget reconciliation.
  static Map<String, dynamic> calculateBudget({
    required double avsMensuel,
    required double lppMensuel,
    double capital3aNet = 0,
    double autresRevenus = 0,
    required double depensesMensuelles,
    required double revenuPreRetraite,
    bool isCouple = false,
  }) {
    final totalRevenus =
        avsMensuel + lppMensuel + (capital3aNet / (20 * 12)) + autresRevenus;
    final solde = totalRevenus - depensesMensuelles;
    final tauxRemplacement = revenuPreRetraite > 0
        ? (totalRevenus / revenuPreRetraite * 100)
        : 0.0;

    final pcSeuil = isCouple ? 4500.0 : 3000.0;
    final pcEligible = totalRevenus < pcSeuil;

    final duree3a = (depensesMensuelles > 0 && capital3aNet > 0)
        ? capital3aNet / (depensesMensuelles * 12)
        : 0.0;

    final alertes = <String>[];
    if (solde < 0) {
      alertes.add(
          'Deficit mensuel de ${formatChfWithPrefix(solde.abs())}');
    }
    if (tauxRemplacement < 60) {
      alertes.add(
          'Taux de remplacement de ${tauxRemplacement.toStringAsFixed(0)}% — en dessous du minimum (60%)');
    }
    if (pcEligible) {
      alertes.add(
          'Tu pourrais etre eligible aux PC. Contacte ton office cantonal.');
    }

    return {
      'totalRevenus': totalRevenus,
      'depenses': depensesMensuelles,
      'solde': solde,
      'tauxRemplacement': tauxRemplacement,
      'pcEligible': pcEligible,
      'duree3aAns': duree3a,
      'alertes': alertes,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe separators.
  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return '${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }
}
