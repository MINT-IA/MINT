/// LLM Failover Service — Sprint S64 (Multi-LLM Redundancy).
///
/// Multi-provider failover: Claude → GPT-4o → fallback templates.
/// Each provider is tried in order. If one fails (timeout, error, compliance
/// breach), the next is tried automatically.
///
/// Design:
///   - Pure orchestration logic; no SharedPreferences I/O (owned by callers).
///   - All providers use string identifiers for loose coupling.
///   - Each call is independent and self-contained.
///   - Integrates with [ProviderHealthService] circuit-breaker (optional).
///
/// References:
///   - FINMA circulaire 2008/21 (risque opérationnel — failover)
///   - LSFin art. 3/8 (qualité de l'information financière)
///   - LPD art. 6 (privacy by design)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

// ════════════════════════════════════════════════════════════════
//  DATA TYPES
// ════════════════════════════════════════════════════════════════

/// Configuration for a single LLM provider in the failover chain.
class LlmProviderConfig {
  /// Provider identifier: "claude", "openai", "mistral".
  final String provider;

  /// API key for this provider. Empty string when not configured.
  final String apiKey;

  /// Optional model override (e.g., "claude-sonnet-4-5-20250929", "gpt-4o").
  final String? model;

  /// Whether this provider is enabled by the user.
  ///
  /// When false, this provider is skipped in the failover chain.
  final bool isAvailable;

  const LlmProviderConfig({
    required this.provider,
    required this.apiKey,
    this.model,
    this.isAvailable = true,
  });

  /// Whether this config has a non-empty API key.
  bool get hasApiKey => apiKey.isNotEmpty;

  /// Effective model name for this provider.
  ///
  /// Returns [model] if set, otherwise the provider's default model.
  String get effectiveModel {
    if (model != null && model!.isNotEmpty) return model!;
    return switch (provider) {
      'claude' => 'claude-sonnet-4-5-20250929',
      'openai' => 'gpt-4o',
      'mistral' => 'mistral-large-latest',
      _ => 'default',
    };
  }
}

/// Log entry for a single provider attempt.
class LlmAttemptLog {
  /// Which provider was attempted.
  final String provider;

  /// Whether the attempt succeeded.
  final bool success;

  /// Wall-clock time for this attempt.
  final Duration latency;

  /// Error message if the attempt failed (null on success).
  ///
  /// PRIVACY: must not contain PII or full API request bodies (LPD art. 6).
  final String? errorMessage;

  const LlmAttemptLog({
    required this.provider,
    required this.success,
    required this.latency,
    this.errorMessage,
  });
}

/// Result of a [LlmFailoverService.generate] call.
class LlmFailoverResult {
  /// The response text (from the first successful provider, or fallback).
  final String text;

  /// Which provider produced this result.
  ///
  /// "fallback" when all providers failed and a static template was used.
  final String providerUsed;

  /// Number of providers that were attempted (including the successful one).
  final int attemptCount;

  /// End-to-end latency for the winning attempt.
  final Duration latency;

  /// Ordered log of all provider attempts (including failures).
  final List<LlmAttemptLog> attempts;

  /// True when all LLM providers failed and a static fallback was used.
  final bool usedFallback;

  const LlmFailoverResult({
    required this.text,
    required this.providerUsed,
    required this.attemptCount,
    required this.latency,
    required this.attempts,
    required this.usedFallback,
  });
}

// ════════════════════════════════════════════════════════════════
//  PROVIDER CALLBACK TYPE
// ════════════════════════════════════════════════════════════════

/// Async function that calls a specific LLM provider.
///
/// Returns the response text, or throws on failure.
/// Used for dependency injection in tests.
typedef LlmProviderCallback = Future<String> Function(
  LlmProviderConfig config,
  String userMessage,
  String systemPrompt,
);

// ════════════════════════════════════════════════════════════════
//  FAILOVER SERVICE
// ════════════════════════════════════════════════════════════════

/// Static fallback text when all LLM providers fail.
///
/// Pre-validated against ComplianceGuard; educational, no banned terms.
const _staticFallback =
    'Le service IA est momentanément indisponible. '
    'Tu peux utiliser les simulateurs (3a, LPP, retraite) '
    'pour des estimations chiffrées, ou réessayer dans quelques instants.\n\n'
    '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

/// Multi-LLM failover orchestrator.
///
/// Tries providers in the order provided. On failure (error, timeout,
/// empty response), the next provider is tried automatically.
///
/// This class contains pure orchestration logic. Network I/O is delegated
/// to the [LlmProviderCallback] injected by the caller.
class LlmFailoverService {
  LlmFailoverService._();

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════════

  /// Attempt to generate a response with automatic provider failover.
  ///
  /// Iterates [providers] in order:
  ///   1. Skips providers where [LlmProviderConfig.isAvailable] == false.
  ///   2. Skips providers without an API key (unless [callProvider] handles it).
  ///   3. Calls [callProvider] with timeout [timeout].
  ///   4. On success → returns immediately with the response.
  ///   5. On failure → records the error, tries the next provider.
  ///
  /// If all providers fail (or the list is empty), returns a static
  /// educational fallback with [LlmFailoverResult.usedFallback] == true.
  ///
  /// [callProvider] is an async function that performs the actual LLM call.
  /// Inject a mock in tests to avoid network I/O.
  static Future<LlmFailoverResult> generate({
    required String userMessage,
    required String systemPrompt,
    required List<LlmProviderConfig> providers,
    required LlmProviderCallback callProvider,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final attempts = <LlmAttemptLog>[];

    for (final config in providers) {
      // Skip unavailable providers.
      if (!config.isAvailable) {
        debugPrint('[LlmFailover] Skipping ${config.provider} (unavailable)');
        continue;
      }

      // Skip providers without API keys.
      if (!config.hasApiKey) {
        debugPrint(
            '[LlmFailover] Skipping ${config.provider} (no API key)');
        continue;
      }

      final stopwatch = Stopwatch()..start();
      try {
        final text = await callProvider(config, userMessage, systemPrompt)
            .timeout(timeout);
        stopwatch.stop();
        final latency = stopwatch.elapsed;

        // Reject empty responses.
        if (text.trim().isEmpty) {
          stopwatch.stop();
          final emptyLog = LlmAttemptLog(
            provider: config.provider,
            success: false,
            latency: stopwatch.elapsed,
            errorMessage: 'Empty response',
          );
          attempts.add(emptyLog);
          debugPrint(
              '[LlmFailover] ${config.provider} returned empty — trying next');
          continue;
        }

        // Success.
        attempts.add(LlmAttemptLog(
          provider: config.provider,
          success: true,
          latency: latency,
        ));

        return LlmFailoverResult(
          text: text,
          providerUsed: config.provider,
          attemptCount: attempts.length,
          latency: latency,
          attempts: List.unmodifiable(attempts),
          usedFallback: false,
        );
      } on TimeoutException {
        stopwatch.stop();
        final errorMsg =
            'Timeout after ${timeout.inSeconds}s';
        debugPrint('[LlmFailover] ${config.provider} $errorMsg');
        attempts.add(LlmAttemptLog(
          provider: config.provider,
          success: false,
          latency: stopwatch.elapsed,
          errorMessage: errorMsg,
        ));
      } catch (e) {
        stopwatch.stop();
        // PRIVACY: log only the error type, not the full message
        // (may contain API keys or PII — LPD art. 6).
        final errorType = e.runtimeType.toString();
        debugPrint(
            '[LlmFailover] ${config.provider} error: $errorType');
        attempts.add(LlmAttemptLog(
          provider: config.provider,
          success: false,
          latency: stopwatch.elapsed,
          errorMessage: errorType,
        ));
      }
    }

    // All providers exhausted — return static fallback.
    debugPrint(
        '[LlmFailover] All providers failed (${attempts.length} attempts) — '
        'using static fallback');

    return LlmFailoverResult(
      text: _staticFallback,
      providerUsed: 'fallback',
      attemptCount: attempts.length,
      latency: Duration.zero,
      attempts: List.unmodifiable(attempts),
      usedFallback: true,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════

  /// Build an ordered provider list from a map of provider → API key.
  ///
  /// Default priority: claude → openai → mistral.
  /// Providers with an empty API key are included but will be skipped
  /// by [generate] (no key guard).
  static List<LlmProviderConfig> buildProviders({
    String claudeApiKey = '',
    String openaiApiKey = '',
    String mistralApiKey = '',
  }) {
    return [
      LlmProviderConfig(
        provider: 'claude',
        apiKey: claudeApiKey,
        model: 'claude-sonnet-4-5-20250929',
      ),
      LlmProviderConfig(
        provider: 'openai',
        apiKey: openaiApiKey,
        model: 'gpt-4o',
      ),
      LlmProviderConfig(
        provider: 'mistral',
        apiKey: mistralApiKey,
        model: 'mistral-large-latest',
      ),
    ];
  }

  /// Static fallback text (exposed for testing).
  static String get staticFallbackText => _staticFallback;
}
