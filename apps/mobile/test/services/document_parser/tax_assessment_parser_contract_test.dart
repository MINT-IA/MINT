import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _candidateId = '99999999-9999-4999-8999-999999999999';
const _useDefaultSourceDate = Object();
const _useDefaultCantonalTax = Object();
const _useDefaultFederalTax = Object();

TaxExtractionCandidate _parse(String text) {
  return TaxDeclarationParser.parseTaxDocument(
    text,
    snapshotIdFactory: () => _candidateId,
  );
}

AssessedTaxAmount _validCantonalTax() => AssessedTaxAmount(
      amountChf: 14520,
      authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
      baseScope: TaxBaseScope.incomeAndWealth,
    );

AssessedTaxAmount _validFederalTax() => AssessedTaxAmount(
      amountChf: 3840,
      authorityScope: TaxAuthorityScope.federalDirect,
      baseScope: TaxBaseScope.incomeOnly,
    );

TaxReviewConfirmation _confirmation({
  double? cantonalIncome = 98500,
  double? federalIncome = 96200,
  double? cantonalWealth = 245000,
  Object? cantonalTax = _useDefaultCantonalTax,
  Object? federalTax = _useDefaultFederalTax,
}) {
  return TaxReviewConfirmation(
    candidate: _parse('AVIS DE TAXATION'),
    taxYear: 2025,
    basedOnTaxYear: null,
    sourceDate: DateTime.utc(2026, 6, 20),
    documentKind: TaxDocumentKind.assessmentNotice,
    assessmentStatus: TaxAssessmentStatus.assessedAppealable,
    subjectScope: TaxSubjectScope.individual,
    cantonCode: 'VD',
    municipalityId: '5586',
    municipalityLabel: 'Lausanne',
    cantonalCommunalTaxableIncomeChf: cantonalIncome,
    federalTaxableIncomeChf: federalIncome,
    cantonalCommunalTaxableWealthChf: cantonalWealth,
    cantonalCommunalAssessedTax: identical(
      cantonalTax,
      _useDefaultCantonalTax,
    )
        ? _validCantonalTax()
        : cantonalTax as AssessedTaxAmount?,
    federalDirectAssessedTax: identical(federalTax, _useDefaultFederalTax)
        ? _validFederalTax()
        : federalTax as AssessedTaxAmount?,
    explicitMarginalIncomeTaxRate: 0.325,
    explicitAverageIncomeTaxRate: 0.186,
  );
}

TaxSnapshot _snapshot({
  String snapshotId = _candidateId,
  int? taxYear = 2025,
  double? cantonalIncome = 98500,
  double? federalIncome = 96200,
  double? cantonalWealth = 245000,
  Object? sourceDate = _useDefaultSourceDate,
  TaxSubjectScope subjectScope = TaxSubjectScope.individual,
  String? cantonCode = 'VD',
  Object? cantonalTax = _useDefaultCantonalTax,
  Object? federalTax = _useDefaultFederalTax,
}) {
  return TaxSnapshot(
    snapshotId: snapshotId,
    profileOwnerId: 'self',
    taxYear: taxYear,
    basedOnTaxYear: null,
    sourceDate: identical(sourceDate, _useDefaultSourceDate)
        ? DateTime.utc(2026, 6, 20)
        : sourceDate as DateTime?,
    documentKind: TaxDocumentKind.assessmentNotice,
    assessmentStatus: TaxAssessmentStatus.assessedAppealable,
    subjectScope: subjectScope,
    cantonCode: cantonCode,
    municipalityId: '5586',
    municipalityLabel: 'Lausanne',
    cantonalCommunalTaxableIncomeChf: cantonalIncome,
    federalTaxableIncomeChf: federalIncome,
    cantonalCommunalTaxableWealthChf: cantonalWealth,
    cantonalCommunalAssessedTax: identical(
      cantonalTax,
      _useDefaultCantonalTax,
    )
        ? _validCantonalTax()
        : cantonalTax as AssessedTaxAmount?,
    federalDirectAssessedTax: identical(federalTax, _useDefaultFederalTax)
        ? _validFederalTax()
        : federalTax as AssessedTaxAmount?,
    explicitMarginalIncomeTaxRate: 0.325,
    explicitAverageIncomeTaxRate: 0.186,
    updatedAt: DateTime.utc(2026, 7, 14),
  );
}

FiscalProfile _validatedFiscalProfile(List<TaxSnapshot> snapshots) {
  return FiscalProfile(
    snapshots: snapshots,
    provenanceValidatedSnapshotIds:
        snapshots.map((snapshot) => snapshot.snapshotId).toSet(),
  );
}

void main() {
  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
  });

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

    test('explicit small percentages stay percentages in canonical ratios', () {
      final fixtures = <String, double>{
        "Taux marginal d'imposition: 1 %": 0.01,
        "Taux marginal d'imposition: 0,5 %": 0.005,
      };

      for (final fixture in fixtures.entries) {
        final candidate = _parse(fixture.key);
        expect(
          candidate.explicitMarginalIncomeTaxRate,
          closeTo(fixture.value, 1e-12),
        );
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

  group('typed tax runtime invariants', () {
    test('review confirmation rejects negative taxable wealth', () {
      expect(
        () => _confirmation(cantonalWealth: -1),
        throwsArgumentError,
      );
    });

    test('snapshot rejects negative taxable wealth', () {
      expect(
        () => _snapshot(cantonalWealth: -1),
        throwsArgumentError,
      );
    });

    final reviewNonFiniteBuilders =
        <String, TaxReviewConfirmation Function(double)>{
      'cantonal taxable income': (value) => _confirmation(
            cantonalIncome: value,
          ),
      'federal taxable income': (value) => _confirmation(
            federalIncome: value,
          ),
      'taxable wealth': (value) => _confirmation(
            cantonalWealth: value,
          ),
    };
    for (final field in reviewNonFiniteBuilders.entries) {
      test('review confirmation rejects non-finite ${field.key}', () {
        for (final value in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          expect(
            () => field.value(value),
            throwsArgumentError,
            reason: 'review confirmation accepted ${field.key}=$value',
          );
        }
      });
    }

    final snapshotNonFiniteBuilders = <String, TaxSnapshot Function(double)>{
      'cantonal taxable income': (value) => _snapshot(
            cantonalIncome: value,
          ),
      'federal taxable income': (value) => _snapshot(
            federalIncome: value,
          ),
      'taxable wealth': (value) => _snapshot(
            cantonalWealth: value,
          ),
    };
    for (final field in snapshotNonFiniteBuilders.entries) {
      test('snapshot rejects non-finite ${field.key}', () {
        for (final value in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          expect(
            () => field.value(value),
            throwsArgumentError,
            reason: 'snapshot accepted ${field.key}=$value',
          );
        }
      });
    }

    test('assessed amount rejects a negative value at runtime', () {
      expect(
        () => AssessedTaxAmount(
          amountChf: -1,
          authorityScope: TaxAuthorityScope.federalDirect,
          baseScope: TaxBaseScope.incomeOnly,
        ),
        throwsArgumentError,
      );
    });

    test('assessed amount rejects non-finite values at runtime', () {
      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => AssessedTaxAmount(
            amountChf: value,
            authorityScope: TaxAuthorityScope.federalDirect,
            baseScope: TaxBaseScope.incomeOnly,
          ),
          throwsArgumentError,
          reason: 'assessed amount accepted $value',
        );
      }
    });

    test('review confirmation enforces assessed-tax authority slots', () {
      expect(
        () => _confirmation(
          cantonalTax: AssessedTaxAmount(
            amountChf: 1000,
            authorityScope: TaxAuthorityScope.federalDirect,
            baseScope: TaxBaseScope.incomeOnly,
          ),
        ),
        throwsArgumentError,
      );

      for (final authority in [
        TaxAuthorityScope.communalOnly,
        TaxAuthorityScope.cantonalOnly,
        TaxAuthorityScope.cantonalCommunalCombined,
        TaxAuthorityScope.unknown,
      ]) {
        final amount = AssessedTaxAmount(
          amountChf: 1000,
          authorityScope: authority,
          baseScope: TaxBaseScope.incomeOnly,
        );
        expect(
          () => _confirmation(cantonalTax: amount),
          returnsNormally,
          reason: 'cantonal slot rejected $authority',
        );
      }

      for (final authority in TaxAuthorityScope.values.where(
        (authority) => authority != TaxAuthorityScope.federalDirect,
      )) {
        final amount = AssessedTaxAmount(
          amountChf: 1000,
          authorityScope: authority,
          baseScope: TaxBaseScope.incomeOnly,
        );
        expect(
          () => _confirmation(federalTax: amount),
          throwsArgumentError,
        );
      }
    });

    test('snapshot enforces assessed-tax authority slots', () {
      expect(
        () => _snapshot(
          cantonalTax: AssessedTaxAmount(
            amountChf: 1000,
            authorityScope: TaxAuthorityScope.federalDirect,
            baseScope: TaxBaseScope.incomeOnly,
          ),
        ),
        throwsArgumentError,
      );

      for (final authority in [
        TaxAuthorityScope.communalOnly,
        TaxAuthorityScope.cantonalOnly,
        TaxAuthorityScope.cantonalCommunalCombined,
        TaxAuthorityScope.unknown,
      ]) {
        final amount = AssessedTaxAmount(
          amountChf: 1000,
          authorityScope: authority,
          baseScope: TaxBaseScope.incomeOnly,
        );
        expect(
          () => _snapshot(cantonalTax: amount),
          returnsNormally,
          reason: 'cantonal slot rejected $authority',
        );
      }

      for (final authority in TaxAuthorityScope.values.where(
        (authority) => authority != TaxAuthorityScope.federalDirect,
      )) {
        final amount = AssessedTaxAmount(
          amountChf: 1000,
          authorityScope: authority,
          baseScope: TaxBaseScope.incomeOnly,
        );
        expect(
          () => _snapshot(federalTax: amount),
          throwsArgumentError,
        );
      }
    });

    test('cold provenance accepts only present allowlisted fiscal leaves', () {
      FeatureFlags.typedTaxProfile = true;
      final snapshot = _snapshot(
        federalIncome: null,
        sourceDate: null,
      );
      const prefix = 'fiscal.snapshots.$_candidateId.';
      final envelope = <String, dynamic>{
        'source': ProfileDataSource.certificate.name,
        'updatedAt': DateTime.utc(2026, 7, 14).toIso8601String(),
        'sourceDate': null,
      };
      final profile = CoachProfile.fromWizardAnswers({
        '_coach_tax_snapshots_v1': jsonEncode({
          'schemaVersion': 1,
          'snapshots': [snapshot.toJson()],
          'legacyQuarantine': null,
        }),
        '__provenance': <String, dynamic>{
          '${prefix}taxYear': envelope,
          '${prefix}sourceDate': envelope,
          '${prefix}federalTaxableIncomeChf': envelope,
          '${prefix}snapshotId': envelope,
          '${prefix}profileOwnerId': envelope,
          '${prefix}updatedAt': envelope,
          '${prefix}rawOcr': envelope,
          '${prefix}inventedLeaf': envelope,
          'fiscal.snapshots.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.taxYear':
              envelope,
        },
      });

      expect(
        profile.dataSources.keys.where((path) => path.startsWith('fiscal.')),
        {'${prefix}taxYear', '${prefix}sourceDate'},
      );
    });

    test('legacy quarantine rejects values outside the tax-key namespace', () {
      FeatureFlags.typedTaxProfile = true;
      final snapshot = _snapshot();
      final profile = CoachProfile.fromWizardAnswers({
        '_coach_tax_snapshots_v1': jsonEncode({
          'schemaVersion': 1,
          'snapshots': [snapshot.toJson()],
          'legacyQuarantine': {
            'legacySchemaVersion': 0,
            'reasonCodes': ['untyped_legacy_tax_facts'],
            'values': {'q_canton': 'VD'},
            'quarantinedAt': DateTime.utc(2026, 7, 14).toIso8601String(),
          },
        }),
      });

      expect(profile.fiscal.snapshots, isEmpty);
      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        profile.fiscal,
        const FiscalSnapshotQuery.latestCompleteness(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        ),
      );
      expect(selection.status, FiscalSelectionStatus.partialAsk);
      expect(selection.snapshot, isNull);
    });

    test('snapshot rejects non-canonical non-null canton codes', () {
      for (final cantonCode in ['', '  ', 'XX', 'vd']) {
        expect(
          () => _snapshot(cantonCode: cantonCode),
          throwsArgumentError,
          reason: 'accepted non-canonical canton code "$cantonCode"',
        );
      }
      expect(() => _snapshot(cantonCode: null), returnsNormally);
    });

    test('precise query rejects unresolved context', () {
      for (final build in <FiscalSnapshotQuery Function()>[
        () => FiscalSnapshotQuery.precise(
              requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
              taxYear: 0,
              subjectScope: TaxSubjectScope.individual,
              cantonCode: 'VD',
            ),
        () => FiscalSnapshotQuery.precise(
              requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
              taxYear: 2025,
              subjectScope: TaxSubjectScope.unknown,
              cantonCode: 'VD',
            ),
        () => FiscalSnapshotQuery.precise(
              requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
              taxYear: 2025,
              subjectScope: TaxSubjectScope.individual,
              cantonCode: 'vd',
            ),
      ]) {
        expect(build, throwsArgumentError);
      }
    });

    test(
        'manual and fromJson fiscal profiles stay neutral until snapshot IDs are explicitly validated',
        () {
      FeatureFlags.typedTaxProfile = true;
      final snapshot = _snapshot();
      final query = FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
      );

      final neutralProfiles = [
        FiscalProfile(snapshots: [snapshot]),
        FiscalProfile.fromJson({
          'snapshots': [snapshot.toJson()],
          'legacyDataNeedsReview': false,
        }),
      ];
      for (final fiscal in neutralProfiles) {
        expect(fiscal.provenanceValidatedSnapshotIds, isEmpty);
        final selection = FiscalSnapshotSelector.selectAssessedBaseline(
          fiscal,
          query,
        );
        expect(selection.status, FiscalSelectionStatus.partialAsk);
        expect(selection.snapshot, isNull);
      }

      final validated = _validatedFiscalProfile([snapshot]);
      expect(validated.provenanceValidatedSnapshotIds, {snapshot.snapshotId});
      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        validated,
        query,
      );
      expect(selection.status, FiscalSelectionStatus.available);
      expect(selection.snapshot, snapshot);
    });

    test('latest completeness resolves only one authoritative best context',
        () {
      FeatureFlags.typedTaxProfile = true;
      const query = FiscalSnapshotQuery.latestCompleteness(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      );

      final single = FiscalSnapshotSelector.selectAssessedBaseline(
        _validatedFiscalProfile([_snapshot()]),
        query,
      );
      expect(single.status, FiscalSelectionStatus.available);
      expect(single.snapshot, isNull,
          reason: 'completeness queries expose status, never fiscal values');

      final latest = FiscalSnapshotSelector.selectAssessedBaseline(
        _validatedFiscalProfile([
          _snapshot(
            snapshotId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            taxYear: 2024,
          ),
          _snapshot(
            snapshotId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            taxYear: 2025,
          ),
        ]),
        query,
      );
      expect(latest.status, FiscalSelectionStatus.available);
      expect(latest.snapshot, isNull,
          reason: 'latest completeness must not expose the winning snapshot');

      final conflict = FiscalSnapshotSelector.selectAssessedBaseline(
        _validatedFiscalProfile([
          _snapshot(
            snapshotId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            cantonCode: 'VD',
          ),
          _snapshot(
            snapshotId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            cantonCode: 'BE',
          ),
        ]),
        query,
      );
      expect(conflict.status, FiscalSelectionStatus.partialAsk);
      expect(conflict.conflictingSnapshotIds, hasLength(2));

      for (final snapshot in [
        _snapshot(cantonCode: null),
        _snapshot(subjectScope: TaxSubjectScope.unknown),
      ]) {
        final selection = FiscalSnapshotSelector.selectAssessedBaseline(
          _validatedFiscalProfile([snapshot]),
          query,
        );
        expect(selection.status, FiscalSelectionStatus.partialAsk);
        expect(selection.snapshot, isNull);
      }

      final invalidCantonJson = _snapshot().toJson()..['cantonCode'] = '';
      final cold = CoachProfile.fromWizardAnswers({
        '_coach_tax_snapshots_v1': jsonEncode({
          'schemaVersion': 1,
          'snapshots': [invalidCantonJson],
          'legacyQuarantine': null,
        }),
      });
      final rejectedCold = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.fiscal,
        query,
      );
      expect(rejectedCold.status, FiscalSelectionStatus.partialAsk);
      expect(rejectedCold.snapshot, isNull);
    });
  });
}
