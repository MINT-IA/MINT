import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT SERVICE — Sprint S21 / Retraite complete
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for Swiss retirement planning:
//   1. estimateAvs    — AVS pension estimate (LAVS art. 21-29)
//   2. compareLpp     — LPP capital vs rente comparison
//   3. calculateBudget — Retirement budget reconciliation
//
// All constants match 2025/2026 legislation.
// No banned terms ("garanti", "certain", "assure", "sans risque").
// ────────────────────────────────────────────────────────────

class RetirementService {
  RetirementService._();

  // All constants delegated to social_insurance.dart.
  // Kept as static getters for backward compatibility with callers
  // using RetirementService.avsMaxRenteAnnuelle etc.
  static double get avsMaxRenteAnnuelle => avsRenteMaxAnnuelle;
  static double get avsCoupleFactor => 1.50;
  static int get avsRetirementAge => avsAgeReferenceHomme;
  static double get avsAnticipationPenaltyPerYear => avsReductionAnticipation;
  static int get maxContributionYears => avsDureeCotisationComplete;
  /// Minimum legal conversion rate — obligatoire part only (LPP art. 14).
  /// For full capital projections, use blended oblig/suroblig rates.
  static double get lppConversionRate => lppTauxConversionMinDecimal;
  static Map<String, String> get cantonNames => cantonFullNames;

  /// Sorted canton codes (alphabetical). Delegates to social_insurance.dart.
  // Note: named differently to avoid shadowing top-level sortedCantonCodes.
  static List<String> get allCantonCodes => sortedCantonCodes;

  // ════════════════════════════════════════════════════════════
  //  1. AVS ESTIMATE
  // ════════════════════════════════════════════════════════════

  /// Estimate AVS retirement pension.
  ///
  /// Returns a map with scenario, rente, adjustment factor, etc.
  ///
  /// **DEPRECATED**: Use `AvsCalculator.computeMonthlyRente()` from financial_core
  /// for accurate RAMD-scaled rente estimation. This simplified method uses
  /// `avsRenteMaxMensuelle * gapFactor` which does not account for RAMD scaling.
  /// TODO: Migrate retirement_screen.dart consumers then delete this method.
  @Deprecated('Use AvsCalculator.computeMonthlyRente() from financial_core')
  static Map<String, dynamic> estimateAvs({
    required int ageActuel,
    int ageRetraite = 65,
    bool isCouple = false,
    int anneesLacunes = 0,
    int esperanceVie = 87,
  }) {
    // Determine scenario
    String scenario;
    double factor;
    double penalitePct;

    if (ageRetraite < avsRetirementAge) {
      scenario = 'anticipation';
      final yearsEarly = avsRetirementAge - ageRetraite;
      factor = 1.0 - (avsAnticipationPenaltyPerYear * yearsEarly);
      penalitePct = -(avsAnticipationPenaltyPerYear * yearsEarly * 100);
    } else if (ageRetraite > avsRetirementAge) {
      scenario = 'ajournement';
      final yearsLate = (ageRetraite - avsRetirementAge).clamp(1, 5);
      factor = 1.0 + (avsDeferralBonus[yearsLate] ?? avsDeferralBonus[5]!);
      penalitePct =
          (avsDeferralBonus[yearsLate] ?? avsDeferralBonus[5]!) * 100;
    } else {
      scenario = 'normal';
      factor = 1.0;
      penalitePct = 0.0;
    }

    // Gap reduction
    final effectiveYears = maxContributionYears - anneesLacunes;
    final gapFactor =
        effectiveYears > 0 ? effectiveYears / maxContributionYears : 0.0;

    // Calculate rente
    final baseRente = avsRenteMaxMensuelle * gapFactor;
    final renteMensuelle = baseRente * factor;
    final renteAnnuelle = AvsCalculator.annualRente(renteMensuelle);

    // Couple
    double? renteCouple;
    if (isCouple) {
      renteCouple = min(
        renteMensuelle * 2,
        avsRenteMaxMensuelle * avsCoupleFactor,
      );
    }

    // Projection
    final duree = esperanceVie - ageRetraite;
    final totalCumule = renteAnnuelle * duree;

    return {
      'scenario': scenario,
      'ageDepart': ageRetraite,
      'renteMensuelle': renteMensuelle,
      'renteAnnuelle': renteAnnuelle,
      'facteurAjustement': factor,
      'penaliteOuBonusPct': penalitePct,
      'renteCoupleMensuelle': renteCouple,
      'dureeEstimeeAns': duree,
      'totalCumule': totalCumule,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  2. LPP CAPITAL VS RENTE
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
    int ageRetraite = 65,
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
  //  3. RETIREMENT BUDGET
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
          'Deficit mensuel de CHF ${solde.abs().toStringAsFixed(0)}');
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
