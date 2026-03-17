import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';

/// Unit tests for LppCertificateParser
///
/// Tests OCR text parsing of Swiss LPP pension certificates (Certificat de
/// prevoyance / Vorsorgeausweis) into structured ExtractedField objects.
///
/// Legal basis: LPP art. 14-16 (conversion rates, bonifications)
void main() {
  // ── Helper ──────────────────────────────────────────────────
  ExtractedField? _findField(ExtractionResult r, String fieldName) {
    try {
      return r.fields.firstWhere((f) => f.fieldName == fieldName);
    } catch (_) {
      return null;
    }
  }

  // ── Sample OCR text (well-formatted) ───────────────────────
  group('parseLppCertificate — sample OCR text', () {
    late ExtractionResult result;

    setUp(() {
      result = LppCertificateParser.parseLppCertificate(
        LppCertificateParser.sampleOcrText,
      );
    });

    test('returns correct document type', () {
      expect(result.documentType, DocumentType.lppCertificate);
    });

    test('extracts avoir de vieillesse total = 143287.50', () {
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(143287.50, 0.01));
      expect(field.profileField, 'avoirLppTotal');
    });

    test('extracts part obligatoire = 98400', () {
      final field = _findField(result, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(98400.0, 0.01));
    });

    test('extracts part surobligatoire = 44887.50', () {
      final field = _findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(44887.50, 0.01));
    });

    test('extracts salaire assure = 72540', () {
      final field = _findField(result, 'lpp_insured_salary');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(72540.0, 0.01));
    });

    test('extracts taux de bonification = 15.0%', () {
      final field = _findField(result, 'lpp_bonification_rate');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(15.0, 0.1));
    });

    test('extracts taux de conversion obligatoire = 6.80%', () {
      final field = _findField(result, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(6.80, 0.01));
    });

    test('extracts taux de conversion surobligatoire = 5.20%', () {
      final field = _findField(result, 'conversion_rate_suroblig');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(5.20, 0.01));
    });

    test('extracts rente de vieillesse projetee = 31450', () {
      final field = _findField(result, 'projected_rente');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(31450.0, 0.01));
    });

    test('extracts capital projete a 65 = 485200', () {
      final field = _findField(result, 'projected_capital_65');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(485200.0, 0.01));
    });

    test('extracts prestation invalidite = 36800', () {
      final field = _findField(result, 'disability_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(36800.0, 0.01));
    });

    test('extracts capital-deces = 220500', () {
      final field = _findField(result, 'death_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(220500.0, 0.01));
    });

    test('extracts rachat possible = 45000', () {
      final field = _findField(result, 'buyback_potential');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(45000.0, 0.01));
    });

    test('extracts cotisation employe = 452.50', () {
      final field = _findField(result, 'employee_contribution');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(452.50, 0.01));
    });

    test('extracts cotisation employeur = 543.00', () {
      final field = _findField(result, 'employer_contribution');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(543.0, 0.01));
    });

    test('has no cross-validation warnings (oblig + suroblig ~ total)', () {
      // 98400 + 44887.50 = 143287.50 == total => no warning
      expect(result.warnings, isEmpty);
    });

    test('overall confidence is above 0.80', () {
      expect(result.overallConfidence, greaterThanOrEqualTo(0.80));
    });

    test('has non-empty disclaimer and sources', () {
      expect(result.disclaimer, isNotEmpty);
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
    });

    test('confidence delta is positive', () {
      expect(result.confidenceDelta, greaterThan(0));
    });
  });

  // ── Swiss number formats ───────────────────────────────────
  group('parseLppCertificate — Swiss number formats', () {
    test('parses apostrophe thousands: 70\'377', () {
      final text = "Avoir de vieillesse total: CHF 70'377.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(70377.0, 0.01));
    });

    test('parses space as thousand separator: 143 287', () {
      final text = "Avoir de vieillesse total: CHF 143 287";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(143287.0, 1.0));
    });

    test('parses comma decimal (Swiss German): 143287,50', () {
      final text = "Altersguthaben total: 143287,50";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(143287.50, 0.01));
    });

    test('parses Fr. prefix', () {
      final text = "Part obligatoire: Fr. 98'400.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(98400.0, 0.01));
    });
  });

  // ── German (DE) format certificates ────────────────────────
  group('parseLppCertificate — German format', () {
    test('parses Altersguthaben total (DE)', () {
      final text = "Altersguthaben gesamt: CHF 200'000.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(200000.0, 0.01));
    });

    test('parses Obligatorischer Teil (DE)', () {
      final text = "Obligatorischer Teil: CHF 120'000.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(120000.0, 0.01));
    });

    test('parses Ueberobligatorischer Teil (DE)', () {
      final text = "Ueberobligatorischer Teil: CHF 80'000.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(80000.0, 0.01));
    });

    test('parses Versicherter Lohn (DE)', () {
      final text = "Versicherter Lohn: CHF 85'000.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_insured_salary');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(85000.0, 0.01));
    });

    test('parses Einkaufspotential (DE)', () {
      final text = "Einkaufspotential: CHF 539'414.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'buyback_potential');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(539414.0, 0.01));
    });

    test('parses Invalidenrente (DE)', () {
      final text = "Invalidenrente: CHF 42'000.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'disability_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(42000.0, 0.01));
    });

    test('parses Todesfallkapital (DE)', () {
      final text = "Todesfallkapital: CHF 300'000.00";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'death_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(300000.0, 0.01));
    });
  });

  // ── Cross-validation: oblig + suroblig ~ total ─────────────
  group('parseLppCertificate — cross-validation', () {
    test('warns when oblig + suroblig does not match total (>5% diff)', () {
      final text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
Part surobligatoire: CHF 20'000.00
""";
      final result = LppCertificateParser.parseLppCertificate(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('ne correspond pas')),
        isTrue,
      );
    });

    test('no warning when oblig + suroblig matches total within 5%', () {
      final text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
Part surobligatoire: CHF 39'000.00
""";
      final result = LppCertificateParser.parseLppCertificate(text);
      // 60000 + 39000 = 99000, diff = 1000, tolerance = 5000 => no warning
      expect(
        result.warnings.any((w) => w.contains('ne correspond pas')),
        isFalse,
      );
    });

    test('infers surobligatoire when total and oblig present but suroblig missing', () {
      final text = """
Avoir de vieillesse total: CHF 150'000.00
Part obligatoire: CHF 90'000.00
""";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(60000.0, 0.01));
      expect(field.confidence, 0.70);
      expect(field.needsReview, isTrue);
      expect(field.label, contains('déduit'));
    });

    test('warns for unusual conversion rate obligatoire (< 5%)', () {
      final text = "Taux de conversion (obligatoire): 4.50 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('inhabituel')),
        isTrue,
      );
    });

    test('warns for unusual conversion rate obligatoire (> 8%)', () {
      final text = "Taux de conversion (obligatoire): 9.00 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('inhabituel')),
        isTrue,
      );
    });

    test('no warning for legal conversion rate 6.80%', () {
      final text = "Taux de conversion (obligatoire): 6.80 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      expect(
        result.warnings.any((w) => w.contains('taux de conversion')),
        isFalse,
      );
    });
  });

  // ── Empty / malformed input ────────────────────────────────
  group('parseLppCertificate — edge cases', () {
    test('empty string produces zero fields and zero confidence', () {
      final result = LppCertificateParser.parseLppCertificate('');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
      expect(result.confidenceDelta, 0.0);
      expect(result.warnings, isEmpty);
      expect(result.documentType, DocumentType.lppCertificate);
    });

    test('random text produces zero fields', () {
      final result = LppCertificateParser.parseLppCertificate(
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      );
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });

    test('text with only labels but no values produces zero fields', () {
      final result = LppCertificateParser.parseLppCertificate(
        'Avoir de vieillesse total: \nPart obligatoire: ',
      );
      expect(result.fields, isEmpty);
    });

    test('handles null-like edge case with only whitespace', () {
      final result = LppCertificateParser.parseLppCertificate('   \n\n  ');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });
  });

  // ── Percentage parsing ─────────────────────────────────────
  group('parseLppCertificate — percentage edge cases', () {
    test('parses percentage with comma decimal: 6,80 %', () {
      final text = "Taux de conversion (obligatoire): 6,80 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(6.80, 0.01));
    });

    test('parses taux de remuneration', () {
      final text = "Taux de rémunération: 5.00 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'remuneration_rate');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(5.0, 0.1));
    });

    test('parses Verzinsung (DE remuneration rate)', () {
      final text = "Verzinsung: 3.50 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'remuneration_rate');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(3.50, 0.1));
    });
  });

  // ── Field confidence & needsReview ─────────────────────────
  group('parseLppCertificate — confidence metadata', () {
    test('CHF-prefixed amount has confidence >= 0.82', () {
      final text = "Avoir de vieillesse total: CHF 143'287.50";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.82));
      expect(field.needsReview, isFalse);
    });

    test('percentage in reasonable range has confidence >= 0.85', () {
      final text = "Taux de conversion (obligatoire): 6.80 %";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.85));
    });

    test('inferred surobligatoire has needsReview = true', () {
      final text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
""";
      final result = LppCertificateParser.parseLppCertificate(text);
      final field = _findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect(field!.needsReview, isTrue);
    });

    test('fieldsNeedingReview returns only low-confidence fields', () {
      final text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
""";
      final result = LppCertificateParser.parseLppCertificate(text);
      for (final f in result.fieldsNeedingReview) {
        expect(f.needsReview, isTrue);
      }
    });
  });

  // ── estimateConfidenceDelta with profile ───────────────────
  group('estimateConfidenceDelta', () {
    test('full impact when profile field is null', () {
      final result = LppCertificateParser.parseLppCertificate(
        LppCertificateParser.sampleOcrText,
      );
      final delta = LppCertificateParser.estimateConfidenceDelta(
        result,
        <String, dynamic>{}, // empty profile
      );
      expect(delta, greaterThan(0));
      expect(delta, lessThanOrEqualTo(30));
    });

    test('partial impact when profile already has values', () {
      final result = LppCertificateParser.parseLppCertificate(
        LppCertificateParser.sampleOcrText,
      );
      final deltaEmpty = LppCertificateParser.estimateConfidenceDelta(
        result,
        <String, dynamic>{},
      );
      final deltaFull = LppCertificateParser.estimateConfidenceDelta(
        result,
        <String, dynamic>{
          'avoirLppTotal': 140000.0,
          'lppObligatoire': 95000.0,
          'lppSurobligatoire': 45000.0,
          'tauxConversionOblig': 6.8,
          'buybackPotential': 40000.0,
        },
      );
      expect(deltaFull, lessThan(deltaEmpty));
    });
  });

  // ── Golden couple: Julien (CPE) ────────────────────────────
  group('parseLppCertificate — golden test Julien', () {
    test('extracts Julien-like certificate values', () {
      final text = """
CERTIFICAT DE PREVOYANCE 2025
Caisse de pension CPE

Avoir de vieillesse total: CHF 70'377.00
Part obligatoire: CHF 45'000.00
Part surobligatoire: CHF 25'377.00
Salaire assuré: CHF 95'747.00
Taux de bonification de vieillesse: 18.0 %
Taux de rémunération: 5.00 %
Rachat possible (montant maximum): CHF 539'414.00
Rente de vieillesse projetée: CHF 33'892.00 / an
Capital de vieillesse projeté à 65: CHF 677'847.00
""";
      final result = LppCertificateParser.parseLppCertificate(text);
      expect(_findField(result, 'lpp_total')!.value, closeTo(70377.0, 1.0));
      expect(_findField(result, 'buyback_potential')!.value, closeTo(539414.0, 1.0));
      expect(_findField(result, 'projected_rente')!.value, closeTo(33892.0, 1.0));
      expect(_findField(result, 'projected_capital_65')!.value, closeTo(677847.0, 1.0));
      expect(_findField(result, 'remuneration_rate')!.value, closeTo(5.0, 0.1));
      expect(result.warnings, isEmpty); // oblig + suroblig == total
    });
  });
}
