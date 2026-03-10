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
//  4 axes (ponderation contextuelle Phase 1) :
//    Liquidite — Budget, epargne, dettes, coussin securite
//    Fiscalite — Canton, 3a, rachats, taux marginal
//    Retraite  — AVS, LPP, 3a, age retraite
//    Securite  — Assurances, protection famille, succession
//
//  Poids : adaptes par age + archetype (ex: 50+ → retraite 35/100,
//  jeune → liquidite 30/100, independant → securite +5).
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
  ///
  /// Phase 1 : ponderation contextuelle par age et archetype.
  /// Les 4 axes sont ponderes differemment selon le profil :
  ///   - 50+ ans → retraite surponderee (35 pts)
  ///   - < 35 ans → liquidite/budget surponderee (30 pts)
  ///   - independant → securite surponderee (30 pts)
  ///   - expat → securite + fiscalite surponderees
  static VisibilityScore compute(CoachProfile profile) {
    final blocs = ConfidenceScorer.scoreAsBlocs(profile);
    final confidence = ConfidenceScorer.score(profile);

    // ── Poids contextuels ─────────────────────────────────
    final weights = _contextualWeights(profile);

    // ── Regrouper les blocs en 4 axes (poids variables) ──
    final liquidite = _computeLiquiditeAxis(blocs, profile,
        maxScore: weights['liquidite']!);
    final fiscalite = _computeFiscaliteAxis(blocs, profile,
        maxScore: weights['fiscalite']!);
    final retraite = _computeRetraiteAxis(blocs, profile,
        maxScore: weights['retraite']!);
    final securite = _computeSecuriteAxis(blocs, profile,
        maxScore: weights['securite']!);

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

  /// Ponderation contextuelle basee sur l'age et l'archetype.
  ///
  /// Retourne un map {axeId: maxPoints} dont la somme = 100.
  static Map<String, double> _contextualWeights(CoachProfile profile) {
    final now = DateTime.now();
    final age = now.year - profile.birthYear;
    final isIndependant = profile.employmentStatus == 'independant';
    final isExpat = profile.nationality != null &&
        profile.nationality != 'CH' &&
        profile.nationality!.isNotEmpty;

    // ── Defaut : uniforme 25/25/25/25 ────────────────────
    double wLiquidite = 25;
    double wFiscalite = 25;
    double wRetraite = 25;
    double wSecurite = 25;

    // ── Ajustements par age ──────────────────────────────
    if (age >= 55) {
      // Proche de la retraite → retraite tres importante
      wRetraite = 35;
      wLiquidite = 20;
      wFiscalite = 25;
      wSecurite = 20;
    } else if (age >= 45) {
      // Preparation retraite → retraite + fiscalite
      wRetraite = 30;
      wLiquidite = 20;
      wFiscalite = 28;
      wSecurite = 22;
    } else if (age < 35) {
      // Jeune actif → liquidite + budget prioritaire
      wLiquidite = 30;
      wRetraite = 20;
      wFiscalite = 25;
      wSecurite = 25;
    }

    // ── Ajustements par archetype ────────────────────────
    if (isIndependant) {
      // Independant : securite cruciale (pas de filet employeur)
      wSecurite += 5;
      wLiquidite -= 5;
    }
    if (isExpat) {
      // Expat : fiscalite + securite (conventions, FATCA, etc.)
      wFiscalite += 3;
      wSecurite += 2;
      wLiquidite -= 3;
      wRetraite -= 2;
    }

    // ── Normaliser a 100 ────────────────────────────────
    final sum = wLiquidite + wFiscalite + wRetraite + wSecurite;
    if (sum != 100) {
      final factor = 100 / sum;
      wLiquidite *= factor;
      wFiscalite *= factor;
      wRetraite *= factor;
      wSecurite *= factor;
    }

    return {
      'liquidite': wLiquidite,
      'fiscalite': wFiscalite,
      'retraite': wRetraite,
      'securite': wSecurite,
    };
  }

  /// Calcule le score couple avec alerte point faible.
  static VisibilityScore computeCouple(
    CoachProfile userProfile,
    CoachProfile conjointProfile,
  ) {
    final userScore = compute(userProfile);
    final conjScore = compute(conjointProfile);

    // Moyenne ponderee par revenu
    final userRevenu = userProfile.salaireBrutMensuel * 12;
    final conjRevenu = conjointProfile.salaireBrutMensuel * 12;
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
        status: avgScore >= uAxis.maxScore * 0.7
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
  //  AXES — regroupement des blocs ConfidenceScorer
  // ════════════════════════════════════════════════════════════

  static VisibilityAxis _computeLiquiditeAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, {
    double maxScore = 25,
  }) {
    // Liquidite = revenu (12) + patrimoine (7) = 19 pts max dans scorer
    final revenu = blocs['revenu']?.score ?? 0;
    final patrimoine = blocs['patrimoine']?.score ?? 0;
    final raw = revenu + patrimoine; // max 19
    final normalized = (raw / 19 * maxScore).clamp(0.0, maxScore);

    final threshold80 = maxScore * 0.8;
    final threshold40 = maxScore * 0.4;
    final status = normalized >= threshold80
        ? 'complete'
        : normalized >= threshold40
            ? 'partial'
            : 'missing';

    return VisibilityAxis(
      id: 'liquidite',
      label: 'Liquidite',
      icon: 'wallet',
      score: normalized,
      maxScore: maxScore,
      status: status,
      hint: revenu == 0
          ? 'Ajoute ton salaire pour commencer'
          : patrimoine == 0
              ? 'Renseigne ton epargne et investissements'
              : 'Tes donnees de liquidite sont completes',
    );
  }

  static VisibilityAxis _computeFiscaliteAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, {
    double maxScore = 25,
  }) {
    // Fiscalite = fiscalite bloc (max 15) + age_canton (8) = 23 pts max
    final fiscal = blocs['fiscalite']?.score ?? 0;
    final ageCanton = blocs['age_canton']?.score ?? 0;
    final raw = fiscal + ageCanton; // max 23
    final normalized = (raw / 23 * maxScore).clamp(0.0, maxScore);

    final threshold80 = maxScore * 0.8;
    final threshold40 = maxScore * 0.4;
    final status = normalized >= threshold80
        ? 'complete'
        : normalized >= threshold40
            ? 'partial'
            : 'missing';

    return VisibilityAxis(
      id: 'fiscalite',
      label: 'Fiscalite',
      icon: 'receipt',
      score: normalized,
      maxScore: maxScore,
      status: status,
      hint: ageCanton == 0
          ? 'Indique ton age et canton de residence'
          : fiscal < 8
              ? 'Scanne ta declaration fiscale'
              : 'Tes donnees fiscales sont completes',
    );
  }

  static VisibilityAxis _computeRetraiteAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, {
    double maxScore = 25,
  }) {
    // Retraite = objectifRetraite (10) + lpp (18) + taux_conversion (5) +
    //            avs (10) + 3a (8) = 51 pts max
    final objectif = blocs['objectifRetraite']?.score ?? 0;
    final lpp = blocs['lpp']?.score ?? 0;
    final taux = blocs['taux_conversion']?.score ?? 0;
    final avs = blocs['avs']?.score ?? 0;
    final troisA = blocs['3a']?.score ?? 0;
    final raw = objectif + lpp + taux + avs + troisA; // max 51
    final normalized = (raw / 51 * maxScore).clamp(0.0, maxScore);

    final threshold80 = maxScore * 0.8;
    final threshold40 = maxScore * 0.4;
    final status = normalized >= threshold80
        ? 'complete'
        : normalized >= threshold40
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
      hint = 'Tes donnees retraite sont completes';
    }

    return VisibilityAxis(
      id: 'retraite',
      label: 'Retraite',
      icon: 'beach_access',
      score: normalized,
      maxScore: maxScore,
      status: status,
      hint: hint,
    );
  }

  static VisibilityAxis _computeSecuriteAxis(
    Map<String, BlockScore> blocs,
    CoachProfile profile, {
    double maxScore = 25,
  }) {
    // Securite = menage (15) + archetype (5) + foreign_pension (2) = 22 pts max
    final menage = blocs['compositionMenage']?.score ?? 0;
    final archetype = blocs['archetype']?.score ?? 0;
    final foreign = blocs['foreign_pension']?.score ?? 0;
    final raw = menage + archetype + foreign; // max 22
    final normalized = (raw / 22 * maxScore).clamp(0.0, maxScore);

    final threshold80 = maxScore * 0.8;
    final threshold40 = maxScore * 0.4;
    final status = normalized >= threshold80
        ? 'complete'
        : normalized >= threshold40
            ? 'partial'
            : 'missing';

    return VisibilityAxis(
      id: 'securite',
      label: 'Securite',
      icon: 'shield',
      score: normalized,
      maxScore: maxScore,
      status: status,
      hint: menage == 0
          ? 'Indique ta situation familiale'
          : archetype == 0
              ? 'Complete ton statut professionnel'
              : 'Tes donnees de securite sont completes',
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
          'Continue a maintenir tes donnees a jour.';
    } else if (percentage >= 60) {
      return 'Bonne visibilite ! '
          'Affine ta ${weakest?.label.toLowerCase() ?? 'situation'} pour aller plus loin.';
    } else if (percentage >= 40) {
      return 'Tu commences a y voir plus clair. '
          'Concentre-toi sur ta ${weakest?.label.toLowerCase() ?? 'situation'}.';
    } else {
      return 'Chaque information compte. '
          'Commence par ${weakest?.hint.toLowerCase() ?? 'renseigner tes donnees'}.';
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
