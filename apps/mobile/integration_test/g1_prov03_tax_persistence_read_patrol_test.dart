import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'cold reload validates exact tax provenance and canonical selectors',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedTaxProfile = true;
      FeatureFlags.documentTaxAssessmentEnabled = true;
      addTearDown(() {
        FeatureFlags.typedTaxProfile = false;
        FeatureFlags.documentTaxAssessmentEnabled = false;
      });
      await $.pumpWidgetAndSettle(const MintApp());

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final provider =
          $.tester.element(materialApp).read<CoachProfileProvider>();
      await provider.waitForReportAnswers();
      await $.pumpAndSettle();

      final profile = provider.profile;
      expect(profile, isNotNull);
      expect(profile!.fiscal.snapshots, hasLength(1));
      final snapshot = profile.fiscal.snapshots.single;
      expect(snapshot.snapshotId, matches(TaxSnapshot.uuidV4Pattern));
      expect(snapshot.profileOwnerId, matches(TaxSnapshot.uuidV4Pattern));
      expect(snapshot.documentKind, TaxDocumentKind.assessmentNotice);
      expect(snapshot.assessmentStatus, TaxAssessmentStatus.assessedAppealable);
      expect(snapshot.taxYear, 2025);
      expect(snapshot.basedOnTaxYear, isNull);
      expect(snapshot.sourceDate, DateTime.utc(2026, 6, 20));
      expect(snapshot.subjectScope, TaxSubjectScope.individual);
      expect(snapshot.cantonCode, 'VD');
      expect(snapshot.municipalityId, '5586');
      expect(snapshot.municipalityLabel, 'Lausanne');
      expect(snapshot.cantonalCommunalTaxableIncomeChf, 98500);
      expect(snapshot.federalTaxableIncomeChf, 96200);
      expect(snapshot.cantonalCommunalTaxableWealthChf, 245000);
      expect(snapshot.cantonalCommunalAssessedTax?.amountChf, 14520);
      expect(
        snapshot.cantonalCommunalAssessedTax?.authorityScope,
        TaxAuthorityScope.cantonalCommunalCombined,
      );
      expect(
        snapshot.cantonalCommunalAssessedTax?.baseScope,
        TaxBaseScope.incomeAndWealth,
      );
      expect(snapshot.federalDirectAssessedTax?.amountChf, 3840);
      expect(
        snapshot.federalDirectAssessedTax?.authorityScope,
        TaxAuthorityScope.federalDirect,
      );
      expect(
        snapshot.federalDirectAssessedTax?.baseScope,
        TaxBaseScope.incomeOnly,
      );
      expect(snapshot.explicitMarginalIncomeTaxRate, closeTo(0.325, 1e-12));
      expect(snapshot.explicitAverageIncomeTaxRate, closeTo(0.1915, 1e-12));
      expect(
        profile.fiscal.provenanceValidatedSnapshotIds,
        contains(snapshot.snapshotId),
      );

      final prefix = 'fiscal.snapshots.${snapshot.snapshotId}.';
      for (final leaf in const [
        'taxYear',
        'sourceDate',
        'documentKind',
        'assessmentStatus',
        'subjectScope',
        'cantonCode',
        'municipalityId',
        'municipalityLabel',
        'cantonalCommunalTaxableIncomeChf',
        'federalTaxableIncomeChf',
        'cantonalCommunalTaxableWealthChf',
        'cantonalCommunalAssessedTax.amountChf',
        'cantonalCommunalAssessedTax.authorityScope',
        'cantonalCommunalAssessedTax.baseScope',
        'federalDirectAssessedTax.amountChf',
        'federalDirectAssessedTax.authorityScope',
        'federalDirectAssessedTax.baseScope',
        'explicitMarginalIncomeTaxRate',
        'explicitAverageIncomeTaxRate',
      ]) {
        final path = '$prefix$leaf';
        expect(profile.dataSources[path], ProfileDataSource.certificate);
        expect(profile.dataTimestamps[path], isNotNull);
        expect(profile.dataSourceDates[path], DateTime.utc(2026, 6, 20));
      }

      FiscalSelectionResult select(FiscalSnapshotQuery query) =>
          FiscalSnapshotSelector.selectAssessedBaseline(profile.fiscal, query);

      final income = select(
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
          taxYear: 2025,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
        ),
      );
      final cantonalTax = select(
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalAssessedTax,
          taxYear: 2025,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
          authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
          baseScope: TaxBaseScope.incomeAndWealth,
        ),
      );
      final federalTax = select(
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.federalDirectAssessedTax,
          taxYear: 2025,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
          authorityScope: TaxAuthorityScope.federalDirect,
          baseScope: TaxBaseScope.incomeOnly,
        ),
      );
      for (final selection in [income, cantonalTax, federalTax]) {
        expect(selection.status, FiscalSelectionStatus.available);
        expect(selection.snapshot?.snapshotId, snapshot.snapshotId);
        expect(selection.conflictingSnapshotIds, isEmpty);
      }

      final confidence = ConfidenceScorer.score(profile);
      expect(
        confidence.prompts.where(
          (prompt) => prompt.fieldPath == 'fiscal.assessedBaseline',
        ),
        isEmpty,
      );

      final answers = provider.reportAnswersSnapshot;
      expect(answers['_coach_tax_snapshots_v1'], isA<String>());
      expect(
        answers.keys.where(
          (key) =>
              key.startsWith('_coach_tax_') && key != '_coach_tax_snapshots_v1',
        ),
        isEmpty,
      );
      final persistedTax = answers['_coach_tax_snapshots_v1'] as String;
      expect(persistedTax, isNot(contains('Dupont Marie')));
      expect(persistedTax, isNot(contains('123.456.789')));
      expect(persistedTax, isNot(contains('AVIS DE TAXATION')));
    },
  );
}
