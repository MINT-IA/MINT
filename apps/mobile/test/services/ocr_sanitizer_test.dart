import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/ocr_sanitizer.dart';

/// Tests for OcrSanitizer (Sprint S34 — SLM Safety).
///
/// Validates Swiss number format parsing, privacy compliance,
/// and sanity caps for OCR-extracted financial values.
void main() {
  group('OcrSanitizer.sanitizeChfAmount', () {
    test('parses plain number', () {
      final result = OcrSanitizer.sanitizeChfAmount('50000');
      expect(result.isValid, true);
      expect(result.value, 50000.0);
    });

    test('parses Swiss apostrophe format (70\'377)', () {
      final result = OcrSanitizer.sanitizeChfAmount("70'377");
      expect(result.isValid, true);
      expect(result.value, 70377.0);
    });

    test('parses CHF prefix with apostrophe (CHF 122\'207)', () {
      final result = OcrSanitizer.sanitizeChfAmount("CHF 122'207");
      expect(result.isValid, true);
      expect(result.value, 122207.0);
    });

    test('parses Fr. prefix', () {
      final result = OcrSanitizer.sanitizeChfAmount('Fr. 7258');
      expect(result.isValid, true);
      expect(result.value, 7258.0);
    });

    test('parses comma as decimal separator', () {
      final result = OcrSanitizer.sanitizeChfAmount('1234,56');
      expect(result.isValid, true);
      expect(result.value, closeTo(1234.56, 0.01));
    });

    test('rejects negative amount', () {
      final result = OcrSanitizer.sanitizeChfAmount('-5000');
      expect(result.isValid, false);
      expect(result.rejectionReason, contains('negatif'));
    });

    test('rejects amount above sanity cap (50M)', () {
      final result = OcrSanitizer.sanitizeChfAmount('60000000');
      expect(result.isValid, false);
      expect(result.rejectionReason, contains('anormalement'));
    });

    test('accepts amount at exactly 50M', () {
      final result = OcrSanitizer.sanitizeChfAmount('50000000');
      expect(result.isValid, true);
      expect(result.value, 50000000.0);
    });

    test('rejects garbage text', () {
      final result = OcrSanitizer.sanitizeChfAmount('abc xyz');
      expect(result.isValid, false);
      expect(result.rejectionReason, contains('non reconnu'));
    });

    test('preserves rawText on valid result', () {
      final result = OcrSanitizer.sanitizeChfAmount("CHF 70'377");
      expect(result.rawText, "CHF 70'377");
    });

    test('preserves rawText on invalid result', () {
      final result = OcrSanitizer.sanitizeChfAmount('not-a-number');
      expect(result.rawText, 'not-a-number');
    });

    test('accepts zero', () {
      final result = OcrSanitizer.sanitizeChfAmount('0');
      expect(result.isValid, true);
      expect(result.value, 0.0);
    });

    test('handles spaces around amount', () {
      final result = OcrSanitizer.sanitizeChfAmount('  50000  ');
      expect(result.isValid, true);
      expect(result.value, 50000.0);
    });
  });

  group('OcrSanitizer.sanitizePercentage', () {
    test('parses plain percentage', () {
      final result = OcrSanitizer.sanitizePercentage('6.8');
      expect(result.isValid, true);
      expect(result.value, 6.8);
    });

    test('parses percentage with % sign', () {
      final result = OcrSanitizer.sanitizePercentage('25.5%');
      expect(result.isValid, true);
      expect(result.value, 25.5);
    });

    test('parses comma decimal (European format)', () {
      final result = OcrSanitizer.sanitizePercentage('6,8%');
      expect(result.isValid, true);
      expect(result.value, 6.8);
    });

    test('rejects percentage > 100', () {
      final result = OcrSanitizer.sanitizePercentage('150');
      expect(result.isValid, false);
      expect(result.rejectionReason, contains('hors limites'));
    });

    test('rejects negative percentage', () {
      final result = OcrSanitizer.sanitizePercentage('-5');
      expect(result.isValid, false);
    });

    test('accepts 0%', () {
      final result = OcrSanitizer.sanitizePercentage('0');
      expect(result.isValid, true);
      expect(result.value, 0.0);
    });

    test('accepts 100%', () {
      final result = OcrSanitizer.sanitizePercentage('100');
      expect(result.isValid, true);
      expect(result.value, 100.0);
    });

    test('rejects garbage text', () {
      final result = OcrSanitizer.sanitizePercentage('abc');
      expect(result.isValid, false);
    });
  });

  group('OcrSanitizer.sanitizeYear', () {
    test('parses valid year', () {
      final result = OcrSanitizer.sanitizeYear('1977');
      expect(result.isValid, true);
      expect(result.value, 1977);
    });

    test('parses year with spaces', () {
      final result = OcrSanitizer.sanitizeYear(' 2025 ');
      expect(result.isValid, true);
      expect(result.value, 2025);
    });

    test('rejects year before 1900', () {
      final result = OcrSanitizer.sanitizeYear('1899');
      expect(result.isValid, false);
      expect(result.rejectionReason, contains('hors limites'));
    });

    test('rejects year after 2100', () {
      final result = OcrSanitizer.sanitizeYear('2101');
      expect(result.isValid, false);
    });

    test('accepts boundary year 1900', () {
      final result = OcrSanitizer.sanitizeYear('1900');
      expect(result.isValid, true);
      expect(result.value, 1900);
    });

    test('accepts boundary year 2100', () {
      final result = OcrSanitizer.sanitizeYear('2100');
      expect(result.isValid, true);
      expect(result.value, 2100);
    });

    test('rejects non-numeric input', () {
      final result = OcrSanitizer.sanitizeYear('vingt-vingt');
      expect(result.isValid, false);
    });

    test('rejects decimal year', () {
      final result = OcrSanitizer.sanitizeYear('2025.5');
      expect(result.isValid, false);
    });
  });

  group('OcrSanitizer.sanitizeAvsNumber', () {
    test('validates correct AVS format (756.XXXX.XXXX.XX)', () {
      final result =
          OcrSanitizer.sanitizeAvsNumber('756.1234.5678.90');
      expect(result.isValid, true);
      expect(result.value, true);
    });

    test('validates AVS without dots', () {
      final result = OcrSanitizer.sanitizeAvsNumber('7561234567890');
      expect(result.isValid, true);
      expect(result.value, true);
    });

    test('masks AVS number in output for privacy (LPD art. 6)', () {
      final result =
          OcrSanitizer.sanitizeAvsNumber('756.1234.5678.90');
      // Raw text must be masked — never store actual AVS number
      expect(result.rawText, '756.XXXX.XXXX.XX');
    });

    test('rejects AVS not starting with 756', () {
      final result =
          OcrSanitizer.sanitizeAvsNumber('757.1234.5678.90');
      expect(result.isValid, false);
      expect(result.rejectionReason, contains('Format AVS invalide'));
    });

    test('rejects AVS with wrong length', () {
      final result = OcrSanitizer.sanitizeAvsNumber('756.1234.5678');
      expect(result.isValid, false);
    });

    test('rejects AVS with letters', () {
      final result =
          OcrSanitizer.sanitizeAvsNumber('756.ABCD.5678.90');
      expect(result.isValid, false);
    });

    test('handles spaces in AVS number', () {
      final result =
          OcrSanitizer.sanitizeAvsNumber('756 1234 5678 90');
      expect(result.isValid, true);
    });

    test('rejects empty string', () {
      final result = OcrSanitizer.sanitizeAvsNumber('');
      expect(result.isValid, false);
    });
  });

  group('SanitizedValue sealed class contract', () {
    test('ValidValue guarantees non-null value and null rejectionReason', () {
      final valid = OcrSanitizer.sanitizeChfAmount('1000');
      expect(valid, isA<ValidValue<double>>());
      expect(valid.value, isNotNull);
      expect(valid.rejectionReason, isNull);
    });

    test('InvalidValue guarantees null value and non-null rejectionReason',
        () {
      final invalid = OcrSanitizer.sanitizeChfAmount('garbage');
      expect(invalid, isA<InvalidValue<double>>());
      expect(invalid.value, isNull);
      expect(invalid.rejectionReason, isNotNull);
    });

    test('default DataSource is document', () {
      final result = OcrSanitizer.sanitizeChfAmount('1000');
      expect(result.source, DataSource.document);
    });
  });
}
