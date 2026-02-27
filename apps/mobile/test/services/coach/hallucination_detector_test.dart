import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/hallucination_detector.dart';

// ────────────────────────────────────────────────────────────
//  HALLUCINATION DETECTOR TESTS — Sprint S34
// ────────────────────────────────────────────────────────────
//
// Verifies number extraction and hallucination detection for:
//   - CHF amounts (Swiss format: 1'820, 1'820.50)
//   - Percentages (58.0%, 85%, integer + decimal)
//   - Scores (62/100)
//   - Durations (3 mois, 2 ans)
//   - Legal constants whitelist (CRIT #2)
//   - Integer percentage capture (CRIT #4)
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

    test('extracts decimal percentage', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ton taux de remplacement est de 58.0%.',
      );
      expect(numbers, isNotEmpty);
      final pct = numbers.firstWhere((n) => n.$3 == 'pct');
      expect(pct.$2, equals(58.0));
    });

    // CRIT #4: integer percentages must be captured
    test('extracts integer percentage (CRIT #4)', () {
      final numbers = HallucinationDetector.extractNumbers(
        'Ton taux de remplacement est de 85%.',
      );
      expect(numbers, isNotEmpty);
      final pct = numbers.firstWhere((n) => n.$3 == 'pct');
      expect(pct.$2, equals(85.0));
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

    // CRIT #4: integer percentage must be detected as hallucination
    test('detects hallucinated integer percentage (CRIT #4)', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton taux de remplacement est de 85%.',
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

  // ═══════════════════════════════════════════════════════════
  // Legal constants whitelist (CRIT #2)
  // ═══════════════════════════════════════════════════════════

  group('Legal constants whitelist (CRIT #2)', () {
    const knownValues = {
      'fri_total': 62.0,
      'capital_final': 450000.0,
      'replacement_ratio': 58.0,
    };

    test('CHF 7258 (3a cap) is NOT flagged as hallucination', () {
      final hallucinations = HallucinationDetector.detect(
        'Le plafond 3a est de CHF 7258 par an (OPP3 art. 7).',
        knownValues,
      );
      final chfHallucinations = hallucinations
          .where((h) => h.foundValue == 7258.0)
          .toList();
      expect(chfHallucinations, isEmpty);
    });

    test('CHF 22680 (seuil LPP) is NOT flagged as hallucination', () {
      final hallucinations = HallucinationDetector.detect(
        'Le seuil LPP est de CHF 22680 (LPP art. 7).',
        knownValues,
      );
      final lppHallucinations = hallucinations
          .where((h) => h.foundValue == 22680.0)
          .toList();
      expect(lppHallucinations, isEmpty);
    });

    test('6.8% (taux conversion LPP) is NOT flagged as hallucination', () {
      final hallucinations = HallucinationDetector.detect(
        'Le taux de conversion minimum est de 6.8% (LPP art. 14).',
        knownValues,
      );
      final pctHallucinations = hallucinations
          .where((h) => h.foundValue == 6.8)
          .toList();
      expect(pctHallucinations, isEmpty);
    });

    test('CHF 2520 (rente AVS max mensuelle) is NOT flagged', () {
      final hallucinations = HallucinationDetector.detect(
        'La rente AVS max est de CHF 2520 par mois (LAVS art. 34).',
        knownValues,
      );
      final avsHallucinations = hallucinations
          .where((h) => h.foundValue == 2520.0)
          .toList();
      expect(avsHallucinations, isEmpty);
    });

    test('CHF 36288 (grand 3a) is NOT flagged', () {
      final hallucinations = HallucinationDetector.detect(
        'Le plafond 3a indépendant est de CHF 36288.',
        knownValues,
      );
      final halluc = hallucinations
          .where((h) => h.foundValue == 36288.0)
          .toList();
      expect(halluc, isEmpty);
    });

    test('CHF 30240 (rente AVS max annuelle) is NOT flagged', () {
      final hallucinations = HallucinationDetector.detect(
        'La rente AVS maximale est de CHF 30240 par an.',
        knownValues,
      );
      final halluc = hallucinations
          .where((h) => h.foundValue == 30240.0)
          .toList();
      expect(halluc, isEmpty);
    });

    test('non-legal CHF amount IS still flagged', () {
      final hallucinations = HallucinationDetector.detect(
        'Ton avoir sera de CHF 777777.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
    });

    test('100% is NOT flagged (common reference percentage)', () {
      final hallucinations = HallucinationDetector.detect(
        'Tu conserves 100% de ton capital.',
        knownValues,
      );
      final pctHallucinations = hallucinations
          .where((h) => h.foundValue == 100.0)
          .toList();
      expect(pctHallucinations, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Relevance distance (HIGH audit fix)
  // ═══════════════════════════════════════════════════════════

  group('Relevance distance', () {
    const knownValues = {
      'fri_total': 62.0,
      'capital_final': 450000.0,
      'replacement_ratio': 58.0,
    };

    test('percentage far from all known values is NOT flagged', () {
      // 2% is >30 points from all known values (58, 62)
      // so it should not be flagged despite not being a legal constant
      final hallucinations = HallucinationDetector.detect(
        'Le taux hypothécaire est de 2%.',
        knownValues,
      );
      final pctHall = hallucinations
          .where((h) => h.foundValue == 2.0)
          .toList();
      expect(pctHall, isEmpty);
    });

    test('percentage close to known value IS still flagged', () {
      // 85% is within 30 points of 58% or 62%, so it IS relevant
      // and 85 - 58 = 27 > 2pt tolerance → flagged
      final hallucinations = HallucinationDetector.detect(
        'Ton taux de remplacement est de 85%.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
    });

    test('CHF amount far from all known values is NOT flagged', () {
      // CHF 50 vs known 450000: ratio = 0.0001 < 0.1 → not relevant
      final hallucinations = HallucinationDetector.detect(
        'La cotisation minimale est de CHF 50.',
        knownValues,
      );
      final chfHall = hallucinations
          .where((h) => h.foundValue == 50.0)
          .toList();
      expect(chfHall, isEmpty);
    });

    test('CHF amount in same order of magnitude IS still flagged', () {
      // CHF 900000 vs 450000: ratio = 2.0 (within 10x) → relevant
      // deviation = 100% > 5% tolerance → flagged
      final hallucinations = HallucinationDetector.detect(
        'Ton capital projeté est de CHF 900000.',
        knownValues,
      );
      expect(hallucinations, isNotEmpty);
    });
  });
}
