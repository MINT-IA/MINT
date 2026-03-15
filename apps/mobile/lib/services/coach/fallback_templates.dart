/// Fallback Templates — Sprint S35 (Coach Narrative).
///
/// Enhanced templates that use [CoachContext] for personalization
/// WITHOUT requiring an LLM call. These serve as the minimum quality
/// bar: if the LLM is unavailable or fails compliance, these are used.
///
/// All user-facing text is i18n via [S] (AppLocalizations).
/// References: LSFin, LAVS, LPP, OPP3, LIFD.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';

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
  static String greeting(CoachContext ctx, S s) {
    final hasName = ctx.firstName.isNotEmpty;
    final salut = hasName
        ? s.fallbackGreetingSalutName(ctx.firstName)
        : s.fallbackGreetingSalut;

    // Same-day return
    if (ctx.daysSinceLastVisit == 0) {
      return hasName
          ? s.fallbackGreetingReturnName(ctx.firstName)
          : s.fallbackGreetingReturn;
    }

    // Recent visit (< 7 days)
    if (ctx.daysSinceLastVisit < 7) {
      return hasName
          ? s.fallbackGreetingRevisitName(ctx.firstName)
          : s.fallbackGreetingRevisit;
    }

    // Fiscal season: 3a deadline (Oct-Dec)
    if (ctx.fiscalSeason == '3a_deadline') {
      return hasName
          ? s.fallbackGreeting3aDeadlineName(ctx.firstName)
          : s.fallbackGreeting3aDeadline;
    }

    // Fiscal season: tax declaration (Feb-Mar)
    if (ctx.fiscalSeason == 'tax_declaration') {
      return hasName
          ? s.fallbackGreetingTaxSeasonName(ctx.firstName)
          : s.fallbackGreetingTaxSeason;
    }

    // Positive delta since last visit
    if (ctx.friDelta > 0) {
      return s.fallbackGreetingDeltaPositive(
        salut,
        ctx.friDelta.toStringAsFixed(0),
      );
    }

    // Negative delta
    if (ctx.friDelta < 0) {
      return s.fallbackGreetingDeltaNegative(
        salut,
        ctx.friDelta.toStringAsFixed(0),
      );
    }

    // Default: show current score
    return s.fallbackGreetingDefault(
      salut,
      ctx.friTotal.toStringAsFixed(0),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Score Summary — max 80 words (ComponentType.scoreSummary)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a score summary with trend indication.
  static String scoreSummary(CoachContext ctx, S s) {
    final score = ctx.friTotal;
    final interpretation = score >= 70
        ? s.fallbackScoreHigh
        : score >= 40
            ? s.fallbackScoreMedium
            : s.fallbackScoreLow;
    final trend = ctx.friDelta > 0
        ? s.fallbackScoreTrendPositive(ctx.friDelta.toStringAsFixed(0))
        : ctx.friDelta < 0
            ? s.fallbackScoreTrendNegative(ctx.friDelta.toStringAsFixed(0))
            : '';
    return '$interpretation$trend';
  }

  // ═══════════════════════════════════════════════════════════════
  // Tip Narrative — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a personalized educational tip based on the user's
  /// most impactful financial lever.
  static String tipNarrative(CoachContext ctx, S s) {
    final taxSaving = ctx.knownValues['tax_saving'] ?? 0;
    final liquidity = ctx.knownValues['months_liquidity'] ?? 6;
    final replacement = ctx.knownValues['replacement_ratio'] ?? 60;

    // Tax optimization lever (> CHF 1000 potential)
    if (taxSaving > 1000) {
      return s.fallbackTipTaxSaving(
        ctx.firstName,
        taxSaving.toStringAsFixed(0),
      );
    }

    // Liquidity alert (< 3 months of reserves)
    if (liquidity < 3) {
      return s.fallbackTipLiquidityAlert(
        ctx.firstName,
        liquidity.toStringAsFixed(0),
      );
    }

    // Retirement gap (replacement ratio < 55%)
    if (replacement < 55) {
      return s.fallbackTipRetirementGap(
        ctx.firstName,
        replacement.toStringAsFixed(0),
      );
    }

    // Default: encourage profile completion with specific enrichment action
    final enrichment = _topEnrichmentAction(ctx, s);
    if (enrichment != null) {
      return s.fallbackTipEnrichmentGeneric(ctx.firstName, enrichment);
    }
    return s.fallbackTipDefault(ctx.firstName);
  }

  // ═══════════════════════════════════════════════════════════════
  // Chiffre Choc Reframe — max 100 words (ComponentType.chiffreChoc)
  // ═══════════════════════════════════════════════════════════════

  /// Contextualizes a shock figure with confidence level and
  /// encourages profile enrichment based on data reliability.
  static String chiffreChocReframe(CoachContext ctx, S s) {
    final confidence = ctx.knownValues['confidence_score'] ?? 30;
    final hasCertifiedData = ctx.dataReliability.values
        .any((v) => v == 'certified');

    if (hasCertifiedData) {
      return s.fallbackChiffreChocCertified;
    }
    final enrichment = _topEnrichmentAction(ctx, s);
    if (confidence < 40) {
      return s.fallbackChiffreChocLowConfidence(
        confidence.toStringAsFixed(0),
        enrichment ?? s.fallbackChiffreChocAddData,
      );
    }
    return s.fallbackChiffreChocDefault(
      confidence.toStringAsFixed(0),
      enrichment ?? s.fallbackChiffreChocMorePrecise,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Enrichment Guide — max 150 words (ComponentType.enrichmentGuide)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a conversational enrichment prompt for a data block.
  /// Used in DataBlockEnrichmentScreen "coach mode".
  static String enrichmentGuide(CoachContext ctx, String blockType, S s) {
    final name = ctx.firstName;
    return switch (blockType) {
      'lpp' => s.fallbackEnrichmentLpp(name),
      'avs' => ctx.archetype.contains('expat')
          ? s.fallbackEnrichmentAvsExpat(name)
          : s.fallbackEnrichmentAvsStandard(name),
      '3a' => s.fallbackEnrichment3a(name),
      'patrimoine' => s.fallbackEnrichmentPatrimoine(name),
      'fiscalite' => s.fallbackEnrichmentFiscalite(name),
      'objectifRetraite' => s.fallbackEnrichmentObjectifRetraite(name),
      'compositionMenage' => s.fallbackEnrichmentCompositionMenage(name),
      _ => s.fallbackEnrichmentDefault(name),
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // FATCA Guidance — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about FATCA obligations for US
  /// citizens/residents in Switzerland. Falls back to a generic
  /// nationality-awareness message for non-US archetypes.
  static String fatcaGuidance(CoachContext ctx, S s) {
    if (ctx.archetype != 'expat_us') {
      return s.fallbackFatcaNonUs(ctx.firstName);
    }
    return s.fallbackFatcaUs(ctx.firstName);
  }

  // ═══════════════════════════════════════════════════════════════
  // Succession Planning — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about Swiss succession law,
  /// pillar beneficiary rules, and cantonal tax implications.
  static String successionPlanning(CoachContext ctx, S s) {
    final cantonNote = ctx.canton.isNotEmpty
        ? s.fallbackSuccessionCantonNote(ctx.canton)
        : '';

    return s.fallbackSuccessionPlanning(ctx.firstName, cantonNote);
  }

  // ═══════════════════════════════════════════════════════════════
  // Libre Passage Guide — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about libre passage accounts
  /// after job change or unemployment.
  static String librePassageGuide(CoachContext ctx, S s) {
    return s.fallbackLibrePassageGuide(ctx.firstName);
  }

  // ═══════════════════════════════════════════════════════════════
  // Disability Bridge — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about disability insurance (AI),
  /// LPP disability benefits, and prevoyance gaps.
  static String disabilityBridge(CoachContext ctx, S s) {
    final ageNote = ctx.age < 55
        ? s.fallbackDisabilityAgeNote(ctx.age)
        : '';

    return s.fallbackDisabilityBridge(ctx.firstName, ageNote);
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Returns the single most impactful enrichment action based on
  /// which key data is still missing or estimated.
  static String? _topEnrichmentAction(CoachContext ctx, S s) {
    final rel = ctx.dataReliability;
    // Priority 1: no certified LPP → suggest scan
    final hasLpp = rel.entries.any(
        (e) => e.key.contains('avoirLpp') && e.value == 'certified');
    if (!hasLpp) {
      return s.fallbackEnrichmentActionLpp;
    }
    // Priority 2: no certified AVS → suggest scan
    final hasAvs = rel.entries.any(
        (e) => e.key.contains('anneesContribuees') && e.value == 'certified');
    if (!hasAvs) {
      return s.fallbackEnrichmentActionAvs;
    }
    // Priority 3: no salary data
    final hasSalary = rel.containsKey('salaireBrutMensuel');
    if (!hasSalary) {
      return s.fallbackEnrichmentActionSalary;
    }
    return null;
  }
}
