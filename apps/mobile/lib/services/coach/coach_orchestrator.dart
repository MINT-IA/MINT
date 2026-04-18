/// Coach Orchestrator — Sprint S44 (Intelligence Branchement).
///
/// Single entry-point for ALL coach AI generation:
///   - Dashboard narrative (greeting, scoreSummary, tip, premierEclairage)
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
///   - Circuit breaker: [ProviderHealthService] prevents hammering dead providers
///   - Quality monitoring: [ResponseQualityMonitor] tracks per-provider quality
///
/// References:
///   - LSFin art. 3/8 (qualité de l'information financière)
///   - LPD art. 6 (privacy by design — SLM on-device)
///   - FINMA circulaire 2008/21 (risque opérationnel — circuit breaker)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/coach_fallback_messages.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach/fallback_templates.dart';
import 'package:mint_mobile/services/coach/prompt_registry.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/llm/provider_health_service.dart';
import 'package:mint_mobile/services/llm/response_quality_monitor.dart';
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

  /// BYOK / server-key cloud LLM timeout.
  /// Backend hard cap is 55s (Claude tool-chain + RAG + compliance). This
  /// orchestrator-level timeout wraps the HTTP call (own 50s timeout) plus
  /// any 401-refresh retry (~1s). 55s keeps the user from staring at a
  /// spinner past the point of no return; genuine hangs are surfaced by
  /// the chat screen's retry UI, not by cutting short live turns.
  static const Duration _byokTimeout = Duration(seconds: 55);

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
    String language = 'fr',
    int cashLevel = 3,
  }) async {
    // Build system prompt with optional memory block injection (S58).
    // Pan5-1: Use PromptRegistry.chatSystemPrompt (enriched, context-aware)
    // instead of bare baseSystemPrompt for chat interactions.
    final basePrompt = PromptRegistry.chatSystemPrompt(ctx);
    final systemPrompt = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$basePrompt\n\n$memoryBlock'
        : basePrompt;

    // FIX-W12: Warn if system prompt exceeds 40% of context
    final systemPromptChars = systemPrompt.length;
    final maxSystemChars = (_maxPromptChars * 0.4).floor();
    if (systemPromptChars > maxSystemChars) {
      debugPrint(
        '[Coach] WARNING: System prompt $systemPromptChars chars exceeds '
        '40% budget ($maxSystemChars). Truncating memory block.',
      );
    }

    // 1. SLM tier for chat
    if (_slmEligible()) {
      debugPrint('[CoachChain] tier1=SLM trying...');
      final conversationCtx = _buildConversationContext(history, userMessage);
      final slmOut = await _trySlm(
        systemPrompt: systemPrompt,
        userPrompt: conversationCtx,
        ctx: ctx,
        componentType: ComponentType.general,
      );
      if (slmOut != null) {
        debugPrint('[CoachChain] tier1=SLM SUCCESS');
        return CoachResponse(
          message: slmOut.text,
          disclaimer: ComplianceGuard.standardDisclaimer,
          wasFiltered: slmOut.wasSanitized,
        );
      }
      debugPrint('[CoachChain] tier1=SLM returned null, falling through');
    } else {
      debugPrint('[CoachChain] tier1=SLM ineligible (skipped)');
    }

    // 2. BYOK RAG tier for chat (skipped in safeModeDegraded emergency mode)
    if (!FeatureFlags.safeModeDegraded &&
        byokConfig != null &&
        byokConfig.hasApiKey) {
      debugPrint('[CoachChain] tier2=BYOK trying...');
      final byokResponse = await _tryByokChat(
        userMessage: userMessage,
        history: history,
        config: byokConfig,
        ctx: ctx,
        memoryBlock: memoryBlock,
        language: language,
        cashLevel: cashLevel,
      );
      if (byokResponse != null) {
        debugPrint('[CoachChain] tier2=BYOK SUCCESS');
        return byokResponse;
      }
      debugPrint('[CoachChain] tier2=BYOK returned null, falling through');
    } else {
      debugPrint('[CoachChain] tier2=BYOK not configured (skipped)');
    }

    // 2.5. Server-key tier — calls /coach/chat (uses Railway ANTHROPIC_API_KEY)
    // Only attempted when BYOK is not configured (no double-call).
    if (!FeatureFlags.safeModeDegraded &&
        (byokConfig == null || !byokConfig.hasApiKey)) {
      debugPrint('[CoachChain] tier3=ServerKey trying...');
      final serverKeyResponse = await _tryServerKeyChat(
        userMessage: userMessage,
        history: history,
        ctx: ctx,
        memoryBlock: memoryBlock,
        language: language,
        cashLevel: cashLevel,
      );
      if (serverKeyResponse != null) {
        debugPrint('[CoachChain] tier3=ServerKey SUCCESS');
        return serverKeyResponse;
      }
      debugPrint('[CoachChain] tier3=ServerKey returned null, falling through');
    } else {
      debugPrint('[CoachChain] tier3=ServerKey skipped (BYOK active or safeMode)');
    }

    // 4. Fallback — honest "coach unavailable" message.
    debugPrint('[CoachChain] ALL TIERS FAILED — returning fallback');
    return _chatFallback(language);
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

    // Run ComplianceGuard for SLM output ONLY for sanitization (banned terms
    // replaced). Never fallback — SLM is on-device, there's no retry tier
    // below it. If the SLM produced text, we show it (sanitized).
    // This matches the bypass policy applied to BYOK / server-key tiers.
    ComplianceResult? compliance;
    try {
      compliance = ComplianceGuard.validate(
        result.text,
        context: ctx,
        componentType: componentType,
      );
    } catch (e) {
      debugPrint('[Orchestrator] ComplianceGuard error on SLM output: $e (returning raw)');
    }

    final text = (compliance != null && compliance.sanitizedText.isNotEmpty)
        ? compliance.sanitizedText
        : result.text;

    return OrchestratorOutput(
      text: text,
      tier: CoachTier.slm,
      wasSanitized: compliance != null && !compliance.isCompliant,
      slmDurationMs: result.durationMs,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — BYOK tier (narrative)
  // ══════════════════════════════════════════════════════════════

  /// Attempt BYOK cloud LLM for a narrative component.
  ///
  /// Integrates with [ProviderHealthService] circuit breaker to skip providers
  /// that have failed repeatedly, and records attempt outcomes for future
  /// circuit-breaker decisions. Also scores response quality via
  /// [ResponseQualityMonitor] for per-provider quality tracking.
  static Future<OrchestratorOutput?> _tryByok({
    required String prompt,
    required LlmConfig config,
    required CoachContext ctx,
    required ComponentType componentType,
  }) async {
    final ragService = RagService();
    final providerStr = _llmProviderString(config.provider);

    // Circuit breaker: skip provider if circuit is open (3+ consecutive failures).
    if (await _isProviderCircuitOpen(providerStr)) {
      debugPrint(
          '[Orchestrator] BYOK skipped — $providerStr circuit open');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    RagResponse ragResponse;
    try {
      ragResponse = await ragService
          .query(
            question: prompt,
            apiKey: config.apiKey,
            provider: providerStr,
            model: config.model,
            profileContext: {
              'first_name': ctx.firstName,
              'age': ctx.age,
              'canton': ctx.canton,
              'archetype': ctx.archetype,
              'fri_total': ctx.friTotal,
              'replacement_ratio': ctx.replacementRatio > 0
                  ? ctx.replacementRatio / 100.0
                  : null,
              'confidence_score': ctx.confidenceScore > 0
                  ? ctx.confidenceScore
                  : null,
              'has_debt': ctx.hasDebt,
              // Spread knownValues for data lookup tools
              ...ctx.knownValues.map((k, v) =>
                  MapEntry(k, v.isFinite && v > 0 ? v : null)),
            },
          )
          .timeout(_byokTimeout);
    } on TimeoutException {
      stopwatch.stop();
      debugPrint('[Orchestrator] BYOK timed out (${_byokTimeout.inSeconds}s)');
      await _recordProviderAttempt(providerStr, false, stopwatch.elapsed);
      return null;
    } catch (e) {
      stopwatch.stop();
      debugPrint('[Orchestrator] BYOK error: $e');
      await _recordProviderAttempt(providerStr, false, stopwatch.elapsed);
      return null;
    }
    stopwatch.stop();

    final rawText = ragResponse.answer;
    if (rawText.trim().isEmpty) {
      await _recordProviderAttempt(providerStr, false, stopwatch.elapsed);
      return null;
    }

    // Backend RAG has its own compliance pipeline. Client ComplianceGuard here
    // caused double-validation false positives. Trust the backend; keep only
    // a light sanitize for local banned-term replacement.
    ComplianceResult? compliance;
    try {
      compliance = ComplianceGuard.validate(
        rawText,
        context: ctx,
        componentType: componentType,
      );
    } catch (e) {
      debugPrint('[Orchestrator] ComplianceGuard error on BYOK narrative: $e (returning raw)');
    }

    await _recordProviderAttempt(providerStr, true, stopwatch.elapsed);
    await _recordResponseQuality(
      providerStr, rawText, prompt,
    );

    final text = (compliance != null && compliance.sanitizedText.isNotEmpty)
        ? compliance.sanitizedText
        : rawText;

    return OrchestratorOutput(
      text: text,
      tier: CoachTier.byok,
      wasSanitized: compliance != null && !compliance.isCompliant,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — BYOK tier (chat)
  // ══════════════════════════════════════════════════════════════

  /// Coach tools in Anthropic format for the BYOK path.
  ///
  /// STAB-03 / STAB-04 / D-04: list expanded to 4 tools so Claude can call
  /// generate_financial_plan and record_check_in in addition to the original
  /// route_to_screen + generate_document. Structured tool_use blocks flow
  /// back through CoachResponse.toolCalls → richToolCalls → WidgetRenderer.
  static const List<Map<String, dynamic>> _coachTools = [
    {
      'name': 'route_to_screen',
      'description':
          'Route the user to a specific MINT screen. The Flutter app verifies '
              'readiness before opening. Use when the question maps to a feature screen.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'intent': {
            'type': 'string',
            'description': 'Intent tag from ScreenRegistry.',
          },
          'confidence': {
            'type': 'number',
            'description': 'Confidence 0.0-1.0.',
          },
          'context_message': {
            'type': 'string',
            'description': 'Educational message explaining relevance.',
          },
        },
        'required': ['intent', 'confidence', 'context_message'],
      },
    },
    {
      'name': 'generate_document',
      'description':
          'Generate a pre-filled document for the user (fiscal declaration prep, '
              'pension fund letter, LPP buyback request). The document is read-only '
              '— MINT never submits it. The user reviews and uses it independently.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'document_type': {
            'type': 'string',
            'enum': [
              'fiscal_declaration',
              'pension_fund_letter',
              'lpp_buyback_request',
            ],
            'description':
                'Type of document to generate: fiscal_declaration, '
                    'pension_fund_letter, or lpp_buyback_request.',
          },
          'context': {
            'type': 'string',
            'description':
                'Brief summary of what the user asked for. No PII.',
          },
        },
        'required': ['document_type', 'context'],
      },
    },
    {
      'name': 'generate_financial_plan',
      'description':
          'Generate a personalized financial plan preview card in the chat. '
              'Use when the user asks for "un plan", "quoi faire", or a concrete '
              'multi-step action list. The card shows a goal, a monthly target, '
              'milestones, and a coach narrative. Read-only — no money movement.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'goal': {
            'type': 'string',
            'description':
                'Short goal description (e.g. "Preparer la retraite", "Acheter un appartement").',
          },
          'monthly_amount': {
            'type': 'number',
            'description':
                'Monthly target amount in CHF. Optional — omit if unknown.',
          },
          'narrative': {
            'type': 'string',
            'description':
                'Coach narrative (1-2 sentences) explaining why this plan.',
          },
        },
        'required': ['goal', 'narrative'],
      },
    },
    {
      'name': 'record_check_in',
      'description':
          'Record a monthly check-in (3a/LPP deposits) and display a summary card. '
              'Use when the user confirms they made their monthly contributions. '
              'The card is persisted to the user profile. Read-only posture — '
              'MINT never moves money, only records what the user reports.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'month': {
            'type': 'string',
            'description':
                'Month of the check-in in YYYY-MM format (e.g. "2026-04").',
          },
          'versements': {
            'type': 'object',
            'description':
                'Map of contribution category → amount in CHF '
                    '(e.g. {"3a": 604.0, "lpp": 250.0}).',
          },
          'summary_message': {
            'type': 'string',
            'description':
                'One-sentence coach summary of what the user accomplished.',
          },
        },
        'required': ['month', 'versements', 'summary_message'],
      },
    },
  ];

  /// Attempt BYOK RAG for a chat response.
  ///
  /// Integrates with [ProviderHealthService] circuit breaker and records
  /// attempt outcomes. Quality scored via [ResponseQualityMonitor].
  static Future<CoachResponse?> _tryByokChat({
    required String userMessage,
    required List<ChatMessage> history,
    required LlmConfig config,
    required CoachContext ctx,
    String? memoryBlock,
    String language = 'fr',
    int cashLevel = 3,
  }) async {
    final ragService = RagService();
    final providerStr = _llmProviderString(config.provider);

    // Circuit breaker: skip provider if circuit is open.
    if (await _isProviderCircuitOpen(providerStr)) {
      debugPrint(
          '[Orchestrator] BYOK chat skipped — $providerStr circuit open');
      return null;
    }

    final baseQuestion = _buildConversationContext(history, userMessage);
    // Prepend memory block to the question so the RAG backend sees the
    // enriched context (lifecycle, goals, conversation history).
    final augmentedQuestion = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$memoryBlock\n\n$baseQuestion'
        : baseQuestion;

    final stopwatch = Stopwatch()..start();
    RagResponse ragResponse;
    try {
      ragResponse = await ragService
          .query(
            question: augmentedQuestion,
            apiKey: config.apiKey,
            provider: providerStr,
            model: config.model,
            profileContext: {
              'first_name': ctx.firstName,
              'age': ctx.age,
              'canton': ctx.canton,
              'archetype': ctx.archetype,
              'fri_total': ctx.friTotal,
              'replacement_ratio': ctx.replacementRatio > 0
                  ? ctx.replacementRatio / 100.0
                  : null,
              'confidence_score': ctx.confidenceScore > 0
                  ? ctx.confidenceScore
                  : null,
              'has_debt': ctx.hasDebt,
              // Spread knownValues for data lookup tools
              ...ctx.knownValues.map((k, v) =>
                  MapEntry(k, v.isFinite && v > 0 ? v : null)),
            },
            language: language,
            cashLevel: cashLevel,
            // Pass tools so Claude can return route_to_screen tool_use blocks.
            tools: providerStr == 'claude' ? _coachTools : null,
          )
          .timeout(_byokTimeout);
    } on TimeoutException {
      stopwatch.stop();
      debugPrint('[Orchestrator] BYOK chat timed out');
      await _recordProviderAttempt(providerStr, false, stopwatch.elapsed);
      return null;
    } catch (e) {
      stopwatch.stop();
      debugPrint('[Orchestrator] BYOK chat error: $e');
      await _recordProviderAttempt(providerStr, false, stopwatch.elapsed);
      return null;
    }
    stopwatch.stop();

    // Backend /rag/query has its own compliance pipeline. Running Flutter
    // ComplianceGuard on top causes false-positive fallbacks from hallucination
    // detection faux positifs (rounding) and double banned-term rejection.
    // Trust the backend — only drop on empty response.
    if (ragResponse.answer.trim().isEmpty) {
      debugPrint('[Orchestrator] BYOK returned empty answer');
      await _recordProviderAttempt(providerStr, false, stopwatch.elapsed);
      return null;
    }

    // Success — record health + quality metrics.
    await _recordProviderAttempt(providerStr, true, stopwatch.elapsed);
    await _recordResponseQuality(
      providerStr, ragResponse.answer, userMessage,
    );

    var text = ragResponse.answer;

    // Transform tool_calls into inline markers that
    // coach_chat_screen can detect and resolve.
    if (ragResponse.hasToolCalls) {
      for (final toolCall in ragResponse.toolCalls) {
        if (toolCall.name == 'route_to_screen') {
          final markerJson = '{"intent":"${toolCall.input['intent']}",'
              '"confidence":${toolCall.input['confidence']},'
              '"context_message":"${_escapeJson(toolCall.input['context_message'] as String? ?? '')}"}';
          text = '$text\n[ROUTE_TO_SCREEN:$markerJson]';
        } else if (toolCall.name == 'generate_document') {
          final markerJson = '{"document_type":"${_escapeJson(toolCall.input['document_type'] as String? ?? '')}",'
              '"context":"${_escapeJson(toolCall.input['context'] as String? ?? '')}"}';
          text = '$text\n[GENERATE_DOCUMENT:$markerJson]';
        }
      }
    }

    return CoachResponse(
      message: text,
      disclaimer: ComplianceGuard.standardDisclaimer,
      sources: ragResponse.sources,
      disclaimers: ragResponse.disclaimers,
      wasFiltered: false,
      toolCalls: ragResponse.toolCalls,
      // ragResponse has no degraded flag — BYOK path uses user's own key.
      degraded: false,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — Server-key tier (COACH-01)
  // ══════════════════════════════════════════════════════════════

  /// Attempt server-key chat via /coach/chat endpoint.
  ///
  /// The backend uses its own ANTHROPIC_API_KEY when no api_key is provided.
  /// Requires JWT auth (user must be logged in).
  /// Returns null on any error (orchestrator falls through to fallback).
  static Future<CoachResponse?> _tryServerKeyChat({
    required String userMessage,
    required List<ChatMessage> history,
    required CoachContext ctx,
    String? memoryBlock,
    String language = 'fr',
    int cashLevel = 3,
  }) async {
    final service = CoachChatApiService();

    // Build conversation history for multi-turn context (same as BYOK path).
    // Bumped 8 → 16 (Gate 0 P0-2, 2026-04-15), then 16 → 32 (Gate 0 P0,
    // 2026-04-17) after users reported the coach forgetting context around
    // turn 4-5. First assistant greeting is pinned (carries lifecycle, plan,
    // regional identity injected at onboarding) so it survives deep
    // conversations. Backend cap is also bumped to 32 msg
    // (coach_chat.py:_sanitize_conversation_history).
    final recentHistory = history
        .where((m) => m.isUser || m.isAssistant)
        .toList();
    final List<ChatMessage> kept;
    if (recentHistory.length <= _conversationContextMaxMessages) {
      kept = recentHistory;
    } else {
      final greeting = recentHistory.firstWhere(
        (m) => m.isAssistant,
        orElse: () => recentHistory.first,
      );
      final tail = recentHistory.sublist(
        recentHistory.length - (_conversationContextMaxMessages - 1),
      );
      kept = tail.contains(greeting) ? tail : [greeting, ...tail];
    }
    final conversationHistory = kept
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.isUser ? _sanitizeUserInput(m.content) : m.content,
            })
        .toList();

    try {
      final response = await service.chat(
        message: userMessage,
        conversationHistory:
            conversationHistory.isNotEmpty ? conversationHistory : null,
        profileContext: {
          'first_name': ctx.firstName,
          'age': ctx.age,
          'canton': ctx.canton,
          'archetype': ctx.archetype,
          'fri_total': ctx.friTotal,
          'fri_delta': ctx.friDelta,
          'primary_focus':
              ctx.primaryFocus.isNotEmpty ? ctx.primaryFocus : null,
          'replacement_ratio':
              ctx.replacementRatio > 0 ? ctx.replacementRatio / 100.0 : null,
          'months_liquidity':
              ctx.monthsLiquidity > 0 ? ctx.monthsLiquidity : null,
          'tax_saving_potential':
              ctx.taxSavingPotential > 0 ? ctx.taxSavingPotential : null,
          'confidence_score':
              ctx.confidenceScore > 0 ? ctx.confidenceScore : null,
          'has_debt': ctx.hasDebt,
          'days_since_last_visit': ctx.daysSinceLastVisit,
          'fiscal_season':
              ctx.fiscalSeason.isNotEmpty ? ctx.fiscalSeason : null,
          'upcoming_event':
              ctx.upcomingEvent.isNotEmpty ? ctx.upcomingEvent : null,
          'check_in_streak': ctx.checkInStreak,
          'last_milestone':
              ctx.lastMilestone.isNotEmpty ? ctx.lastMilestone : null,
          if (ctx.dataReliability.isNotEmpty)
            'data_reliability': ctx.dataReliability,
          ...ctx.knownValues.map(
              (k, v) => MapEntry(k, v.isFinite && v > 0 ? v : null)),
        },
        memoryBlock: memoryBlock,
        language: language,
        cashLevel: cashLevel,
      ).timeout(_byokTimeout);

      // Backend /coach/chat has already run its own ComplianceGuard Python pipeline
      // (banned-term sanitization, hallucination detection, disclaimer injection).
      // Running the Flutter ComplianceGuard on top causes double-validation with
      // different thresholds (client 30% hallucination, server 30% + legal
      // constant whitelist drift) → false positives that drop every 2nd reply
      // to the fallback "coach pas disponible" message. Trust the backend.
      // Silent-fail protection: if the response is empty, drop to the next tier.
      if (response.message.trim().isEmpty) {
        debugPrint('[Orchestrator] Server-key returned empty message');
        return null;
      }
      var text = response.message;

      // Transform tool_calls into inline markers (same as BYOK path)
      for (final toolCall in response.toolCalls) {
        if (toolCall.name == 'route_to_screen') {
          final markerJson = '{"intent":"${toolCall.input['intent']}",'
              '"confidence":${toolCall.input['confidence']},'
              '"context_message":"${_escapeJson(toolCall.input['context_message'] as String? ?? '')}"}';
          text = '$text\n[ROUTE_TO_SCREEN:$markerJson]';
        } else if (toolCall.name == 'generate_document') {
          final markerJson =
              '{"document_type":"${_escapeJson(toolCall.input['document_type'] as String? ?? '')}",'
              '"context":"${_escapeJson(toolCall.input['context'] as String? ?? '')}"}';
          text = '$text\n[GENERATE_DOCUMENT:$markerJson]';
        }
      }

      return CoachResponse(
        message: text,
        disclaimer: ComplianceGuard.standardDisclaimer,
        sources: response.sources,
        disclaimers: response.disclaimers,
        wasFiltered: false,
        toolCalls: response.toolCalls,
        // v2.7 Task 8: surface Haiku-fallback flag from backend response_meta.
        degraded: response.degraded,
      );
    } on TimeoutException {
      // 2026-04-17 audit: we used to return null here, which dropped the
      // turn to `_chatFallback` ("Le coach IA n'est pas disponible").
      // The user then perceived the coach as permanently gone. Rethrow as
      // a typed network failure so the chat screen's catch block renders
      // a retry CTA with the last user message.
      debugPrint('[Orchestrator] Server-key chat timed out');
      throw const CoachChatApiException(
        code: 'timeout',
        message: 'Coach request timed out.',
      );
    } on CoachChatApiException {
      // Auth / entitlement / service_unavailable / server_error: propagate
      // so the chat screen can tell the user something specific and offer
      // a retry. Do NOT fall to the silent fallback template.
      rethrow;
    } catch (e) {
      debugPrint('[Orchestrator] Server-key chat error: $e');
      return null;
    }
  }

  /// Escape a string for safe JSON embedding.
  static String _escapeJson(String s) =>
      s.replaceAll('"', r'\"').replaceAll('\n', r'\n');

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
  ///
  /// Resolves KNOWN_GAPS_v2.2.md Cat 7 (P2 — FR-only fallback). The
  /// orchestrator is a static service with no `BuildContext`, so we
  /// dispatch on the ISO 639-1 [languageCode] via
  /// [CoachFallbackMessages]. Anti-shame doctrine: MINT is the subject
  /// of the unavailability, never the user. CLAUDE.md §7 compliant.
  static CoachResponse _chatFallback(String languageCode) {
    final message = CoachFallbackMessages.chatUnavailable(
      languageCode,
      ComplianceGuard.standardDisclaimer,
    );
    return CoachResponse(
      message: message,
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
      case ComponentType.premierEclairage:
        return 'premier_eclairage';
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
      case ComponentType.premierEclairage:
        return 'Commente le premier éclairage de manière éducative.';
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
      case ComponentType.premierEclairage:
        return FallbackTemplates.premierEclairageReframe(ctx);
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

  /// Maximum conversation history to include in SLM/BYOK context.
  ///
  /// Bumped from 8 → 32 (Gate 0 P0, 2026-04-17). Smaller caps caused the coach
  /// to "forget" the user mid-conversation: the first assistant message carries
  /// lifecycle, plan, and regional identity injected by the greeting, and was
  /// being purged as early as turn 4.
  static const int _conversationContextMaxMessages = 32;

  /// Build conversation context string for multi-turn chat.
  ///
  /// Keeps the last [_conversationContextMaxMessages] messages. The first
  /// assistant greeting is pinned (carries system context — lifecycle, plan,
  /// regional identity) and never purged even if history exceeds the cap.
  /// User messages are sanitized to prevent prompt injection.
  static String _buildConversationContext(
    List<ChatMessage> history,
    String currentMessage,
  ) {
    final relevant =
        history.where((m) => m.isUser || m.isAssistant).toList();
    if (relevant.length <= 1) return _sanitizeUserInput(currentMessage);

    final List<ChatMessage> kept;
    if (relevant.length <= _conversationContextMaxMessages) {
      kept = relevant;
    } else {
      // Preserve the first assistant message (greeting) + tail, so system
      // context injected at turn 0 survives deep conversations.
      final greeting = relevant.firstWhere(
        (m) => m.isAssistant,
        orElse: () => relevant.first,
      );
      final tail = relevant.sublist(
        relevant.length - (_conversationContextMaxMessages - 1),
      );
      kept = tail.contains(greeting) ? tail : [greeting, ...tail];
    }

    final buf = StringBuffer('Contexte de la conversation :\n');
    for (final msg in kept) {
      final content = msg.isUser ? _sanitizeUserInput(msg.content) : msg.content;
      buf.writeln('${msg.isUser ? "Utilisateur" : "Coach"}: $content');
    }
    buf.writeln('\nNouvelle question :\n${_sanitizeUserInput(currentMessage)}');

    // Truncate to context window before sending to SLM.
    return _truncateToContextWindow(buf.toString());
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — provider health & quality integration
  // ══════════════════════════════════════════════════════════════

  /// Check whether the circuit breaker for [provider] is open.
  ///
  /// Returns false (allow call) if SharedPreferences is unavailable
  /// (graceful degradation — never block a call due to metrics infra).
  static Future<bool> _isProviderCircuitOpen(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await ProviderHealthService.isCircuitOpen(provider, prefs);
    } catch (e) {
      debugPrint(
          '[Orchestrator] ProviderHealthService unavailable: $e — allowing call');
      return false;
    }
  }

  /// Record the outcome of a BYOK provider call for circuit-breaker tracking.
  ///
  /// Fire-and-forget — never blocks the response path. Failures in
  /// SharedPreferences are silently ignored (metrics are best-effort).
  static Future<void> _recordProviderAttempt(
    String provider,
    bool success,
    Duration latency,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await ProviderHealthService.recordAttempt(
        provider: provider,
        success: success,
        latency: latency,
        prefs: prefs,
      );
    } catch (e) {
      // Best-effort: never crash the coach flow due to metrics.
      debugPrint('[Orchestrator] Failed to record health metric: $e');
    }
  }

  /// Score and record response quality for per-provider analytics.
  ///
  /// Fire-and-forget — never blocks the response path.
  static Future<void> _recordResponseQuality(
    String provider,
    String response,
    String userMessage,
  ) async {
    try {
      final qualityScore = ResponseQualityMonitor.score(
        response,
        userMessage,
        provider: provider,
      );
      final prefs = await SharedPreferences.getInstance();
      await ResponseQualityMonitor.record(qualityScore, prefs);
    } catch (e) {
      // Best-effort: never crash the coach flow due to quality metrics.
      debugPrint('[Orchestrator] Failed to record quality metric: $e');
    }
  }
}
