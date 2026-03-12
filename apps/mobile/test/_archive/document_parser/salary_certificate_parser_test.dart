import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/salary_certificate_parser.dart';

const _sampleOcrText = '''
FMV SA - Forces Motrices Valaisannes
Bulletin de salaire - Janvier 2026

Nom: Battaglia Julien
Date de naissance: 12.01.1977

Salaire de base:        CHF 9'078.35
Allocations familiales: CHF   200.00
Forfait:                CHF   100.00
Taux d'activité: 100%

Cotisations:
AVS/AI/APG:           - CHF   497.05
AC (chômage):         - CHF   103.17
LPP employé·e:        - CHF   452.00
AANP:                 - CHF    30.00
IJM:                  - CHF    40.65

Salaire net versé:      CHF 8'255.48
''';

void main() {
  group('SalaryCertificateParser', () {
    test('parses sample OCR text — extracts salaire brut', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      expect(result.documentType, DocumentType.salaryCertificate);
      final brut = result.fields.firstWhere((f) => f.fieldName == 'salaire_brut');
      expect(brut.value, closeTo(9078.35, 0.01));
    });

    test('parses sample OCR text — extracts AVS cotisation', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final avs = result.fields.firstWhere((f) => f.fieldName == 'cotisation_avs');
      expect(avs.value, closeTo(497.05, 0.01));
    });

    test('parses sample OCR text — extracts LPP cotisation', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final lpp = result.fields.firstWhere((f) => f.fieldName == 'cotisation_lpp');
      expect(lpp.value, closeTo(452.00, 0.01));
    });

    test('parses sample OCR text — extracts AC cotisation', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final ac = result.fields.firstWhere((f) => f.fieldName == 'cotisation_ac');
      expect(ac.value, closeTo(103.17, 0.01));
    });

    test('parses sample OCR text — extracts salaire net', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final net = result.fields.firstWhere((f) => f.fieldName == 'salaire_net');
      expect(net.value, closeTo(8255.48, 0.01));
    });

    test('parses sample OCR text — extracts taux activité', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final taux = result.fields.firstWhere((f) => f.fieldName == 'taux_activite');
      expect(taux.value, closeTo(100, 0.1));
    });

    test('parses sample OCR text — extracts employer', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final employer = result.fields.firstWhere((f) => f.fieldName == 'employeur');
      expect((employer.value as String).contains('FMV SA'), isTrue);
    });

    test('parses sample OCR text — extracts allocations familiales', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      final allocs = result.fields.firstWhere((f) => f.fieldName == 'allocations_familiales');
      expect(allocs.value, closeTo(200.00, 0.01));
    });

    test('parses German payslip format', () {
      const germanText = '''
Muster AG
Grundlohn:          CHF 7'083.35
Beschäftigungsgrad: 80%
AHV/IV/EO:         - CHF 375.00
ALV:               - CHF  78.00
BVG Arbeitnehmer:  - CHF 380.00
NBU:               - CHF  25.00
Nettolohn:          CHF 6'225.35
''';
      final result = SalaryCertificateParser.parse(germanText);
      final brut = result.fields.firstWhere((f) => f.fieldName == 'salaire_brut');
      expect(brut.value, closeTo(7083.35, 0.01));
      final taux = result.fields.firstWhere((f) => f.fieldName == 'taux_activite');
      expect(taux.value, closeTo(80, 0.1));
      final ahv = result.fields.firstWhere((f) => f.fieldName == 'cotisation_avs');
      expect(ahv.value, closeTo(375.00, 0.01));
      final net = result.fields.firstWhere((f) => f.fieldName == 'salaire_net');
      expect(net.value, closeTo(6225.35, 0.01));
      final employer = result.fields.firstWhere((f) => f.fieldName == 'employeur');
      expect((employer.value as String).contains('AG'), isTrue);
    });

    test('warns when net does not match brut minus deductions', () {
      const inconsistent = "Salaire de base: CHF 10'000.00\nAVS/AI/APG:     - CHF 530.00\nNet versé:       CHF 5'000.00\n";
      final result = SalaryCertificateParser.parse(inconsistent);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('diffère'));
    });

    test('no warning when net is consistent with brut minus deductions', () {
      const consistent = "Salaire de base: CHF 10'000.00\nAVS/AI/APG:     - CHF 530.00\nAC (chômage):   - CHF 110.00\nLPP employé·e:  - CHF 450.00\nNet versé:       CHF 8'910.00\n";
      final result = SalaryCertificateParser.parse(consistent);
      final crossValWarnings = result.warnings.where((w) => w.contains('diffère')).toList();
      expect(crossValWarnings, isEmpty);
    });

    test('warns on unusual activity rate', () {
      const weird = "Salaire de base: CHF 5'000.00\nTaux d'activité: 5%\n";
      final result = SalaryCertificateParser.parse(weird);
      expect(result.warnings.any((w) => w.contains('inhabituel')), isTrue);
    });

    test('confidence is weighted by extraction completeness', () {
      const minimal = "Salaire de base: CHF 8'000.00\nNet versé: CHF 6'500.00\n";
      final result = SalaryCertificateParser.parse(minimal);
      // Minimal text extracts salaire_brut, salaire_net, and employer (heuristic).
      // Average confidence across extracted fields is ~0.80.
      expect(result.overallConfidence, lessThan(0.85));
      expect(result.overallConfidence, greaterThan(0.0));
    });

    test('returns empty result for empty text', () {
      final result = SalaryCertificateParser.parse('');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
      expect(result.warnings, isEmpty);
    });

    test('disclaimer mentions outil éducatif and LSFin', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      expect(result.disclaimer, contains('ducatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources reference LAVS, LPP, LACI', () {
      final result = SalaryCertificateParser.parse(_sampleOcrText);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LACI')), isTrue);
    });

    test('documentType is salaryCertificate', () {
      final result = SalaryCertificateParser.parse('Salaire de base: 5000');
      expect(result.documentType, DocumentType.salaryCertificate);
    });

    test('extracts 13ème salaire', () {
      const text = "Salaire de base: CHF 7'000.00\n13ème salaire: CHF 583.35\nNet versé: CHF 6'200.00\n";
      final result = SalaryCertificateParser.parse(text);
      final treizieme = result.fields.firstWhere((f) => f.fieldName == 'treizieme_salaire');
      expect(treizieme.value, closeTo(583.35, 0.01));
    });

    test('extracts impôt à la source', () {
      const text = "Salaire de base: CHF 7'000.00\nImpôt à la source: - CHF 850.00\nNet versé: CHF 5'500.00\n";
      final result = SalaryCertificateParser.parse(text);
      final impot = result.fields.firstWhere((f) => f.fieldName == 'impot_source');
      expect(impot.value, closeTo(850.00, 0.01));
    });
  });
}
