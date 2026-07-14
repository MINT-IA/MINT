import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';

const _candidateId = '99999999-9999-4999-8999-999999999999';

TaxExtractionCandidate _parse(String text) {
  return TaxDeclarationParser.parseTaxDocument(
    text,
    snapshotIdFactory: () => _candidateId,
  );
}

void main() {
  group('typed document classification', () {
    test('distinguishes every supported document kind and safe default status',
        () {
      final fixtures = <String, (TaxDocumentKind, TaxAssessmentStatus)>{
        '''
AVIS DE TAXATION
Période fiscale 2025
Décision susceptible de réclamation
''': (
          TaxDocumentKind.assessmentNotice,
          TaxAssessmentStatus.assessedAppealable,
        ),
        '''
DÉCLARATION D'IMPÔT 2025
Formulaire rempli par le contribuable
''': (
          TaxDocumentKind.taxpayerReturn,
          TaxAssessmentStatus.selfDeclared,
        ),
        '''
BORDEREAU PROVISOIRE IFD 2025
Calculé sur la base de la taxation 2024
''': (
          TaxDocumentKind.provisionalBill,
          TaxAssessmentStatus.provisional,
        ),
        '''
BORDEREAU FINAL 2025
Facture après décompte des acomptes
''': (
          TaxDocumentKind.finalTaxBill,
          TaxAssessmentStatus.unknown,
        ),
        'RELEVÉ FISCAL SANS QUALIFICATION': (
          TaxDocumentKind.unknown,
          TaxAssessmentStatus.unknown,
        ),
      };

      for (final fixture in fixtures.entries) {
        final candidate = _parse(fixture.key);
        expect(candidate.documentKind, fixture.value.$1);
        expect(candidate.assessmentStatus, fixture.value.$2);
      }
    });

    test('extracts period, basis, source date, tax unit and jurisdiction', () {
      final candidate = _parse('''
AVIS DE TAXATION
Période fiscale: 2025
Émis le: 20.06.2026
Taxation commune des époux
Canton: VD
Commune: Lausanne
No OFS commune: 5586
''');

      expect(candidate.taxYear, 2025);
      expect(candidate.basedOnTaxYear, isNull);
      expect(candidate.sourceDate, DateTime.utc(2026, 6, 20));
      expect(candidate.subjectScope, TaxSubjectScope.jointlyAssessedCouple);
      expect(candidate.cantonCode, 'VD');
      expect(candidate.municipalityId, '5586');
      expect(candidate.municipalityLabel, 'Lausanne');

      final provisional = _parse('''
BORDEREAU PROVISOIRE IFD
Période fiscale: 2025
Calculé sur la base de la taxation 2024
Date d'émission: 05.02.2026
''');
      expect(provisional.taxYear, 2025);
      expect(provisional.basedOnTaxYear, 2024);
      expect(provisional.sourceDate, DateTime.utc(2026, 2, 5));
    });

    test('classifies the German document vocabulary without upgrading it', () {
      final fixtures = <String, (TaxDocumentKind, TaxAssessmentStatus)>{
        'VERANLAGUNGSVERFÜGUNG 2025, Einsprachefrist 30 Tage': (
          TaxDocumentKind.assessmentNotice,
          TaxAssessmentStatus.assessedAppealable,
        ),
        'STEUERERKLÄRUNG 2025, Angaben der steuerpflichtigen Person': (
          TaxDocumentKind.taxpayerReturn,
          TaxAssessmentStatus.selfDeclared,
        ),
        'PROVISORISCHE STEUERRECHNUNG 2025': (
          TaxDocumentKind.provisionalBill,
          TaxAssessmentStatus.provisional,
        ),
        'SCHLUSSRECHNUNG 2025, Akontozahlungen abgerechnet': (
          TaxDocumentKind.finalTaxBill,
          TaxAssessmentStatus.unknown,
        ),
        'STEUERDOKUMENT OHNE QUALIFIKATION': (
          TaxDocumentKind.unknown,
          TaxAssessmentStatus.unknown,
        ),
      };

      for (final fixture in fixtures.entries) {
        final candidate = _parse(fixture.key);
        expect(candidate.documentKind, fixture.value.$1);
        expect(candidate.assessmentStatus, fixture.value.$2);
      }
    });
  });

  group('typed values preserve Swiss fiscal meaning', () {
    test('keeps ICC and IFD taxable incomes and assessed taxes distinct', () {
      final candidate = _parse('''
AVIS DE TAXATION
Période fiscale: 2025
Revenu imposable ICC: CHF 98'500.00
Revenu imposable IFD: CHF 96'200.00
Fortune imposable ICC: CHF 245'000.00
Impôt cantonal et communal, revenu et fortune: CHF 14'520.00
Impôt fédéral direct sur le revenu: CHF 3'840.00
Taux marginal d'imposition: 32.5 %
''');

      expect(candidate.cantonalCommunalTaxableIncomeChf, 98500);
      expect(candidate.federalTaxableIncomeChf, 96200);
      expect(candidate.cantonalCommunalTaxableWealthChf, 245000);
      expect(candidate.cantonalCommunalAssessedTax!.amountChf, 14520);
      expect(
        candidate.cantonalCommunalAssessedTax!.authorityScope,
        TaxAuthorityScope.cantonalCommunalCombined,
      );
      expect(
        candidate.cantonalCommunalAssessedTax!.baseScope,
        TaxBaseScope.incomeAndWealth,
      );
      expect(candidate.federalDirectAssessedTax!.amountChf, 3840);
      expect(
        candidate.federalDirectAssessedTax!.authorityScope,
        TaxAuthorityScope.federalDirect,
      );
      expect(candidate.explicitMarginalIncomeTaxRate, closeTo(0.325, 1e-9));
    });

    test(
        'cantonal-only and combined ICC amounts keep different authority scope',
        () {
      final cantonalOnly = _parse(
        "Impôt cantonal sur le revenu: CHF 10'000.00",
      );
      final combined = _parse(
        "Impôt cantonal et communal sur le revenu: CHF 14'520.00",
      );

      expect(
        cantonalOnly.cantonalCommunalAssessedTax!.authorityScope,
        TaxAuthorityScope.cantonalOnly,
      );
      expect(
        combined.cantonalCommunalAssessedTax!.authorityScope,
        TaxAuthorityScope.cantonalCommunalCombined,
      );
    });

    test('average and effective labels map only to an average ratio', () {
      final fixtures = <String, double>{
        "Taux moyen d'imposition: 22.3 %": 0.223,
        'Effektiver Steuersatz: 19,4 %': 0.194,
      };

      for (final fixture in fixtures.entries) {
        final candidate = _parse(fixture.key);
        expect(
          candidate.explicitAverageIncomeTaxRate,
          closeTo(fixture.value, 1e-9),
        );
        expect(candidate.explicitMarginalIncomeTaxRate, isNull);
      }
    });

    test('computed tax-to-income ratio populates neither canonical rate', () {
      final candidate = _parse('''
Revenu imposable ICC: CHF 100'000.00
Revenu imposable IFD: CHF 100'000.00
Impôt cantonal et communal: CHF 15'000.00
Impôt fédéral direct: CHF 5'000.00
''');

      expect(candidate.explicitMarginalIncomeTaxRate, isNull);
      expect(candidate.explicitAverageIncomeTaxRate, isNull);
    });

    test('negative net wealth is not promoted to taxable wealth', () {
      final candidate = _parse("Reinvermögen: CHF -25'000.00");
      expect(candidate.cantonalCommunalTaxableWealthChf, isNull);
    });
  });
}
