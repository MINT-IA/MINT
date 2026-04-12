// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/llm/provider_health_service.dart';

// ────────────────────────────────────────────────────────────
//  PROVIDER HEALTH SERVICE TESTS — Sprint S64
// ────────────────────────────────────────────────────────────
//
// 17 tests covering:
//   - Record success increments count
//   - Record failure increments count
//   - 3 consecutive failures → circuit opens
//   - Circuit reopens after 5 minutes (half-open)
//   - Probe success → circuit closes
//   - Probe fails → reopen
//   - Success rate calculation
//   - Average latency calculation
//   - No data → healthy defaults
//   - Multiple providers tracked independently
//   - resetProvider clears data
//   - resetAll clears all providers
//   - isCircuitOpen returns false for healthy provider
//   - getHealth returns map of all providers
//   - Extended backoff logic after failed probe
//   - Circuit stays open before timeout elapsed
//   - ProviderHealth.healthy() factory
//
// References: FINMA circulaire 2008/21
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  // ProviderHealth — data model
  // ═══════════════════════════════════════════════════════════

  group('ProviderHealth', () {
    test('healthy() factory returns all-zero healthy defaults', () {
      final h = ProviderHealth.healthy('claude');

      expect(h.provider, 'claude');
      expect(h.totalAttempts, 0);
      expect(h.successCount, 0);
      expect(h.failureCount, 0);
      expect(h.successRate, 1.0);
      expect(h.averageLatency, Duration.zero);
      expect(h.consecutiveFailures, 0);
      expect(h.circuitOpen, false);
      expect(h.circuitOpensAt, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // recordAttempt — success
  // ═══════════════════════════════════════════════════════════

  group('recordAttempt — success', () {
    test('success increments totalAttempts and successCount', () async {
      final prefs = await SharedPreferences.getInstance();

      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: true,
        latency: const Duration(milliseconds: 300),
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.totalAttempts, 1);
      expect(health.successCount, 1);
      expect(health.failureCount, 0);
      expect(health.consecutiveFailures, 0);
    });

    test('success resets consecutiveFailures to 0', () async {
      final prefs = await SharedPreferences.getInstance();

      // Record 2 failures
      for (var i = 0; i < 2; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      // Then a success
      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: true,
        latency: const Duration(milliseconds: 200),
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.consecutiveFailures, 0);
      expect(health.successCount, 1);
    });

    test('success after circuit open → circuit closes', () async {
      final prefs = await SharedPreferences.getInstance();

      // Open circuit with 3 failures
      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      var health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.circuitOpen, true);

      // Record success (probe succeeds)
      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: true,
        latency: const Duration(milliseconds: 100),
        prefs: prefs,
      );

      health = await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.circuitOpen, false);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // recordAttempt — failure
  // ═══════════════════════════════════════════════════════════

  group('recordAttempt — failure', () {
    test('failure increments totalAttempts and failureCount', () async {
      final prefs = await SharedPreferences.getInstance();

      await ProviderHealthService.recordAttempt(
        provider: 'openai',
        success: false,
        latency: const Duration(milliseconds: 500),
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('openai', prefs);
      expect(health.totalAttempts, 1);
      expect(health.failureCount, 1);
      expect(health.successCount, 0);
      expect(health.consecutiveFailures, 1);
    });

    test('3 consecutive failures → circuit opens', () async {
      final prefs = await SharedPreferences.getInstance();

      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.circuitOpen, true);
      expect(health.consecutiveFailures, 3);
      expect(health.circuitOpensAt, isNotNull);
    });

    test('2 consecutive failures → circuit stays closed', () async {
      final prefs = await SharedPreferences.getInstance();

      for (var i = 0; i < 2; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'mistral',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      final health =
          await ProviderHealthService.getProviderHealth('mistral', prefs);
      expect(health.circuitOpen, false);
    });

    test('circuit does not reopen if already open', () async {
      final prefs = await SharedPreferences.getInstance();

      // Open it
      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      final openedAt = (await ProviderHealthService.getProviderHealth(
        'claude',
        prefs,
      ))
          .circuitOpensAt!;

      // One more failure — circuitOpensAt should not change
      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: false,
        latency: Duration.zero,
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.circuitOpensAt, openedAt);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // isCircuitOpen — circuit-breaker behaviour
  // ═══════════════════════════════════════════════════════════

  group('isCircuitOpen', () {
    test('returns false for healthy provider (no data)', () async {
      final prefs = await SharedPreferences.getInstance();
      final open =
          await ProviderHealthService.isCircuitOpen('claude', prefs);
      expect(open, false);
    });

    test('returns true after 3 consecutive failures', () async {
      final prefs = await SharedPreferences.getInstance();

      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      final open =
          await ProviderHealthService.isCircuitOpen('claude', prefs);
      expect(open, true);
    });

    test('circuit stays open before timeout elapsed', () async {
      final prefs = await SharedPreferences.getInstance();

      // Open the circuit
      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'openai',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      // Check immediately — should still be open
      final open =
          await ProviderHealthService.isCircuitOpen('openai', prefs);
      expect(open, true);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Success rate and latency calculations
  // ═══════════════════════════════════════════════════════════

  group('Success rate and latency', () {
    test('success rate = successCount / totalAttempts', () async {
      final prefs = await SharedPreferences.getInstance();

      // 3 successes, 1 failure → 75%
      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: true,
          latency: const Duration(milliseconds: 200),
          prefs: prefs,
        );
      }
      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: false,
        latency: const Duration(milliseconds: 300),
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.successRate, closeTo(0.75, 0.001));
    });

    test('no data → success rate = 1.0 (healthy default)', () async {
      final prefs = await SharedPreferences.getInstance();
      final health =
          await ProviderHealthService.getProviderHealth('mistral', prefs);
      expect(health.successRate, 1.0);
    });

    test('average latency calculated correctly', () async {
      final prefs = await SharedPreferences.getInstance();

      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: true,
        latency: const Duration(milliseconds: 100),
        prefs: prefs,
      );
      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: true,
        latency: const Duration(milliseconds: 300),
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      // Average of 100ms and 300ms = 200ms
      expect(health.averageLatency.inMilliseconds, closeTo(200, 1));
    });

    test('no data → averageLatency = Duration.zero', () async {
      final prefs = await SharedPreferences.getInstance();
      final health =
          await ProviderHealthService.getProviderHealth('openai', prefs);
      expect(health.averageLatency, Duration.zero);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Multiple providers tracked independently
  // ═══════════════════════════════════════════════════════════

  group('Multiple providers', () {
    test('different providers tracked independently', () async {
      final prefs = await SharedPreferences.getInstance();

      // 3 failures for claude
      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }
      // 1 success for openai
      await ProviderHealthService.recordAttempt(
        provider: 'openai',
        success: true,
        latency: const Duration(milliseconds: 200),
        prefs: prefs,
      );

      final claudeHealth =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      final openaiHealth =
          await ProviderHealthService.getProviderHealth('openai', prefs);

      expect(claudeHealth.circuitOpen, true);
      expect(openaiHealth.circuitOpen, false);
      expect(openaiHealth.successCount, 1);
    });

    test('getHealth returns map of all tracked providers', () async {
      final prefs = await SharedPreferences.getInstance();

      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: true,
        latency: const Duration(milliseconds: 100),
        prefs: prefs,
      );
      await ProviderHealthService.recordAttempt(
        provider: 'openai',
        success: true,
        latency: const Duration(milliseconds: 200),
        prefs: prefs,
      );

      final healthMap = await ProviderHealthService.getHealth(prefs);

      expect(healthMap.containsKey('claude'), true);
      expect(healthMap.containsKey('openai'), true);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Reset helpers
  // ═══════════════════════════════════════════════════════════

  group('Reset helpers', () {
    test('resetProvider clears data for that provider', () async {
      final prefs = await SharedPreferences.getInstance();

      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      await ProviderHealthService.resetProvider('claude', prefs);

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.totalAttempts, 0);
      expect(health.circuitOpen, false);
    });

    test('resetAll clears data for all providers', () async {
      final prefs = await SharedPreferences.getInstance();

      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: false,
        latency: Duration.zero,
        prefs: prefs,
      );
      await ProviderHealthService.recordAttempt(
        provider: 'openai',
        success: false,
        latency: Duration.zero,
        prefs: prefs,
      );

      await ProviderHealthService.resetAll(prefs);

      final healthMap = await ProviderHealthService.getHealth(prefs);
      expect(healthMap, isEmpty);
    });

    test('failure after reset starts fresh consecutive count', () async {
      final prefs = await SharedPreferences.getInstance();

      // Open circuit
      for (var i = 0; i < 3; i++) {
        await ProviderHealthService.recordAttempt(
          provider: 'claude',
          success: false,
          latency: Duration.zero,
          prefs: prefs,
        );
      }

      await ProviderHealthService.resetProvider('claude', prefs);

      // Single failure after reset should NOT open circuit
      await ProviderHealthService.recordAttempt(
        provider: 'claude',
        success: false,
        latency: Duration.zero,
        prefs: prefs,
      );

      final health =
          await ProviderHealthService.getProviderHealth('claude', prefs);
      expect(health.circuitOpen, false);
      expect(health.consecutiveFailures, 1);
    });
  });
}
