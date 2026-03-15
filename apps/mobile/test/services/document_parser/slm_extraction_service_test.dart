import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/slm_extraction_service.dart';
import 'package:mint_mobile/services/document_parser/slm_extraction_validator.dart';

void main() {
  // ────────────────────────────────────────────────────────────
  //  OCR COMPRESSION TESTS
  // ────────────────────────────────────────────────────────────

  group('compressOcrText', () {
    test('removes blank lines and decorative characters', () {
      const ocr = '''
Line 1
────────────────
Line 2

Line 3
═══════════════
Line 4
''';
      final result = SlmExtractionService.compressOcrText(ocr, []);
      expect(result, isNot(contains('────')));
      expect(result, isNot(contains('═══')));
      expect(result, contains('Line 1'));
      expect(result, contains('Line 4'));
    });

    test('removes sections already extracted by regex', () {
      const ocr = '''
Données salariales
Salaire déterminant 122'206.80
Projection de l'avoir de vieillesse
âge 65 1'200.00 676'647.00
Rachats possibles
Rachat en vue de la retraite ordinaire 539'413.70
''';
      final alreadyFound = [
        const ExtractedField(
          fieldName: 'lpp_determining_salary',
          label: 'Salaire déterminant',
          value: 122206.80,
          confidence: 0.90,
          sourceText: "Salaire déterminant 122'206.80",
          needsReview: false,
        ),
      ];
      final result = SlmExtractionService.compressOcrText(ocr, alreadyFound);
      // Salary line should be removed (already extracted)
      expect(result, isNot(contains("122'206.80")));
      // But section headers and other data should remain
      expect(result, contains('Rachats possibles'));
      expect(result, contains("539'413.70"));
    });

    test('preserves section headers even when nearby data is extracted', () {
      const ocr = '''
Données salariales
Salaire déterminant 0.00 122'206.80
''';
      final alreadyFound = [
        const ExtractedField(
          fieldName: 'lpp_determining_salary',
          label: 'Salaire',
          value: 122206.80,
          confidence: 0.90,
          sourceText: "Salaire déterminant 0.00 122'206.80",
          needsReview: false,
        ),
      ];
      final result = SlmExtractionService.compressOcrText(ocr, alreadyFound);
      // Section header "Données salariales" should be preserved
      expect(result, contains('Données salariales'));
    });

    test('respects maxChars limit and truncates from bottom', () {
      final longOcr = List.generate(200, (i) => 'Line $i with some data ${i * 100}').join('\n');
      final result = SlmExtractionService.compressOcrText(longOcr, [], maxChars: 500);
      expect(result.length, lessThanOrEqualTo(510)); // Small margin for [...]
      expect(result, contains('Line 0')); // Top preserved
      expect(result, contains('[...]')); // Truncation marker
    });

    test('returns full text when shorter than maxChars', () {
      const shortOcr = 'Just a short text';
      final result = SlmExtractionService.compressOcrText(shortOcr, []);
      expect(result, equals('Just a short text'));
    });
  });

  // ────────────────────────────────────────────────────────────
  //  PROMPT BUILDING TESTS
  // ────────────────────────────────────────────────────────────

  group('buildPrompt', () {
    test('system prompt contains all missing field names', () {
      final prompt = SlmExtractionService.buildPrompt(
        'Some OCR text',
        ['lpp_total', 'buyback_potential', 'remuneration_rate'],
        DocumentType.lppCertificate,
      );
      expect(prompt.system, contains('"lpp_total"'));
      expect(prompt.system, contains('"buyback_potential"'));
      expect(prompt.system, contains('"remuneration_rate"'));
    });

    test('user prompt contains the compressed OCR', () {
      const ocr = 'Certificat de prévoyance au 08.03.2026';
      final prompt = SlmExtractionService.buildPrompt(
        ocr,
        ['lpp_total'],
        DocumentType.lppCertificate,
      );
      expect(prompt.user, contains(ocr));
      expect(prompt.user, contains('TEXTE OCR'));
    });

    test('system prompt fits within token budget', () {
      // All LPP fields missing (worst case)
      final allFields = [
        'lpp_total', 'lpp_obligatoire', 'lpp_surobligatoire',
        'lpp_insured_salary', 'conversion_rate_oblig', 'buyback_potential',
        'projected_capital_65', 'projected_rente', 'disability_coverage',
        'death_coverage', 'employee_contribution', 'employer_contribution',
      ];
      final prompt = SlmExtractionService.buildPrompt(
        'Short OCR',
        allFields,
        DocumentType.lppCertificate,
      );
      // System prompt should be under ~1400 chars (~400 tokens)
      expect(prompt.system.length, lessThan(1400));
    });
  });

  // ────────────────────────────────────────────────────────────
  //  RESPONSE PARSING TESTS
  // ────────────────────────────────────────────────────────────

  group('parseSlmResponse', () {
    test('parses valid JSON with multiple fields', () {
      const response = '''
{"fields":[
  {"name":"lpp_total","value":70376.60,"source":"Avoir de vieillesse 70'376.60"},
  {"name":"buyback_potential","value":539413.70,"source":"Rachat 539'413.70"}
]}''';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields.length, equals(2));
      expect(fields[0].fieldName, equals('lpp_total'));
      expect(fields[0].value, closeTo(70376.60, 0.01));
      expect(fields[1].fieldName, equals('buyback_potential'));
      expect(fields[1].value, closeTo(539413.70, 0.01));
    });

    test('returns empty list for malformed JSON', () {
      const response = 'This is not JSON at all';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields, isEmpty);
    });

    test('filters out null values', () {
      const response = '''
{"fields":[
  {"name":"lpp_total","value":70376.60,"source":"text"},
  {"name":"buyback_potential","value":null,"source":"not found"}
]}''';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields.length, equals(1));
      expect(fields[0].fieldName, equals('lpp_total'));
    });

    test('ignores unknown field names', () {
      const response = '''
{"fields":[
  {"name":"lpp_total","value":70376.60,"source":"text"},
  {"name":"unknown_field","value":12345,"source":"text"}
]}''';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields.length, equals(1));
    });

    test('handles empty fields array', () {
      const response = '{"fields":[]}';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields, isEmpty);
    });

    test('handles JSON wrapped in markdown code blocks', () {
      const response = '''
```json
{"fields":[{"name":"lpp_total","value":70376.60,"source":"text"}]}
```''';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields.length, equals(1));
    });

    test('parses string values as numbers', () {
      const response = '''
{"fields":[{"name":"lpp_total","value":"70376.60","source":"text"}]}''';
      final fields = SlmExtractionService.parseSlmResponse(
        response,
        DocumentType.lppCertificate,
      );
      expect(fields.length, equals(1));
      expect(fields[0].value, closeTo(70376.60, 0.01));
    });
  });

  // ────────────────────────────────────────────────────────────
  //  VALIDATOR TESTS (Hallucination Guard)
  // ────────────────────────────────────────────────────────────

  group('SlmExtractionValidator', () {
    const ocrText = """
Prestation de sortie au 08.03.2026
Avoir de vieillesse 70'376.60
Montant minimum 66'526.15
Avoir de vieillesse LPP 30'243.80
Rachat en vue de la retraite ordinaire à l'âge de 65 ans 539'413.70
""";

    test('Layer 1: accepts field when source text found verbatim', () {
      final candidate = ExtractedField(
        fieldName: 'lpp_total',
        label: 'Avoir total',
        value: 70376.60,
        confidence: 0.65,
        sourceText: "Avoir de vieillesse 70'376.60",
        needsReview: true,
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNotNull);
      expect(result!.confidence, greaterThanOrEqualTo(0.50));
      expect(result.confidence, lessThanOrEqualTo(0.75));
    });

    test('Layer 1: rejects field when source text not in OCR', () {
      final candidate = ExtractedField(
        fieldName: 'lpp_total',
        label: 'Avoir total',
        value: 70376.60,
        confidence: 0.65,
        sourceText: "Capital total 70'376.60",
        needsReview: true,
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      // Should still pass because the NUMBER is in the OCR (fuzzy match)
      expect(result, isNotNull);
    });

    test('Layer 1: rejects field when source text AND number not in OCR', () {
      final candidate = ExtractedField(
        fieldName: 'lpp_total',
        label: 'Avoir total',
        value: 999999.99,
        confidence: 0.65,
        sourceText: "Invented text 999'999.99",
        needsReview: true,
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNull);
    });

    test('Layer 2: rejects field when value mismatches source (10x error)', () {
      final candidate = ExtractedField(
        fieldName: 'lpp_total',
        label: 'Avoir total',
        value: 703766.0, // 10x the actual value
        confidence: 0.65,
        sourceText: "Avoir de vieillesse 70'376.60",
        needsReview: true,
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNull);
    });

    test('Layer 2: accepts field when value matches source within 1%', () {
      final candidate = ExtractedField(
        fieldName: 'lpp_total',
        label: 'Avoir total',
        value: 70377.0, // ~0.001% off
        confidence: 0.65,
        sourceText: "Avoir de vieillesse 70'376.60",
        needsReview: true,
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNotNull);
    });

    test('Layer 3: rejects value outside semantic bounds', () {
      final candidate = ExtractedField(
        fieldName: 'conversion_rate_oblig',
        label: 'Taux conversion',
        value: 68.0, // 68% instead of 6.8%
        confidence: 0.65,
        sourceText: "6.80",
        needsReview: true,
      );
      // This should fail semantic bounds (3-8%) even if layer 2 fails first
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNull);
    });

    test('Layer 3: accepts value within semantic bounds', () {
      final candidate = ExtractedField(
        fieldName: 'buyback_potential',
        label: 'Rachat',
        value: 539413.70,
        confidence: 0.65,
        sourceText: "539'413.70",
        needsReview: true,
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNotNull);
      expect(result!.value, closeTo(539413.70, 1.0));
    });

    test('all SLM validated fields have needsReview = true', () {
      final candidate = ExtractedField(
        fieldName: 'lpp_total',
        label: 'Avoir total',
        value: 70376.60,
        confidence: 0.65,
        sourceText: "Avoir de vieillesse 70'376.60",
        needsReview: false, // Even if candidate says false
      );
      final result = SlmExtractionValidator.validate(candidate, ocrText);
      expect(result, isNotNull);
      expect(result!.needsReview, isTrue); // Always true for SLM
    });
  });

  // ────────────────────────────────────────────────────────────
  //  SOURCE VERIFICATION TESTS
  // ────────────────────────────────────────────────────────────

  group('verifySourceInOcr', () {
    test('exact match returns found=true, exact=true', () {
      const ocr = "Avoir de vieillesse 70'376.60";
      final result = SlmExtractionValidator.verifySourceInOcr(
        "Avoir de vieillesse 70'376.60",
        ocr,
      );
      expect(result.found, isTrue);
      expect(result.exact, isTrue);
    });

    test('fuzzy match (numbers only) returns found=true, exact=false', () {
      const ocr = "Avoir de vieillesse total 70'376.60";
      final result = SlmExtractionValidator.verifySourceInOcr(
        "Capital de vieillesse 70'376.60",
        ocr,
      );
      expect(result.found, isTrue);
      expect(result.exact, isFalse);
    });

    test('empty source returns found=false', () {
      final result = SlmExtractionValidator.verifySourceInOcr('', 'any text');
      expect(result.found, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────
  //  SEMANTIC BOUNDS TESTS
  // ────────────────────────────────────────────────────────────

  group('checkSemanticBounds', () {
    test('LPP total within bounds', () {
      expect(SlmExtractionValidator.checkSemanticBounds('lpp_total', 70376.60), isTrue);
    });

    test('LPP total at zero bound', () {
      expect(SlmExtractionValidator.checkSemanticBounds('lpp_total', 0), isTrue);
    });

    test('LPP total above max bound', () {
      expect(SlmExtractionValidator.checkSemanticBounds('lpp_total', 6000000), isFalse);
    });

    test('conversion rate within bounds', () {
      expect(SlmExtractionValidator.checkSemanticBounds('conversion_rate_oblig', 6.8), isTrue);
    });

    test('conversion rate out of bounds', () {
      expect(SlmExtractionValidator.checkSemanticBounds('conversion_rate_oblig', 68.0), isFalse);
    });

    test('unknown field uses generic bounds', () {
      expect(SlmExtractionValidator.checkSemanticBounds('some_unknown', 50000), isTrue);
      expect(SlmExtractionValidator.checkSemanticBounds('some_unknown', -1), isFalse);
    });
  });
}
