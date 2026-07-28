// ────────────────────────────────────────────────────────────
//  MODÈLE IMPÔT REVENU v2 — MIROIR du backend canonique
//  (beads MINT_nosync-97h / -81n)
//
//  MIRROR services/backend/app/services/fiscal/cantonal_comparator.py
//  (estimate_income_tax v2) : IFD 2026 progressif (recoupé Form. 58c) +
//  impôt cantonal+communal INTERPOLÉ entre 130 points calibrés sur l'API
//  officielle ESTV (26 cantons x 5 revenus, chef-lieu, célibataire,
//  collecte 2026-07-23). Remplace les modèles « taux effectif x facteur »
//  quasi quadratiques dont les DIFFÉRENCES d'impôt (économies marginales)
//  étaient fausses — cause des conclusions bloc/étalé INVERSÉES entre
//  coach (backend) et écran (mobile) sur le rachat LPP.
//
//  Toute recalibration passe par le backend d'abord, puis ce miroir
//  (mêmes tables, mêmes conventions d'interpolation).
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/constants/social_insurance.dart';

/// Barème IFD 2026 (LIFD art. 36, célibataire) — (borne sup, taux tranche).
const List<List<double>> incomeTaxFederalBrackets2026 = [
  [15200, 0.0000],
  [33200, 0.0077],
  [43500, 0.0088],
  [58000, 0.0264],
  [76200, 0.0297],
  [82100, 0.0594],
  [108900, 0.0660],
  [141500, 0.0880],
  [185100, 0.1100],
  [794000, 0.1320],
  [double.infinity, 0.1150],
];

/// Points de revenu imposable de la table cantonale (CHF).
/// Nœuds bas 15k/25k/35k ajoutés (collecte ESTV 2026-07-28, finding INC-1) :
/// sous 40k l'ancienne interpolation linéaire depuis (0,0) surestimait
/// l'impôt cantonal jusqu'à +59.8 % (seuil non imposable ~15k). Miroir du
/// backend cantonal_comparator.py::CANTONAL_TAX_POINTS_INCOME.
const List<double> cantonalTaxPointsIncome = [
  15000,
  25000,
  35000,
  40000,
  70000,
  100000,
  150000,
  250000,
];

/// Impôt cantonal+communal (chef-lieu) en CHF — API ESTV.
/// Points 40k-250k : collecte 2026-07-23 ; points bas 15k/25k/35k :
/// collecte 2026-07-28 (finding INC-1). SG/TI : barèmes 2025 (ESTV pas
/// encore publié leur 2026). Miroir exact de cantonal_comparator.py.
const Map<String, List<double>> cantonalCommunalTaxChf = {
  'AG': [410, 1271, 2490, 3186, 8183, 13806, 23656, 44288],
  'AI': [456, 1368, 2538, 3146, 7022, 11096, 17860, 30400],
  'AR': [578, 1895, 3458, 4272, 9806, 15852, 26396, 47856],
  'BE': [2088, 3927, 5834, 6839, 13129, 20273, 33232, 60810],
  'BL': [0, 1011, 2612, 3579, 10563, 18511, 32802, 62251],
  'BS': [3150, 5250, 7350, 8400, 14700, 21000, 31500, 54844],
  'FR': [932, 2321, 4067, 5027, 11704, 18992, 32619, 59400],
  'GE': [25, 878, 2700, 3706, 10593, 17967, 30803, 58279],
  'GL': [453, 1579, 3006, 3790, 8942, 14373, 23990, 45027],
  'GR': [0, 814, 2289, 3097, 8622, 14368, 24362, 44579],
  'JU': [663, 2158, 3917, 4875, 11430, 18651, 31852, 58743],
  'LU': [164, 1236, 2684, 3410, 7760, 12110, 19648, 36020],
  'NE': [448, 2204, 4399, 5511, 12657, 20555, 34781, 62646],
  'NW': [159, 1101, 2501, 3220, 7634, 12191, 20054, 34130],
  'OW': [1920, 3200, 4480, 5119, 8959, 12798, 19197, 31995],
  'SG': [331, 1750, 3266, 4238, 10356, 17071, 28492, 51334], // barème 2025
  'SH': [548, 1413, 2470, 3085, 7525, 12772, 21661, 39408],
  'SO': [303, 1551, 3544, 4570, 11203, 18007, 30402, 55242],
  'SZ': [663, 1461, 2350, 2813, 5936, 9270, 14828, 25943],
  'TG': [150, 1363, 2869, 3703, 8974, 14440, 23852, 43827],
  'TI': [301, 1254, 2807, 3720, 9979, 16987, 29443, 55098], // barème 2025
  'UR': [2147, 3531, 4916, 5608, 9762, 13915, 20838, 34683],
  'VD': [1348, 2957, 4763, 5666, 12039, 19588, 33776, 65070],
  'VS': [765, 1681, 2979, 3750, 9467, 16829, 32371, 59684],
  'ZG': [472, 951, 1525, 1882, 4162, 7325, 13435, 23835],
  'ZH': [431, 1252, 2333, 2975, 7586, 13228, 23832, 48497],
};

/// Impôt sur le revenu estimé (IFD + cantonal interpolé), miroir backend v2.
///
/// [taxableIncome] : revenu IMPOSABLE. Marié : x0.80 (splitting).
/// Limites (dites) : célibataire chef-lieu sans confession ; estimation
/// éducative, jamais un conseil fiscal (LSFin).
/// Décomposition (fédéral, cantonal+communal) — miroir Dart de
/// `estimate_income_tax_parts` backend (PR #997). Le facteur marié x0.80
/// est appliqué PROPORTIONNELLEMENT aux deux parts : la somme peut
/// différer du total canonique [estimateIncomeTaxV2] d'au plus un
/// centime d'arrondi (même conception que le backend — les fixtures de
/// parité pinent les TOTAUX, la décomposition sert l'affichage).
({double federal, double cantonal}) estimateIncomeTaxV2Parts(
  double taxableIncome,
  String canton, {
  bool isMarried = false,
}) {
  var impotFederal = 0.0;
  var prevBound = 0.0;
  for (final bracket in incomeTaxFederalBrackets2026) {
    final upper = bracket[0];
    final rate = bracket[1];
    if (taxableIncome <= prevBound) break;
    final taxable =
        (taxableIncome < upper ? taxableIncome : upper) - prevBound;
    impotFederal += taxable * rate;
    prevBound = upper;
  }

  var pts = cantonalCommunalTaxChf[canton.toUpperCase()];
  if (pts == null) {
    final all = cantonalCommunalTaxChf.values.toList();
    pts = List<double>.generate(
      cantonalTaxPointsIncome.length,
      (i) => all.fold<double>(0, (s, v) => s + v[i]) / all.length,
    );
  }
  final incomes = cantonalTaxPointsIncome;
  double impotCantonal;
  if (taxableIncome <= 0) {
    impotCantonal = 0;
  } else if (taxableIncome <= incomes.first) {
    impotCantonal = pts.first * (taxableIncome / incomes.first);
  } else if (taxableIncome >= incomes.last) {
    final slope = (pts.last - pts[pts.length - 2]) /
        (incomes.last - incomes[incomes.length - 2]);
    impotCantonal = pts.last + slope * (taxableIncome - incomes.last);
  } else {
    impotCantonal = 0;
    for (var i = 0; i < incomes.length - 1; i++) {
      if (taxableIncome >= incomes[i] && taxableIncome <= incomes[i + 1]) {
        final ratio =
            (taxableIncome - incomes[i]) / (incomes[i + 1] - incomes[i]);
        impotCantonal = pts[i] + ratio * (pts[i + 1] - pts[i]);
        break;
      }
    }
  }

  if (isMarried) {
    impotFederal *= 0.80;
    impotCantonal *= 0.80;
  }
  return (federal: impotFederal, cantonal: impotCantonal);
}

double estimateIncomeTaxV2(
  double taxableIncome,
  String canton, {
  bool isMarried = false,
}) {
  // Review #1007 : délégation à la décomposition — une seule
  // implémentation des boucles (contrat d'identité testé sur les 26
  // cantons). Le facteur marié s'applique à la SOMME, ordre des
  // flottants identique à l'ancien corps (leçon backend #997 — les
  // parités croisées sont gelées au centime).
  final parts = estimateIncomeTaxV2Parts(taxableIncome, canton);
  var total = parts.federal + parts.cantonal;
  if (isMarried) {
    total *= 0.80;
  }
  return total;
}


/// Montants de la table capital (CHF).
const List<double> capitalTaxPointsAmount = [
  100000,
  250000,
  500000,
  750000,
  1000000,
];

/// Impôt cantonal+communal (chef-lieu) sur une PRESTATION EN CAPITAL de
/// prévoyance — MIRROR backend CANTONAL_CAPITAL_TAX_CHF (beads -2i2,
/// API ESTV API_calculateManyCapitalTaxes, 2026-07-23, célibataire
/// homme 65 ans ; TI/VS sensibles âge/sexe, documenté). IFD art. 38
/// (1/5 du barème revenu) NON incluse — calculée séparément.
const Map<String, List<double>> cantonalCapitalTaxChf = {
  'AG': [4142, 13287, 29398, 45815, 62233],
  'AI': [2774, 7600, 15200, 22800, 30400],
  'AR': [7400, 18500, 39042, 63708, 88374],
  'BE': [4091, 12422, 30758, 51708, 73154],
  'BL': [3300, 8250, 23100, 47850, 72600],
  'BS': [4750, 16750, 36750, 56750, 76750],
  'FR': [2700, 13500, 36000, 58500, 81000],
  'GE': [3588, 11650, 26550, 42203, 58069],
  'GL': [4828, 12070, 24140, 36210, 48280],
  'GR': [2700, 6750, 18000, 27000, 36000],
  'JU': [5637, 17495, 37682, 57870, 78057],
  'LU': [3016, 9106, 19256, 29406, 39556],
  'NE': [5139, 15661, 31775, 48148, 64519],
  'NW': [3035, 8520, 17045, 25570, 34095],
  'OW': [5119, 12798, 25596, 38394, 51192],
  'SG': [5346, 13365, 26730, 40095, 53460],
  'SH': [2542, 7870, 15741, 23611, 31482],
  'SO': [4489, 13799, 28350, 42525, 56700],
  'SZ': [1389, 8140, 21375, 32063, 42750],
  'TG': [6024, 15060, 30120, 45180, 60240],
  'TI': [3860, 9650, 24841, 43425, 57900], // sensible âge/sexe (homme/65 retenu)
  'UR': [3705, 9263, 18525, 27788, 37050],
  'VD': [4052, 13460, 31446, 49542, 67638],
  'VS': [4200, 11434, 33420, 60000, 80000], // sensible âge/sexe (homme/65 retenu)
  'ZG': [2197, 7352, 17752, 28152, 38552],
  'ZH': [4280, 10700, 24567, 52601, 86542],
};

/// Impôt total sur un retrait en capital 2e/3e pilier — modèle v2 -2i2,
/// MIRROR exact du backend estimate_capital_withdrawal_tax.
double estimateCapitalWithdrawalTaxV2(
  double amount,
  String canton, {
  bool isMarried = false,
}) {
  if (amount <= 0) return 0;

  var ifdFull = 0.0;
  var prevBound = 0.0;
  for (final bracket in incomeTaxFederalBrackets2026) {
    final upper = bracket[0];
    final rate = bracket[1];
    if (amount <= prevBound) break;
    final taxable = (amount < upper ? amount : upper) - prevBound;
    ifdFull += taxable * rate;
    prevBound = upper;
  }
  final ifd = ifdFull / 5.0;

  var pts = cantonalCapitalTaxChf[canton.toUpperCase()];
  if (pts == null) {
    final all = cantonalCapitalTaxChf.values.toList();
    pts = List<double>.generate(
      capitalTaxPointsAmount.length,
      (i) => all.fold<double>(0, (s, v) => s + v[i]) / all.length,
    );
  }
  final amounts = capitalTaxPointsAmount;
  double cantonal;
  if (amount <= amounts.first) {
    cantonal = pts.first * (amount / amounts.first);
  } else if (amount >= amounts.last) {
    final slope = (pts[pts.length - 1] - pts[pts.length - 2]) /
        (amounts[amounts.length - 1] - amounts[amounts.length - 2]);
    cantonal = pts.last + slope * (amount - amounts.last);
  } else {
    cantonal = pts.last;
    for (var i = 0; i < amounts.length - 1; i++) {
      if (amount >= amounts[i] && amount <= amounts[i + 1]) {
        final ratio = (amount - amounts[i]) / (amounts[i + 1] - amounts[i]);
        cantonal = pts[i] + ratio * (pts[i + 1] - pts[i]);
        break;
      }
    }
  }

  if (isMarried) {
    // Coefficient par canton importé directement (review #990 : une
    // dépendance injectable nullable permettait une divergence silencieuse
    // marié == célibataire si le caller oubliait l'injection).
    cantonal *= marriedCapitalTaxDiscountFor(canton.toUpperCase());
  }
  return ifd + cantonal;
}
