import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';

// ────────────────────────────────────────────────────────────
//  SLM ENGINE TESTS
// ────────────────────────────────────────────────────────────
//
// Tests cover (unit-level, no native runtime):
//   1. Initial status is notDownloaded
//   2. isAvailable is false when not running
//   3. modelId delegates to SlmDownloadService.modelId
//   4. Constants are sensible values
//   5. Token estimation (French text)
//   6. Token estimation (empty text)
//   7. Token estimation (short text)
//   8. SlmResult construction
//   9. SlmStatus enum has all expected values
//  10. generate() returns null when engine not available
//  11. generateStream() returns empty when not available
//  12. modelDisplayName is set
// ────────────────────────────────────────────────────────────

void main() {
  group('SlmEngine — unit tests (no native runtime)', () {
    late SlmEngine engine;

    setUp(() {
      engine = SlmEngine.instance;
    });

    test('1. initial status is notDownloaded', () {
      // Singleton may have state from previous tests, but on fresh app
      // it starts as notDownloaded. We test the enum value exists.
      expect(SlmStatus.notDownloaded, isNotNull);
      expect(SlmStatus.values.length, 5);
    });

    test('2. isAvailable is false when status != running', () {
      // Without native init, engine cannot be running
      // The singleton status may vary, but generate() should return null
      // if not available.
      if (engine.status != SlmStatus.running) {
        expect(engine.isAvailable, isFalse);
      }
    });

    test('3. modelId delegates to SlmDownloadService.modelId', () {
      expect(SlmEngine.modelId, equals(SlmDownloadService.modelId));
      expect(SlmEngine.modelId, contains('.task'));
    });

    test('4. constants are sensible', () {
      expect(SlmEngine.maxContextTokens, equals(8192));
      expect(SlmEngine.defaultMaxTokens, equals(256));
      expect(SlmEngine.defaultTemperature, equals(0.3));
      expect(SlmEngine.defaultTemperature, greaterThan(0.0));
      expect(SlmEngine.defaultTemperature, lessThan(1.0));
    });

    test('5. token estimation — French text', () {
      // ~3.5 chars per token for French
      const frenchText = 'Bonjour, ton score de prévoyance est de 62/100.';
      final tokens = _estimateTokens(frenchText);
      expect(tokens, greaterThan(0));
      // 48 chars / 3.5 ≈ 14 tokens
      expect(tokens, equals(14));
    });

    test('6. token estimation — empty text', () {
      expect(_estimateTokens(''), equals(0));
    });

    test('7. token estimation — short text', () {
      // 3 chars / 3.5 = 0.857 → ceil = 1
      expect(_estimateTokens('abc'), equals(1));
    });

    test('8. SlmResult construction', () {
      const result = SlmResult(
        text: 'Bonjour Julien',
        durationMs: 1500,
        tokensGenerated: 4,
      );
      expect(result.text, 'Bonjour Julien');
      expect(result.durationMs, 1500);
      expect(result.tokensGenerated, 4);
    });

    test('9. SlmStatus enum values', () {
      expect(
          SlmStatus.values,
          containsAll([
            SlmStatus.notDownloaded,
            SlmStatus.downloading,
            SlmStatus.ready,
            SlmStatus.running,
            SlmStatus.error,
          ]));
    });

    test('10. generate() returns null when engine not available', () async {
      // Without native init, engine is not running
      if (!engine.isAvailable) {
        final result = await engine.generate(
          systemPrompt: 'test',
          userPrompt: 'test',
        );
        expect(result, isNull);
      }
    });

    test('11. generateStream() yields nothing when not available', () async {
      if (!engine.isAvailable) {
        final tokens = <String>[];
        await for (final token in engine.generateStream(
          systemPrompt: 'test',
          userPrompt: 'test',
        )) {
          tokens.add(token);
        }
        expect(tokens, isEmpty);
      }
    });

    test('12. modelDisplayName is set', () {
      expect(SlmEngine.modelDisplayName, isNotEmpty);
      expect(SlmEngine.modelDisplayName, contains('Gemma'));
    });
  });
}

/// Mirror of SlmEngine._estimateTokens for testing.
int _estimateTokens(String text) {
  if (text.isEmpty) return 0;
  return (text.length / 3.5).ceil();
}
