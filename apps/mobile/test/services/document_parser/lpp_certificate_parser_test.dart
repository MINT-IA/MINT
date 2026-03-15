import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';

void main() {
  // ────────────────────────────────────────────────────────────
  //  GOLDEN TEST: Julien's CPE certificate (test/golden/Julien/)
  // ────────────────────────────────────────────────────────────
  //
  //  Expected values from CPE Caisse de Pension Energie certificate:
  //
  //  Avoir total (Prestation de sortie):  70'376.60
  //  Part LPP (obligatoire):              30'243.80
  //  Part surobligatoire (déduit):        40'132.80
  //  Salaire déterminant (Base):          122'206.80
  //  Salaire assuré (Base):               91'967.00
  //  Cotisation salarié/an (total):       13'964.40  (4.20 + 91.80 + 0.00 + 13'868.40)
  //  Cotisation employeur/an (total):     15'420.00  (6.00 + 138.00 + 0.00 + 15'276.00)
  //  Taux de rémunération:                5.00%
  //  Capital projeté à 65 (Bonus+Base):   677'847.00  (1'200 + 676'647)
  //  Rente projetée à 65 (Bonus+Base):    33'892.00  (60 + 33'832)
  //  TdC à 65 ans:                        5.00%
  //  Invalidité annuelle (Bonus+Base):    57'576.00  (2'388 + 55'188)
  //  Conjoint annuel (Bonus+Base):        38'388.00  (1'596 + 36'792)
  //  Rachat ordinaire 65:                 539'413.70
  //  Rachat anticipé 58:                  703'066.90
  //  EPL max:                             60'075.25

  late ExtractionResult result;

  setUpAll(() {
    result =
        LppCertificateParser.parseLppCertificate(LppCertificateParser.sampleOcrText);
  });

  group('LPP Certificate Parser — Julien CPE golden test', () {
    test('extracts avoir de vieillesse total = 70376.60', () {
      final field = _findField(result, 'lpp_total');
      expect(field, isNotNull, reason: 'lpp_total not found');
      expect(field!.value, closeTo(70376.60, 1.0));
    });

    test('extracts part obligatoire (LPP) = 30243.80', () {
      final field = _findField(result, 'lpp_obligatoire');
      expect(field, isNotNull, reason: 'lpp_obligatoire not found');
      expect(field!.value, closeTo(30243.80, 1.0));
    });

    test('extracts or infers part surobligatoire = 40132.80', () {
      final field = _findField(result, 'lpp_surobligatoire');
      expect(field, isNotNull, reason: 'lpp_surobligatoire not found');
      expect(field!.value, closeTo(40132.80, 1.0));
    });

    test('obligatoire + surobligatoire = total', () {
      final total = _findField(result, 'lpp_total')!.value as double;
      final oblig = _findField(result, 'lpp_obligatoire')!.value as double;
      final suroblig = _findField(result, 'lpp_surobligatoire')!.value as double;
      expect(oblig + suroblig, closeTo(total, 1.0));
    });

    test('extracts salaire assuré = 91967', () {
      final field = _findField(result, 'lpp_insured_salary');
      expect(field, isNotNull, reason: 'lpp_insured_salary not found');
      expect(field!.value, closeTo(91967.0, 1.0));
    });

    test('extracts salaire déterminant = 122206.80', () {
      final field = _findField(result, 'lpp_determining_salary');
      expect(field, isNotNull, reason: 'lpp_determining_salary not found');
      expect(field!.value, closeTo(122206.80, 1.0));
    });

    test('extracts taux de rémunération = 5.00%', () {
      final field = _findField(result, 'remuneration_rate');
      expect(field, isNotNull, reason: 'remuneration_rate not found');
      expect(field!.value, closeTo(5.0, 0.1));
    });

    test('extracts projected capital at 65 = 677847', () {
      final field = _findField(result, 'projected_capital_65');
      expect(field, isNotNull, reason: 'projected_capital_65 not found');
      expect(field!.value, closeTo(677847.0, 1.0));
    });

    test('extracts projected rente at 65 = 33892', () {
      final field = _findField(result, 'projected_rente');
      expect(field, isNotNull, reason: 'projected_rente not found');
      expect(field!.value, closeTo(33892.0, 1.0));
    });

    test('extracts TdC at 65 = 5.00%', () {
      final field = _findField(result, 'conversion_rate_at_65');
      expect(field, isNotNull, reason: 'conversion_rate_at_65 not found');
      expect(field!.value, closeTo(5.0, 0.1));
    });

    test('extracts rente invalidité = 57576', () {
      final field = _findField(result, 'disability_coverage');
      expect(field, isNotNull, reason: 'disability_coverage not found');
      expect(field!.value, closeTo(57576.0, 1.0));
    });

    test('extracts rente conjoint = 38388', () {
      final field = _findField(result, 'death_coverage');
      expect(field, isNotNull, reason: 'death_coverage not found');
      expect(field!.value, closeTo(38388.0, 1.0));
    });

    test('extracts rachat ordinaire 65 = 539413.70', () {
      final field = _findField(result, 'buyback_potential');
      expect(field, isNotNull, reason: 'buyback_potential not found');
      expect(field!.value, closeTo(539413.70, 1.0));
    });

    test('extracts rachat anticipé 58 = 703066.90', () {
      final field = _findField(result, 'buyback_early_retirement');
      expect(field, isNotNull, reason: 'buyback_early_retirement not found');
      expect(field!.value, closeTo(703066.90, 1.0));
    });

    test('extracts EPL max = 60075.25', () {
      final field = _findField(result, 'epl_max');
      expect(field, isNotNull, reason: 'epl_max not found');
      expect(field!.value, closeTo(60075.25, 1.0));
    });

    test('extracts cotisation salarié annuelle', () {
      final field = _findField(result, 'employee_contribution');
      expect(field, isNotNull, reason: 'employee_contribution not found');
      // 4.20 + 91.80 + 0.00 + 13'868.40 = 13'964.40
      expect(field!.value, closeTo(13964.40, 5.0));
    });

    test('extracts cotisation employeur annuelle', () {
      final field = _findField(result, 'employer_contribution');
      expect(field, isNotNull, reason: 'employer_contribution not found');
      // 6.00 + 138.00 + 0.00 + 15'276.00 = 15'420.00
      expect(field!.value, closeTo(15420.0, 5.0));
    });

    test('overall confidence > 0.80', () {
      expect(result.overallConfidence, greaterThan(0.80));
    });

    test('confidence delta > 20 points', () {
      expect(result.confidenceDelta, greaterThan(20.0));
    });

    test('has compliance disclaimer', () {
      expect(result.disclaimer, contains('éducatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('has legal sources', () {
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
    });

    test('document type is lppCertificate', () {
      expect(result.documentType, equals(DocumentType.lppCertificate));
    });

    test('extracts at least 15 fields from Julien certificate', () {
      expect(result.fieldCount, greaterThanOrEqualTo(15));
    });
  });

  // ── Standard format backward compatibility ──
  group('LPP Certificate Parser — standard single-column format', () {
    late ExtractionResult standardResult;

    setUpAll(() {
      standardResult = LppCertificateParser.parseLppCertificate(_standardSampleText);
    });

    test('extracts avoir total from standard format', () {
      final field = _findField(standardResult, 'lpp_total');
      expect(field, isNotNull);
      expect(field!.value, closeTo(143287.50, 1.0));
    });

    test('extracts part obligatoire from standard format', () {
      final field = _findField(standardResult, 'lpp_obligatoire');
      expect(field, isNotNull);
      expect(field!.value, closeTo(98400.0, 1.0));
    });

    test('extracts part surobligatoire from standard format', () {
      final field = _findField(standardResult, 'lpp_surobligatoire');
      expect(field, isNotNull);
      expect(field!.value, closeTo(44887.50, 1.0));
    });

    test('extracts conversion rate obligatoire from standard format', () {
      final field = _findField(standardResult, 'conversion_rate_oblig');
      expect(field, isNotNull);
      expect(field!.value, closeTo(6.80, 0.1));
    });

    test('extracts rachat from standard format', () {
      final field = _findField(standardResult, 'buyback_potential');
      expect(field, isNotNull);
      expect(field!.value, closeTo(45000.0, 1.0));
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────

ExtractedField? _findField(ExtractionResult result, String fieldName) {
  try {
    return result.fields.firstWhere((f) => f.fieldName == fieldName);
  } catch (_) {
    return null;
  }
}

// ── Standard single-column certificate format (backward compat) ──
const String _standardSampleText = """
CERTIFICAT DE PREVOYANCE 2025
Caisse de pension XY — Fondation collective LPP

Nom: Dupont Marie
Date de naissance: 15.03.1988
No. assuré: 12345-678

AVOIR DE VIEILLESSE
Avoir de vieillesse total:                    CHF 143'287.50
  Part obligatoire:                            CHF 98'400.00
  Part surobligatoire:                         CHF 44'887.50

SALAIRE ET COTISATIONS
Salaire assuré:                                CHF 72'540.00
Taux de bonification de vieillesse:            15.0 %
Cotisation de l'employé mensuelle:             CHF 452.50
Cotisation de l'employeur mensuelle:           CHF 543.00

TAUX DE CONVERSION
Taux de conversion (obligatoire):              6.80 %
Taux de conversion (surobligatoire):           5.20 %

PRESTATIONS PROJETEES A 65 ANS
Rente de vieillesse projetée:                  CHF 31'450.00 / an
Capital de vieillesse projeté à 65:            CHF 485'200.00

PRESTATIONS DE RISQUE
Prestation d'invalidité:                       CHF 36'800.00 / an
Capital-décès:                                 CHF 220'500.00

RACHAT
Rachat possible (montant maximum):             CHF 45'000.00
""";
