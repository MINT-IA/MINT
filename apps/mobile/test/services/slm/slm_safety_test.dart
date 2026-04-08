import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';

// ────────────────────────────────────────────────────────────
//  SLM SAFETY + OCR SANITIZER TESTS — Sprint S34
// ────────────────────────────────────────────────────────────
//
// Tests cover:
//   1. No-network assertion on SlmEngine
//   2. OCR sanitizer: CHF amounts
//   3. OCR sanitizer: percentages
//   4. OCR sanitizer: years
//   5. OCR sanitizer: AVS numbers (privacy masking)
//   6. CRIT #7: sealed class type safety
//
// References: LPD art. 6, FINMA circular 2008/21
// ────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════
  // SLM no-network assertions
  // ═══════════════════════════════════════════════════════════

  group('SlmEngine — no-network contract', () {
    test('isOnDeviceOnly is true (compile-time contract)', () {
      expect(SlmEngine.isOnDeviceOnly, isTrue);
    });

    test('engine starts in notDownloaded status', () {
      final engine = SlmEngine.instance;
      expect(engine.status, equals(SlmStatus.notDownloaded));
    });

    test('generate returns null when not available', () async {
      final engine = SlmEngine.instance;
      final result = await engine.generate(
        systemPrompt: 'test',
        userPrompt: 'test',
      );
      expect(result, isNull);
    });

    test('generateStream returns empty when not available', () async {
      final engine = SlmEngine.instance;
      final tokens = <String>[];
      await for (final token in engine.generateStream(
        systemPrompt: 'test',
        userPrompt: 'test',
      )) {
        tokens.add(token);
      }
      expect(tokens, isEmpty);
    });
  });

  // OcrSanitizer tests removed — service deleted (dead code cleanup P2-16).

}
