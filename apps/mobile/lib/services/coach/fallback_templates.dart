/// Fallback Templates — Sprint S35 (Coach Narrative).
///
/// Enhanced templates that use [CoachContext] for personalization
/// WITHOUT requiring an LLM call. These serve as the minimum quality
/// bar: if the LLM is unavailable or fails compliance, these are used.
///
/// All text in French (informal "tu"). No banned terms.
/// References: LSFin, LAVS, LPP, OPP3, LIFD.
library;

import 'coach_models.dart';

class FallbackTemplates {
  FallbackTemplates._();

  // ═══════════════════════════════════════════════════════════════
  // Greeting — max 30 words (ComponentType.greeting)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a personalized greeting based on context signals:
  /// - Days since last visit
  /// - Fiscal season
  /// - FRI score delta
  static String greeting(CoachContext ctx) {
    final hasName = ctx.firstName.isNotEmpty;
    final salut = hasName ? 'Salut ${ctx.firstName}.' : 'Bonjour.';

    // Same-day return
    if (ctx.daysSinceLastVisit == 0) {
      return hasName ? 'Bon retour, ${ctx.firstName}.' : 'Bon retour.';
    }

    // Recent visit (< 7 days)
    if (ctx.daysSinceLastVisit < 7) {
      return hasName ? 'Content de te revoir, ${ctx.firstName}.' : 'Content de te revoir.';
    }

    // Fiscal season: 3a deadline (Oct-Dec)
    if (ctx.fiscalSeason == '3a_deadline') {
      return hasName
          ? '${ctx.firstName}, pense à ton 3a avant la fin de l\'année.'
          : 'Pense à ton 3a avant la fin de l\'année.';
    }

    // Fiscal season: tax declaration (Feb-Mar)
    if (ctx.fiscalSeason == 'tax_declaration') {
      return hasName
          ? '${ctx.firstName}, c\'est la saison de la déclaration fiscale.'
          : 'C\'est la saison de la déclaration fiscale.';
    }

    // Positive delta since last visit
    if (ctx.friDelta > 0) {
      return '$salut +${ctx.friDelta.toStringAsFixed(0)} points depuis ta dernière visite.';
    }

    // Negative delta
    if (ctx.friDelta < 0) {
      return '$salut Ton score a bougé de ${ctx.friDelta.toStringAsFixed(0)} points.';
    }

    // Default: show current score
    return '$salut Ton score de solidité : ${ctx.friTotal.toStringAsFixed(0)}/100.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Score Summary — max 80 words (ComponentType.scoreSummary)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a score summary with trend indication.
  static String scoreSummary(CoachContext ctx) {
    final trend = ctx.friDelta > 0
        ? 'En progression de ${ctx.friDelta.toStringAsFixed(0)} points.'
        : ctx.friDelta < 0
            ? 'En recul de ${ctx.friDelta.abs().toStringAsFixed(0)} points.'
            : 'Stable.';
    return 'Solidité financière : ${ctx.friTotal.toStringAsFixed(0)}/100. $trend';
  }

  // ═══════════════════════════════════════════════════════════════
  // Tip Narrative — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a personalized educational tip based on the user's
  /// most impactful financial lever.
  static String tipNarrative(CoachContext ctx) {
    final taxSaving = ctx.knownValues['tax_saving'] ?? 0;
    final liquidity = ctx.knownValues['months_liquidity'] ?? 6;
    final replacement = ctx.knownValues['replacement_ratio'] ?? 60;

    // Tax optimization lever (> CHF 1000 potential)
    if (taxSaving > 1000) {
      return '${ctx.firstName}, un versement 3a pourrait réduire ton impôt '
          'd\'environ CHF ${taxSaving.toStringAsFixed(0)} cette année. '
          'Simule l\'impact sur ton profil.';
    }

    // Liquidity alert (< 3 months of reserves)
    if (liquidity < 3) {
      return 'Ta réserve de liquidité couvre environ '
          '${liquidity.toStringAsFixed(1)} mois. '
          'Un objectif de 3 à 6 mois est souvent considéré comme une base solide.';
    }

    // Retirement gap (replacement ratio < 55%)
    if (replacement < 55) {
      return 'Ton taux de remplacement estimé à la retraite est de '
          '${replacement.toStringAsFixed(0)}%. '
          'Explore les options pour combler l\'écart dans le simulateur.';
    }

    // Default: encourage profile completion with specific enrichment action
    final enrichment = _topEnrichmentAction(ctx);
    if (enrichment != null) {
      return 'Ton score de solidité est de '
          '${ctx.friTotal.toStringAsFixed(0)}/100. $enrichment';
    }
    return 'Ton score de solidité est de '
        '${ctx.friTotal.toStringAsFixed(0)}/100. '
        'Continue à affiner ton profil pour des estimations plus précises.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Chiffre Choc Reframe — max 100 words (ComponentType.chiffreChoc)
  // ═══════════════════════════════════════════════════════════════

  /// Contextualizes a shock figure with confidence level and
  /// encourages profile enrichment based on data reliability.
  static String chiffreChocReframe(CoachContext ctx) {
    final confidence = ctx.knownValues['confidence_score'] ?? 30;
    final hasCertifiedData = ctx.dataReliability.values
        .any((v) => v == 'certified');

    if (hasCertifiedData) {
      return 'Ce chiffre s\'appuie sur des données certifiées '
          '(confiance : ${confidence.toStringAsFixed(0)}%). '
          'Continue à enrichir ton profil pour affiner l\'estimation.';
    }
    final enrichment = _topEnrichmentAction(ctx);
    return 'Ce chiffre est basé sur '
        '${confidence.toStringAsFixed(0)}% de données concrètes. '
        '${enrichment ?? 'Plus tu précises ton profil, plus l\'estimation s\'affine.'}';
  }

  // ═══════════════════════════════════════════════════════════════
  // Enrichment Guide — max 150 words (ComponentType.enrichmentGuide)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a conversational enrichment prompt for a data block.
  /// Used in DataBlockEnrichmentScreen "coach mode".
  static String enrichmentGuide(CoachContext ctx, String blockType) {
    final name = ctx.firstName;
    return switch (blockType) {
      'lpp' =>
        '$name, connais-tu ton avoir LPP actuel? '
        'Ton certificat de prevoyance (2e pilier) indique le montant exact. '
        'Avec ton salaire et ton age, l\'estimation pourrait varier '
        'significativement du reel. Un scan du certificat affinerait '
        'tes projections de +18 points de confiance.',
      'avs' =>
        '$name, as-tu deja demande ton extrait de compte AVS? '
        'Il confirme tes annees de cotisation effectives. '
        '${ctx.archetype.contains('expat') ? 'En tant qu\'expatrie, des lacunes sont probables. ' : ''}'
        'Commander un extrait est gratuit sur le site de ta caisse de compensation.',
      '3a' =>
        '$name, combien de comptes 3a as-tu et chez quel provider? '
        'Connaitre les soldes exacts permet de calculer ton avantage fiscal '
        'et de projeter ta prevoyance complete.',
      'patrimoine' =>
        '$name, as-tu de l\'epargne en dehors de la prevoyance? '
        'Comptes courants, investissements, immobilier — ces donnees '
        'completent ton Financial Resilience Index.',
      'fiscalite' =>
        '$name, dans quelle commune habites-tu? '
        'Le coefficient communal varie de 60% a 130% et impacte '
        'directement ton taux d\'imposition reel. '
        'Une declaration fiscale ou un avis de taxation donnerait un calcul precis.',
      'objectifRetraite' =>
        '$name, a quel age souhaiterais-tu arreter de travailler? '
        'Entre 58 et 70 ans, chaque annee change la donne : '
        'rente reduite avant 65 ans, majoree apres.',
      'compositionMenage' =>
        '$name, es-tu en couple? '
        'Si oui, les projections changent significativement : '
        'AVS plafonnee pour les maries, rente de survivant LPP, '
        'et possibilites d\'optimisation fiscale a deux.',
      _ =>
        '$name, continue a enrichir ton profil. '
        'Chaque donnee ajoutee ameliore la precision de tes projections.',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Returns the single most impactful enrichment action based on
  /// which key data is still missing or estimated.
  static String? _topEnrichmentAction(CoachContext ctx) {
    final rel = ctx.dataReliability;
    // Priority 1: no certified LPP → suggest scan
    final hasLpp = rel.entries.any(
        (e) => e.key.contains('avoirLpp') && e.value == 'certified');
    if (!hasLpp) {
      return 'Scanne ton certificat LPP pour des projections plus fiables.';
    }
    // Priority 2: no certified AVS → suggest scan
    final hasAvs = rel.entries.any(
        (e) => e.key.contains('anneesContribuees') && e.value == 'certified');
    if (!hasAvs) {
      return 'Scanne ton extrait AVS pour affiner ta rente estimée.';
    }
    // Priority 3: no salary data
    final hasSalary = rel.containsKey('salaireBrutMensuel');
    if (!hasSalary) {
      return 'Renseigne ton salaire brut pour des projections personnalisées.';
    }
    return null;
  }
}
