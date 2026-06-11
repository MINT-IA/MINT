// ALL replacement-rate computations MUST use ReplacementRate from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT re-implement totalRetirement / netIncome as a local ratio.

/// Taux de remplacement — définition canonique unique (financial_core L1).
///
/// UNE définition app-wide (lock CONTEXT W1) : le taux de remplacement est le
/// rapport entre le revenu de retraite mensuel projeté et le revenu **NET**
/// mensuel courant. Le dénominateur est le NET (sens économique : « combien de
/// mon pouvoir d'achat actuel vais-je retrouver ? »), JAMAIS le brut.
///
/// Composition canonique du numérateur : AVS + LPP. Le service de la dette est
/// une donnée *budget*, pas un revenu de retraite — il ne doit pas être
/// soustrait du revenu de retraite total (sinon le taux diverge d'un moteur à
/// l'autre, cf. matrice D3 : 63% vs 46.5% pour le même profil dans la même
/// session).
///
/// Fonction pure, déterministe, offline-capable (aucune dépendance réseau).
/// Le revenu NET courant provient de [NetIncomeBreakdown.compute]
/// (canton + âge aware) — plus de ratio plat 0.75 / 0.78.
///
/// Note golden Julien/Lauren à confirmer post-merge (non-bloquant).
class ReplacementRate {
  ReplacementRate._();

  /// Taux de remplacement en pourcentage (0-100, non borné en haut).
  ///
  /// [totalMonthlyRetirement] : revenu de retraite mensuel projeté (AVS + LPP,
  /// SANS soustraction du service de dette).
  /// [netMonthlyIncome] : revenu NET mensuel courant (NetIncomeBreakdown).
  ///
  /// Retourne `0` si le NET est non-positif (pas de division par zéro) ou si le
  /// numérateur est négatif (clamp ≥ 0).
  static double percent({
    required double totalMonthlyRetirement,
    required double netMonthlyIncome,
  }) {
    if (netMonthlyIncome <= 0) return 0.0;
    final retirement = totalMonthlyRetirement < 0 ? 0.0 : totalMonthlyRetirement;
    return retirement / netMonthlyIncome * 100.0;
  }

  /// Taux de remplacement en fraction (0-1), pour les consommateurs historiques
  /// qui comparent contre des seuils décimaux (`< 0.55`) ou multiplient par 100
  /// eux-mêmes. Même définition que [percent], divisée par 100.
  static double fraction({
    required double totalMonthlyRetirement,
    required double netMonthlyIncome,
  }) =>
      percent(
        totalMonthlyRetirement: totalMonthlyRetirement,
        netMonthlyIncome: netMonthlyIncome,
      ) /
      100.0;
}
