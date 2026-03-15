import 'dart:math';
import 'package:mint_mobile/data/commune_data.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  FISCAL SERVICE — Sprint S20 / Comparateur 26 cantons
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for cantonal tax comparison:
//   1. estimateTax        — Estimate tax for one canton
//   2. compareAllCantons  — Rank all 26 cantons
//   3. simulateMove       — Compare two cantons (move scenario)
//
// Effective rates = total charge / gross income (chef-lieu, 2024-2026).
// These are simplified estimates, NOT exact tax calculations.
// No banned terms ("garanti", "certain", "assuré", "sans risque").
// ────────────────────────────────────────────────────────────

class FiscalService {
  FiscalService._();

  // ════════════════════════════════════════════════════════════
  //  EFFECTIVE TAX RATES — single, 100k income, chef-lieu
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> effectiveRates100kSingle = {
    'ZG': 0.0823,
    'NW': 0.0891,
    'OW': 0.0934,
    'AI': 0.0956,
    'AR': 0.1012,
    'SZ': 0.1034,
    'UR': 0.1067,
    'LU': 0.1089,
    'GL': 0.1102,
    'TG': 0.1145,
    'SH': 0.1167,
    'AG': 0.1189,
    'GR': 0.1203,
    'BL': 0.1256,
    'SG': 0.1278,
    'ZH': 0.1290,
    'FR': 0.1312,
    'SO': 0.1334,
    'TI': 0.1356,
    'BE': 0.1389,
    'NE': 0.1423,
    'VS': 0.1456,
    'VD': 0.1489,
    'JU': 0.1512,
    'GE': 0.1545,
    'BS': 0.1578,
  };

  // ════════════════════════════════════════════════════════════
  //  CANTON NAMES (i18n via ARB)
  // ════════════════════════════════════════════════════════════

  /// Internal fallback map (used when no [S] is available).
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
    'BS': 'Bâle-Ville',
    'BL': 'Bâle-Campagne',
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
    'NE': 'Neuchâtel',
    'GE': 'Genève',
    'JU': 'Jura',
  };

  /// Localized canton name via ARB. Falls back to [cantonNames] if unknown code.
  static String getCantonName(S s, String code) {
    switch (code) {
      case 'ZH': return s.fiscalServiceCantonZH;
      case 'BE': return s.fiscalServiceCantonBE;
      case 'LU': return s.fiscalServiceCantonLU;
      case 'UR': return s.fiscalServiceCantonUR;
      case 'SZ': return s.fiscalServiceCantonSZ;
      case 'OW': return s.fiscalServiceCantonOW;
      case 'NW': return s.fiscalServiceCantonNW;
      case 'GL': return s.fiscalServiceCantonGL;
      case 'ZG': return s.fiscalServiceCantonZG;
      case 'FR': return s.fiscalServiceCantonFR;
      case 'SO': return s.fiscalServiceCantonSO;
      case 'BS': return s.fiscalServiceCantonBS;
      case 'BL': return s.fiscalServiceCantonBL;
      case 'SH': return s.fiscalServiceCantonSH;
      case 'AR': return s.fiscalServiceCantonAR;
      case 'AI': return s.fiscalServiceCantonAI;
      case 'SG': return s.fiscalServiceCantonSG;
      case 'GR': return s.fiscalServiceCantonGR;
      case 'AG': return s.fiscalServiceCantonAG;
      case 'TG': return s.fiscalServiceCantonTG;
      case 'TI': return s.fiscalServiceCantonTI;
      case 'VD': return s.fiscalServiceCantonVD;
      case 'VS': return s.fiscalServiceCantonVS;
      case 'NE': return s.fiscalServiceCantonNE;
      case 'GE': return s.fiscalServiceCantonGE;
      case 'JU': return s.fiscalServiceCantonJU;
      default: return cantonNames[code] ?? code;
    }
  }

  /// Returns all 26 canton names localized via [S].
  static Map<String, String> getCantonNames(S s) {
    return {
      for (final code in cantonNames.keys) code: getCantonName(s, code),
    };
  }

  // ════════════════════════════════════════════════════════════
  //  INCOME ADJUSTMENT FACTORS (relative to 100k base)
  // ════════════════════════════════════════════════════════════

  static const Map<int, double> _incomeAdjustments = {
    50000: 0.75,
    80000: 0.90,
    100000: 1.00,
    150000: 1.10,
    200000: 1.18,
    300000: 1.25,
    500000: 1.32,
  };

  // ════════════════════════════════════════════════════════════
  //  FAMILY ADJUSTMENTS
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> _familyAdjustments = {
    'celibataire_0': 1.00,
    'marie_0': 0.85,
    'marie_1': 0.78,
    'marie_2': 0.72,
    'marie_3': 0.66,
  };

  // ════════════════════════════════════════════════════════════
  //  NATIONAL AVERAGE (for comparison gauge)
  // ════════════════════════════════════════════════════════════

  static const double nationalAverageRate100k = 0.1250;

  // ════════════════════════════════════════════════════════════
  //  1. ESTIMATE TAX
  // ════════════════════════════════════════════════════════════

  /// Estimate tax for a profile in a specific canton.
  ///
  /// Returns a map with: canton, cantonNom, revenuImposable,
  /// impotFederal, impotCantonalCommunal, chargeTotale, tauxEffectif.
  /// When [commune] is provided, adjusts the cantonal+communal portion
  /// using the commune multiplier vs chef-lieu multiplier ratio.
  static Map<String, dynamic> estimateTax({
    required double revenuBrut,
    required String canton,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
    String? commune,
  }) {
    final baseRate = effectiveRates100kSingle[canton] ?? 0.13;
    final incomeAdj = _interpolateIncomeAdjustment(revenuBrut);
    final familyKey = '${etatCivil}_${min(nombreEnfants, 3)}';
    final familyAdj = _familyAdjustments[familyKey] ?? 1.0;

    final effectiveRate = baseRate * incomeAdj * familyAdj;
    final chargeTotaleBase = revenuBrut * effectiveRate;

    // Split: ~25% federal, ~75% cantonal+communal
    final impotFederal = chargeTotaleBase * 0.25;
    double impotCantonalCommunal = chargeTotaleBase * 0.75;

    // Ajustement communal (ratio commune / chef-lieu)
    String communeLabel = '';
    if (commune != null) {
      final communeMult = CommuneData.getCommuneMultiplier(canton, commune);
      final chefLieuMult = CommuneData.getChefLieuMultiplier(canton);
      if (communeMult != null && chefLieuMult != null && chefLieuMult > 0) {
        final communeRatio = communeMult / chefLieuMult;
        impotCantonalCommunal *= communeRatio;
        communeLabel = commune;
      }
    }

    final chargeTotale = impotFederal + impotCantonalCommunal;
    final tauxEffectif = revenuBrut > 0 ? (chargeTotale / revenuBrut) * 100 : 0.0;

    return {
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'commune': communeLabel,
      'revenuImposable': revenuBrut,
      'impotFederal': impotFederal,
      'impotCantonalCommunal': impotCantonalCommunal,
      'chargeTotale': chargeTotale,
      'tauxEffectif': tauxEffectif,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  2. COMPARE ALL CANTONS
  // ════════════════════════════════════════════════════════════

  /// Rank all 26 cantons by total tax charge.
  static List<Map<String, dynamic>> compareAllCantons({
    required double revenuBrut,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
  }) {
    final results = <Map<String, dynamic>>[];
    for (final canton in effectiveRates100kSingle.keys) {
      results.add(estimateTax(
        revenuBrut: revenuBrut,
        canton: canton,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      ));
    }
    results.sort((a, b) =>
        (a['chargeTotale'] as double).compareTo(b['chargeTotale'] as double));
    for (int i = 0; i < results.length; i++) {
      results[i]['rang'] = i + 1;
      results[i]['differenceVsPremier'] =
          (results[i]['chargeTotale'] as double) -
              (results[0]['chargeTotale'] as double);
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════
  //  3. SIMULATE MOVE
  // ════════════════════════════════════════════════════════════

  /// Simulate moving between two cantons (optionally with communes).
  ///
  /// [s] is required to produce localized user-facing text (chiffreChoc).
  static Map<String, dynamic> simulateMove({
    required S s,
    required double revenuBrut,
    required String cantonDepart,
    required String cantonArrivee,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
    String? communeDepart,
    String? communeArrivee,
  }) {
    final taxDepart = estimateTax(
      revenuBrut: revenuBrut,
      canton: cantonDepart,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      commune: communeDepart,
    );
    final taxArrivee = estimateTax(
      revenuBrut: revenuBrut,
      canton: cantonArrivee,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      commune: communeArrivee,
    );

    final economieAnnuelle = (taxDepart['chargeTotale'] as double) -
        (taxArrivee['chargeTotale'] as double);
    final economieMensuelle = economieAnnuelle / 12;
    final economie10Ans = economieAnnuelle * 10;

    String chiffreChoc;
    if (economieAnnuelle > 0) {
      chiffreChoc = s.fiscalServiceMoveSavings(
        getCantonName(s, cantonDepart),
        getCantonName(s, cantonArrivee),
        formatChf(economieAnnuelle),
        formatChf(economie10Ans),
      );
    } else if (economieAnnuelle < 0) {
      chiffreChoc = s.fiscalServiceMoveCost(formatChf(-economieAnnuelle));
    } else {
      chiffreChoc = s.fiscalServiceMoveEquivalent;
    }

    return {
      'cantonDepart': cantonDepart,
      'cantonDepartNom': getCantonName(s, cantonDepart),
      'cantonArrivee': cantonArrivee,
      'cantonArriveeNom': getCantonName(s, cantonArrivee),
      'chargeDepart': taxDepart['chargeTotale'],
      'chargeArrivee': taxArrivee['chargeTotale'],
      'tauxDepart': taxDepart['tauxEffectif'],
      'tauxArrivee': taxArrivee['tauxEffectif'],
      'economieAnnuelle': economieAnnuelle,
      'economieMensuelle': economieMensuelle,
      'economie10Ans': economie10Ans,
      'chiffreChoc': chiffreChoc,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Interpolate income adjustment between known brackets.
  static double _interpolateIncomeAdjustment(double income) {
    final keys = _incomeAdjustments.keys.toList()..sort();
    if (income <= keys.first) return _incomeAdjustments[keys.first]!;
    if (income >= keys.last) return _incomeAdjustments[keys.last]!;

    for (int i = 0; i < keys.length - 1; i++) {
      if (income >= keys[i] && income <= keys[i + 1]) {
        final ratio = (income - keys[i]) / (keys[i + 1] - keys[i]);
        return _incomeAdjustments[keys[i]]! +
            ratio *
                (_incomeAdjustments[keys[i + 1]]! -
                    _incomeAdjustments[keys[i]]!);
      }
    }
    return 1.0;
  }

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

  /// Sorted list of canton codes (alphabetical).
  static List<String> get sortedCantonCodes {
    final codes = cantonNames.keys.toList()..sort();
    return codes;
  }

  /// Estimate the national average effective tax rate for a given profile.
  ///
  /// Uses nationalAverageRate100k adjusted for income and family.
  static double estimateNationalAverageRate({
    required double revenuBrut,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
  }) {
    final incomeAdj = _interpolateIncomeAdjustment(revenuBrut);
    final familyKey = '${etatCivil}_${min(nombreEnfants, 3)}';
    final familyAdj = _familyAdjustments[familyKey] ?? 1.0;
    return nationalAverageRate100k * incomeAdj * familyAdj * 100;
  }
}
