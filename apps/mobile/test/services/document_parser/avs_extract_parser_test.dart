import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';

/// Unit tests for AvsExtractParser
///
/// Tests OCR text parsing of Swiss AVS individual account extracts (Extrait
/// de compte individuel CI / Individueller Kontoauszug IK) into structured
/// ExtractedField objects.
///
/// Legal basis: LAVS art. 29ter-30, 29sexies, 34-35
void main() {
  // ── Helper ──────────────────────────────────────────────────
  ExtractedField? findField(ExtractionResult r, String fieldName) {
    try {
      return r.fields.firstWhere((f) => f.fieldName == fieldName);
    } catch (_) {
      return null;
    }
  }

  // ── Sample OCR text (well-formatted) ───────────────────────
  group('parseAvsExtract — sample OCR text', () {
    late ExtractionResult result;

    setUp(() {
      result = AvsExtractParser.parseAvsExtract(
        AvsExtractParser.sampleOcrText,
      );
    });

    test('returns correct document type', () {
      expect(result.documentType, DocumentType.avsExtract);
    });

    test('extracts annees de cotisation = 22', () {
      final field = findField(result, 'annees_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(22.0, 0.01));
      expect(field.profileField, 'avsContributionYears');
    });

    test('extracts RAMD = 72450', () {
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(72450.0, 0.01));
      expect(field.profileField, 'avsRamd');
    });

    test('extracts lacunes de cotisation = 0', () {
      final field = findField(result, 'lacunes_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(0.0, 0.01));
      expect(field.profileField, 'avsGaps');
    });

    test('extracts bonifications educatives = 3', () {
      final field = findField(result, 'bonifications_educatives');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(3.0, 0.01));
      expect(field.profileField, 'avsEducationCredits');
    });

    test('has non-empty disclaimer and sources', () {
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('ducatif'));
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
    });

    test('overall confidence is above 0.80', () {
      expect(result.overallConfidence, greaterThanOrEqualTo(0.80));
    });

    test('confidence delta is positive', () {
      expect(result.confidenceDelta, greaterThan(0));
      expect(result.confidenceDelta, lessThanOrEqualTo(25));
    });

    test('no warnings for well-formatted sample', () {
      expect(result.warnings, isEmpty);
    });
  });

  // ── Swiss number formats for RAMD ──────────────────────────
  group('parseAvsExtract — Swiss number formats', () {
    test('parses apostrophe thousands: 72\'450', () {
      const text = "Revenu annuel moyen déterminant (RAMD): CHF 72'450.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(72450.0, 0.01));
    });

    test('parses space as thousand separator: 72 450', () {
      const text = "Revenu annuel moyen déterminant: CHF 72 450";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(72450.0, 1.0));
    });

    test('parses RAMD abbreviation directly', () {
      const text = "RAMD: CHF 88'200.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(88200.0, 0.01));
    });

    test('parses Fr. prefix for RAMD', () {
      const text = "Revenu annuel moyen déterminant: Fr. 65'000.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(65000.0, 0.01));
    });

    test('parses comma decimal (Swiss German): 72450,00', () {
      const text = "RAMD: 72450,00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(72450.0, 0.01));
    });
  });

  // ── German (DE) format ─────────────────────────────────────
  group('parseAvsExtract — German format', () {
    test('parses Beitragsjahre (DE)', () {
      const text = "Beitragsjahre: 30";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'annees_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(30.0, 0.01));
    });

    test('parses Massgebendes durchschnittliches Jahreseinkommen (DE)', () {
      const text =
          "Massgebendes durchschnittliches Jahreseinkommen: CHF 80'000.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(80000.0, 0.01));
    });

    test('parses MDJE abbreviation (DE)', () {
      const text = "MDJE: CHF 75'000.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(75000.0, 0.01));
    });

    test('parses Beitragslücken (DE)', () {
      const text = "Beitragslücken: 2";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'lacunes_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(2.0, 0.01));
    });

    test('parses Erziehungsgutschriften (DE)', () {
      const text = "Erziehungsgutschriften: 5";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'bonifications_educatives');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(5.0, 0.01));
    });
  });

  // ── Cross-validation with userAge ──────────────────────────
  group('parseAvsExtract — cross-validation with userAge', () {
    test('warns when annees > age - 20', () {
      const text = "Années de cotisation: 30";
      final result = AvsExtractParser.parseAvsExtract(text, userAge: 40);
      // 40 - 20 = 20 max years, but 30 claimed
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('passe le maximum')),
        isTrue,
      );
    });

    test('no warning when annees <= age - 20', () {
      const text = "Années de cotisation: 15";
      final result = AvsExtractParser.parseAvsExtract(text, userAge: 40);
      // 40 - 20 = 20 max, 15 <= 20 => OK
      expect(
        result.warnings.any((w) => w.contains('passe le maximum')),
        isFalse,
      );
    });

    test('warns when annees + lacunes > age - 20', () {
      const text = """
Années de cotisation: 12
Lacunes de cotisation: 10
""";
      final result = AvsExtractParser.parseAvsExtract(text, userAge: 40);
      // 12 + 10 = 22, max = 20
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('somme')),
        isTrue,
      );
    });

    test('no warning when annees + lacunes <= age - 20', () {
      const text = """
Années de cotisation: 15
Lacunes de cotisation: 3
""";
      final result = AvsExtractParser.parseAvsExtract(text, userAge: 40);
      // 15 + 3 = 18, max = 20 => OK
      expect(
        result.warnings.any((w) => w.contains('somme')),
        isFalse,
      );
    });

    test('no age-based warnings when userAge is not provided', () {
      const text = "Années de cotisation: 50";
      final result = AvsExtractParser.parseAvsExtract(text);
      // Without userAge, no age-based validation
      expect(
        result.warnings.any((w) => w.contains('passe le maximum')),
        isFalse,
      );
    });
  });

  // ── RAMD plausibility cross-validation ─────────────────────
  group('parseAvsExtract — RAMD plausibility', () {
    test('warns when RAMD > 100000 (above AVS cap)', () {
      const text = "RAMD: CHF 120'000.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('lev')),
        isTrue,
      );
    });

    test('warns when RAMD is very low (< 1000 but > 0)', () {
      const text = "RAMD: CHF 500.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('bas')),
        isTrue,
      );
    });

    test('no warning for reasonable RAMD = 72450', () {
      const text = "RAMD: CHF 72'450.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      expect(
        result.warnings.any(
            (w) => w.contains('lev') || w.contains('bas')),
        isFalse,
      );
    });
  });

  // ── Bonifications educatives plausibility ──────────────────
  group('parseAvsExtract — bonifications educatives plausibility', () {
    test('warns when bonifications > 16', () {
      const text = "Bonifications pour tâches éducatives: 18";
      final result = AvsExtractParser.parseAvsExtract(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('ducatives')),
        isTrue,
      );
    });

    test('no warning when bonifications <= 16', () {
      const text = "Bonifications pour tâches éducatives: 8";
      final result = AvsExtractParser.parseAvsExtract(text);
      expect(
        result.warnings.any((w) => w.contains('ducatives')),
        isFalse,
      );
    });
  });

  // ── Empty / malformed input ────────────────────────────────
  group('parseAvsExtract — edge cases', () {
    test('empty string produces zero fields and zero confidence', () {
      final result = AvsExtractParser.parseAvsExtract('');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
      expect(result.confidenceDelta, 0.0);
      expect(result.warnings, isEmpty);
      expect(result.documentType, DocumentType.avsExtract);
    });

    test('random text produces zero fields', () {
      final result = AvsExtractParser.parseAvsExtract(
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      );
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });

    test('handles whitespace-only input', () {
      final result = AvsExtractParser.parseAvsExtract('   \n\n  ');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });

    test('text with labels but no numeric values produces zero fields', () {
      final result = AvsExtractParser.parseAvsExtract(
        'Années de cotisation: \nRAMD: ',
      );
      expect(result.fields, isEmpty);
    });
  });

  // ── Confidence metadata ────────────────────────────────────
  group('parseAvsExtract — confidence metadata', () {
    test('integer fields (years) have confidence = 0.88', () {
      const text = "Années de cotisation: 22";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'annees_cotisation');
      expect(field, isNotNull);
      expect(field!.confidence, closeTo(0.88, 0.01));
      expect(field.needsReview, isFalse);
    });

    test('CHF-prefixed RAMD has confidence >= 0.82', () {
      const text = "RAMD: CHF 72'450.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.82));
    });

    test('all high-confidence fields have confidence >= 0.80', () {
      final result = AvsExtractParser.parseAvsExtract(
        AvsExtractParser.sampleOcrText,
      );
      for (final f in result.highConfidenceFields) {
        expect(f.confidence, greaterThanOrEqualTo(0.80));
      }
    });
  });

  // ── estimateConfidenceDelta with profile ───────────────────
  group('estimateConfidenceDelta', () {
    test('full impact when profile is empty', () {
      final result = AvsExtractParser.parseAvsExtract(
        AvsExtractParser.sampleOcrText,
      );
      final delta = AvsExtractParser.estimateConfidenceDelta(
        result,
        <String, dynamic>{},
      );
      expect(delta, greaterThan(0));
      expect(delta, lessThanOrEqualTo(25));
    });

    test('partial impact when profile already has values', () {
      final result = AvsExtractParser.parseAvsExtract(
        AvsExtractParser.sampleOcrText,
      );
      final deltaEmpty = AvsExtractParser.estimateConfidenceDelta(
        result,
        <String, dynamic>{},
      );
      final deltaFull = AvsExtractParser.estimateConfidenceDelta(
        result,
        <String, dynamic>{
          'avsContributionYears': 20.0,
          'avsRamd': 70000.0,
          'avsGaps': 0.0,
        },
      );
      // avsGaps=0 counts as "null or 0" => full impact, but others get 0.5x
      expect(deltaFull, lessThan(deltaEmpty));
    });
  });

  // ── French variant patterns ────────────────────────────────
  group('parseAvsExtract — French variant patterns', () {
    test('parses "durée de cotisation"', () {
      const text = "Durée de cotisation: 28";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'annees_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(28.0, 0.01));
    });

    test('parses "nombre d\'années"', () {
      const text = "Nombre d'années: 25";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'annees_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(25.0, 0.01));
    });

    test('parses "revenu déterminant moyen"', () {
      const text = "Revenu déterminant moyen: CHF 68'000.00";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'ramd');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(68000.0, 0.01));
    });

    test('parses "années manquantes" as lacunes', () {
      const text = "Années manquantes: 2";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'lacunes_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(2.0, 0.01));
    });

    test('parses reversed format "22 années de cotisation"', () {
      const text = "22 années de cotisation";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'annees_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(22.0, 0.01));
    });

    test('parses reversed format "2 lacunes"', () {
      const text = "2 lacunes de cotisation";
      final result = AvsExtractParser.parseAvsExtract(text);
      final field = findField(result, 'lacunes_cotisation');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(2.0, 0.01));
    });
  });

  // ── Golden couple: Julien (age 49) ─────────────────────────
  group('parseAvsExtract — golden test Julien', () {
    test('extracts Julien-like AVS extract with age validation', () {
      const text = """
EXTRAIT DE COMPTE INDIVIDUEL (CI)
Caisse de compensation AVS du Valais

Assuré: Battaglia Julien
No. AVS: 756.xxxx.xxxx.xx
Date de naissance: 12.01.1977

RÉCAPITULATIF
Années de cotisation: 29
Revenu annuel moyen déterminant (RAMD): CHF 88'200.00
Lacunes de cotisation: 0
Bonifications pour tâches éducatives: 0
""";
      final result = AvsExtractParser.parseAvsExtract(text, userAge: 49);
      expect(findField(result, 'annees_cotisation')!.value, closeTo(29.0, 0.01));
      expect(findField(result, 'ramd')!.value, closeTo(88200.0, 0.01));
      expect(findField(result, 'lacunes_cotisation')!.value, closeTo(0.0, 0.01));
      expect(findField(result, 'bonifications_educatives')!.value, closeTo(0.0, 0.01));
      // 29 years <= 49 - 20 = 29 max => no warning
      expect(
        result.warnings.any((w) => w.contains('passe le maximum')),
        isFalse,
      );
      // RAMD 88200 <= 100000 => no high RAMD warning
      expect(
        result.warnings.any((w) => w.contains('lev')),
        isFalse,
      );
    });
  });
}
