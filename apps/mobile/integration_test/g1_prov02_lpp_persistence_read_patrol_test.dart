import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
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
const _presentationFactKeys = <LppEvidenceFactKey>{
  LppEvidenceFactKey.retirementPensionAnnualChf,
  LppEvidenceFactKey.retirementCapitalLumpSumChf,
  LppEvidenceFactKey.disabilityPensionAnnualChf,
  LppEvidenceFactKey.disabilityCapitalLumpSumChf,
  LppEvidenceFactKey.deathCapitalLumpSumChf,
};
const _looseLppAnswerKeys = <String>{
  '_coach_avoir_lpp',
  '_coach_avoir_lpp_oblig',
  '_coach_avoir_lpp_suroblig',
  '_coach_salaire_assure',
  '_coach_rachat_maximum',
  '_coach_taux_conversion',
  '_coach_taux_conversion_suroblig',
  '_coach_rendement_caisse',
  '_coach_lpp_source',
  ...legacyPartnerLppAnswerKeys,
};
final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  patrolTest(
    'cold reload validates the 12 strict facts and five presentation facts',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
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
      final answers = provider.reportAnswersSnapshot;
      final rawRoot = answers['_coach_lpp_evidence_v1'];
      expect(rawRoot, isA<String>());
      final persistedRoot = rawRoot as String;
      final root = LppEvidenceRoot.fromJsonString(persistedRoot);
      expect(root, isNotNull);
      expect(root!.manualPartner, isNull);
      expect(root.legacyPartnerQuarantine, isNull);
      final snapshot = LppEvidenceSelector.selectSelf(rawRoot);
      expect(snapshot, isNotNull);
      expect(snapshot!.snapshotId, matches(_uuidV4Pattern));
      expect(snapshot.facts.keys.toSet(), _expectedFacts.keys.toSet());
      expect(
        snapshot.facts.values.map((fact) => fact.updatedAt).toSet(),
        hasLength(1),
      );

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
        expect(persisted.profileOwnerId, matches(_uuidV4Pattern));
        expect(persisted.profileOwnerId, persisted.actorProfileOwnerId);
        expect(
          persisted.authorizationMode,
          LppEvidenceAuthorizationMode.self,
        );
        expect(persisted.authorizationGrantId, isNull);
        expect(persisted.status, LppEvidenceStatus.available);
      }

      final hydratedProfile = profile!;
      for (final key in _presentationFactKeys) {
        final hydrated = hydratedProfile.prevoyance.lppEvidenceFact(key);
        expect(hydrated, isNotNull, reason: key.profilePath);
        expect(hydrated!.value, closeTo(_expectedFacts[key]!, 0.01));
        expect(
          hydratedProfile.dataSources[key.profilePath],
          ProfileDataSource.certificate,
        );
        expect(hydratedProfile.dataTimestamps[key.profilePath], isNotNull);
        expect(
          hydratedProfile.dataSourceDates[key.profilePath],
          DateTime.utc(2025, 12, 31),
        );
        expect(
          hydratedProfile.prevoyance.lppEvidenceStatus(key),
          LppEvidenceStatus.available,
        );
      }

      for (final looseKey in _looseLppAnswerKeys) {
        expect(answers.containsKey(looseKey), isFalse, reason: looseKey);
      }
      final backendSafe = ReportPersistenceService.backendSafeAnswers(answers);
      expect(backendSafe.containsKey('_coach_lpp_evidence_v1'), isFalse);
      expect(
        backendSafe.keys.toSet().intersection(_looseLppAnswerKeys),
        isEmpty,
      );
      expect(jsonDecode(persistedRoot), isA<Map<String, dynamic>>());
      expect(persistedRoot, isNot(contains('"sourceText"')));
      expect(persistedRoot, isNot(contains('"rawOcr"')));
      expect(persistedRoot, isNot(contains('Dupont Marie')));
      expect(persistedRoot, isNot(contains('12345-678')));
      expect(
          persistedRoot,
          isNot(contains(
              'CERTIFICAT DE PREVOYANCE'))); // lint-ignore: synthetic privacy sentinel, not UI copy
    },
  );
}
