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
const List<double> cantonalTaxPointsIncome = [
  40000,
  70000,
  100000,
  150000,
  250000,
];

/// Impôt cantonal+communal (chef-lieu) en CHF — API ESTV 2026-07-23.
/// SG/TI : barèmes 2025 (ESTV pas encore publié leur 2026).
const Map<String, List<double>> cantonalCommunalTaxChf = {
  'AG': [3186, 8183, 13806, 23656, 44288],
  'AI': [3146, 7022, 11096, 17860, 30400],
  'AR': [4272, 9806, 15852, 26396, 47856],
  'BE': [6839, 13129, 20273, 33232, 60810],
  'BL': [3579, 10563, 18511, 32802, 62251],
  'BS': [8400, 14700, 21000, 31500, 54844],
  'FR': [5027, 11704, 18992, 32619, 59400],
  'GE': [3706, 10593, 17967, 30803, 58279],
  'GL': [3790, 8942, 14373, 23990, 45027],
  'GR': [3097, 8622, 14368, 24362, 44579],
  'JU': [4875, 11430, 18651, 31852, 58743],
  'LU': [3410, 7760, 12110, 19648, 36020],
  'NE': [5511, 12657, 20555, 34781, 62646],
  'NW': [3220, 7634, 12191, 20054, 34130],
  'OW': [5119, 8959, 12798, 19197, 31995],
  'SG': [4238, 10356, 17071, 28492, 51334], // barème 2025
  'SH': [3085, 7525, 12772, 21661, 39408],
  'SO': [4570, 11203, 18007, 30402, 55242],
  'SZ': [2813, 5936, 9270, 14828, 25943],
  'TG': [3703, 8974, 14440, 23852, 43827],
  'TI': [3720, 9979, 16987, 29443, 55098], // barème 2025
  'UR': [5608, 9762, 13915, 20838, 34683],
  'VD': [5666, 12039, 19588, 33776, 65070],
  'VS': [3750, 9467, 16829, 32371, 59684],
  'ZG': [1882, 4162, 7325, 13435, 23835],
  'ZH': [2975, 7586, 13228, 23832, 48497],
};

/// Impôt sur le revenu estimé (IFD + cantonal interpolé), miroir backend v2.
///
/// [taxableIncome] : revenu IMPOSABLE. Marié : x0.80 (splitting).
/// Limites (dites) : célibataire chef-lieu sans confession ; estimation
/// éducative, jamais un conseil fiscal (LSFin).
double estimateIncomeTaxV2(
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
    final slope = (pts[pts.length - 1] - pts[pts.length - 2]) /
        (incomes[incomes.length - 1] - incomes[incomes.length - 2]);
    impotCantonal = pts.last + slope * (taxableIncome - incomes.last);
  } else {
    impotCantonal = pts.last;
    for (var i = 0; i < incomes.length - 1; i++) {
      if (taxableIncome >= incomes[i] && taxableIncome <= incomes[i + 1]) {
        final ratio =
            (taxableIncome - incomes[i]) / (incomes[i + 1] - incomes[i]);
        impotCantonal = pts[i] + ratio * (pts[i + 1] - pts[i]);
        break;
      }
    }
  }

  var total = impotFederal + impotCantonal;
  if (isMarried) {
    total *= 0.80;
  }
  return total;
}
