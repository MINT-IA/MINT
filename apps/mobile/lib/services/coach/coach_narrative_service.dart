/// Coach Narrative Service — Sprint S35 / updated S44.
///
/// Generates 4 independent narrative components, each validated through
/// [ComplianceGuard] before reaching the UI:
///   1. Greeting — personalized, context-aware salutation
///   2. Score Summary — FRI score with trend explanation
///   3. Tip Narrative — actionable educational insight
///   4. Chiffre Choc Reframe — contextualizes shock figures
///
/// Synchronous API: uses [FallbackTemplates] as the generation engine
/// (no LLM dependency). If ComplianceGuard flags a violation, falls back
/// to the template output.
///
/// Async LLM-enhanced API (S44): delegates to [CoachOrchestrator] which
/// runs the full SLM → BYOK → FallbackTemplates chain.
///
/// All output text is in French (informal "tu"), free of banned terms,
/// and compliant with LSFin educational framing.
library;

import 'package:mint_mobile/services/coach_llm_service.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';

import 'coach_models.dart';
import 'coach_orchestrator.dart';
import 'compliance_guard.dart';
import 'fallback_templates.dart';

/// Result container for all 4 narrative components.
class CoachNarrativeResult {
  /// Personalized greeting (max 30 words).
  final String greeting;

  /// FRI score summary with trend (max 80 words).
  final String scoreSummary;

  /// Actionable educational tip (max 120 words).
  final String tipNarrative;

  /// Chiffre choc contextualizer (max 100 words).
  final String chiffreChocReframe;

  const CoachNarrativeResult({
    required this.greeting,
    required this.scoreSummary,
    required this.tipNarrative,
    required this.chiffreChocReframe,
  });
}

/// Stateless service that generates compliant coach narratives.
///
/// Every generated text passes through [ComplianceGuard.validate()]
/// before reaching the UI. If validation fails (banned terms,
/// prescriptive language, hallucinated numbers, wrong language),
/// the fallback template is used instead.
class CoachNarrativeService {
  CoachNarrativeService._();

  // ═══════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════

  /// Generate all 4 narrative components in one call.
  ///
  /// Each component is independently validated through ComplianceGuard.
  /// Failure of one component does not affect the others.
  static CoachNarrativeResult generateAll(CoachContext ctx, S s) {
    return CoachNarrativeResult(
      greeting: _generateGreeting(ctx, s),
      scoreSummary: _generateScoreSummary(ctx, s),
      tipNarrative: _generateTipNarrative(ctx, s),
      chiffreChocReframe: _generateChiffreChocReframe(ctx, s),
    );
  }

  /// Generate only the greeting component.
  static String generateGreeting(CoachContext ctx, S s) =>
      _generateGreeting(ctx, s);

  /// Generate only the score summary component.
  static String generateScoreSummary(CoachContext ctx, S s) =>
      _generateScoreSummary(ctx, s);

  /// Generate only the tip narrative component.
  static String generateTipNarrative(CoachContext ctx, S s) =>
      _generateTipNarrative(ctx, s);

  /// Generate only the chiffre choc reframe component.
  static String generateChiffreChocReframe(CoachContext ctx, S s) =>
      _generateChiffreChocReframe(ctx, s);

  /// Generate an enrichment guide for a specific data block.
  ///
  /// Returns a conversational prompt guiding the user to provide
  /// missing data for the given [blockType]. Uses the same
  /// fallback → compliance pipeline as other components.
  static String generateEnrichmentGuide(
    CoachContext ctx, {
    required String blockType,
    required S s,
  }) =>
      _generateEnrichmentGuide(ctx, blockType, s);

  // ═══════════════════════════════════════════════════════════════
  // LLM-enhanced API (S44) — delegates to CoachOrchestrator
  // ═══════════════════════════════════════════════════════════════

  /// Generate all 4 components with SLM → BYOK → template chain.
  ///
  /// Each component is independently generated through [CoachOrchestrator].
  /// [byokConfig] is optional; if null, only SLM and templates are tried.
  static Future<CoachNarrativeResult> generateAllEnhanced(
    CoachContext ctx, {
    LlmConfig? byokConfig,
    required S s,
  }) async {
    // Sequential calls: SlmEngine has an _isGenerating guard that blocks
    // concurrent SLM requests. Parallel Future.wait() would cause 3 of 4
    // components to fall back to templates even when SLM is available.
    final greeting = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.greeting,
      ctx: ctx,
      byokConfig: byokConfig,
      s: s,
    );
    final scoreSummary = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.scoreSummary,
      ctx: ctx,
      byokConfig: byokConfig,
      s: s,
    );
    final tip = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.tip,
      ctx: ctx,
      byokConfig: byokConfig,
      s: s,
    );
    final chiffreChoc = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.chiffreChoc,
      ctx: ctx,
      byokConfig: byokConfig,
      s: s,
    );
    return CoachNarrativeResult(
      greeting: greeting.text,
      scoreSummary: scoreSummary.text,
      tipNarrative: tip.text,
      chiffreChocReframe: chiffreChoc.text,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Internal — generate + validate + fallback
  // ═══════════════════════════════════════════════════════════════

  static String _generateGreeting(CoachContext ctx, S s) {
    final text = FallbackTemplates.greeting(ctx, s);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.greeting,
    );
    return result.useFallback ? FallbackTemplates.greeting(ctx, s) : result.sanitizedText;
  }

  static String _generateScoreSummary(CoachContext ctx, S s) {
    final text = FallbackTemplates.scoreSummary(ctx, s);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.scoreSummary,
    );
    return result.useFallback
        ? FallbackTemplates.scoreSummary(ctx, s)
        : result.sanitizedText;
  }

  static String _generateTipNarrative(CoachContext ctx, S s) {
    final text = FallbackTemplates.tipNarrative(ctx, s);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.tip,
    );
    return result.useFallback
        ? FallbackTemplates.tipNarrative(ctx, s)
        : result.sanitizedText;
  }

  static String _generateChiffreChocReframe(CoachContext ctx, S s) {
    final text = FallbackTemplates.chiffreChocReframe(ctx, s);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.chiffreChoc,
    );
    return result.useFallback
        ? FallbackTemplates.chiffreChocReframe(ctx, s)
        : result.sanitizedText;
  }

  static String _generateEnrichmentGuide(CoachContext ctx, String blockType, S s) {
    final text = FallbackTemplates.enrichmentGuide(ctx, blockType, s);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.enrichmentGuide,
    );
    return result.useFallback
        ? FallbackTemplates.enrichmentGuide(ctx, blockType, s)
        : result.sanitizedText;
  }
}
