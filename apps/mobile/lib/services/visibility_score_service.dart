import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

// ────────────────────────────────────────────────────────────
//  VISIBILITY SCORE SERVICE — S48 / Phase 0 Pulse
// ────────────────────────────────────────────────────────────
//
//  Calcule le score de "visibilite financiere" : combien
//  l'utilisateur connait de sa propre situation.
//
//  Ce n'est PAS un jugement sur la qualite de la situation.
//  C'est une mesure de CLARTE : "tu vois X% de ta situation."
//
//  4 axes avec ponderation contextuelle (Phase 1) :
//    Liquidite — Budget, epargne, dettes, coussin securite
//    Fiscalite — Canton, 3a, rachats, taux marginal
//    Retraite  — AVS, LPP, 3a, age retraite
//    Securite  — Assurances, protection famille, succession
//
//  Phase 1 : poids dynamiques selon age et archetype.
//    - 50+ : Retraite 30, Securite 25, Fiscalite 25, Liquidite 20
//    - Independant : Securite +5, Liquidite +5
//    - < 35 : Liquidite 30, Fiscalite 25, Retraite 20, Securite 25
//
//  Utilise ConfidenceScorer (financial_core) comme moteur —
//  ne duplique AUCUNE logique de calcul.
// ────────────────────────────────────────────────────────────

/// Un axe du score de visibilite.
class VisibilityAxis {
  final String id;
  final String label;
  final String icon; // emoji or icon name
  final double score; // 0-25
  final double maxScore; // 25 in Phase 0
  final String status; // 'complete', 'partial', 'missing'
  final String hint; // courte action pour ameliorer

  const VisibilityAxis({
    required this.id,
    required this.label,
    required this.icon,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.hint,
  });

  double get percentage => maxScore > 0 ? (score / maxScore * 100) : 0;
}

/// Resultat du score de visibilite financiere.
class VisibilityScore {
  /// Score global 0-100 (somme des 4 axes).
  final double total;

  /// Pourcentage affiche a l'utilisateur.
  final int percentage;

  /// Les 4 axes detailles.
  final List<VisibilityAxis> axes;

  /// Narrative courte (1 phrase) pour le dashboard.
  final String narrative;

  /// Actions prioritaires (max 3).
  final List<VisibilityAction> actions;

  /// Score couple : min des deux profils (alerte point faible).
  final double? coupleMin;

  /// Nom du conjoint avec le score le plus bas (pour l'alerte).
  final String? coupleWeakName;

  /// Score du conjoint le plus faible.
  final double? coupleWeakScore;

  const VisibilityScore({
    required this.total,
    required this.percentage,
    required this.axes,
    required this.narrative,
    required this.actions,
    this.coupleMin,
    this.coupleWeakName,
    this.coupleWeakScore,
  });
}

/// Action prioritaire sur le dashboard Pulse.
class VisibilityAction {
  final String id;
  final String title;
  final String subtitle;
  final String route;
  final String icon;
  final String category; // axe concerne
  final int impactPoints; // points de visibilite gagnes

  const VisibilityAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.category,
    required this.impactPoints,
  });
}

/// Service de calcul du score de visibilite financiere.
///
/// Delegue au ConfidenceScorer pour les calculs bruts,
/// puis regroupe en 4 axes comprehensibles.
class VisibilityScoreService {
  VisibilityScoreService._();

  /// Calcule le score de visibilite pour un profil.
  static VisibilityScore compute(CoachProfile profile) {
    final (:blocs, :confidence) = ConfidenceScorer.scoreWithBlocs(profile);

    // ── Poids contextuels (Phase 1) ─────────────────────────
    final weights = _contextualWeights(profile);

    // ── Regrouper les blocs en 4 axes ──────────────────────
    final liquidite = _computeLiquiditeAxis(blocs, profile, weights.liquidite);
    final fiscalite = _computeFiscaliteAxis(blocs, profile, weights.fiscalite);
    final retraite = _computeRetraiteAxis(blocs, profile, weights.retraite);
    final securite = _computeSecuriteAxis(blocs, profile, weights.securite);

    final axes = [liquidite, retraite, fiscalite, securite];
    final total = axes.fold<double>(0, (sum, a) => sum + a.score);
    final percentage = total.round().clamp(0, 100);

    // ── Narrative ──────────────────────────────────────────
    final narrative = _generateNarrative(percentage, axes);

    // ── Actions prioritaires (top 3 enrichment prompts) ───
    final actions = _buildActions(confidence.prompts);

    return VisibilityScore(
      total: total,
      percentage: percentage,
      axes: axes,
      narrative: narrative,
      actions: actions,
    );
  }

  /// Calcule le score couple avec alerte point faible.
  static VisibilityScore computeCouple(
    CoachProfile userProfile,
    CoachProfile conjointProfile,
  ) {
    final userScore = compute(userProfile);
    final conjScore = compute(conjointProfile);

    // Moyenne ponderee par revenu (revenuBrutAnnuel inclut 13e mois + bonus)
    final userRevenu = userProfile.revenuBrutAnnuel;
    final conjRevenu = conjointProfile.revenuBrutAnnuel;
    final totalRevenu = userRevenu + conjRevenu;

    double coupleTotal;
    if (totalRevenu > 0) {
      coupleTotal = (userScore.total * userRevenu +
              conjScore.total * conjRevenu) /
          totalRevenu;
    } else {
      coupleTotal = (userScore.total + conjScore.total) / 2;
    }

    // Point faible = min des deux
    final minScore =
        userScore.total < conjScore.total ? userScore : conjScore;
    final weakName = userScore.total < conjScore.total
        ? (userProfile.firstName ?? 'Utilisateur')
        : (conjointProfile.firstName ?? 'Partenaire');

    // Merge axes (moyenne simple pour l'affichage)
    final mergedAxes = <VisibilityAxis>[];
    for (var i = 0; i < userScore.axes.length; i++) {
      final uAxis = userScore.axes[i];
      final cAxis = conjScore.axes[i];
      final avgScore = (uAxis.score + cAxis.score) / 2;
      mergedAxes.add(VisibilityAxis(
        id: uAxis.id,
        label: uAxis.label,
        icon: uAxis.icon,
        score: avgScore,
        maxScore: uAxis.maxScore,
        status: avgScore >= uAxis.maxScore * 0.8
            ? 'complete'
            : avgScore > 0
                ? 'partial'
                : 'missing',
        hint: uAxis.score < cAxis.score ? uAxis.hint : cAxis.hint,
      ));
    }

    // Merge actions (top 3 from both, deduplicated by id)
    final allActions = [...userScore.actions, ...conjScore.actions];
    final seen = <String>{};
    final mergedActions = <VisibilityAction>[];
    for (final a in allActions) {
      if (seen.add(a.id) && mergedActions.length < 3) {
        mergedActions.add(a);
      }
    }

    final couplePercentage = coupleTotal.round().clamp(0, 100);

    return VisibilityScore(
      total: coupleTotal,
      percentage: couplePercentage,
      axes: mergedAxes,
      narrative: _generateNarrative(couplePercentage, mergedAxes),
      actions: mergedActions,
      coupleMin: minScore.total,
      coupleWeakName: weakName,
      coupleWeakScore: minScore.total,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CONTEXTUAL WEIGHTS — Phase 1
  // ════════════════════════════════════════════════════════════

  /// Poids des 4 axes adaptes au profil. Somme = 100.
  static _AxisWeights _contextualWeights(CoachProfile profile) {
    final age = profile.age;
    final isIndep = profile.employmentStatus == 'independant';

    // Base: egal 25/25/25/25
    double wLiq = 25, wFisc = 25, wRet = 25, wSec = 25;

    // Age-driven rebalancing
    if (age >= 50) {
      // Retraite devient prioritaire
      wRet = 30;
      wLiq = 20;
      // Fiscalite et securite restent a 25
    } else if (age < 35) {
      // Liquidite plus importante pour les jeunes
      wLiq = 30;
      wRet = 20;
      // Fiscalite et securite restent a 25
    }

    // Archetype-driven adjustments
    if (isIndep) {
      // Independants : securite + liquidite renforcees
      wSec += 5;
      wRet -= 5;
    }

    return _AxisWeights(
      liquidite: wLiq,
      fiscalite: wFisc,
      retraite: wRet,
      securite: wSec,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  AXES — regroupement des blocs ConfidenceScorer
  // ════════════════════════════════════════════════════════════

  static VisibilityAxis _computeLiquiditeAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, [
    double maxWeight = 25,
  ]) {
    // Liquidite = revenu (12) + patrimoine (7) = 19 pts max dans scorer
    // Normalise sur maxWeight (contextual)
    final revenu = blocs['revenu']?.score ?? 0;
    final patrimoine = blocs['patrimoine']?.score ?? 0;
    final raw = revenu + patrimoine; // max 19
    final normalized = (raw / 19 * maxWeight).clamp(0.0, maxWeight);

    final status = normalized >= maxWeight * 0.8
        ? 'complete'
        : normalized >= maxWeight * 0.4
            ? 'partial'
            : 'missing';

    return VisibilityAxis(
      id: 'liquidite',
      label: 'Liquidité',
      icon: 'wallet',
      score: normalized,
      maxScore: maxWeight,
      status: status,
      hint: revenu == 0
          ? 'Ajoute ton salaire pour commencer'
          : patrimoine == 0
              ? 'Renseigne ton épargne et investissements'
              : 'Tes données de liquidité sont complètes',
    );
  }

  static VisibilityAxis _computeFiscaliteAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, [
    double maxWeight = 25,
  ]) {
    // Fiscalite = fiscalite bloc (max 15) + age_canton (8) = 23 pts max
    // Normalise sur maxWeight (contextual)
    final fiscal = blocs['fiscalite']?.score ?? 0;
    final ageCanton = blocs['age_canton']?.score ?? 0;
    final raw = fiscal + ageCanton; // max 23
    final normalized = (raw / 23 * maxWeight).clamp(0.0, maxWeight);

    final status = normalized >= maxWeight * 0.8
        ? 'complete'
        : normalized >= maxWeight * 0.4
            ? 'partial'
            : 'missing';

    return VisibilityAxis(
      id: 'fiscalite',
      label: 'Fiscalité',
      icon: 'receipt',
      score: normalized,
      maxScore: maxWeight,
      status: status,
      hint: ageCanton == 0
          ? 'Indique ton âge et canton de résidence'
          : fiscal < 8
              ? 'Scanne ta déclaration fiscale'
              : 'Tes données fiscales sont complètes',
    );
  }

  static VisibilityAxis _computeRetraiteAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, [
    double maxWeight = 25,
  ]) {
    // Retraite = objectifRetraite (10) + lpp (18) + taux_conversion (5) +
    //            avs (10) + 3a (8) = 51 pts max
    // Normalise sur maxWeight (contextual)
    final objectif = blocs['objectifRetraite']?.score ?? 0;
    final lpp = blocs['lpp']?.score ?? 0;
    final taux = blocs['taux_conversion']?.score ?? 0;
    final avs = blocs['avs']?.score ?? 0;
    final troisA = blocs['3a']?.score ?? 0;
    final raw = objectif + lpp + taux + avs + troisA; // max 51
    final normalized = (raw / 51 * maxWeight).clamp(0.0, maxWeight);

    final status = normalized >= maxWeight * 0.8
        ? 'complete'
        : normalized >= maxWeight * 0.4
            ? 'partial'
            : 'missing';

    String hint;
    if (lpp == 0) {
      hint = 'Ajoute ton certificat LPP';
    } else if (avs < 5) {
      hint = 'Commande ton extrait AVS';
    } else if (troisA < 4) {
      hint = 'Renseigne tes comptes 3a';
    } else {
      hint = 'Tes données retraite sont complètes';
    }

    return VisibilityAxis(
      id: 'retraite',
      label: 'Retraite',
      icon: 'beach_access',
      score: normalized,
      maxScore: maxWeight,
      status: status,
      hint: hint,
    );
  }

  static VisibilityAxis _computeSecuriteAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, [
    double maxWeight = 25,
  ]) {
    // Securite = menage (15) + archetype (5) + foreign_pension (2) = 22 pts max
    // Normalise sur maxWeight (contextual)
    final menage = blocs['compositionMenage']?.score ?? 0;
    final archetype = blocs['archetype']?.score ?? 0;
    final foreign = blocs['foreign_pension']?.score ?? 0;
    final raw = menage + archetype + foreign; // max 22
    final normalized = (raw / 22 * maxWeight).clamp(0.0, maxWeight);

    final status = normalized >= maxWeight * 0.8
        ? 'complete'
        : normalized >= maxWeight * 0.4
            ? 'partial'
            : 'missing';

    return VisibilityAxis(
      id: 'securite',
      label: 'Sécurité',
      icon: 'shield',
      score: normalized,
      maxScore: maxWeight,
      status: status,
      hint: menage == 0
          ? 'Indique ta situation familiale'
          : archetype == 0
              ? 'Complète ton statut professionnel'
              : 'Tes données de sécurité sont complètes',
    );
  }

  // ════════════════════════════════════════════════════════════
  //  NARRATIVE — phrase courte pour le dashboard
  // ════════════════════════════════════════════════════════════

  static String _generateNarrative(int percentage, List<VisibilityAxis> axes) {
    // Trouver l'axe le plus faible
    VisibilityAxis? weakest;
    for (final axis in axes) {
      if (weakest == null || axis.percentage < weakest.percentage) {
        weakest = axis;
      }
    }

    if (percentage >= 80) {
      return 'Tu as une vision claire de ta situation. '
          'Continue à maintenir tes données à jour.';
    } else if (percentage >= 60) {
      return 'Bonne visibilité\u00a0! '
          'Affine ta ${weakest?.label.toLowerCase() ?? 'situation'} pour aller plus loin.';
    } else if (percentage >= 40) {
      return 'Tu commences à y voir plus clair. '
          'Concentre-toi sur ta ${weakest?.label.toLowerCase() ?? 'situation'}.';
    } else {
      return 'Chaque information compte. '
          'Commence par ${weakest?.hint.toLowerCase() ?? 'renseigner tes données'}.';
    }
  }

  // ════════════════════════════════════════════════════════════
  //  ACTIONS — top 3 enrichment prompts → action cards
  // ════════════════════════════════════════════════════════════

  static List<VisibilityAction> _buildActions(List<EnrichmentPrompt> prompts) {
    final actions = <VisibilityAction>[];

    for (final prompt in prompts) {
      if (actions.length >= 3) break;

      // Skip retirement urgency prompts (meta, not actionable)
      if (prompt.category == 'retirement_urgency') continue;

      actions.add(VisibilityAction(
        id: prompt.category,
        title: prompt.label,
        subtitle: prompt.action,
        route: _routeForCategory(prompt.category),
        icon: _iconForCategory(prompt.category),
        category: prompt.category,
        impactPoints: prompt.impact,
      ));
    }

    return actions;
  }

  static String _routeForCategory(String category) {
    return switch (category) {
      'lpp' => '/lpp-deep/rachat',
      'avs' => '/profile/bilan',
      '3a' => '/simulator/3a',
      'patrimoine' => '/profile/bilan',
      'fiscalite' => '/profile/bilan',
      'menage' => '/household',
      'income' => '/profile/bilan',
      'objectif_retraite' => '/profile/bilan',
      'foreign_pension' => '/profile/bilan',
      'accuracy' => '/document-scan',
      'freshness' => '/profile/bilan',
      _ => '/profile/bilan',
    };
  }

  static String _iconForCategory(String category) {
    return switch (category) {
      'lpp' => 'account_balance',
      'avs' => 'verified_user',
      '3a' => 'savings',
      'patrimoine' => 'trending_up',
      'fiscalite' => 'receipt_long',
      'menage' => 'family_restroom',
      'income' => 'payments',
      'objectif_retraite' => 'flag',
      'foreign_pension' => 'public',
      'accuracy' => 'document_scanner',
      'freshness' => 'update',
      _ => 'info',
    };
  }
}

/// Poids contextuels des 4 axes de visibilite.
/// Somme toujours = 100.
class _AxisWeights {
  final double liquidite;
  final double fiscalite;
  final double retraite;
  final double securite;

  const _AxisWeights({
    required this.liquidite,
    required this.fiscalite,
    required this.retraite,
    required this.securite,
  });
}
