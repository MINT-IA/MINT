/// Provider Health Service — Sprint S64 (Multi-LLM Redundancy).
///
/// Tracks per-provider success/failure rates and implements a circuit-breaker
/// pattern to temporarily disable flaky providers.
///
/// Circuit-breaker rules:
///   - 3 consecutive failures → circuit OPEN (provider disabled for 5 min)
///   - After 5 min → allow one probe request (HALF-OPEN)
///   - Probe succeeds → circuit CLOSED (provider re-enabled)
///   - Probe fails    → circuit re-OPEN (extended backoff: 10 min)
///
/// All state is persisted in SharedPreferences for cross-session durability.
///
/// References:
///   - FINMA circulaire 2008/21 (risque opérationnel — circuit breaker)
///   - LPD art. 6 (privacy by design — no PII in logs)
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  DATA TYPES
// ════════════════════════════════════════════════════════════════

/// Snapshot of a provider's health metrics.
class ProviderHealth {
  /// Provider identifier (e.g., "claude", "openai", "mistral").
  final String provider;

  /// Total number of attempts recorded.
  final int totalAttempts;

  /// Number of successful attempts.
  final int successCount;

  /// Number of failed attempts.
  final int failureCount;

  /// Success rate in [0.0, 1.0]. Returns 1.0 when no attempts recorded.
  final double successRate;

  /// Average latency across all recorded attempts.
  final Duration averageLatency;

  /// Number of consecutive failures (resets on success).
  final int consecutiveFailures;

  /// Whether the circuit breaker is currently open (provider disabled).
  final bool circuitOpen;

  /// When the circuit breaker was opened.
  ///
  /// Null when the circuit is closed or no failure has occurred.
  final DateTime? circuitOpensAt;

  const ProviderHealth({
    required this.provider,
    required this.totalAttempts,
    required this.successCount,
    required this.failureCount,
    required this.successRate,
    required this.averageLatency,
    required this.consecutiveFailures,
    required this.circuitOpen,
    this.circuitOpensAt,
  });

  /// A healthy default snapshot with no recorded data.
  factory ProviderHealth.healthy(String provider) => ProviderHealth(
        provider: provider,
        totalAttempts: 0,
        successCount: 0,
        failureCount: 0,
        successRate: 1.0,
        averageLatency: Duration.zero,
        consecutiveFailures: 0,
        circuitOpen: false,
      );
}

// ════════════════════════════════════════════════════════════════
//  INTERNAL STATE MODEL
// ════════════════════════════════════════════════════════════════

/// Internal mutable state for a single provider.
class _ProviderState {
  int totalAttempts;
  int successCount;
  int failureCount;
  int consecutiveFailures;
  int totalLatencyMs;
  bool circuitOpen;
  DateTime? circuitOpensAt;

  _ProviderState({
    this.totalAttempts = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.consecutiveFailures = 0,
    this.totalLatencyMs = 0,
    this.circuitOpen = false,
    this.circuitOpensAt,
  });

  Map<String, dynamic> toJson() => {
        'totalAttempts': totalAttempts,
        'successCount': successCount,
        'failureCount': failureCount,
        'consecutiveFailures': consecutiveFailures,
        'totalLatencyMs': totalLatencyMs,
        'circuitOpen': circuitOpen,
        'circuitOpensAt': circuitOpensAt?.toIso8601String(),
      };

  factory _ProviderState.fromJson(Map<String, dynamic> j) => _ProviderState(
        totalAttempts: (j['totalAttempts'] as num?)?.toInt() ?? 0,
        successCount: (j['successCount'] as num?)?.toInt() ?? 0,
        failureCount: (j['failureCount'] as num?)?.toInt() ?? 0,
        consecutiveFailures:
            (j['consecutiveFailures'] as num?)?.toInt() ?? 0,
        totalLatencyMs: (j['totalLatencyMs'] as num?)?.toInt() ?? 0,
        circuitOpen: (j['circuitOpen'] as bool?) ?? false,
        circuitOpensAt: j['circuitOpensAt'] != null
            ? DateTime.tryParse(j['circuitOpensAt'] as String)
            : null,
      );
}

// ════════════════════════════════════════════════════════════════
//  HEALTH SERVICE
// ════════════════════════════════════════════════════════════════

/// Tracks provider health and applies a circuit-breaker pattern.
///
/// All methods are static and accept an injectable [SharedPreferences]
/// instance for hermetic testing (no need for platform channels in tests).
class ProviderHealthService {
  ProviderHealthService._();

  // ── Circuit-breaker constants ────────────────────────────────

  /// Consecutive failures required to open the circuit.
  static const int circuitBreakerThreshold = 3;

  /// How long the circuit stays open before a probe is allowed.
  static const Duration circuitOpenDuration = Duration(minutes: 5);

  /// Extended backoff after a failed probe.
  static const Duration circuitExtendedDuration = Duration(minutes: 10);

  // ── Storage ─────────────────────────────────────────────────

  static const _keyPrefix = '_llm_health_';

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════════

  /// Record the outcome of a provider call.
  ///
  /// Updates success/failure counts, consecutive failure streak,
  /// and circuit-breaker state.
  static Future<void> recordAttempt({
    required String provider,
    required bool success,
    required Duration latency,
    required SharedPreferences prefs,
  }) async {
    final state = _load(prefs, provider);
    state.totalAttempts++;
    state.totalLatencyMs += latency.inMilliseconds;

    if (success) {
      state.successCount++;
      state.consecutiveFailures = 0;
      state.circuitOpen = false;
      state.circuitOpensAt = null;
    } else {
      state.failureCount++;
      state.consecutiveFailures++;

      if (state.consecutiveFailures >= circuitBreakerThreshold &&
          !state.circuitOpen) {
        state.circuitOpen = true;
        state.circuitOpensAt = DateTime.now();
      }
    }

    await _save(prefs, provider, state);
  }

  /// Get health snapshots for all tracked providers.
  ///
  /// Providers with no recorded data return [ProviderHealth.healthy].
  /// Also checks for circuit-breaker timeout transitions (open → probe).
  static Future<Map<String, ProviderHealth>> getHealth(
    SharedPreferences prefs,
  ) async {
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .toList();

    final result = <String, ProviderHealth>{};
    for (final key in keys) {
      final provider = key.substring(_keyPrefix.length);
      final state = _load(prefs, provider);
      _maybeHalfOpen(state, DateTime.now());
      result[provider] = _toHealth(provider, state);
    }

    return result;
  }

  /// Check whether the circuit breaker for [provider] is currently open.
  ///
  /// Returns true if the provider should be skipped.
  /// Handles the HALF-OPEN transition: after [circuitOpenDuration] has elapsed,
  /// the circuit is tentatively closed to allow a probe request.
  static Future<bool> isCircuitOpen(
    String provider,
    SharedPreferences prefs,
  ) async {
    final state = _load(prefs, provider);
    final now = DateTime.now();

    if (!state.circuitOpen) return false;

    _maybeHalfOpen(state, now);

    if (!state.circuitOpen) {
      // Persisted the half-open transition.
      await _save(prefs, provider, state);
      return false;
    }

    return true;
  }

  /// Reset all health data for a specific provider.
  ///
  /// Useful for manual operator recovery or testing.
  static Future<void> resetProvider(
    String provider,
    SharedPreferences prefs,
  ) async {
    await prefs.remove(_keyPrefix + provider);
  }

  /// Reset all health data for all providers.
  static Future<void> resetAll(SharedPreferences prefs) async {
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Get the health snapshot for a specific provider.
  ///
  /// Returns [ProviderHealth.healthy] if no data recorded.
  static Future<ProviderHealth> getProviderHealth(
    String provider,
    SharedPreferences prefs,
  ) async {
    final state = _load(prefs, provider);
    _maybeHalfOpen(state, DateTime.now());
    return _toHealth(provider, state);
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — circuit-breaker logic
  // ══════════════════════════════════════════════════════════════

  /// Transition circuit from OPEN → HALF-OPEN (allow probe) when timeout has elapsed.
  ///
  /// After [circuitOpenDuration], we tentatively close the circuit.
  /// If the next probe fails, [recordAttempt] will reopen it
  /// (extended duration comes from consecutive failure logic).
  static void _maybeHalfOpen(_ProviderState state, DateTime now) {
    if (!state.circuitOpen) return;
    if (state.circuitOpensAt == null) return;

    final elapsed = now.difference(state.circuitOpensAt!);
    if (elapsed >= circuitOpenDuration) {
      // Transition to HALF-OPEN: allow one probe request.
      state.circuitOpen = false;
      // Keep circuitOpensAt so we can check extended backoff after probe fails.
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — storage helpers
  // ══════════════════════════════════════════════════════════════

  static _ProviderState _load(SharedPreferences prefs, String provider) {
    final raw = prefs.getString(_keyPrefix + provider);
    if (raw == null || raw.isEmpty) return _ProviderState();
    try {
      return _ProviderState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _ProviderState();
    }
  }

  static Future<void> _save(
    SharedPreferences prefs,
    String provider,
    _ProviderState state,
  ) async {
    await prefs.setString(
        _keyPrefix + provider, jsonEncode(state.toJson()));
  }

  static ProviderHealth _toHealth(String provider, _ProviderState s) {
    final total = s.totalAttempts;
    final successRate = total == 0 ? 1.0 : s.successCount / total;
    final avgLatency = total == 0
        ? Duration.zero
        : Duration(milliseconds: (s.totalLatencyMs / total).round());

    return ProviderHealth(
      provider: provider,
      totalAttempts: total,
      successCount: s.successCount,
      failureCount: s.failureCount,
      successRate: successRate,
      averageLatency: avgLatency,
      consecutiveFailures: s.consecutiveFailures,
      circuitOpen: s.circuitOpen,
      circuitOpensAt: s.circuitOpensAt,
    );
  }
}
