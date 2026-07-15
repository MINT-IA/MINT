import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';

/// Unit tests for LppCertificateParser
///
/// Tests OCR text parsing of Swiss LPP pension certificates (Certificat de
/// prevoyance / Vorsorgeausweis) into structured ExtractedField objects.
///
/// Legal basis: LPP art. 14-16 (conversion rates, bonifications)
void main() {
  // ── Helper ──────────────────────────────────────────────────
  ExtractedField? findField(ExtractionResult r, String fieldName) {
    try {
      return r.fields.firstWhere((f) => f.fieldName == fieldName);
    } catch (_) {
      return null;
    }
  }

  ExtractionResult parseCertificate(String body) {
    return LppCertificateParser.parseLppCertificate(
      'CERTIFICAT DE PRÉVOYANCE\nPersonne assurée :\n$body',
    );
  }

  group('disability pension and capital semantics', () {
    test('keeps annual pension distinct from lump-sum capital', () {
      final result = parseCertificate('''
Certificat de prévoyance
Rente d'invalidité annuelle: CHF 36'800
Capital invalidité (versement unique): CHF 175'000
''');

      expect(findField(result, 'disability_coverage')!.value, 36800.0);
      expect(
        findField(result, 'disability_coverage')!.profileField,
        'disabilityCoverage',
      );
      expect(findField(result, 'disability_capital')!.value, 175000.0);
      expect(
        findField(result, 'disability_capital')!.profileField,
        'lppDisabilityCapital',
      );
    });

    test('ambiguous disability prestation is not promoted to either fact', () {
      final result = parseCertificate('''
Certificat de prévoyance
Prestation d'invalidité: CHF 90'000
''');

      expect(findField(result, 'disability_coverage'), isNull);
      expect(findField(result, 'disability_capital'), isNull);
    });

    test('only explicit death-capital labels populate death capital', () {
      for (final text in <String>[
        'Prestation de décès: CHF 220\'000',
        'Prestation de décès: CHF 36\'000 / an',
        'Todesfallleistung: CHF 220\'000',
      ]) {
        final result = parseCertificate(text);
        expect(findField(result, 'death_coverage'), isNull, reason: text);
      }

      final explicitFrench = parseCertificate(
        'Capital décès: CHF 220\'000',
      );
      final explicitGerman = parseCertificate(
        'Todesfallkapital: CHF 220\'000',
      );
      expect(findField(explicitFrench, 'death_coverage')!.value, 220000.0);
      expect(findField(explicitGerman, 'death_coverage')!.value, 220000.0);
    });
  });

  group('annual pension period semantics', () {
    test('generic and monthly retirement pensions stay absent', () {
      for (final text in <String>[
        'Rente de vieillesse projetée: CHF 31\'450',
        'Rente de vieillesse projetée: CHF 2\'620 / mois',
        'Voraussichtliche Altersrente: CHF 31\'450',
        'Voraussichtliche Altersrente: CHF 2\'620 pro Monat',
      ]) {
        final result = parseCertificate(text);
        expect(findField(result, 'projected_rente'), isNull, reason: text);
      }
    });

    test('generic and monthly disability pensions stay absent', () {
      for (final text in <String>[
        'Rente d\'invalidité: CHF 36\'800',
        'Rente d\'invalidité: CHF 3\'066 / mois',
        'Invalidenrente: CHF 42\'000',
        'Invalidenrente: CHF 3\'500 pro Monat',
      ]) {
        final result = parseCertificate(text);
        expect(findField(result, 'disability_coverage'), isNull, reason: text);
      }
    });

    test('explicit French and German annual pensions remain available', () {
      final frenchRetirement = parseCertificate(
        'Rente de vieillesse projetée: CHF 31\'450 / an',
      );
      final germanRetirement = parseCertificate(
        'Voraussichtliche Altersrente: CHF 31\'450 pro Jahr',
      );
      final frenchDisability = parseCertificate(
        'Rente d\'invalidité annuelle: CHF 36\'800',
      );
      final germanDisability = parseCertificate(
        'Invalidenrente: CHF 42\'000 pro Jahr',
      );

      expect(findField(frenchRetirement, 'projected_rente')!.value, 31450.0);
      expect(findField(germanRetirement, 'projected_rente')!.value, 31450.0);
      expect(
          findField(frenchDisability, 'disability_coverage')!.value, 36800.0);
      expect(
          findField(germanDisability, 'disability_coverage')!.value, 42000.0);
    });
  });

  // ── Sample OCR text (well-formatted) ───────────────────────
  group('parseLppCertificate — sample OCR text', () {
    late ExtractionResult result;

    setUp(() {
      result = parseCertificate(
        LppCertificateParser.sampleOcrText,
      );
    });

    test('returns correct document type', () {
      expect(result.documentType, DocumentType.lppCertificate);
    });

    test('extracts avoir de vieillesse total = 143287.50', () {
      final field = findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(143287.50, 0.01));
      expect(field.profileField, 'avoirLppTotal');
    });

    test('extracts part obligatoire = 98400', () {
      final field = findField(result, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(98400.0, 0.01));
    });

    test('extracts part surobligatoire = 44887.50', () {
      final field = findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(44887.50, 0.01));
    });

    test('extracts salaire assure = 72540', () {
      final field = findField(result, 'lpp_insured_salary');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(72540.0, 0.01));
    });

    test('extracts taux de bonification = 15.0%', () {
      final field = findField(result, 'lpp_bonification_rate');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(15.0, 0.1));
    });

    test('extracts taux de conversion obligatoire = 6.80%', () {
      final field = findField(result, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(6.80, 0.01));
    });

    test('extracts taux de conversion surobligatoire = 5.20%', () {
      final field = findField(result, 'conversion_rate_suroblig');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(5.20, 0.01));
    });

    test('extracts rente de vieillesse projetee = 31450', () {
      final field = findField(result, 'projected_rente');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(31450.0, 0.01));
    });

    test('extracts capital projete a 65 = 485200', () {
      final field = findField(result, 'projected_capital_65');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(485200.0, 0.01));
    });

    test('extracts prestation invalidite = 36800', () {
      final field = findField(result, 'disability_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(36800.0, 0.01));
    });

    test('extracts capital invalidite verse en une fois = 175000', () {
      final field = findField(result, 'disability_capital');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(175000.0, 0.01));
    });

    test('extracts capital-deces = 220500', () {
      final field = findField(result, 'death_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(220500.0, 0.01));
    });

    test('extracts rachat possible = 45000', () {
      final field = findField(result, 'buyback_potential');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(45000.0, 0.01));
    });

    test('extracts cotisation employe = 452.50', () {
      final field = findField(result, 'employee_contribution');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(452.50, 0.01));
    });

    test('extracts cotisation employeur = 543.00', () {
      final field = findField(result, 'employer_contribution');
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
      const text = "Avoir de vieillesse total: CHF 70'377.00";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(70377.0, 0.01));
    });

    test('parses space as thousand separator: 143 287', () {
      const text = "Avoir de vieillesse total: CHF 143 287";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(143287.0, 1.0));
    });

    test('parses comma decimal (Swiss German): 143287,50', () {
      const text = "Altersguthaben total: 143287,50";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(143287.50, 0.01));
    });

    test('parses Fr. prefix', () {
      const text = "Part obligatoire: Fr. 98'400.00";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(98400.0, 0.01));
    });
  });

  // ── German (DE) format certificates ────────────────────────
  group('parseLppCertificate — German format', () {
    test('parses Altersguthaben total (DE)', () {
      const text = "Altersguthaben gesamt: CHF 200'000.00";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(200000.0, 0.01));
    });

    test('parses Obligatorischer Teil (DE)', () {
      const text = "Obligatorischer Teil: CHF 120'000.00";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(120000.0, 0.01));
    });

    test('parses Ueberobligatorischer Teil (DE)', () {
      const text = "Ueberobligatorischer Teil: CHF 80'000.00";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(80000.0, 0.01));
    });

    test('parses Versicherter Lohn (DE)', () {
      const text = "Versicherter Lohn: CHF 85'000.00";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_insured_salary');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(85000.0, 0.01));
    });

    test('parses Einkaufspotential (DE)', () {
      const text = "Einkaufspotential: CHF 539'414.00";
      final result = parseCertificate(text);
      final field = findField(result, 'buyback_potential');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(539414.0, 0.01));
    });

    test('parses annual Invalidenrente (DE)', () {
      const text = "Invalidenrente: CHF 42'000.00 pro Jahr";
      final result = parseCertificate(text);
      final field = findField(result, 'disability_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(42000.0, 0.01));
    });

    test('parses Todesfallkapital (DE)', () {
      const text = "Todesfallkapital: CHF 300'000.00";
      final result = parseCertificate(text);
      final field = findField(result, 'death_coverage');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(300000.0, 0.01));
    });
  });

  // ── Cross-validation: oblig + suroblig ~ total ─────────────
  group('parseLppCertificate — cross-validation', () {
    test('warns when oblig + suroblig does not match total (>5% diff)', () {
      const text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
Part surobligatoire: CHF 20'000.00
""";
      final result = parseCertificate(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('ne correspond pas')),
        isTrue,
      );
    });

    test('no warning when oblig + suroblig matches total within 5%', () {
      const text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
Part surobligatoire: CHF 39'000.00
""";
      final result = parseCertificate(text);
      // 60000 + 39000 = 99000, diff = 1000, tolerance = 5000 => no warning
      expect(
        result.warnings.any((w) => w.contains('ne correspond pas')),
        isFalse,
      );
    });

    test(
        'infers surobligatoire when total and oblig present but suroblig missing',
        () {
      const text = """
Avoir de vieillesse total: CHF 150'000.00
Part obligatoire: CHF 90'000.00
""";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(60000.0, 0.01));
      expect(field.confidence, 0.70);
      expect(field.needsReview, isTrue);
      expect(field.label, contains('déduit'));
    });

    test('warns for unusual conversion rate obligatoire (< 5%)', () {
      const text = "Taux de conversion (obligatoire): 4.50 %";
      final result = parseCertificate(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('inhabituel')),
        isTrue,
      );
    });

    test('warns for unusual conversion rate obligatoire (> 8%)', () {
      const text = "Taux de conversion (obligatoire): 9.00 %";
      final result = parseCertificate(text);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('inhabituel')),
        isTrue,
      );
    });

    test('no warning for legal conversion rate 6.80%', () {
      const text = "Taux de conversion (obligatoire): 6.80 %";
      final result = parseCertificate(text);
      expect(
        result.warnings.any((w) => w.contains('taux de conversion')),
        isFalse,
      );
    });
  });

  // ── Empty / malformed input ────────────────────────────────
  group('parseLppCertificate — edge cases', () {
    test('requires an explicit personal certificate kind marker', () {
      final result = LppCertificateParser.parseLppCertificate(
        'Avoir de vieillesse total: CHF 125\'000',
      );

      expect(result.fields, isEmpty);
    });

    test('certificate title without an individualization label stays empty',
        () {
      final result = LppCertificateParser.parseLppCertificate('''
PLAN BONUS — CERTIFICAT DE PRÉVOYANCE
Avoir de vieillesse total: CHF 125'000
Salaire assuré: CHF 92'000
''');

      expect(result.fields, isEmpty);
      final adapted = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.localParser,
        sourceOverallConfidence: 1,
        fields: result.fields,
      );
      expect(adapted.candidate!.facts, isEmpty);
    });

    test('certificate title plus N° AVS label passes without retaining it', () {
      final result = LppCertificateParser.parseLppCertificate('''
CERTIFICAT DE PRÉVOYANCE
N° AVS:
Avoir de vieillesse total: CHF 125'000
''');

      expect(findField(result, 'lpp_total')!.value, 125000.0);
      expect(
        result.fields.any((field) => field.sourceText.contains('N° AVS')),
        isFalse,
      );
    });

    test('N° d’assuré labels pass without retaining identity text', () {
      for (final label in const ["N° d'assuré:", 'N° d’assuré:']) {
        final result = LppCertificateParser.parseLppCertificate('''
CERTIFICAT DE PRÉVOYANCE
$label
Avoir de vieillesse total: CHF 125'000
''');

        expect(findField(result, 'lpp_total')!.value, 125000.0, reason: label);
        expect(
          result.fields.any(
            (field) =>
                field.sourceText.contains("d'assuré") ||
                field.sourceText.contains('d’assuré'),
          ),
          isFalse,
          reason: label,
        );
      }
    });

    test('frozen German title and standalone assuré(e) labels pass', () {
      final french = LppCertificateParser.parseLppCertificate('''
CERTIFICAT DE PRÉVOYANCE
Assuré(e):
Avoir de vieillesse total: CHF 125'000
''');
      final german = LppCertificateParser.parseLppCertificate('''
VORSORGEBESCHEINIGUNG
Versicherte Person:
Altersguthaben total: CHF 125'000
''');

      expect(findField(french, 'lpp_total')!.value, 125000.0);
      expect(findField(german, 'lpp_total')!.value, 125000.0);
    });

    test('Plan Base and Bonus documents produce no local candidate', () {
      for (final plan in <String>[
        '''PLAN BASE
Avoir de vieillesse total: CHF 125'000
Salaire assuré: CHF 92'000''',
        '''PLAN BONUS
Total des avoirs: CHF 125'000
Rachat maximum: CHF 45'000''',
      ]) {
        final parsed = LppCertificateParser.parseLppCertificate(plan);
        final adapted = LppExtractionAdapter.adapt(
          source: LppAcquisitionSource.localParser,
          sourceOverallConfidence: 1,
          fields: parsed.fields,
        );
        expect(parsed.fields, isEmpty);
        expect(adapted.candidate!.facts, isEmpty);
      }
    });

    test('empty string produces zero fields and zero confidence', () {
      final result = parseCertificate('');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
      expect(result.confidenceDelta, 0.0);
      expect(result.warnings, isEmpty);
      expect(result.documentType, DocumentType.lppCertificate);
    });

    test('random text produces zero fields', () {
      final result = parseCertificate(
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      );
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });

    test('text with only labels but no values produces zero fields', () {
      final result = parseCertificate(
        'Avoir de vieillesse total: \nPart obligatoire: ',
      );
      expect(result.fields, isEmpty);
    });

    test('handles null-like edge case with only whitespace', () {
      final result = parseCertificate('   \n\n  ');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });
  });

  // ── Percentage parsing ─────────────────────────────────────
  group('parseLppCertificate — percentage edge cases', () {
    test('keeps explicit sub-one percent as percentage points at the seam', () {
      final parsed = parseCertificate(
        'Taux de conversion (surobligatoire): 0.50 %',
      );
      final adapted = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.localParser,
        sourceOverallConfidence: 1,
        fields: parsed.fields,
      );

      expect(
        adapted.candidate!
            .factFor(
              LppEvidenceFactKey.extraMandatoryConversionRateRatio,
            )!
            .value,
        closeTo(0.005, 1e-12),
      );
    });

    test('rejects bare percentage values instead of inferring their scale', () {
      final result = parseCertificate(
        'Taux de conversion (surobligatoire): 0.50',
      );

      expect(findField(result, 'conversion_rate_suroblig'), isNull);
    });

    test('parses percentage with comma decimal: 6,80 %', () {
      const text = "Taux de conversion (obligatoire): 6,80 %";
      final result = parseCertificate(text);
      final field = findField(result, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(6.80, 0.01));
    });

    test('parses taux de remuneration', () {
      const text = "Taux de rémunération: 5.00 %";
      final result = parseCertificate(text);
      final field = findField(result, 'remuneration_rate');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(5.0, 0.1));
    });

    test('parses Verzinsung (DE remuneration rate)', () {
      const text = "Verzinsung: 3.50 %";
      final result = parseCertificate(text);
      final field = findField(result, 'remuneration_rate');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(3.50, 0.1));
    });
  });

  group('strict current LPP and amount semantics', () {
    test('generic capital de vieillesse is not a current vested balance', () {
      final generic = parseCertificate(
        'Capital de vieillesse: CHF 480\'000',
      );
      final current = parseCertificate(
        'Avoir de vieillesse total: CHF 125\'000',
      );
      final projected = parseCertificate(
        'Capital de vieillesse projeté à 65: CHF 480\'000',
      );

      expect(findField(generic, 'lpp_total'), isNull);
      expect(findField(current, 'lpp_total')!.value, 125000.0);
      expect(findField(projected, 'lpp_total'), isNull);
      expect(findField(projected, 'projected_capital_65')!.value, 480000.0);
    });

    test('normalizes validated mixed Swiss separators and U+2019', () {
      final german = parseCertificate(
        'Avoir de vieillesse total: CHF 143.287,50',
      );
      final swiss = parseCertificate(
        'Avoir de vieillesse total: CHF 143’287.50',
      );

      expect(findField(german, 'lpp_total')!.value, 143287.50);
      expect(findField(swiss, 'lpp_total')!.value, 143287.50);
    });

    test('malformed multiple separators fail closed', () {
      for (final malformed in <String>[
        'CHF 143.28.7,50',
        'CHF 143,28,7.50',
        'CHF 14\'32\'87.50',
      ]) {
        final result = parseCertificate(
          'Avoir de vieillesse total: $malformed',
        );
        expect(findField(result, 'lpp_total'), isNull, reason: malformed);
      }
    });
  });

  group('strict salary, conversion and buyback semantics', () {
    test('generic conversion rate never becomes mandatory', () {
      final generic = parseCertificate(
        'Taux de conversion: 6.80 %',
      );
      final explicit = parseCertificate(
        'Taux de conversion (obligatoire): 6.80 %',
      );

      expect(findField(generic, 'conversion_rate_oblig'), isNull);
      expect(findField(explicit, 'conversion_rate_oblig')!.value, 6.8);
    });

    test('risk and savings salaries do not select the first row', () {
      final result = parseCertificate('''
Salaire assuré: CHF 92'000 (risque)
Salaire assuré: CHF 76'000 (épargne)
''');

      expect(findField(result, 'lpp_insured_salary'), isNull);
    });

    test('one coordinated or explicit total insured salary remains usable', () {
      final coordinated = parseCertificate(
        'Salaire coordonné: CHF 91\'967',
      );
      final total = parseCertificate(
        'Salaire assuré total: CHF 92\'000',
      );

      expect(findField(coordinated, 'lpp_insured_salary')!.value, 91967.0);
      expect(findField(total, 'lpp_insured_salary')!.value, 92000.0);
    });

    test('early-retirement buybacks stay absent across bounded contexts', () {
      for (final text in <String>[
        'Montant de rachat: CHF 24\'000 — retraite anticipée',
        'Retraite anticipée\nMontant de rachat: CHF 24\'000',
        'Vorzeitige Pensionierung\nEinkaufspotential: CHF 24\'000',
      ]) {
        final result = parseCertificate(text);
        expect(findField(result, 'buyback_potential'), isNull, reason: text);
      }
    });

    test('ordinary buyback wins only when distinct from early-retirement row',
        () {
      final result = parseCertificate('''
Montant de rachat: CHF 24'000 — retraite anticipée
Rachat maximum ordinaire: CHF 51'000
''');

      expect(findField(result, 'buyback_potential')!.value, 51000.0);
    });
  });

  // ── Field confidence & needsReview ─────────────────────────
  group('parseLppCertificate — confidence metadata', () {
    test('CHF-prefixed amount has confidence >= 0.82', () {
      const text = "Avoir de vieillesse total: CHF 143'287.50";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_total');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.82));
      expect(field.needsReview, isFalse);
    });

    test('percentage in reasonable range has confidence >= 0.85', () {
      const text = "Taux de conversion (obligatoire): 6.80 %";
      final result = parseCertificate(text);
      final field = findField(result, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.85));
    });

    test('inferred surobligatoire has needsReview = true', () {
      const text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
""";
      final result = parseCertificate(text);
      final field = findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect(field!.needsReview, isTrue);
    });

    test('fieldsNeedingReview returns only low-confidence fields', () {
      const text = """
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 60'000.00
""";
      final result = parseCertificate(text);
      for (final f in result.fieldsNeedingReview) {
        expect(f.needsReview, isTrue);
      }
    });
  });

  // ── estimateConfidenceDelta with profile ───────────────────
  group('estimateConfidenceDelta', () {
    test('full impact when profile field is null', () {
      final result = parseCertificate(
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
      final result = parseCertificate(
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

  // ── Synthetic CPE-like contract ───────────────────────────
  group('parseLppCertificate — synthetic CPE-like contract', () {
    test('extracts synthetic certificate values', () {
      const text = """
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
      final result = parseCertificate(text);
      expect(findField(result, 'lpp_total')!.value, closeTo(70377.0, 1.0));
      expect(findField(result, 'buyback_potential')!.value,
          closeTo(539414.0, 1.0));
      expect(
          findField(result, 'projected_rente')!.value, closeTo(33892.0, 1.0));
      expect(findField(result, 'projected_capital_65')!.value,
          closeTo(677847.0, 1.0));
      expect(findField(result, 'remuneration_rate')!.value, closeTo(5.0, 0.1));
      expect(result.warnings, isEmpty); // oblig + suroblig == total
    });
  });
}
