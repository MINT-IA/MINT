import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';

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

  // ════════════════════════════════════════════════════════════
  //  AVS CONSTANTS (LAVS art. 21-29, 2025/2026)
  // ════════════════════════════════════════════════════════════

  /// Maximum AVS annual pension (single person).
  static const double avsMaxRenteAnnuelle = 30240.0;

  /// Couple plafond factor (150% of single max).
  static const double avsCoupleFactor = 1.50;

  /// Reference retirement age.
  static const int avsRetirementAge = 65;

  /// Anticipation penalty per year (6.8%/yr).
  static const double avsAnticipationPenaltyPerYear = 0.068;

  /// Deferral bonus by number of years (1-5).
  static const Map<int, double> avsDeferralBonus = {
    1: 0.052,
    2: 0.108,
    3: 0.171,
    4: 0.240,
    5: 0.315,
  };

  /// Maximum contribution years for full AVS pension.
  static const int maxContributionYears = 44;

  // ════════════════════════════════════════════════════════════
  //  LPP CONSTANTS (LPP art. 14)
  // ════════════════════════════════════════════════════════════

  /// Minimum legal conversion rate (6.8%).
  static const double lppConversionRate = 0.068;

  // ════════════════════════════════════════════════════════════
  //  CAPITAL WITHDRAWAL TAX BY CANTON
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> tauxImpotRetraitCapital = {
    'ZH': 0.065,
    'BE': 0.075,
    'LU': 0.055,
    'UR': 0.050,
    'SZ': 0.040,
    'OW': 0.045,
    'NW': 0.040,
    'GL': 0.055,
    'ZG': 0.035,
    'FR': 0.070,
    'SO': 0.065,
    'BS': 0.075,
    'BL': 0.065,
    'SH': 0.060,
    'AR': 0.055,
    'AI': 0.045,
    'SG': 0.060,
    'GR': 0.055,
    'AG': 0.060,
    'TG': 0.055,
    'TI': 0.065,
    'VD': 0.080,
    'VS': 0.060,
    'NE': 0.070,
    'GE': 0.075,
    'JU': 0.065,
  };

  /// Canton full names (French).
  static const Map<String, String> cantonNames = {
    'ZH': 'Zurich',
    'BE': 'Berne',
    'LU': 'Lucerne',
    'UR': 'Uri',
    'SZ': 'Schwyz',
    'OW': 'Obwald',
    'NW': 'Nidwald',
    'GL': 'Glaris',
    'ZG': 'Zoug',
    'FR': 'Fribourg',
    'SO': 'Soleure',
    'BS': 'Bale-Ville',
    'BL': 'Bale-Campagne',
    'SH': 'Schaffhouse',
    'AR': 'Appenzell RE',
    'AI': 'Appenzell RI',
    'SG': 'Saint-Gall',
    'GR': 'Grisons',
    'AG': 'Argovie',
    'TG': 'Thurgovie',
    'TI': 'Tessin',
    'VD': 'Vaud',
    'VS': 'Valais',
    'NE': 'Neuchatel',
    'GE': 'Geneve',
    'JU': 'Jura',
  };

  /// Sorted canton codes (alphabetical).
  static List<String> get sortedCantonCodes {
    final codes = cantonNames.keys.toList()..sort();
    return codes;
  }

  // ════════════════════════════════════════════════════════════
  //  1. AVS ESTIMATE
  // ════════════════════════════════════════════════════════════

  /// Estimate AVS retirement pension.
  ///
  /// Returns a map with scenario, rente, adjustment factor, etc.
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
    final renteAnnuelle = renteMensuelle * 12;

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
  static Map<String, dynamic> compareLpp({
    required double capitalLpp,
    String canton = 'ZH',
    int ageRetraite = 65,
    int esperanceVie = 87,
  }) {
    // Rente
    final renteAnnuelle = capitalLpp * lppConversionRate;
    final renteMensuelle = renteAnnuelle / 12;

    // Capital tax
    final taux = tauxImpotRetraitCapital[canton.toUpperCase()] ?? 0.065;
    final impot = _calculateProgressiveTax(capitalLpp, taux);
    final capitalNet = capitalLpp - impot;

    // Breakeven
    final duree = esperanceVie - ageRetraite;
    int breakeven = ageRetraite;
    double cumul = 0;
    for (int y = 0; y <= duree; y++) {
      cumul += renteAnnuelle;
      if (cumul >= capitalNet) {
        breakeven = ageRetraite + y;
        break;
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
  //  PROGRESSIVE TAX CALCULATION
  // ════════════════════════════════════════════════════════════

  static double _calculateProgressiveTax(double montant, double baseRate) {
    if (montant <= 0) return 0.0;
    const brackets = [
      [0, 100000, 1.0],
      [100000, 200000, 1.15],
      [200000, 500000, 1.30],
      [500000, 1000000, 1.50],
    ];
    const lastMultiplier = 1.70;

    double totalTax = 0;
    double remaining = montant;
    for (final bracket in brackets) {
      final tranche = bracket[1] - bracket[0];
      final taxable = remaining < tranche ? remaining : tranche;
      if (taxable <= 0) break;
      totalTax += taxable * baseRate * bracket[2];
      remaining -= taxable;
    }
    if (remaining > 0) {
      totalTax += remaining * baseRate * lastMultiplier;
    }
    return totalTax;
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
