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
    // Same-day return
    if (ctx.daysSinceLastVisit == 0) {
      return 'Bon retour, ${ctx.firstName}.';
    }

    // Recent visit (< 7 days)
    if (ctx.daysSinceLastVisit < 7) {
      return 'Content de te revoir, ${ctx.firstName}.';
    }

    // Fiscal season: 3a deadline (Oct-Dec)
    if (ctx.fiscalSeason == '3a_deadline') {
      return '${ctx.firstName}, pense à ton 3a avant la fin de l\'année.';
    }

    // Fiscal season: tax declaration (Feb-Mar)
    if (ctx.fiscalSeason == 'tax_declaration') {
      return '${ctx.firstName}, c\'est la saison de la déclaration fiscale.';
    }

    // Positive delta since last visit
    if (ctx.friDelta > 0) {
      return 'Salut ${ctx.firstName}. '
          '+${ctx.friDelta.toStringAsFixed(0)} points depuis ta dernière visite.';
    }

    // Negative delta
    if (ctx.friDelta < 0) {
      return 'Salut ${ctx.firstName}. '
          'Ton score a bougé de ${ctx.friDelta.toStringAsFixed(0)} points.';
    }

    // Default: show current score
    return 'Salut ${ctx.firstName}. '
        'Ton score de solidité : ${ctx.friTotal.toStringAsFixed(0)}/100.';
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

    // Default: encourage profile completion
    return 'Ton score de solidité est de '
        '${ctx.friTotal.toStringAsFixed(0)}/100. '
        'Continue à affiner ton profil pour des estimations plus précises.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Chiffre Choc Reframe — max 100 words (ComponentType.chiffreChoc)
  // ═══════════════════════════════════════════════════════════════

  /// Contextualizes a shock figure with confidence level and
  /// encourages profile enrichment.
  static String chiffreChocReframe(CoachContext ctx) {
    final confidence = ctx.knownValues['confidence_score'] ?? 30;
    return 'Ce chiffre est basé sur '
        '${confidence.toStringAsFixed(0)}% de données concrètes. '
        'Plus tu précises ton profil, plus l\'estimation s\'affine.';
  }
}
