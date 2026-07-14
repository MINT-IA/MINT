import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'writes one synthetic typed tax assessment through the real scan review',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedTaxProfile = true;
      FeatureFlags.documentTaxAssessmentEnabled = true;
      addTearDown(() {
        FeatureFlags.typedTaxProfile = false;
        FeatureFlags.documentTaxAssessmentEnabled = false;
      });
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///scan');
      await $.pumpAndSettle();

      await $(#document_scan_tax_type_selector).waitUntilVisible();
      await $(#document_scan_tax_type_selector).tap();
      await $(#document_scan_tax_example_cta).scrollTo().tap();
      await $.pumpAndSettle();

      await $(#tax_review_back_cta).waitUntilVisible();

      await $(#tax_review_subject_scope).scrollTo().tap();
      await $(#tax_review_subject_scope_individual).tap();
      await $(#tax_review_source_date).scrollTo().enterText('2026-06-20');
      await $(#tax_review_canton_code).scrollTo().enterText('VD');
      await $(#tax_review_municipality_id).scrollTo().enterText('5586');
      await $(#tax_review_municipality_label).scrollTo().enterText('Lausanne');
      await $(#tax_review_cantonal_communal_taxable_income_chf)
          .scrollTo()
          .enterText('98500');
      await $(#tax_review_federal_taxable_income_chf)
          .scrollTo()
          .enterText('96200');
      await $(#tax_review_cantonal_communal_taxable_wealth_chf)
          .scrollTo()
          .enterText('245000');

      await $(#tax_review_cantonal_base_scope).scrollTo().tap();
      await $(#tax_review_cantonal_base_scope_income_and_wealth).tap();
      await $(#tax_review_federal_base_scope).scrollTo().tap();
      await $(#tax_review_federal_base_scope_income_only).tap();

      await $(#tax_review_confirm_cta).scrollTo().tap();
      await $(find.bySemanticsIdentifier('document_impact_return_cta'))
          .waitUntilVisible();

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final provider =
          $.tester.element(materialApp).read<CoachProfileProvider>();
      final profile = provider.profile;
      expect(profile, isNotNull);
      expect(profile!.fiscal.snapshots, hasLength(1));
      final snapshot = profile.fiscal.snapshots.single;
      expect(snapshot.snapshotId, matches(TaxSnapshot.uuidV4Pattern));
      expect(snapshot.documentKind, TaxDocumentKind.assessmentNotice);
      expect(snapshot.assessmentStatus, TaxAssessmentStatus.assessedAppealable);
      expect(snapshot.taxYear, 2025);
      expect(snapshot.sourceDate, DateTime.utc(2026, 6, 20));
      expect(snapshot.subjectScope, TaxSubjectScope.individual);
      expect(snapshot.cantonCode, 'VD');
      expect(snapshot.municipalityId, '5586');
      expect(snapshot.municipalityLabel, 'Lausanne');
      expect(snapshot.cantonalCommunalTaxableIncomeChf, 98500);
      expect(snapshot.federalTaxableIncomeChf, 96200);
      expect(snapshot.cantonalCommunalTaxableWealthChf, 245000);
      expect(snapshot.cantonalCommunalAssessedTax?.amountChf, 14520);
      expect(snapshot.federalDirectAssessedTax?.amountChf, 3840);
      expect(
        profile.fiscal.provenanceValidatedSnapshotIds,
        contains(snapshot.snapshotId),
      );
      expect(
        provider.reportAnswersSnapshot['_coach_tax_snapshots_v1'],
        isA<String>(),
      );
    },
  );
}
