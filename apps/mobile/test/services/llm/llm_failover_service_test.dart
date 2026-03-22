// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/llm/llm_failover_service.dart';

// ────────────────────────────────────────────────────────────
//  LLM FAILOVER SERVICE TESTS — Sprint S64
// ────────────────────────────────────────────────────────────
//
// 18 tests covering:
//   - Single provider success on first attempt
//   - First provider fails, second succeeds → attemptCount=2
//   - All providers fail → usedFallback=true
//   - Timeout respected
//   - Empty provider list → usedFallback=true
//   - Provider order respected
//   - Unavailable providers are skipped
//   - Providers without API key are skipped
//   - Compliance breach (empty response) → try next
//   - LlmAttemptLog fields
//   - LlmProviderConfig helpers
//   - LlmFailoverResult fields
//   - buildProviders helper
//   - staticFallbackText content
//
// References: FINMA circulaire 2008/21, LSFin art. 3/8
// ────────────────────────────────────────────────────────────

/// Helper: build a callback that always succeeds with [text].
LlmProviderCallback _successCallback(String text) {
  return (config, userMessage, systemPrompt) async => text;
}

/// Helper: build a callback that always throws.
LlmProviderCallback _failCallback(String message) {
  return (config, userMessage, systemPrompt) async =>
      throw Exception(message);
}

/// Helper: build a callback that times out.
LlmProviderCallback _timeoutCallback(Duration delay) {
  return (config, userMessage, systemPrompt) async {
    await Future<void>.delayed(delay);
    return 'Too late';
  };
}

/// Helper: callback that succeeds for one provider, fails for others.
LlmProviderCallback _firstSucceedingCallback({
  required String successfulProvider,
  required String successText,
}) {
  return (config, userMessage, systemPrompt) async {
    if (config.provider == successfulProvider) return successText;
    throw Exception('Provider ${config.provider} failed');
  };
}

void main() {
  // ═══════════════════════════════════════════════════════════
  // LlmProviderConfig — data model
  // ═══════════════════════════════════════════════════════════

  group('LlmProviderConfig', () {
    test('hasApiKey returns true when key is non-empty', () {
      const config = LlmProviderConfig(provider: 'claude', apiKey: 'sk-test');
      expect(config.hasApiKey, true);
    });

    test('hasApiKey returns false when key is empty', () {
      const config = LlmProviderConfig(provider: 'claude', apiKey: '');
      expect(config.hasApiKey, false);
    });

    test('effectiveModel returns explicit model when provided', () {
      const config = LlmProviderConfig(
        provider: 'claude',
        apiKey: 'sk-test',
        model: 'claude-3-opus-20240229',
      );
      expect(config.effectiveModel, 'claude-3-opus-20240229');
    });

    test('effectiveModel returns default claude model when none specified', () {
      const config = LlmProviderConfig(provider: 'claude', apiKey: 'sk-test');
      expect(config.effectiveModel, 'claude-sonnet-4-5-20250929');
    });

    test('effectiveModel returns gpt-4o as default for openai', () {
      const config = LlmProviderConfig(provider: 'openai', apiKey: 'sk-test');
      expect(config.effectiveModel, 'gpt-4o');
    });

    test('effectiveModel returns mistral-large for mistral', () {
      const config = LlmProviderConfig(provider: 'mistral', apiKey: 'sk-test');
      expect(config.effectiveModel, 'mistral-large-latest');
    });

    test('isAvailable defaults to true', () {
      const config = LlmProviderConfig(provider: 'claude', apiKey: 'sk-test');
      expect(config.isAvailable, true);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LlmFailoverService.generate — core failover
  // ═══════════════════════════════════════════════════════════

  group('LlmFailoverService.generate — failover chain', () {
    test('single provider success → returns on first attempt', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test question',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
        ],
        callProvider: _successCallback('Hello from Claude'),
      );

      expect(result.text, 'Hello from Claude');
      expect(result.providerUsed, 'claude');
      expect(result.attemptCount, 1);
      expect(result.usedFallback, false);
      expect(result.attempts.length, 1);
      expect(result.attempts.first.success, true);
    });

    test('first provider fails, second succeeds → attemptCount=2', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: _firstSucceedingCallback(
          successfulProvider: 'openai',
          successText: 'Hello from GPT-4o',
        ),
      );

      expect(result.text, 'Hello from GPT-4o');
      expect(result.providerUsed, 'openai');
      expect(result.attemptCount, 2);
      expect(result.usedFallback, false);
      expect(result.attempts.length, 2);
      expect(result.attempts[0].provider, 'claude');
      expect(result.attempts[0].success, false);
      expect(result.attempts[1].provider, 'openai');
      expect(result.attempts[1].success, true);
    });

    test('all providers fail → usedFallback=true', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: _failCallback('network error'),
      );

      expect(result.usedFallback, true);
      expect(result.providerUsed, 'fallback');
      expect(result.text, isNotEmpty);
      expect(result.text, contains('IA'));
      expect(result.attempts.length, 2);
      expect(result.attempts.every((a) => !a.success), true);
    });

    test('empty provider list → usedFallback=true, attemptCount=0', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: const [],
        callProvider: _successCallback('should not be called'),
      );

      expect(result.usedFallback, true);
      expect(result.providerUsed, 'fallback');
      expect(result.attemptCount, 0);
      expect(result.attempts, isEmpty);
    });

    test('unavailable provider is skipped', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(
              provider: 'claude', apiKey: 'sk-claude', isAvailable: false),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: _firstSucceedingCallback(
          successfulProvider: 'openai',
          successText: 'GPT-4o response',
        ),
      );

      // claude was skipped → only openai attempted
      expect(result.providerUsed, 'openai');
      expect(result.attemptCount, 1);
      expect(result.attempts.length, 1);
    });

    test('provider without API key is skipped', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: ''),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: _firstSucceedingCallback(
          successfulProvider: 'openai',
          successText: 'GPT-4o response',
        ),
      );

      // claude has no key → skipped
      expect(result.providerUsed, 'openai');
      expect(result.attemptCount, 1);
    });

    test('provider order respected — claude tried before openai', () async {
      final attemptOrder = <String>[];

      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: (config, userMessage, systemPrompt) async {
          attemptOrder.add(config.provider);
          if (config.provider == 'claude') return 'Claude succeeded';
          return 'OpenAI response';
        },
      );

      expect(attemptOrder.first, 'claude');
      expect(result.providerUsed, 'claude');
    });

    test('empty response → try next provider', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: (config, userMessage, systemPrompt) async {
          if (config.provider == 'claude') return '';
          return 'OpenAI response';
        },
      );

      // empty response from claude → fallover to openai
      expect(result.providerUsed, 'openai');
      expect(result.text, 'OpenAI response');
      expect(result.attempts[0].errorMessage, contains('Empty'));
    });

    test('timeout respected — provider times out → fallback used', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
        ],
        callProvider: _timeoutCallback(const Duration(seconds: 10)),
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.usedFallback, true);
      expect(result.attempts.first.success, false);
      expect(result.attempts.first.errorMessage, contains('Timeout'));
    });

    test('whitespace-only response treated as empty → try next', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
          const LlmProviderConfig(provider: 'openai', apiKey: 'sk-openai'),
        ],
        callProvider: (config, userMessage, systemPrompt) async {
          if (config.provider == 'claude') return '   \n  ';
          return 'GPT response';
        },
      );

      expect(result.providerUsed, 'openai');
    });

    test('all providers unavailable → usedFallback=true', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(
              provider: 'claude', apiKey: 'sk-c', isAvailable: false),
          const LlmProviderConfig(
              provider: 'openai', apiKey: 'sk-o', isAvailable: false),
        ],
        callProvider: _successCallback('Unreachable'),
      );

      expect(result.usedFallback, true);
      expect(result.attemptCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LlmAttemptLog
  // ═══════════════════════════════════════════════════════════

  group('LlmAttemptLog', () {
    test('stores all fields correctly', () {
      const log = LlmAttemptLog(
        provider: 'claude',
        success: true,
        latency: Duration(milliseconds: 250),
        errorMessage: null,
      );

      expect(log.provider, 'claude');
      expect(log.success, true);
      expect(log.latency.inMilliseconds, 250);
      expect(log.errorMessage, isNull);
    });

    test('failed attempt stores error message', () {
      const log = LlmAttemptLog(
        provider: 'openai',
        success: false,
        latency: Duration(milliseconds: 500),
        errorMessage: 'TimeoutException',
      );

      expect(log.success, false);
      expect(log.errorMessage, 'TimeoutException');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LlmFailoverResult
  // ═══════════════════════════════════════════════════════════

  group('LlmFailoverResult', () {
    test('attempts list is unmodifiable after successful call', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'claude', apiKey: 'sk-claude'),
        ],
        callProvider: _successCallback('Response'),
      );

      expect(
        () => (result.attempts as List).add(const LlmAttemptLog(
          provider: 'fake',
          success: true,
          latency: Duration.zero,
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('usedFallback=false when provider succeeds', () async {
      final result = await LlmFailoverService.generate(
        userMessage: 'Test',
        systemPrompt: 'System',
        providers: [
          const LlmProviderConfig(provider: 'mistral', apiKey: 'sk-mistral'),
        ],
        callProvider: _successCallback('Mistral response'),
      );

      expect(result.usedFallback, false);
      expect(result.providerUsed, 'mistral');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // buildProviders helper
  // ═══════════════════════════════════════════════════════════

  group('LlmFailoverService.buildProviders', () {
    test('returns 3 providers in order claude, openai, mistral', () {
      final providers = LlmFailoverService.buildProviders(
        claudeApiKey: 'sk-c',
        openaiApiKey: 'sk-o',
        mistralApiKey: 'sk-m',
      );

      expect(providers.length, 3);
      expect(providers[0].provider, 'claude');
      expect(providers[1].provider, 'openai');
      expect(providers[2].provider, 'mistral');
    });

    test('providers have correct API keys', () {
      final providers = LlmFailoverService.buildProviders(
        claudeApiKey: 'sk-claude-key',
        openaiApiKey: 'sk-openai-key',
      );

      expect(providers[0].apiKey, 'sk-claude-key');
      expect(providers[1].apiKey, 'sk-openai-key');
      expect(providers[2].apiKey, '');
    });

    test('empty API keys make provider fail hasApiKey check', () {
      final providers = LlmFailoverService.buildProviders();

      for (final p in providers) {
        expect(p.hasApiKey, false);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Static fallback text
  // ═══════════════════════════════════════════════════════════

  group('Static fallback text', () {
    test('fallback text is non-empty', () {
      expect(LlmFailoverService.staticFallbackText, isNotEmpty);
    });

    test('fallback text contains educational disclaimer', () {
      final text = LlmFailoverService.staticFallbackText.toLowerCase();
      expect(
        text,
        anyOf(
          contains('éducatif'),
          contains('lsfin'),
          contains('conseil financier'),
        ),
      );
    });

    test('fallback text does not contain banned term "garanti"', () {
      expect(
        LlmFailoverService.staticFallbackText.toLowerCase(),
        isNot(contains('garanti')),
      );
    });

    test('fallback text does not contain banned term "sans risque"', () {
      expect(
        LlmFailoverService.staticFallbackText.toLowerCase(),
        isNot(contains('sans risque')),
      );
    });
  });
}
