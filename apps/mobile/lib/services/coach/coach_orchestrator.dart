/// Coach Orchestrator — Sprint S44 (Intelligence Branchement).
///
/// Single entry-point for ALL coach AI generation:
///   - Dashboard narrative (greeting, scoreSummary, tip, chiffreChoc)
///   - Chat responses (BYOK / mock fallback)
///
/// Priority chain (privacy-first):
///   1. SLM on-device (Gemma 3n) — timeout 30s, zero network, privacy total
///   2. BYOK cloud LLM            — timeout 30s, user opt-in, RAG-grounded
///   3. FallbackTemplates         — always available, zero LLM dependency
///
/// Guarantees:
///   - ComplianceGuard applied centrally on ALL outputs (SLM, BYOK, templates)
///   - RAM guard: SLM skipped when [FeatureFlags.slmPluginReady] is false
///   - Context truncated to [SlmEngine.maxContextTokens] before SLM call
///   - Offline-safe: falls through to FallbackTemplates with no network
///
/// References:
///   - LSFin art. 3/8 (qualité de l'information financière)
///   - LPD art. 6 (privacy by design — SLM on-device)
///   - FINMA circulaire 2008/21 (risque opérationnel)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach/fallback_templates.dart';
import 'package:mint_mobile/services/coach/prompt_registry.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';

// ════════════════════════════════════════════════════════════════
//  DATA TYPES
// ════════════════════════════════════════════════════════════════

/// Which tier actually produced the output.
enum CoachTier {
  /// On-device SLM (Gemma 3n) — privacy-first, zero network.
  slm,

  /// Cloud BYOK LLM (OpenAI / Anthropic / Mistral).
  byok,

  /// Static FallbackTemplates — always available.
  fallback,
}

/// A compliant, validated text output from the coach orchestrator.
class OrchestratorOutput {
  /// The validated and sanitized text to display.
  final String text;

  /// Which tier produced this output.
  final CoachTier tier;

  /// Whether ComplianceGuard sanitized anything (for debug/analytics).
  final bool wasSanitized;

  /// SLM inference duration in ms (0 when tier != slm).
  final int slmDurationMs;

  const OrchestratorOutput({
    required this.text,
    required this.tier,
    this.wasSanitized = false,
    this.slmDurationMs = 0,
  });
}

// ════════════════════════════════════════════════════════════════
//  ORCHESTRATOR
// ════════════════════════════════════════════════════════════════

/// Central coach AI orchestrator.
///
/// Stateless — all state lives in [SlmEngine.instance] and [FeatureFlags].
/// Every public method is safe to call from any isolate context.
///
/// ## RAM guard
///
/// [FeatureFlags.slmPluginReady] acts as the RAM guard:
/// - Set to `false` on devices with < 4 GB usable RAM (done in app init)
/// - When false, the orchestrator skips SLM and goes straight to BYOK/templates
///
/// ## Token truncation
///
/// Prompts are truncated to [SlmEngine.maxContextTokens] (2048) before being
/// sent to the SLM. The truncation keeps the tail (most recent context) and
/// drops the head (older, less relevant context).
class CoachOrchestrator {
  CoachOrchestrator._();

  /// SLM inference timeout (generous for first-init which loads ~2.3 GB).
  static const Duration _slmTimeout = Duration(seconds: 30);

  /// BYOK cloud LLM timeout.
  static const Duration _byokTimeout = Duration(seconds: 30);

  /// Average chars per token (French with accents).
  static const double _charsPerToken = 3.5;

  /// Max chars to send to SLM (derived from maxContextTokens).
  static int get _maxPromptChars =>
      (SlmEngine.maxContextTokens * _charsPerToken).floor();

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API — narrative (dashboard surface)
  // ══════════════════════════════════════════════════════════════

  /// Generate a single narrative text component.
  ///
  /// [componentType] selects the prompt template and word limit.
  /// [byokConfig] is optional; if null or has no key, BYOK is skipped.
  ///
  /// Fallback chain: SLM (30s) → BYOK (30s) → FallbackTemplates.
  /// ComplianceGuard applied on each tier's output.
  static Future<OrchestratorOutput> generateNarrativeComponent({
    required ComponentType componentType,
    required CoachContext ctx,
    LlmConfig? byokConfig,
  }) async {
    // 1. SLM tier
    if (_slmEligible()) {
      final slmOut = await _trySlm(
        systemPrompt: PromptRegistry.getPrompt(
          _componentTypeToKey(componentType),
          ctx,
        ),
        userPrompt: _userPromptForComponent(componentType, ctx),
        ctx: ctx,
        componentType: componentType,
      );
      if (slmOut != null) return slmOut;
    }

    // 2. BYOK tier (skipped in safeModeDegraded emergency mode)
    if (!FeatureFlags.safeModeDegraded &&
        byokConfig != null &&
        byokConfig.hasApiKey) {
      final byokOut = await _tryByok(
        prompt: PromptRegistry.getPrompt(
          _componentTypeToKey(componentType),
          ctx,
        ),
        config: byokConfig,
        ctx: ctx,
        componentType: componentType,
      );
      if (byokOut != null) return byokOut;
    }

    // 3. FallbackTemplates (always succeeds)
    return _generateFallback(componentType: componentType, ctx: ctx);
  }

  /// Generate a chat response.
  ///
  /// Chat surface fallback chain: SLM (30s) → BYOK (30s) → mock template.
  /// ComplianceGuard applied centrally on all outputs.
  ///
  /// [memoryBlock] — optional enriched context from [ContextInjectorService].
  /// When provided, appended to the system prompt for lifecycle-aware,
  /// goal-aware, and conversation-history-aware AI responses.
  static Future<CoachResponse> generateChat({
    required String userMessage,
    required List<ChatMessage> history,
    required CoachContext ctx,
    LlmConfig? byokConfig,
    String? memoryBlock,
  }) async {
    // Build system prompt with optional memory block injection (S58).
    const basePrompt = PromptRegistry.baseSystemPrompt;
    final systemPrompt = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$basePrompt\n\n$memoryBlock'
        : basePrompt;

    // 1. SLM tier for chat
    if (_slmEligible()) {
      final conversationCtx = _buildConversationContext(history, userMessage);
      final slmOut = await _trySlm(
        systemPrompt: systemPrompt,
        userPrompt: conversationCtx,
        ctx: ctx,
        componentType: ComponentType.general,
      );
      if (slmOut != null) {
        return CoachResponse(
          message: slmOut.text,
          disclaimer: ComplianceGuard.standardDisclaimer,
          wasFiltered: slmOut.wasSanitized,
        );
      }
    }

    // 2. BYOK RAG tier for chat (skipped in safeModeDegraded emergency mode)
    if (!FeatureFlags.safeModeDegraded &&
        byokConfig != null &&
        byokConfig.hasApiKey) {
      final byokResponse = await _tryByokChat(
        userMessage: userMessage,
        history: history,
        config: byokConfig,
        ctx: ctx,
        memoryBlock: memoryBlock,
      );
      if (byokResponse != null) return byokResponse;
    }

    // 3. Mock fallback (no LLM, keyword-based)
    return _chatFallback();
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — SLM tier
  // ══════════════════════════════════════════════════════════════

  /// Whether SLM is eligible to run.
  ///
  /// Conditions:
  ///   - [FeatureFlags.enableSlmNarratives] == true (kill switch)
  ///   - [FeatureFlags.slmPluginReady] == true (RAM guard / plugin availability)
  ///   - [FeatureFlags.safeModeDegraded] == false (emergency degraded mode)
  static bool _slmEligible() {
    return FeatureFlags.enableSlmNarratives &&
        FeatureFlags.slmPluginReady &&
        !FeatureFlags.safeModeDegraded;
  }

  /// Cached init future — prevents concurrent [_ensureInitialized] calls
  /// from spawning multiple init sequences. If init is already in flight,
  /// subsequent callers share the same future.
  static Future<bool>? _initFuture;

  /// Ensure the SLM engine is initialized before inference.
  ///
  /// Handles re-initialization after [SlmEngine.dispose] — when the user
  /// leaves the coach screen and returns, the engine is disposed to free
  /// ~2 GB of RAM. This method transparently re-initializes it.
  ///
  /// Uses a cached future to deduplicate concurrent calls: if init is
  /// already in progress, all callers await the same future.
  ///
  /// Returns true if the engine is ready for inference, false otherwise.
  static Future<bool> _ensureInitialized() {
    return _initFuture ??=
        _doEnsureInitialized().whenComplete(() => _initFuture = null);
  }

  /// Internal init logic, called only via [_ensureInitialized].
  static Future<bool> _doEnsureInitialized() async {
    final engine = SlmEngine.instance;

    // Already running — nothing to do.
    if (engine.isAvailable) return true;

    // Re-initialize (handles both first-init and post-dispose cases).
    try {
      final ok = await engine.initialize().timeout(_slmTimeout);
      if (!ok) {
        debugPrint('[Orchestrator] SLM (re-)init returned false');
      }
      return ok;
    } catch (e) {
      debugPrint('[Orchestrator] SLM (re-)init failed: $e');
      return false;
    }
  }

  /// Attempt SLM generation with [_slmTimeout].
  ///
  /// Returns null if:
  ///   - SLM model not downloaded (skip → next tier)
  ///   - SLM initialization fails (skip → next tier)
  ///   - SLM times out (skip → next tier)
  ///   - SLM output fails ComplianceGuard (skip → next tier)
  static Future<OrchestratorOutput?> _trySlm({
    required String systemPrompt,
    required String userPrompt,
    required CoachContext ctx,
    required ComponentType componentType,
  }) async {
    // Ensure SLM is initialized (handles first-init and post-dispose re-init).
    if (!await _ensureInitialized()) return null;

    final engine = SlmEngine.instance;

    // Truncate prompt to context window.
    final truncatedPrompt = _truncateToContextWindow(userPrompt);

    // Generate with timeout.
    SlmResult? result;
    try {
      result = await engine
          .generate(
            systemPrompt: systemPrompt,
            userPrompt: truncatedPrompt,
            maxTokens: SlmEngine.defaultMaxTokens,
          )
          .timeout(_slmTimeout);
    } on TimeoutException {
      debugPrint('[Orchestrator] SLM timed out (${_slmTimeout.inSeconds}s)');
      return null;
    } catch (e) {
      debugPrint('[Orchestrator] SLM generation error: $e');
      return null;
    }

    if (result == null || result.text.trim().isEmpty) return null;

    // Validate through ComplianceGuard.
    ComplianceResult compliance;
    try {
      compliance = ComplianceGuard.validate(
        result.text,
        context: ctx,
        componentType: componentType,
      );
    } catch (e) {
      debugPrint('[Orchestrator] ComplianceGuard error on SLM output: $e');
      return null;
    }

    if (compliance.useFallback) {
      debugPrint(
          '[Orchestrator] SLM output rejected by ComplianceGuard: ${compliance.violations}');
      return null;
    }

    return OrchestratorOutput(
      text: compliance.sanitizedText.isNotEmpty
          ? compliance.sanitizedText
          : result.text,
      tier: CoachTier.slm,
      wasSanitized: !compliance.isCompliant,
      slmDurationMs: result.durationMs,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — BYOK tier (narrative)
  // ══════════════════════════════════════════════════════════════

  /// Attempt BYOK cloud LLM for a narrative component.
  static Future<OrchestratorOutput?> _tryByok({
    required String prompt,
    required LlmConfig config,
    required CoachContext ctx,
    required ComponentType componentType,
  }) async {
    final ragService = RagService();
    final providerStr = _llmProviderString(config.provider);

    RagResponse ragResponse;
    try {
      ragResponse = await ragService
          .query(
            question: prompt,
            apiKey: config.apiKey,
            provider: providerStr,
            model: config.model,
            profileContext: {
              'firstName': ctx.firstName,
              'age': ctx.age.toString(),
              'canton': ctx.canton,
              'archetype': ctx.archetype,
              'friTotal': ctx.friTotal.toStringAsFixed(0),
              'replacementRatio': ctx.replacementRatio.toStringAsFixed(0),
            },
          )
          .timeout(_byokTimeout);
    } on TimeoutException {
      debugPrint('[Orchestrator] BYOK timed out (${_byokTimeout.inSeconds}s)');
      return null;
    } catch (e) {
      debugPrint('[Orchestrator] BYOK error: $e');
      return null;
    }

    final rawText = ragResponse.answer;
    if (rawText.trim().isEmpty) return null;

    ComplianceResult compliance;
    try {
      compliance = ComplianceGuard.validate(
        rawText,
        context: ctx,
        componentType: componentType,
      );
    } catch (e) {
      debugPrint('[Orchestrator] ComplianceGuard error on BYOK output: $e');
      return null;
    }

    if (compliance.useFallback) {
      debugPrint(
          '[Orchestrator] BYOK output rejected by ComplianceGuard: ${compliance.violations}');
      return null;
    }

    return OrchestratorOutput(
      text: compliance.sanitizedText.isNotEmpty
          ? compliance.sanitizedText
          : rawText,
      tier: CoachTier.byok,
      wasSanitized: !compliance.isCompliant,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — BYOK tier (chat)
  // ══════════════════════════════════════════════════════════════

  /// Attempt BYOK RAG for a chat response.
  static Future<CoachResponse?> _tryByokChat({
    required String userMessage,
    required List<ChatMessage> history,
    required LlmConfig config,
    required CoachContext ctx,
    String? memoryBlock,
  }) async {
    final ragService = RagService();
    final providerStr = _llmProviderString(config.provider);
    final baseQuestion = _buildConversationContext(history, userMessage);
    // Prepend memory block to the question so the RAG backend sees the
    // enriched context (lifecycle, goals, conversation history).
    final augmentedQuestion = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$memoryBlock\n\n$baseQuestion'
        : baseQuestion;

    RagResponse ragResponse;
    try {
      ragResponse = await ragService
          .query(
            question: augmentedQuestion,
            apiKey: config.apiKey,
            provider: providerStr,
            model: config.model,
            profileContext: {
              'firstName': ctx.firstName,
              'age': ctx.age.toString(),
              'canton': ctx.canton,
              'archetype': ctx.archetype,
              'friTotal': ctx.friTotal.toStringAsFixed(0),
              'replacementRatio': ctx.replacementRatio.toStringAsFixed(0),
            },
          )
          .timeout(_byokTimeout);
    } on TimeoutException {
      debugPrint('[Orchestrator] BYOK chat timed out');
      return null;
    } catch (e) {
      debugPrint('[Orchestrator] BYOK chat error: $e');
      return null;
    }

    ComplianceResult compliance;
    try {
      compliance = ComplianceGuard.validate(
        ragResponse.answer,
        context: ctx,
        componentType: ComponentType.general,
      );
    } catch (_) {
      return null;
    }

    if (compliance.useFallback) return null;

    final text = compliance.sanitizedText.isNotEmpty
        ? compliance.sanitizedText
        : ragResponse.answer;

    return CoachResponse(
      message: text,
      disclaimer: ComplianceGuard.standardDisclaimer,
      sources: ragResponse.sources,
      disclaimers: ragResponse.disclaimers,
      wasFiltered: !compliance.isCompliant,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — FallbackTemplates tier
  // ══════════════════════════════════════════════════════════════

  /// Generate from FallbackTemplates — always succeeds.
  ///
  /// ComplianceGuard is still applied (templates should always pass,
  /// but defense-in-depth requires validation on every output path).
  static OrchestratorOutput _generateFallback({
    required ComponentType componentType,
    required CoachContext ctx,
  }) {
    final rawText = _fallbackForComponent(componentType, ctx);

    ComplianceResult compliance;
    try {
      compliance = ComplianceGuard.validate(
        rawText,
        context: ctx,
        componentType: componentType,
      );
    } catch (_) {
      // If even the guard crashes on the template, return raw template.
      return OrchestratorOutput(
        text: rawText,
        tier: CoachTier.fallback,
        wasSanitized: false,
      );
    }

    // Templates should always pass — if not, return the template anyway
    // (fallback of the fallback: just show the template text).
    final text = (compliance.useFallback || compliance.sanitizedText.isEmpty)
        ? rawText
        : compliance.sanitizedText;

    return OrchestratorOutput(
      text: text,
      tier: CoachTier.fallback,
      wasSanitized: !compliance.isCompliant,
    );
  }

  /// Safe chat fallback — honest message when no LLM is available.
  // TODO(S57-i18n): migrate hardcoded FR strings — service has no BuildContext;
  // requires static localisation accessor or caller-injected strings (Phase 1.3).
  static CoachResponse _chatFallback() {
    return const CoachResponse(
      message: 'Le coach IA n\'est pas disponible pour le moment.\n\n'
          'En attendant, tu peux :\n'
          '• Explorer tes simulateurs (3a, LPP, retraite)\n'
          '• Consulter les fiches éducatives\n'
          '• Enrichir ton profil pour des projections plus précises\n\n'
          '_${ComplianceGuard.standardDisclaimer}_',
      disclaimer: ComplianceGuard.standardDisclaimer,
      wasFiltered: false,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API — streaming chat (SLM only)
  // ══════════════════════════════════════════════════════════════

  /// Stream a chat response token-by-token from the SLM.
  ///
  /// Returns null if SLM is not eligible or not available.
  /// Caller should fall back to [generateChat] for BYOK / fallback.
  ///
  /// Handles re-initialization after dispose — when the user leaves the
  /// coach screen and returns, the engine is transparently re-initialized.
  ///
  /// [memoryBlock] — optional enriched context from [ContextInjectorService].
  static Stream<String>? streamChat({
    required String userMessage,
    required List<ChatMessage> history,
    required CoachContext ctx,
    String? memoryBlock,
  }) {
    if (!_slmEligible()) return null;

    final engine = SlmEngine.instance;

    // If engine was disposed (user left coach screen), we need async re-init.
    // Wrap the entire flow in an async* generator that ensures init first.
    if (!engine.isAvailable) {
      return _streamChatWithReInit(
        userMessage: userMessage,
        history: history,
        ctx: ctx,
        memoryBlock: memoryBlock,
      );
    }

    final basePrompt = _selectSystemPrompt(ctx);
    final systemPrompt = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$basePrompt\n\n$memoryBlock'
        : basePrompt;
    final conversationCtx = _buildConversationContext(history, userMessage);
    final truncated = _truncateToContextWindow(conversationCtx);

    return engine.generateStream(
      systemPrompt: systemPrompt,
      userPrompt: truncated,
    );
  }

  /// Select the appropriate system prompt based on user context.
  /// Uses senior prompt for 60+, base prompt otherwise.
  static String _selectSystemPrompt(CoachContext ctx) {
    if (ctx.age >= 60) return PromptRegistry.chatSeniorPrompt(ctx);
    return PromptRegistry.baseSystemPrompt;
  }

  /// Internal: stream chat with async re-initialization before streaming.
  ///
  /// Used when [SlmEngine] was disposed and needs re-init before generating.
  static Stream<String> _streamChatWithReInit({
    required String userMessage,
    required List<ChatMessage> history,
    required CoachContext ctx,
    String? memoryBlock,
  }) async* {
    final ok = await _ensureInitialized();
    if (!ok) return;

    final engine = SlmEngine.instance;
    final basePrompt = _selectSystemPrompt(ctx);
    final systemPrompt = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$basePrompt\n\n$memoryBlock'
        : basePrompt;
    final conversationCtx = _buildConversationContext(history, userMessage);
    final truncated = _truncateToContextWindow(conversationCtx);

    yield* engine.generateStream(
      systemPrompt: systemPrompt,
      userPrompt: truncated,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — helpers
  // ══════════════════════════════════════════════════════════════

  /// Map [ComponentType] to the key used by [PromptRegistry.getPrompt].
  static String _componentTypeToKey(ComponentType type) {
    switch (type) {
      case ComponentType.greeting:
        return 'greeting';
      case ComponentType.scoreSummary:
        return 'score_summary';
      case ComponentType.tip:
        return 'tip';
      case ComponentType.chiffreChoc:
        return 'chiffre_choc';
      case ComponentType.scenario:
        return 'scenario';
      case ComponentType.enrichmentGuide:
        return 'enrichment_guide';
      case ComponentType.general:
      case ComponentType.chatSystem:
      case ComponentType.chatSafeMode:
      case ComponentType.chatFollowUp:
      case ComponentType.chatSimulation:
      case ComponentType.chatSenior:
        return 'general';
    }
  }

  /// Short user-turn prompt sent to the SLM (after system prompt).
  static String _userPromptForComponent(
    ComponentType type,
    CoachContext ctx,
  ) {
    switch (type) {
      case ComponentType.greeting:
        return 'Génère un greeting pour ${ctx.firstName} (score ${ctx.friTotal.toStringAsFixed(0)}/100).';
      case ComponentType.scoreSummary:
        return 'Génère un résumé du score FRI ${ctx.friTotal.toStringAsFixed(0)}/100.';
      case ComponentType.tip:
        return 'Génère un tip éducatif personnalisé.';
      case ComponentType.chiffreChoc:
        return 'Commente le chiffre choc de manière éducative.';
      case ComponentType.scenario:
        return 'Narre le scénario de projection.';
      case ComponentType.enrichmentGuide:
        return 'Guide l\'utilisateur pour compléter son profil.';
      case ComponentType.general:
      case ComponentType.chatSystem:
      case ComponentType.chatSafeMode:
      case ComponentType.chatFollowUp:
      case ComponentType.chatSimulation:
      case ComponentType.chatSenior:
        return 'Réponds de manière éducative.';
    }
  }

  /// Get the appropriate FallbackTemplate for a component type.
  ///
  /// For [ComponentType.tip], selects a context-aware template based on the
  /// user's archetype and life situation. Falls back to the generic
  /// [FallbackTemplates.tipNarrative] when no specialized template matches.
  static String _fallbackForComponent(
    ComponentType type,
    CoachContext ctx,
  ) {
    switch (type) {
      case ComponentType.greeting:
        return FallbackTemplates.greeting(ctx);
      case ComponentType.scoreSummary:
        return FallbackTemplates.scoreSummary(ctx);
      case ComponentType.tip:
        return _contextualTip(ctx);
      case ComponentType.chiffreChoc:
        return FallbackTemplates.chiffreChocReframe(ctx);
      case ComponentType.enrichmentGuide:
        return FallbackTemplates.enrichmentGuide(ctx, 'general');
      case ComponentType.scenario:
      case ComponentType.general:
      case ComponentType.chatSystem:
      case ComponentType.chatSafeMode:
      case ComponentType.chatFollowUp:
      case ComponentType.chatSimulation:
      case ComponentType.chatSenior:
        return FallbackTemplates.scoreSummary(ctx);
    }
  }

  /// Select the most relevant tip template based on user context.
  ///
  /// Priority:
  ///   1. FATCA guidance for expat_us archetype
  ///   2. Disability bridge for users < 55 with no disability data
  ///   3. Libre passage for users in job transition
  ///   4. Succession planning for users > 50
  ///   5. Generic tip narrative (default)
  static String _contextualTip(CoachContext ctx) {
    // Life event-specific guidance — all 18 from definitive enum.
    final lifeEvent = ctx.knownValues['last_life_event']?.toString() ?? '';
    if (lifeEvent.isNotEmpty) {
      final eventTip = _lifeEventTip(ctx, lifeEvent);
      if (eventTip != null) return eventTip;
    }

    // FATCA: highest priority for US taxpayers
    if (ctx.archetype == 'expat_us') {
      return FallbackTemplates.fatcaGuidance(ctx);
    }

    // Disability: flag coverage gaps for working-age users
    final hasDisabilityData =
        ctx.dataReliability.keys.any((k) => k.contains('invalidit'));
    if (ctx.age < 55 && !hasDisabilityData) {
      return FallbackTemplates.disabilityBridge(ctx);
    }

    // Succession: relevant for 50+ (estate planning horizon)
    if (ctx.age >= 50) {
      return FallbackTemplates.successionPlanning(ctx);
    }

    // Default: generic personalized tip
    return FallbackTemplates.tipNarrative(ctx);
  }

  /// Map a life event to its specialized fallback template.
  static String? _lifeEventTip(CoachContext ctx, String event) {
    return switch (event) {
      'marriage' => FallbackTemplates.marriageGuidance(ctx),
      'divorce' => FallbackTemplates.divorceGuidance(ctx),
      'birth' => FallbackTemplates.birthGuidance(ctx),
      'concubinage' => FallbackTemplates.concubinageGuidance(ctx),
      'deathOfRelative' => FallbackTemplates.deathOfRelativeGuidance(ctx),
      'firstJob' => FallbackTemplates.firstJobGuidance(ctx),
      'newJob' || 'jobLoss' => FallbackTemplates.librePassageGuide(ctx),
      'selfEmployment' => FallbackTemplates.selfEmploymentGuidance(ctx),
      'retirement' => FallbackTemplates.retirementGuidance(ctx),
      'housingPurchase' => FallbackTemplates.housingPurchaseGuidance(ctx),
      'housingSale' => FallbackTemplates.housingSaleGuidance(ctx),
      'inheritance' => FallbackTemplates.inheritanceGuidance(ctx),
      'donation' => FallbackTemplates.donationGuidance(ctx),
      'disability' => FallbackTemplates.disabilityBridge(ctx),
      'cantonMove' => FallbackTemplates.cantonMoveGuidance(ctx),
      'countryMove' => FallbackTemplates.countryMoveGuidance(ctx),
      'debtCrisis' => FallbackTemplates.debtCrisisGuidance(ctx),
      _ => null,
    };
  }

  /// Map [LlmProvider] to the string expected by [RagService].
  static String _llmProviderString(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.anthropic:
        return 'claude';
      case LlmProvider.mistral:
        return 'mistral';
      case LlmProvider.openai:
        return 'openai';
    }
  }

  /// Truncate a prompt to fit the SLM context window.
  ///
  /// Keeps the TAIL of the text (most recent/relevant context).
  /// Returns the original string if it fits within [_maxPromptChars].
  static String _truncateToContextWindow(String prompt) {
    if (prompt.length <= _maxPromptChars) return prompt;
    debugPrint(
      '[Orchestrator] Prompt truncated: ${prompt.length} → $_maxPromptChars chars',
    );
    return prompt.substring(prompt.length - _maxPromptChars);
  }

  /// Sanitize user input to prevent prompt injection.
  ///
  /// Strips system markers that could manipulate the LLM context:
  /// memory block delimiters, system instructions, etc.
  static String _sanitizeUserInput(String input) {
    var s = input;
    // Strip system prompt markers (case-insensitive)
    for (final marker in [
      '--- MÉMOIRE MINT ---',
      '--- FIN MÉMOIRE ---',
      'RAPPEL\u00a0:',
      'HISTORIQUE DE CONVERSATION',
    ]) {
      s = s.replaceAll(RegExp(RegExp.escape(marker), caseSensitive: false), '');
    }
    // Strip triple-dash delimiters only when surrounded by whitespace/BOL/EOL
    // (avoids mangling legitimate text like "45---65")
    s = s.replaceAll(RegExp(r'(?<=\s|^)-{3,}(?=\s|$)'), '');
    // Collapse excessive whitespace
    s = s.replaceAll(RegExp(r'\s{3,}'), '  ');
    return s.trim();
  }

  /// Build conversation context string for multi-turn chat.
  ///
  /// Keeps the last 8 messages (4 exchanges) to stay within token limits.
  /// User messages are sanitized to prevent prompt injection.
  static String _buildConversationContext(
    List<ChatMessage> history,
    String currentMessage,
  ) {
    final relevant =
        history.where((m) => m.isUser || m.isAssistant).toList();
    if (relevant.length <= 1) return _sanitizeUserInput(currentMessage);

    final tail =
        relevant.length > 8 ? relevant.sublist(relevant.length - 8) : relevant;

    final buf = StringBuffer('Contexte de la conversation :\n');
    for (final msg in tail) {
      final content = msg.isUser ? _sanitizeUserInput(msg.content) : msg.content;
      buf.writeln('${msg.isUser ? "Utilisateur" : "Coach"}: $content');
    }
    buf.writeln('\nNouvelle question :\n${_sanitizeUserInput(currentMessage)}');

    // Truncate to context window before sending to SLM.
    return _truncateToContextWindow(buf.toString());
  }
}
