import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
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

void main() {
  patrolTest(
    'writes the 12 synthetic typed LPP facts through scan review and impact',
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
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl(
        'mint:///scan?type=lppCertificate',
      );
      await $.pumpAndSettle();

      await $(#document_scan_lpp_type_selector).waitUntilVisible();
      await $(#document_scan_lpp_type_selector).tap();
      await $(#document_scan_lpp_example_cta).scrollTo().tap();
      await $.pumpAndSettle();

      await $(#lpp_review_source_date).waitUntilVisible();
      await $(#lpp_review_source_date).enterText(_sourceDate);
      await $(#lpp_review_confirm_cta).scrollTo().tap();
      await $(#lpp_review_subject_self).waitUntilVisible();
      await $(#lpp_review_subject_self).tap();
      await $(find.bySemanticsIdentifier('document_impact_return_cta'))
          .waitUntilExists();

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final provider =
          $.tester.element(materialApp).read<CoachProfileProvider>();
      final profile = provider.profile;
      expect(profile, isNotNull);
      final rawRoot = provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'];
      expect(rawRoot, isA<String>());
      final snapshot = LppEvidenceSelector.selectSelf(rawRoot);
      expect(snapshot, isNotNull);
      expect(snapshot!.facts.keys.toSet(), _expectedFacts.keys.toSet());

      for (final entry in _expectedFacts.entries) {
        final persisted = snapshot.facts[entry.key];
        expect(persisted, isNotNull, reason: entry.key.wireName);
        final tolerance =
            entry.key.unit == LppEvidenceUnit.ratio ? 1e-12 : 0.01;
        expect(persisted!.unit, entry.key.unit);
        expect(persisted.value, closeTo(entry.value, tolerance));
        expect(persisted.source, 'certificate');
        expect(persisted.sourceDate, DateTime.utc(2025, 12, 31));
        expect(persisted.ownerKind, LppEvidenceOwnerKind.self);
        expect(persisted.profileOwnerId, persisted.actorProfileOwnerId);

        final hydrated = profile!.prevoyance.lppEvidenceFact(entry.key);
        expect(hydrated, isNotNull, reason: entry.key.profilePath);
        expect(hydrated!.unit, entry.key.unit);
        expect(hydrated.value, closeTo(entry.value, tolerance));
        expect(
          profile.prevoyance.lppEvidenceStatus(entry.key),
          LppEvidenceStatus.available,
        );
      }

      final persistedRoot = rawRoot as String;
      expect(persistedRoot, isNot(contains('Dupont Marie')));
      expect(persistedRoot, isNot(contains('12345-678')));
      expect(
          persistedRoot,
          isNot(contains(
              'CERTIFICAT DE PREVOYANCE'))); // lint-ignore: synthetic privacy sentinel, not UI copy
    },
  );
}
