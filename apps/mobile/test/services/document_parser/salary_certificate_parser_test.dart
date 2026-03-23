// ────────────────────────────────────────────────────────────
//  SALARY CERTIFICATE PARSER — Unit Tests
// ────────────────────────────────────────────────────────────
//
//  Tests for SalaryCertificateParser.parse() covering:
//  - Swiss number parsing (apostrophe, CHF prefix, Fr. prefix)
//  - French and German label recognition
//  - Field extraction accuracy
//  - Missing / empty / null-equivalent input handling
//  - Edge cases: zero values filtered, very large numbers,
//    cross-validation warnings, percentage (taux d'activité)
//  - ExtractionResult metadata (documentType, disclaimer, sources)
// ────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/salary_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

void main() {
  // ── Swiss number parsing (via field extraction) ──────────────

  group('Swiss number parsing — apostrophe thousands separator', () {
    test("parses CHF 7'083.35 → 7083.35", () {
      const ocr = "Brut mensuel : CHF 7'083.35";
      final result = SalaryCertificateParser.parse(ocr);
      final brut = _field(result, 'salaire_brut');
      expect(brut, isNotNull);
      expect(brut!.value as double, closeTo(7083.35, 0.01));
    });

    test("parses 125'000 → 125000 (no decimal)", () {
      const ocr = "Salaire de base : 125'000";
      final result = SalaryCertificateParser.parse(ocr);
      final brut = _field(result, 'salaire_brut');
      expect(brut, isNotNull);
      expect(brut!.value as double, closeTo(125000, 0.01));
    });

    test("parses right single quote (Unicode 2019) as thousands separator", () {
      // U+2019 RIGHT SINGLE QUOTATION MARK — common in OCR output
      const ocr = "Brut mensuel : 10\u2019500.00";
      final result = SalaryCertificateParser.parse(ocr);
      final brut = _field(result, 'salaire_brut');
      expect(brut, isNotNull);
      expect(brut!.value as double, closeTo(10500.00, 0.01));
    });
  });

  // ── French label recognition ─────────────────────────────────

  group('French label recognition', () {
    test('extracts salaire_brut from "Salaire de base"', () {
      const ocr = "Salaire de base : CHF 9'200.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'salaire_brut'), isNotNull);
    });

    test('extracts salaire_net from "net versé"', () {
      const ocr = "Net versé : CHF 7'100.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'salaire_net'), isNotNull);
    });

    test('extracts cotisation_lpp from "prévoyance professionnelle"', () {
      const ocr = "Prévoyance professionnelle : - 450.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'cotisation_lpp'), isNotNull);
    });

    test('extracts cotisation_avs from "AVS/AI/APG"', () {
      const ocr = "AVS / AI / APG : - 520.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'cotisation_avs'), isNotNull);
    });

    test('extracts taux_activite from "Taux d\'activité : 80%"', () {
      const ocr = "Taux d'activité : 80%";
      final result = SalaryCertificateParser.parse(ocr);
      final field = _field(result, 'taux_activite');
      expect(field, isNotNull);
      expect(field!.value as double, closeTo(80.0, 0.1));
    });
  });

  // ── German label recognition ──────────────────────────────────

  group('German label recognition (Deutschschweiz)', () {
    test('extracts salaire_brut from "Grundlohn"', () {
      const ocr = "Grundlohn : CHF 8'750.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'salaire_brut'), isNotNull);
    });

    test('extracts salaire_brut from "Monatslohn"', () {
      const ocr = "Monatslohn : 6'900.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'salaire_brut'), isNotNull);
    });

    test('extracts cotisation_avs from "AHV/IV/EO"', () {
      const ocr = "AHV / IV / EO : - 490.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'cotisation_avs'), isNotNull);
    });

    test('extracts cotisation_lpp from "BVG Arbeitnehmer"', () {
      const ocr = "BVG Arbeitnehmer : - 380.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'cotisation_lpp'), isNotNull);
    });

    test('extracts taux_activite from "Beschäftigungsgrad"', () {
      const ocr = "Beschäftigungsgrad : 100%";
      final result = SalaryCertificateParser.parse(ocr);
      final field = _field(result, 'taux_activite');
      expect(field, isNotNull);
      expect(field!.value as double, closeTo(100.0, 0.1));
    });
  });

  // ── Missing required fields return gracefully ────────────────

  group('Missing fields — graceful null handling', () {
    test('empty string returns result with zero fields and overallConfidence 0', () {
      final result = SalaryCertificateParser.parse('');
      // Employer heuristic may also fail on empty input
      expect(result.fields.where((f) => f.fieldName != 'employeur'), isEmpty);
      expect(result.overallConfidence, equals(0.0));
    });

    test('unrelated OCR text returns no numeric fields', () {
      const ocr = 'Merci de votre confiance. Cordialement, Jean-Pierre.';
      final result = SalaryCertificateParser.parse(ocr);
      final numericFields = result.fields
          .where((f) => f.fieldName != 'employeur' && f.value is double)
          .toList();
      expect(numericFields, isEmpty);
    });

    test('missing salaire_brut does not crash parse', () {
      // Only net present — brut absent
      const ocr = "Net versé : CHF 6'200.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'salaire_brut'), isNull);
      expect(_field(result, 'salaire_net'), isNotNull);
    });

    test('missing salaire_net does not crash parse', () {
      const ocr = "Salaire de base : CHF 9'000.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'salaire_net'), isNull);
    });
  });

  // ── Zero and negative value filtering ────────────────────────

  group('Zero values are filtered out', () {
    test('field with value 0 is not added to results', () {
      // The parser skips value <= 0
      const ocr = "Bonus : 0.00";
      final result = SalaryCertificateParser.parse(ocr);
      expect(_field(result, 'bonus'), isNull);
    });
  });

  // ── Very large numbers ────────────────────────────────────────

  group('Very large numbers', () {
    test("parses 1'200'000 correctly for a large annual salary context", () {
      // Annual bonus on a certificate
      const ocr = "Bonus : CHF 1'200'000.00";
      final result = SalaryCertificateParser.parse(ocr);
      final bonus = _field(result, 'bonus');
      expect(bonus, isNotNull);
      expect(bonus!.value as double, closeTo(1200000.0, 1.0));
    });

    test("handles 6-digit monthly salary without overflow", () {
      const ocr = "Salaire de base : CHF 100'000.00";
      final result = SalaryCertificateParser.parse(ocr);
      final brut = _field(result, 'salaire_brut');
      expect(brut, isNotNull);
      expect(brut!.value as double, closeTo(100000.0, 0.01));
    });
  });

  // ── Cross-validation warning ─────────────────────────────────

  group('Cross-validation warnings', () {
    test('emits warning when net differs from brut minus deductions by >5%', () {
      // brut=9000, avs=530, ac=135, lpp=450 → expectedNet ~7885
      // but stated net=6000 → delta large
      const ocr = """
Salaire de base : CHF 9'000.00
AVS / AI / APG : - 530.00
AC : - 135.00
LPP employé : - 450.00
Net versé : CHF 6'000.00
""";
      final result = SalaryCertificateParser.parse(ocr);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('Vérifie les déductions')),
        isTrue,
      );
    });

    test('no warning when net matches brut minus deductions within tolerance', () {
      // brut=9000, avs=530, ac=135, lpp=450 → expectedNet=7885 → state 7890
      const ocr = """
Salaire de base : CHF 9'000.00
AVS / AI / APG : - 530.00
AC : - 135.00
LPP employé : - 450.00
Net versé : CHF 7'885.00
""";
      final result = SalaryCertificateParser.parse(ocr);
      final deductionWarnings =
          result.warnings.where((w) => w.contains('Vérifie les déductions'));
      expect(deductionWarnings, isEmpty);
    });
  });

  // ── ExtractionResult metadata ─────────────────────────────────

  group('ExtractionResult metadata', () {
    test('documentType is salaryCertificate', () {
      final result = SalaryCertificateParser.parse("Brut mensuel : 5'000.00");
      expect(result.documentType, equals(DocumentType.salaryCertificate));
    });

    test('confidenceDelta equals confidenceImpact constant (20)', () {
      final result = SalaryCertificateParser.parse('anything');
      expect(result.confidenceDelta,
          equals(SalaryCertificateParser.confidenceImpact.toDouble()));
    });

    test('disclaimer is non-empty and contains LSFin reference', () {
      final result = SalaryCertificateParser.parse('');
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources list references LAVS art. 5, LPP art. 66, LACI art. 3', () {
      final result = SalaryCertificateParser.parse('');
      expect(result.sources, hasLength(greaterThanOrEqualTo(3)));
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LACI')), isTrue);
    });

    test('overallConfidence is average of field confidences', () {
      const ocr = """
Salaire de base : CHF 8'000.00
Net versé : CHF 6'500.00
""";
      final result = SalaryCertificateParser.parse(ocr);
      if (result.fields.isNotEmpty) {
        final expected = result.fields
                .map((f) => f.confidence)
                .reduce((a, b) => a + b) /
            result.fields.length;
        expect(result.overallConfidence, closeTo(expected, 0.001));
      }
    });

    test('highConfidenceFields only contains fields with confidence >= 0.80', () {
      const ocr = "Salaire de base : CHF 9'200.00";
      final result = SalaryCertificateParser.parse(ocr);
      for (final f in result.highConfidenceFields) {
        expect(f.confidence, greaterThanOrEqualTo(0.80));
      }
    });
  });

  // ── Employer extraction ────────────────────────────────────────

  group('Employer extraction heuristic', () {
    test('extracts SA company name from first lines', () {
      const ocr = """Technologie Romande SA
Rue de la Paix 12
1000 Lausanne

Salaire de base : CHF 7'500.00
""";
      final result = SalaryCertificateParser.parse(ocr);
      final employer = _field(result, 'employeur');
      expect(employer, isNotNull);
      expect(employer!.value as String, contains('SA'));
    });

    test('employer field profileField is "employeur"', () {
      const ocr = "Entreprise GmbH\nBrut mensuel : 5'000.00";
      final result = SalaryCertificateParser.parse(ocr);
      final employer = _field(result, 'employeur');
      if (employer != null) {
        expect(employer.profileField, equals('employeur'));
      }
    });
  });

  // ── Taux d'activité sanity check ──────────────────────────────

  group('Taux d\'activité sanity check', () {
    test('warns when taux activité is below 10%', () {
      const ocr = "Taux d'activité : 5%";
      final result = SalaryCertificateParser.parse(ocr);
      expect(result.warnings.any((w) => w.contains('activité')), isTrue);
    });

    test('no warning when taux activité is 80%', () {
      const ocr = "Taux d'activité : 80%";
      final result = SalaryCertificateParser.parse(ocr);
      final tauxWarnings =
          result.warnings.where((w) => w.contains('activité'));
      expect(tauxWarnings, isEmpty);
    });
  });
}

// ── Test helper ────────────────────────────────────────────────

ExtractedField? _field(ExtractionResult result, String fieldName) {
  try {
    return result.fields.firstWhere((f) => f.fieldName == fieldName);
  } catch (_) {
    return null;
  }
}
