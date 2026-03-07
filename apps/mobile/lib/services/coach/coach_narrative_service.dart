/// Coach Narrative Service — Sprint S35.
///
/// Generates 4 independent narrative components, each validated through
/// [ComplianceGuard] before reaching the UI:
///   1. Greeting — personalized, context-aware salutation
///   2. Score Summary — FRI score with trend explanation
///   3. Tip Narrative — actionable educational insight
///   4. Chiffre Choc Reframe — contextualizes shock figures
///
/// Uses [FallbackTemplates] as the generation engine (no LLM dependency).
/// If ComplianceGuard flags a violation, falls back to the template output.
///
/// All output text is in French (informal "tu"), free of banned terms,
/// and compliant with LSFin educational framing.
library;

import 'coach_models.dart';
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
  static CoachNarrativeResult generateAll(CoachContext ctx) {
    return CoachNarrativeResult(
      greeting: _generateGreeting(ctx),
      scoreSummary: _generateScoreSummary(ctx),
      tipNarrative: _generateTipNarrative(ctx),
      chiffreChocReframe: _generateChiffreChocReframe(ctx),
    );
  }

  /// Generate only the greeting component.
  static String generateGreeting(CoachContext ctx) => _generateGreeting(ctx);

  /// Generate only the score summary component.
  static String generateScoreSummary(CoachContext ctx) =>
      _generateScoreSummary(ctx);

  /// Generate only the tip narrative component.
  static String generateTipNarrative(CoachContext ctx) =>
      _generateTipNarrative(ctx);

  /// Generate only the chiffre choc reframe component.
  static String generateChiffreChocReframe(CoachContext ctx) =>
      _generateChiffreChocReframe(ctx);

  /// Generate an enrichment guide for a specific data block.
  ///
  /// Returns a conversational prompt guiding the user to provide
  /// missing data for the given [blockType]. Uses the same
  /// fallback → compliance pipeline as other components.
  static String generateEnrichmentGuide(
    CoachContext ctx, {
    required String blockType,
  }) =>
      _generateEnrichmentGuide(ctx, blockType);

  // ═══════════════════════════════════════════════════════════════
  // Internal — generate + validate + fallback
  // ═══════════════════════════════════════════════════════════════

  static String _generateGreeting(CoachContext ctx) {
    final text = FallbackTemplates.greeting(ctx);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.greeting,
    );
    return result.useFallback ? FallbackTemplates.greeting(ctx) : result.sanitizedText;
  }

  static String _generateScoreSummary(CoachContext ctx) {
    final text = FallbackTemplates.scoreSummary(ctx);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.scoreSummary,
    );
    return result.useFallback
        ? FallbackTemplates.scoreSummary(ctx)
        : result.sanitizedText;
  }

  static String _generateTipNarrative(CoachContext ctx) {
    final text = FallbackTemplates.tipNarrative(ctx);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.tip,
    );
    return result.useFallback
        ? FallbackTemplates.tipNarrative(ctx)
        : result.sanitizedText;
  }

  static String _generateChiffreChocReframe(CoachContext ctx) {
    final text = FallbackTemplates.chiffreChocReframe(ctx);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.chiffreChoc,
    );
    return result.useFallback
        ? FallbackTemplates.chiffreChocReframe(ctx)
        : result.sanitizedText;
  }

  static String _generateEnrichmentGuide(CoachContext ctx, String blockType) {
    final text = FallbackTemplates.enrichmentGuide(ctx, blockType);
    final result = ComplianceGuard.validate(
      text,
      context: ctx,
      componentType: ComponentType.enrichmentGuide,
    );
    return result.useFallback
        ? FallbackTemplates.enrichmentGuide(ctx, blockType)
        : result.sanitizedText;
  }
}
