import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/hallucination_detector.dart';

// ────────────────────────────────────────────────────────────
//  HALLUCINATION DETECTOR TESTS — Sprint S34
// ────────────────────────────────────────────────────────────
//
// Verifies number extraction and hallucination detection for:
//   - CHF amounts (Swiss format: 1'820, 1'820.50)
//   - Percentages (58.0%, 6.8%)
//   - Scores (62/100)
//   - Durations (3 mois, 2 ans)
//
// References: FINMA circular 2008/21, LSFin art. 8
// ────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════
  // Number extraction
  // ═══════════════════════════════════════════════════════════

  group('Number extraction', () {
    test('extracts CHF amount with apostrophe formatting', () {
      final numbers = HallucinationDetector.extractNumbers(
        "Ton capital est de CHF 450'000.",
      );
      expect(numbers, isNotEmpty);
      final chf = numbers.firstWhere((n) => n.$3 == 'chf');
      expect(chf.$2, equals(450000.0));
    });

    test('extracts CHF amount without formatting', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ton avoir 3a est de CHF 25000.',
      );
      expect(numbers, isNotEmpty);
      final chf = numbers.firstWhere((n) => n.$3 == 'chf');
      expect(chf.$2, equals(25000.0));
    });

    test('extracts percentage', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ton taux de remplacement est de 58.0%.',
      );
      expect(numbers, isNotEmpty);
      final pct = numbers.firstWhere((n) => n.$3 == 'pct');
      expect(pct.$2, equals(58.0));
    });

    test('extracts score (X/100)', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ton score de solidité est de 62/100.',
      );
      expect(numbers, isNotEmpty);
      final score = numbers.firstWhere((n) => n.$3 == 'score');
      expect(score.$2, equals(62.0));
    });

    test('extracts duration in months', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ta réserve couvre 4 mois de dépenses.',
      );
      expect(numbers, isNotEmpty);
      final dur = numbers.firstWhere((n) => n.$3 == 'duration');
      expect(dur.$2, equals(4.0));
    });

    test('extracts duration in years', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Tu as cotisé pendant 12 ans.',
      );
      expect(numbers, isNotEmpty);
      final dur = numbers.firstWhere((n) => n.$3 == 'duration');
      expect(dur.$2, equals(12.0));
    });

    test('extracts multiple numbers from same text', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ton capital est de CHF 450000 avec un taux de 58.0%.',
      );
      expect(numbers.length, greaterThanOrEqualTo(2));
    });

    test('returns empty for text without numbers', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Continue à affiner ton profil.',
      );
      expect(numbers, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Hallucination detection
  // ═══════════════════════════════════════════════════════════

  group('Hallucination detection', () {
    const knownValues = {
      'fri_total': 62.0,
      'capital_final': 450000.0,
      'replacement_ratio': 58.0,
      'epargne_3a': 25000.0,
    };

    test('no hallucination when numbers match known values', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton capital projeté est de CHF 450000.',
        knownValues,
      );
      expect(hallucinations, isEmpty);
    });

    test('detects hallucinated CHF amount (>5% deviation)', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton capital projeté est de CHF 900000.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
      expect(hallucinations.first.foundValue, equals(900000.0));
    });

    test('accepts CHF within 5% tolerance', () {
      // 450000 * 1.04 = 468000 (within 5%)
      final hallucinations = HallucinationDetector.detect(
        'Ton capital projeté est d\'environ CHF 468000.',
        knownValues,
      );
      expect(hallucinations, isEmpty);
    });

    test('detects hallucinated percentage (>2pt deviation)', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton taux de remplacement est de 85.0%.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
    });

    test('accepts percentage within 2pt tolerance', () {
      // 58% + 1.5pt = 59.5%
      final hallucinations = HallucinationDetector.detect(
        'Ton taux de remplacement est de 59.5%.',
        knownValues,
      );
      expect(hallucinations, isEmpty);
    });

    test('detects hallucinated score (>2pt deviation)', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton score est de 95/100.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
    });

    test('returns empty when knownValues is empty', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton capital est de CHF 999999.',
        {},
      );
      expect(hallucinations, isEmpty);
    });

    test('HallucinatedNumber has correct fields', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton capital projeté est de CHF 900000.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
      final h = hallucinations.first;
      expect(h.foundText, contains('900000'));
      expect(h.foundValue, equals(900000.0));
      expect(h.closestKey, isNotEmpty);
      expect(h.deviationPct, greaterThan(0));
    });
  });
}
