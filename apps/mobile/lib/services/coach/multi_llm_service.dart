/// Multi-LLM Service — Sprint S64 (Multi-LLM Redundancy).
///
/// Orchestrates multiple LLM backends with automatic failover:
///   1. Claude (primary) — timeout 20s, max 2 retries
///   2. GPT-4o (secondary) — timeout 25s, max 1 retry
///   3. LocalFallback (tertiary) — template-based, always succeeds
///
/// Every response passes through [ComplianceGuard] before reaching the user.
///
/// Health monitoring:
///   - Tracks success/failure per provider
///   - Degrades provider after 3 consecutive failures
///   - Marks provider as down after 5 consecutive failures
///   - Auto-recovers after [_recoveryWindow] (5 minutes)
///
/// Quality monitoring:
///   - Scores every response on 4 axes (relevance, compliance, french, overall)
///   - Geometric mean for overall score
///
/// References:
///   - LSFin art. 3/8 (quality of financial information)
///   - FINMA circulaire 2008/21 (operational risk — failover)
///   - LPD art. 6 (privacy by design)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach/local_fallback_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart'
    show ChatMessage, LlmConfig;
import 'package:mint_mobile/services/rag_service.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS & DATA TYPES
// ════════════════════════════════════════════════════════════════

/// Supported LLM providers for multi-LLM failover.
enum LlmProvider { claude, gpt4o, localFallback }

/// Health status of an LLM provider.
enum LlmHealthStatus { healthy, degraded, down }

/// Configuration for a single LLM provider in the failover chain.
class LlmProviderConfig {
  /// Which provider this configuration is for.
  final LlmProvider provider;

  /// Priority in the failover chain (1 = primary, 2 = secondary, 3 = tertiary).
  final int priority;

  /// Per-request timeout.
  final Duration timeout;

  /// Maximum retry attempts before failing over to next provider.
  final int maxRetries;

  /// Whether this provider has passed compliance hardening validation.
  final bool complianceValidated;

  const LlmProviderConfig({
    required this.provider,
    required this.priority,
    required this.timeout,
    required this.maxRetries,
    this.complianceValidated = true,
  });
}

/// Response from a multi-LLM call, enriched with metadata.
class LlmResponse {
  /// The compliance-validated response text.
  final String content;

  /// Which provider actually produced this response.
  final LlmProvider provider;

  /// End-to-end latency for this request.
  final Duration latency;

  /// Tokens consumed (0 for local fallback).
  final int tokensUsed;

  /// Whether the response passed ComplianceGuard.
  final bool passedCompliance;

  /// Quality score (null if scoring not yet run).
  final QualityScore? quality;

  const LlmResponse({
    required this.content,
    required this.provider,
    required this.latency,
    this.tokensUsed = 0,
    this.passedCompliance = true,
    this.quality,
  });
}

/// Quality score for an LLM response — 4-axis scoring.
class QualityScore {
  /// 0-1: did the response answer the question.
  final double relevance;

  /// 0-1: no banned terms, educational tone, conditional language.
  final double compliance;

  /// 0-1: proper accents, grammar, NBSP usage.
  final double frenchQuality;

  /// Geometric mean of the 3 axes.
  final double overall;

  const QualityScore({
    required this.relevance,
    required this.compliance,
    required this.frenchQuality,
    required this.overall,
  });

  /// Compute quality score from the 3 raw axes.
  factory QualityScore.compute({
    required double relevance,
    required double compliance,
    required double frenchQuality,
  }) {
    final overall = _geometricMean([relevance, compliance, frenchQuality]);
    return QualityScore(
      relevance: relevance,
      compliance: compliance,
      frenchQuality: frenchQuality,
      overall: overall,
    );
  }

  static double _geometricMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    final product = values.fold(1.0, (a, b) => a * b);
    return math.pow(product, 1.0 / values.length).toDouble();
  }
}

// ════════════════════════════════════════════════════════════════
//  HEALTH TRACKER (internal)
// ════════════════════════════════════════════════════════════════

class _ProviderHealth {
  int consecutiveFailures = 0;
  DateTime? lastFailure;
  Duration? lastLatency;
  LlmHealthStatus status = LlmHealthStatus.healthy;

  /// Failures needed to transition to degraded.
  static const int degradedThreshold = 3;

  /// Failures needed to transition to down.
  static const int downThreshold = 5;
}

// ════════════════════════════════════════════════════════════════
//  MULTI-LLM SERVICE
// ════════════════════════════════════════════════════════════════

/// Central multi-LLM service with automatic failover and quality monitoring.
///
/// Stateless except for health tracking state. Thread-safe for concurrent
/// calls (each call is independent, health state updates are monotonic).
class MultiLlmService {
  MultiLlmService._();

  /// Recovery window — after this duration, a degraded/down provider
  /// is tentatively promoted back to healthy for a retry.
  static const Duration _recoveryWindow = Duration(minutes: 5);

  /// Provider configurations, ordered by priority.
  static const List<LlmProviderConfig> _configs = [
    LlmProviderConfig(
      provider: LlmProvider.claude,
      priority: 1,
      timeout: Duration(seconds: 20),
      maxRetries: 2,
    ),
    LlmProviderConfig(
      provider: LlmProvider.gpt4o,
      priority: 2,
      timeout: Duration(seconds: 25),
      maxRetries: 1,
    ),
    LlmProviderConfig(
      provider: LlmProvider.localFallback,
      priority: 3,
      timeout: Duration(seconds: 1),
      maxRetries: 0,
    ),
  ];

  /// Health state per provider.
  static final Map<LlmProvider, _ProviderHealth> _health = {
    for (final p in LlmProvider.values) p: _ProviderHealth(),
  };

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════════

  /// Get provider configurations (sorted by priority).
  static List<LlmProviderConfig> get providers =>
      List.unmodifiable(_configs);

  /// Get health status of a specific provider.
  static LlmHealthStatus healthOf(LlmProvider provider) {
    _checkRecovery(provider);
    return _health[provider]!.status;
  }

  /// Intelligent chat routing with automatic failover.
  ///
  /// Tries providers in priority order (claude -> gpt4o -> localFallback).
  /// Skips providers that are marked as [LlmHealthStatus.down].
  /// Runs [ComplianceGuard] on EVERY response regardless of provider.
  ///
  /// [apiKey] and [llmConfig] are used for cloud providers.
  /// [memoryBlock] is optional enriched context from ContextInjectorService.
  static Future<LlmResponse> chat({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? memoryBlock,
    LlmConfig? llmConfig,
  }) async {
    final sortedConfigs = List<LlmProviderConfig>.from(_configs)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final config in sortedConfigs) {
      // Check recovery window for degraded/down providers.
      _checkRecovery(config.provider);

      // Skip providers that are down.
      if (_health[config.provider]!.status == LlmHealthStatus.down) {
        debugPrint(
          '[MultiLLM] Skipping ${config.provider.name} (status: down)',
        );
        continue;
      }

      // Local fallback — always succeeds, no retry needed.
      if (config.provider == LlmProvider.localFallback) {
        return _handleLocalFallback(
          messages: messages,
          systemPrompt: systemPrompt,
        );
      }

      // Cloud provider — try with retries.
      final result = await _tryCloudProvider(
        config: config,
        systemPrompt: systemPrompt,
        messages: messages,
        memoryBlock: memoryBlock,
        llmConfig: llmConfig,
      );
      if (result != null) return result;
    }

    // All providers exhausted — this should not happen since localFallback
    // always succeeds, but defensive programming.
    return _handleLocalFallback(
      messages: messages,
      systemPrompt: systemPrompt,
    );
  }

  /// Run health checks on all providers.
  ///
  /// Returns current status (does not probe — returns tracked state).
  static Future<Map<LlmProvider, LlmHealthStatus>> healthCheck() async {
    final result = <LlmProvider, LlmHealthStatus>{};
    for (final provider in LlmProvider.values) {
      _checkRecovery(provider);
      result[provider] = _health[provider]!.status;
    }
    return result;
  }

  /// Report a failure for a provider (external callers, e.g. monitoring).
  static void reportFailure(LlmProvider provider, String reason) {
    _recordFailure(provider, reason);
  }

  /// Report a success for a provider (external callers).
  static void reportSuccess(LlmProvider provider, Duration latency) {
    _recordSuccess(provider, latency);
  }

  /// Score a response for quality monitoring.
  static Future<QualityScore> scoreResponse(LlmResponse response) async {
    return _computeQuality(response.content);
  }

  /// Reset health state for all providers (testing/recovery).
  @visibleForTesting
  static void resetHealth() {
    for (final entry in _health.entries) {
      entry.value
        ..consecutiveFailures = 0
        ..lastFailure = null
        ..lastLatency = null
        ..status = LlmHealthStatus.healthy;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — cloud provider handling
  // ══════════════════════════════════════════════════════════════

  /// Try a cloud provider with retries.
  static Future<LlmResponse?> _tryCloudProvider({
    required LlmProviderConfig config,
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? memoryBlock,
    LlmConfig? llmConfig,
  }) async {
    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      final stopwatch = Stopwatch()..start();
      try {
        final rawText = await _callProvider(
          provider: config.provider,
          systemPrompt: systemPrompt,
          messages: messages,
          memoryBlock: memoryBlock,
          llmConfig: llmConfig,
        ).timeout(config.timeout);

        stopwatch.stop();
        final latency = stopwatch.elapsed;

        if (rawText == null || rawText.trim().isEmpty) {
          debugPrint(
            '[MultiLLM] ${config.provider.name} returned empty (attempt ${attempt + 1})',
          );
          continue;
        }

        // Run ComplianceGuard on every response.
        final compliance = ComplianceGuard.validate(rawText);

        if (compliance.useFallback) {
          debugPrint(
            '[MultiLLM] ${config.provider.name} failed compliance: '
            '${compliance.violations}',
          );
          _recordFailure(
            config.provider,
            'Compliance rejection: ${compliance.violations.join(", ")}',
          );
          continue;
        }

        // Success!
        _recordSuccess(config.provider, latency);

        final text = compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : rawText;
        final quality = _computeQuality(text);

        return LlmResponse(
          content: text,
          provider: config.provider,
          latency: latency,
          passedCompliance: compliance.isCompliant,
          quality: quality,
        );
      } on TimeoutException {
        stopwatch.stop();
        debugPrint(
          '[MultiLLM] ${config.provider.name} timed out '
          '(${config.timeout.inSeconds}s, attempt ${attempt + 1})',
        );
        _recordFailure(config.provider, 'Timeout');
      } catch (e) {
        stopwatch.stop();
        // PRIVACY: Only log error type, never full message (may contain
        // API keys in URL, PII in request body, etc. — LPD art. 6).
        final errorType = e.runtimeType.toString();
        debugPrint(
          '[MultiLLM] ${config.provider.name} error (attempt ${attempt + 1}): $errorType',
        );
        _recordFailure(config.provider, errorType);
      }
    }

    return null; // All retries exhausted for this provider.
  }

  /// Call a specific cloud LLM provider.
  ///
  /// Maps [LlmProvider] to the appropriate backend call.
  static Future<String?> _callProvider({
    required LlmProvider provider,
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? memoryBlock,
    LlmConfig? llmConfig,
  }) async {
    if (llmConfig == null || !llmConfig.hasApiKey) return null;

    final ragService = RagService();
    final userMessage = messages.isNotEmpty ? messages.last.content : '';

    // Build augmented question with memory context.
    final question = (memoryBlock != null && memoryBlock.isNotEmpty)
        ? '$memoryBlock\n\n$userMessage'
        : userMessage;

    // Map MultiLlm provider to RAG provider string.
    final providerStr = switch (provider) {
      LlmProvider.claude => 'claude',
      LlmProvider.gpt4o => 'openai',
      LlmProvider.localFallback => 'local',
    };

    // Map MultiLlm provider to model string.
    final model = switch (provider) {
      LlmProvider.claude => 'claude-sonnet-4-5-20250929',
      LlmProvider.gpt4o => 'gpt-4o',
      LlmProvider.localFallback => '',
    };

    final response = await ragService.query(
      question: question,
      apiKey: llmConfig.apiKey,
      provider: providerStr,
      model: model,
      profileContext: const {},
    );

    return response.answer;
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — local fallback
  // ══════════════════════════════════════════════════════════════

  static LlmResponse _handleLocalFallback({
    required List<ChatMessage> messages,
    required String systemPrompt,
  }) {
    final userMessage = messages.isNotEmpty ? messages.last.content : '';
    final fallbackText = LocalFallbackService.generateFallback(
      userMessage: userMessage,
    );

    // COMPLIANCE: Run ComplianceGuard on local fallback too — same pipeline
    // as cloud providers. Templates are pre-validated but defense-in-depth
    // requires no bypass (LSFin art. 3/8, FINMA circular 2008/21).
    final compliance = ComplianceGuard.validate(fallbackText);

    final text = compliance.useFallback
        ? _emergencyFallback
        : (compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : fallbackText);

    final quality = _computeQuality(text);

    return LlmResponse(
      content: text,
      provider: LlmProvider.localFallback,
      latency: Duration.zero,
      tokensUsed: 0,
      passedCompliance: compliance.isCompliant,
      quality: quality,
    );
  }

  /// Last-resort emergency fallback when even local templates fail compliance.
  /// This text is statically validated — no banned terms, educational tone.
  static const String _emergencyFallback =
      'Je ne suis pas en mesure de répondre pour le moment. '
      'Explore les simulateurs (3a, LPP, retraite) dans l\u2019app '
      'pour des estimations chiffrées.\n\n'
      '_${ComplianceGuard.standardDisclaimer}_';

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — health tracking
  // ══════════════════════════════════════════════════════════════

  static void _recordFailure(LlmProvider provider, String reason) {
    final h = _health[provider]!;
    h.consecutiveFailures++;
    h.lastFailure = DateTime.now();

    if (h.consecutiveFailures >= _ProviderHealth.downThreshold) {
      h.status = LlmHealthStatus.down;
      debugPrint('[MultiLLM] ${provider.name} marked DOWN ($reason)');
    } else if (h.consecutiveFailures >= _ProviderHealth.degradedThreshold) {
      h.status = LlmHealthStatus.degraded;
      debugPrint('[MultiLLM] ${provider.name} marked DEGRADED ($reason)');
    }
  }

  static void _recordSuccess(LlmProvider provider, Duration latency) {
    final h = _health[provider]!;
    h.consecutiveFailures = 0;
    h.lastLatency = latency;
    h.status = LlmHealthStatus.healthy;
  }

  /// Check if a provider should be tentatively recovered.
  ///
  /// After [_recoveryWindow] since last failure, reset to healthy
  /// so the provider gets another chance.
  static void _checkRecovery(LlmProvider provider) {
    final h = _health[provider]!;
    if (h.status == LlmHealthStatus.healthy) return;
    if (h.lastFailure == null) return;

    final elapsed = DateTime.now().difference(h.lastFailure!);
    if (elapsed >= _recoveryWindow) {
      debugPrint(
        '[MultiLLM] ${provider.name} recovered after ${elapsed.inMinutes}min',
      );
      h
        ..consecutiveFailures = 0
        ..status = LlmHealthStatus.healthy;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — quality scoring
  // ══════════════════════════════════════════════════════════════

  /// Compute quality score for a response text.
  ///
  /// - relevance: heuristic based on response length and structure
  /// - compliance: checks banned terms, prescriptive language
  /// - frenchQuality: checks accents, NBSP usage
  static QualityScore _computeQuality(String text) {
    final relevance = _scoreRelevance(text);
    final compliance = _scoreCompliance(text);
    final frenchQuality = _scoreFrenchQuality(text);
    return QualityScore.compute(
      relevance: relevance,
      compliance: compliance,
      frenchQuality: frenchQuality,
    );
  }

  /// Relevance heuristic: penalize very short or empty responses.
  static double _scoreRelevance(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    if (wordCount < 5) return 0.2;
    if (wordCount < 15) return 0.5;
    if (wordCount < 30) return 0.7;
    return 1.0;
  }

  /// Compliance score: check for banned terms and prescriptive patterns.
  static double _scoreCompliance(String text) {
    var score = 1.0;
    final lower = text.toLowerCase();

    // Check banned terms.
    for (final term in ComplianceGuard.bannedTerms) {
      if (lower.contains(term)) {
        score -= 0.15;
      }
    }

    // Check prescriptive patterns.
    for (final pattern in ComplianceGuard.prescriptivePatterns) {
      if (pattern.hasMatch(text)) {
        score -= 0.2;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  /// French quality score: check accents, NBSP, and grammar markers.
  static double _scoreFrenchQuality(String text) {
    var score = 1.0;

    // Check for missing NBSP before punctuation.
    final missingNbsp = RegExp(r'\w[!?:;%]');
    final nbspViolations = missingNbsp.allMatches(text).length;
    score -= nbspViolations * 0.05;

    // Check for common missing accents in financial French.
    final missingAccents = [
      RegExp(r'\bimpot\b', caseSensitive: false),
      RegExp(r'\betre\b', caseSensitive: false),
      RegExp(r'\bprevoyance\b', caseSensitive: false),
      RegExp(r'\binterets\b', caseSensitive: false),
    ];
    for (final pattern in missingAccents) {
      if (pattern.hasMatch(text)) {
        score -= 0.1;
      }
    }

    return score.clamp(0.0, 1.0);
  }
}
