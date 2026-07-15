import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _sourceDate = '2025-12-31';
const _expectedFacts = <LppEvidenceFactKey, double>{
  LppEvidenceFactKey.vestedBenefitsCapitalChf: 143287.50,
  LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: 98400,
  LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: 44887.50,
  LppEvidenceFactKey.insuredSalaryAnnualChf: 72540,
  LppEvidenceFactKey.maximumBuybackCapitalChf: 45000,
  LppEvidenceFactKey.mandatoryConversionRateRatio: 0.068,
  LppEvidenceFactKey.extraMandatoryConversionRateRatio: 0.052,
  LppEvidenceFactKey.retirementPensionAnnualChf: 31450,
  LppEvidenceFactKey.retirementCapitalLumpSumChf: 485200,
  LppEvidenceFactKey.disabilityPensionAnnualChf: 36800,
  LppEvidenceFactKey.disabilityCapitalLumpSumChf: 175000,
  LppEvidenceFactKey.deathCapitalLumpSumChf: 220500,
};

void _expectSnapshot(
  LppEvidenceSnapshot snapshot, {
  required LppEvidenceOwnerKind ownerKind,
}) {
  expect(snapshot.facts.keys.toSet(), _expectedFacts.keys.toSet());
  for (final entry in _expectedFacts.entries) {
    final persisted = snapshot.facts[entry.key];
    expect(persisted, isNotNull, reason: entry.key.wireName);
    final tolerance = entry.key.unit == LppEvidenceUnit.ratio ? 1e-12 : 0.01;
    expect(persisted!.unit, entry.key.unit);
    expect(persisted.value, closeTo(entry.value, tolerance));
    expect(persisted.source, 'certificate');
    expect(persisted.sourceDate, DateTime.utc(2025, 12, 31));
    expect(persisted.ownerKind, ownerKind);
    expect(persisted.authorizationGrantId, isNull);
    expect(
      persisted.authorizationMode,
      ownerKind == LppEvidenceOwnerKind.self
          ? LppEvidenceAuthorizationMode.self
          : LppEvidenceAuthorizationMode.manualPartnerDeclaration,
    );
    expect(
      persisted.profileOwnerId == persisted.actorProfileOwnerId,
      ownerKind == LppEvidenceOwnerKind.self,
    );
  }
}

void main() {
  patrolTest(
    'writes synthetic partner and self LPP facts through gated review',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
      });
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers({
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'marie',
        'q_partner_birth_year': 1982,
        'q_partner_employment_status': 'salarie',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final provider =
          $.tester.element(materialApp).read<CoachProfileProvider>();
      final scanSessions =
          $.tester.element(materialApp).read<ScanSessionProvider>();
      await provider.waitForReportAnswers();
      final profile = provider.profile;
      expect(profile, isNotNull);
      expect(profile!.conjoint, isNotNull);
      expect(profile.conjoint!.invitationLevel, 'declared');

      await $.platformAutomator.mobile.openUrl(
        'mint:///scan?type=lppCertificate',
      );
      await $.pumpAndSettle();

      await $(#document_scan_lpp_type_selector).waitUntilVisible();
      await $(#document_scan_lpp_type_selector).tap();

      // Refusal after choosing the locally declared partner must create
      // neither a volatile session nor durable ledger evidence.
      await $(#document_scan_lpp_example_cta).scrollTo().tap();
      await $(#lpp_acquisition_owner_manual_partner).waitUntilVisible();
      await $(#lpp_acquisition_owner_manual_partner).tap();
      await $(#lpp_acquisition_partner_attestation).waitUntilVisible();
      await $(#lpp_acquisition_cancel).tap();
      await $.pumpAndSettle();
      expect(scanSessions.retainedSessionCount, 0);
      expect(
        provider.reportAnswersSnapshot.containsKey('_coach_lpp_evidence_v1'),
        isFalse,
      );

      // The same checked-in synthetic, PII-free surface exercises the
      // successful manual-partner contract without linking a second account.
      await $(#document_scan_lpp_example_cta).scrollTo().tap();
      await $(#lpp_acquisition_owner_manual_partner).waitUntilVisible();
      await $(#lpp_acquisition_owner_manual_partner).tap();
      await $(#lpp_acquisition_partner_attestation).waitUntilVisible();
      await $(#lpp_acquisition_partner_attest_confirm).tap();
      await $.pumpAndSettle();

      await $(#lpp_review_owner_badge).waitUntilVisible();
      await $(#lpp_review_restart_owner_cta).waitUntilVisible();
      expect(
        find.byKey(const Key('lpp_review_subject_self')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('lpp_review_subject_manual_partner')),
        findsNothing,
      );
      await $(#lpp_review_source_date).waitUntilVisible();
      await $(#lpp_review_source_date).enterText(_sourceDate);
      await $(#lpp_review_confirm_cta).scrollTo().tap();
      await $(find.bySemanticsIdentifier('document_impact_return_cta'))
          .waitUntilExists();

      var rawRoot = provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'];
      expect(rawRoot, isA<String>());
      final manualOwnerId = LppEvidenceSelector.manualPartnerOwnerId(rawRoot);
      expect(manualOwnerId, isNotNull);
      final manualPartner = LppEvidenceSelector.selectManualPartner(
        rawRoot,
        expectedOwnerId: manualOwnerId!,
      );
      expect(manualPartner, isNotNull);
      _expectSnapshot(
        manualPartner!,
        ownerKind: LppEvidenceOwnerKind.manualPartner,
      );

      await $(find.bySemanticsIdentifier('document_impact_return_cta'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle();
      expect(scanSessions.retainedSessionCount, 0);
      expect(
        find.bySemanticsIdentifier('document_impact_return_cta'),
        findsNothing,
      );
      await $.platformAutomator.mobile.openUrl(
        'mint:///scan?type=lppCertificate',
      );
      await $.pumpAndSettle();
      await $(#document_scan_lpp_type_selector).waitUntilVisible();
      await $(#document_scan_lpp_type_selector).tap();
      await $(#document_scan_lpp_example_cta).scrollTo().tap();
      await $(#lpp_acquisition_owner_self).waitUntilVisible();
      await $(#lpp_acquisition_owner_self).tap();
      await $(#lpp_review_owner_badge).waitUntilVisible();
      await $(#lpp_review_source_date).enterText(_sourceDate);
      await $(#lpp_review_confirm_cta).scrollTo().tap();
      final selfImpactCta =
          $(find.bySemanticsIdentifier('document_impact_return_cta'));
      await selfImpactCta.scrollTo();
      await selfImpactCta.waitUntilVisible();

      rawRoot = provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'];
      final self = LppEvidenceSelector.selectSelf(rawRoot);
      expect(self, isNotNull);
      _expectSnapshot(self!, ownerKind: LppEvidenceOwnerKind.self);
      expect(
        LppEvidenceSelector.selectManualPartner(
          rawRoot,
          expectedOwnerId: LppEvidenceSelector.manualPartnerOwnerId(rawRoot)!,
        ),
        isNotNull,
      );

      final persistedRoot = rawRoot as String;
      expect(
        persistedRoot,
        isNot(contains(
          'EXEMPLE SYNTHETIQUE SANS DONNEES PERSONNELLES', // lint-ignore: synthetic privacy sentinel, not UI copy
        )),
      );
    },
  );
}
