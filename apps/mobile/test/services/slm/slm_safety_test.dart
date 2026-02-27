import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/ocr_sanitizer.dart';
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

  // ═══════════════════════════════════════════════════════════
  // OCR Sanitizer — CHF amounts
  // ═══════════════════════════════════════════════════════════

  group('OcrSanitizer — CHF amounts', () {
    test('parses standard CHF amount', () {
      final result = OcrSanitizer.sanitizeChfAmount('45000');
      expect(result.isValid, isTrue);
      expect(result.value, equals(45000.0));
    });

    test('parses Swiss-formatted amount with apostrophes', () {
      final result = OcrSanitizer.sanitizeChfAmount("CHF 450'000");
      expect(result.isValid, isTrue);
      expect(result.value, equals(450000.0));
    });

    test('parses amount with "Fr." prefix', () {
      final result = OcrSanitizer.sanitizeChfAmount('Fr. 1200.50');
      expect(result.isValid, isTrue);
      expect(result.value, equals(1200.50));
    });

    test('parses amount with comma decimal separator', () {
      final result = OcrSanitizer.sanitizeChfAmount('1200,50');
      expect(result.isValid, isTrue);
      expect(result.value, equals(1200.50));
    });

    test('rejects negative amount', () {
      final result = OcrSanitizer.sanitizeChfAmount('-5000');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('négatif'));
    });

    test('rejects amount above sanity cap', () {
      final result = OcrSanitizer.sanitizeChfAmount('99000000');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('élevé'));
    });

    test('rejects unparseable text', () {
      final result = OcrSanitizer.sanitizeChfAmount('abc xyz');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('non reconnu'));
    });

    test('parses zero as valid', () {
      final result = OcrSanitizer.sanitizeChfAmount('0');
      expect(result.isValid, isTrue);
      expect(result.value, equals(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // OCR Sanitizer — Percentages
  // ═══════════════════════════════════════════════════════════

  group('OcrSanitizer — Percentages', () {
    test('parses standard percentage', () {
      final result = OcrSanitizer.sanitizePercentage('6.8%');
      expect(result.isValid, isTrue);
      expect(result.value, equals(6.8));
    });

    test('parses percentage without symbol', () {
      final result = OcrSanitizer.sanitizePercentage('58');
      expect(result.isValid, isTrue);
      expect(result.value, equals(58.0));
    });

    test('rejects negative percentage', () {
      final result = OcrSanitizer.sanitizePercentage('-5%');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('hors limites'));
    });

    test('rejects percentage above 100', () {
      final result = OcrSanitizer.sanitizePercentage('150%');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('hors limites'));
    });

    test('parses 0% as valid', () {
      final result = OcrSanitizer.sanitizePercentage('0%');
      expect(result.isValid, isTrue);
      expect(result.value, equals(0.0));
    });

    test('parses 100% as valid', () {
      final result = OcrSanitizer.sanitizePercentage('100');
      expect(result.isValid, isTrue);
      expect(result.value, equals(100.0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // OCR Sanitizer — Years
  // ═══════════════════════════════════════════════════════════

  group('OcrSanitizer — Years', () {
    test('parses valid year', () {
      final result = OcrSanitizer.sanitizeYear('2025');
      expect(result.isValid, isTrue);
      expect(result.value, equals(2025));
    });

    test('rejects year before 1900', () {
      final result = OcrSanitizer.sanitizeYear('1850');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('hors limites'));
    });

    test('rejects year after 2100', () {
      final result = OcrSanitizer.sanitizeYear('2200');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('hors limites'));
    });

    test('rejects non-numeric year', () {
      final result = OcrSanitizer.sanitizeYear('ABCD');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('non reconnue'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // OCR Sanitizer — AVS numbers (privacy)
  // ═══════════════════════════════════════════════════════════

  group('OcrSanitizer — AVS numbers', () {
    test('accepts valid AVS number format', () {
      final result = OcrSanitizer.sanitizeAvsNumber('756.1234.5678.97');
      expect(result.isValid, isTrue);
      expect(result.value, isTrue);
    });

    test('masks raw text for privacy', () {
      final result = OcrSanitizer.sanitizeAvsNumber('756.1234.5678.97');
      expect(result.rawText, contains('XXXX'));
      expect(result.rawText, isNot(contains('1234')));
    });

    test('rejects AVS number not starting with 756', () {
      final result = OcrSanitizer.sanitizeAvsNumber('757.1234.5678.97');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('AVS invalide'));
    });

    test('rejects AVS number with wrong length', () {
      final result = OcrSanitizer.sanitizeAvsNumber('756.1234.5678');
      expect(result.isValid, isFalse);
    });

    test('rejects AVS number with letters', () {
      final result = OcrSanitizer.sanitizeAvsNumber('756.ABCD.5678.97');
      expect(result.isValid, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // CRIT #7: Sealed class type safety
  // ═══════════════════════════════════════════════════════════

  group('CRIT #7 — Sealed class type safety', () {
    test('ValidValue has non-null value', () {
      final result = OcrSanitizer.sanitizeChfAmount('1000');
      expect(result, isA<ValidValue<double>>());
      expect(result.value, isNotNull);
      expect(result.value, equals(1000.0));
      expect(result.rejectionReason, isNull);
    });

    test('InvalidValue has non-null rejectionReason', () {
      final result = OcrSanitizer.sanitizeChfAmount('abc');
      expect(result, isA<InvalidValue<double>>());
      expect(result.value, isNull);
      expect(result.rejectionReason, isNotNull);
      expect(result.rejectionReason, contains('non reconnu'));
    });

    test('switch exhaustiveness on sealed class', () {
      final result = OcrSanitizer.sanitizeChfAmount('5000');
      // This compiles only because SanitizedValue is sealed
      final description = switch (result) {
        ValidValue(:final value) => 'Valid: $value',
        InvalidValue(:final rejectionReason) => 'Invalid: $rejectionReason',
      };
      expect(description, startsWith('Valid:'));
    });

    test('ValidValue year has correct type', () {
      final result = OcrSanitizer.sanitizeYear('2025');
      expect(result, isA<ValidValue<int>>());
      expect(result.value, isA<int>());
    });

    test('InvalidValue year has correct type', () {
      final result = OcrSanitizer.sanitizeYear('ABCD');
      expect(result, isA<InvalidValue<int>>());
      expect(result.value, isNull);
    });
  });
}
