import 'dart:math';
import 'package:mint_mobile/data/commune_data.dart';
import 'package:mint_mobile/services/financial_core/income_tax_model_v2.dart';

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
  //  CANTON NAMES (French)
  // ════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════
  //  INCOME ADJUSTMENT FACTORS (relative to 100k base)
  // ════════════════════════════════════════════════════════════


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

  /// Réduction enfants RELATIVE à marié sans enfant (convention #997) —
  /// célibataire avec enfants : inchangé (limite dite).
  static double _childFactor(
      {required bool isMarried, required int children}) {
    if (!isMarried || children <= 0) return 1.0;
    final key = 'marie_${min(children, 3)}';
    return _familyAdjustments[key]! / _familyAdjustments['marie_0']!;
  }

  // ════════════════════════════════════════════════════════════
  //  NATIONAL AVERAGE (for comparison gauge)
  // ════════════════════════════════════════════════════════════


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
    // Beads -2b7 : miroir du backend #997 — parts du modèle v2 sur le
    // revenu imposable (~85% du brut, simplification documentée), enfants
    // en ratio relatif marié, ratio communal appliqué à la part
    // cantonale RÉELLE. Remplace « taux effectif 100k x facteur revenu »
    // (différences d'impôt fausses — même défaut que le bloc supprimé
    // backend).
    final revenuImposable = revenuBrut * 0.85;
    final isMarried = etatCivil == 'marie';
    final parts = estimateIncomeTaxV2Parts(revenuImposable, canton,
        isMarried: isMarried);
    final cf = _childFactor(isMarried: isMarried, children: nombreEnfants);
    var impotFederal = parts.federal * cf;
    double impotCantonalCommunal = parts.cantonal * cf;

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
      'revenuImposable': revenuImposable,
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
    for (final canton in cantonalCommunalTaxChf.keys) {
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
  static Map<String, dynamic> simulateMove({
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

    String premierEclairage;
    if (economieAnnuelle > 0) {
      premierEclairage =
          'En déménageant de ${cantonNames[cantonDepart]} à ${cantonNames[cantonArrivee]}, '
          'tu économiserais ~${formatChf(economieAnnuelle)}/an soit '
          '${formatChf(economie10Ans)} sur 10 ans';
    } else if (economieAnnuelle < 0) {
      premierEclairage =
          'Attention : ce déménagement te coûterait ~${formatChf(-economieAnnuelle)}/an '
          'en impôts supplémentaires';
    } else {
      premierEclairage = 'Charge fiscale équivalente dans les deux cantons';
    }

    return {
      'cantonDepart': cantonDepart,
      'cantonDepartNom': cantonNames[cantonDepart] ?? cantonDepart,
      'cantonArrivee': cantonArrivee,
      'cantonArriveeNom': cantonNames[cantonArrivee] ?? cantonArrivee,
      'chargeDepart': taxDepart['chargeTotale'],
      'chargeArrivee': taxArrivee['chargeTotale'],
      'tauxDepart': taxDepart['tauxEffectif'],
      'tauxArrivee': taxArrivee['tauxEffectif'],
      'economieAnnuelle': economieAnnuelle,
      'economieMensuelle': economieMensuelle,
      'economie10Ans': economie10Ans,
      'premierEclairage': premierEclairage,
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
    // Beads -2b7 : moyenne RÉELLE des 26 charges v2 au profil donné —
    // remplace la constante 12.5% x facteurs (heuristique).
    if (revenuBrut <= 0) return 0;
    double total = 0;
    var n = 0;
    for (final canton in cantonalCommunalTaxChf.keys) {
      total += estimateTax(
        revenuBrut: revenuBrut,
        canton: canton,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      )['chargeTotale'] as double;
      n += 1;
    }
    return (total / n) / revenuBrut * 100;
  }
}
