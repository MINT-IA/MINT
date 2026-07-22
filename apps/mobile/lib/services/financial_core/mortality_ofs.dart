import 'dart:math' as math;

// ════════════════════════════════════════════════════════════════════════════
//  MORTALITÉ OFS 2023 — échantillonnage de l'âge de décès
// ════════════════════════════════════════════════════════════════════════════
//
// Table de mortalité période OFS/BFS 2023 (Vollständige jährliche
// Sterbetafel, codes su-d-01.04.02.02.04 hommes / .05 femmes, base
// STATPOP+BEVNAT, population résidante permanente).
// Espérance de vie officielle à 65 ans (2023) : hommes 20.3, femmes 22.8.
// e65 recalculée depuis les ancres ci-dessous (trapèzes) : 20.30 / 22.84 —
// écart < 0.1 an vs valeurs officielles.
//
// Ancres : survivants S(x) sur 100 000 naissances, âges 60 → 105 par pas
// de 5 ans. Valeurs OFS exactes de 60 à 100 (S(100) = S(99) − D(99)) ;
// SEUL le point 105 est extrapolé (Gompertz calibré sur Q(99), sens
// conservateur pour le risque de longévité).
//
// Limites documentées : table période (pas générationnelle) — sous-estime
// légèrement la longévité des cohortes jeunes ; queue réelle 105-110 non
// modélisée (masse résiduelle rattachée à 105).
// ════════════════════════════════════════════════════════════════════════════

/// Âges des ancres de la table.
const List<int> _anchorAges = [60, 65, 70, 75, 80, 85, 90, 95, 100, 105];

/// Survivants hommes S(x), OFS 2023, base 100 000 naissances.
const List<double> _survivorsMen = [
  94231, 91219, 86454, 79026, 67902, 51499, 28969, 9257, 1511, 80,
];

/// Survivantes femmes S(x), OFS 2023, base 100 000 naissances.
const List<double> _survivorsWomen = [
  96549, 94755, 91782, 86833, 78630, 64853, 42583, 17258, 3417, 199,
];

/// Échantillonnage de l'âge de décès sur la table de mortalité OFS 2023.
///
/// Pure et statique — remplace l'ancien tirage uniforme 82-95 du Monte
/// Carlo (ni genré, ni conditionnel à l'âge, distribution irréaliste).
class MortalityOfs {
  MortalityOfs._();

  /// Tire un âge de décès par inverse-CDF sur la survie conditionnelle
  /// S(t)/S(a), interpolation linéaire entre les ancres quinquennales.
  ///
  /// [currentAge] : l'âge de conditionnement est plafonné à la première
  /// ancre (60) — la mortalité avant 60 ans n'est pas modélisée (hors
  /// scope d'une projection retraite) — et borné à 104 au-delà.
  /// [gender] : 'M' → table hommes, 'F' → table femmes. Genre inconnu →
  /// table FEMMES (survie la plus longue) : le risque modélisé est la
  /// LONGÉVITÉ (survivre à son capital), le choix prudent est la vie la
  /// plus longue, pas la moyenne H/F.
  static int sampleDeathAge(
    math.Random random, {
    required int currentAge,
    String? gender,
  }) {
    final table = gender == 'M' ? _survivorsMen : _survivorsWomen;
    final conditionAge = currentAge.clamp(_anchorAges.first, 104);
    final sAtCondition = _survivalAt(table, conditionAge.toDouble());

    // P(T > t | T > a) = S(t)/S(a) = u  ->  chercher t tel que
    // S(t) = u * S(a). u=0 exclu (jamais tiré par nextDouble), la masse
    // au-delà de 105 est rattachée à 105.
    final u = random.nextDouble();
    final targetSurvivors = u * sAtCondition;
    if (targetSurvivors <= table.last) return _anchorAges.last;

    // Trouver le segment [i, i+1] où S passe sous la cible.
    for (int i = 0; i < _anchorAges.length - 1; i++) {
      final s0 = table[i];
      final s1 = table[i + 1];
      if (targetSurvivors <= s0 && targetSurvivors > s1) {
        final frac = (s0 - targetSurvivors) / (s0 - s1);
        final t = _anchorAges[i] + frac * (_anchorAges[i + 1] - _anchorAges[i]);
        // Le décès ne peut pas précéder l'âge de conditionnement.
        return math.max(t.floor(), conditionAge);
      }
    }
    return _anchorAges.last;
  }

  /// S(x) interpolé linéairement entre les ancres.
  static double _survivalAt(List<double> table, double age) {
    if (age <= _anchorAges.first) return table.first;
    if (age >= _anchorAges.last) return table.last;
    for (int i = 0; i < _anchorAges.length - 1; i++) {
      if (age >= _anchorAges[i] && age < _anchorAges[i + 1]) {
        final frac = (age - _anchorAges[i]) /
            (_anchorAges[i + 1] - _anchorAges[i]);
        return table[i] + frac * (table[i + 1] - table[i]);
      }
    }
    return table.last;
  }
}
