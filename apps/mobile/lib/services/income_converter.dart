/// IncomeConverter — utilitaire net↔brut pour les calculateurs MINT.
///
/// L'user MINT saisit son revenu **net mensuel** (ce qu'il voit sur son
/// compte). Les calculateurs `financial_core/*` raisonnent en **brut
/// annuel** (salaire déterminant LPP/AVS/fiscal). Ce service pont les
/// deux mondes avec des facteurs conservateurs annotés par archetype.
///
/// Doctrine : feedback `feedback_net_monthly_not_gross_annual.md`
/// (Julien 2026-04-22 — « moi franchement mon revenu brut, à Niel j'en
/// sais rien, par contre je sais que je gagne 7600 francs net par
/// mois »).
///
/// Confidence : les chiffres dérivés d'un net-estimé user sont
/// `MintConfidenceLevel.medium`. Un scan de fiche de salaire ou
/// certificat LPP remonte la confidence à `high` / `very_high` et
/// remplace ce facteur par la valeur extraite.
library;

/// Facteurs brut/net (moyenne suisse 2026) — sources :
///   - AVS/AI/APG 5.3 % part salarié (LAVS art. 5)
///   - LPP cotisation moyenne 7.5 % (LPP art. 16, taux âge-dépendant
///     7-18 % ; 7.5 % = moyenne pondérée de la population suisse active)
///   - LAA non-professionnelle ~1.4 %
///   - IJM cantonale moyenne ~0.5-1.5 %
/// Total cotisations ≈ 15 %. Le facteur brut = net × 1/(1 - 0.15) ≈ 1.176.
/// Arrondi à 1.17 pour lisibilité de la constante.
const double _kSalariedNetToGrossFactor = 1.17;

/// Indépendant : pas de LPP employeur, pas de LAA, cotisations perso
/// plus faibles en pourcentage (AVS 10 %, AI, APG). Facteur net→brut
/// plus bas (≈ 1.10).
const double _kSelfEmployedNetToGrossFactor = 1.10;

class IncomeConverter {
  IncomeConverter._();

  /// Convertit un revenu net mensuel (CHF) en revenu brut annuel (CHF).
  ///
  /// [netMonthly] : ce que l'user voit tomber sur son compte (CHF).
  /// [isSalaried] : true pour un salarié affilié LPP (défaut),
  /// false pour un indépendant sans LPP.
  static double netMonthlyToGrossAnnual(
    double netMonthly, {
    bool isSalaried = true,
  }) {
    final factor =
        isSalaried ? _kSalariedNetToGrossFactor : _kSelfEmployedNetToGrossFactor;
    return netMonthly * 12 * factor;
  }

  /// Convertit une fourchette (min, max) de revenu net mensuel en
  /// fourchette brut annuel. Utile pour propager l'incertitude jusqu'aux
  /// chiffres héros affichés à l'user (doctrine intervalle, pas point).
  static ({double lowGrossAnnual, double highGrossAnnual}) netMonthlyRangeToGrossAnnual(
    ({double low, double high}) netMonthlyRange, {
    bool isSalaried = true,
  }) {
    return (
      lowGrossAnnual:
          netMonthlyToGrossAnnual(netMonthlyRange.low, isSalaried: isSalaried),
      highGrossAnnual:
          netMonthlyToGrossAnnual(netMonthlyRange.high, isSalaried: isSalaried),
    );
  }

  /// Accesseur du facteur utilisé — pour les scènes qui veulent
  /// afficher « hypothèse : brut ≈ net × 1.17 » en sous-texte nLPD.
  static double factorFor({required bool isSalaried}) {
    return isSalaried
        ? _kSalariedNetToGrossFactor
        : _kSelfEmployedNetToGrossFactor;
  }
}
