import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/account_session_bootstrap.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/g1_ret_ref_lpp_capital_notice_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _replacementAcquisitionId = '71717171-7171-4171-8171-717171717171';
const _replacementMarker =
    '%PDF-1.7 MINT capital-notice invalidation synthetic bytes only';

LppReviewConfirmation _replacementReview(DateTime now) {
  final bytes = Uint8List.fromList(utf8.encode(_replacementMarker));
  return LppReviewConfirmation(
    authorization: LppAcquisitionAuthorization(
      acquisitionId: _replacementAcquisitionId,
      subject: LppEvidenceOwnerKind.self,
      partnerAttested: false,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: now.subtract(const Duration(minutes: 5)),
      documentSha256: LppAcquisitionAuthorization.sha256Hex(bytes),
    ),
    sourceDate: DateTime.utc(now.year, now.month, now.day),
    facts: const <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
        value: 151000,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
        value: 74800,
        unit: LppEvidenceUnit.chfPerYear,
      ),
    },
  );
}

void main() {
  patrolTest(
    'cold reader proves capital dossier, PDF, recovery, and invalidations',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
      FeatureFlags.lppRegulationReferenceEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
        FeatureFlags.lppRegulationReferenceEnabled = false;
      });

      final now = DateTime.now().toUtc();
      final preferences = await SharedPreferences.getInstance();
      final writerPid = preferences.getInt(g1LppCapitalNoticeWriterPidKey);
      expect(writerPid, isNotNull);
      expect(pid, isNot(writerPid));
      if (writerPid == null || writerPid <= 0 || writerPid == pid) {
        fail('Reader did not cross the required writer process boundary');
      }
      addTearDown(() async {
        await preferences.remove(g1LppCapitalNoticeWriterPidKey);
      });

      final originalAnswers = await ReportPersistenceService.loadAnswers();
      final originalStrictRootJson = originalAnswers['_coach_lpp_evidence_v1'];
      if (originalStrictRootJson is! String) {
        fail('Missing strict LPP root before provider hydration');
      }
      final persistedRoot = LppEvidenceRoot.fromJsonString(
        originalStrictRootJson,
        now: () => now,
      );
      if (persistedRoot == null || persistedRoot.self == null) {
        fail('Missing numeric self LPP root before provider hydration');
      }
      final persistedCapital = persistedRoot.self!.lppCapitalNoticeDeadline;
      final persistedRegulation = persistedRoot.selfRegulationReference;
      if (persistedCapital == null || persistedRegulation == null) {
        fail('Missing capital or regulation authority before hydration');
      }
      expect(
        persistedCapital.authorityReferenceId,
        persistedRegulation.referenceId,
      );
      expect(persistedCapital.sourceDate, persistedRegulation.sourceDate);
      expect(persistedCapital.legalYear, persistedRegulation.legalYear);

      final referenceStore = DocumentReferenceStore();
      final originalDocumentReferences = await referenceStore.load();
      final regulationReferenceIndex = originalDocumentReferences.indexWhere(
        (stored) =>
            stored.referenceId == persistedRegulation.referenceId &&
            stored.kind == ConfirmedDocumentReference.lppRegulationKind,
      );
      final capitalReferenceIndex = originalDocumentReferences.indexWhere(
        (stored) =>
            stored.referenceId == persistedCapital.referenceId &&
            stored.kind == ConfirmedDocumentReference.lppCapitalNoticeKind,
      );
      expect(regulationReferenceIndex, greaterThanOrEqualTo(0));
      expect(capitalReferenceIndex, greaterThan(regulationReferenceIndex));

      await $.pumpWidgetAndSettle(const MintApp());
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final appContext = $.tester.element(materialApp);
      final bootstrap = appContext.read<AccountSessionBootstrap>();
      await bootstrap.start();
      final provider = appContext.read<CoachProfileProvider>();
      final documents = appContext.read<DocumentProvider>();
      await provider.waitForReportAnswers();
      documents.bindLedger(provider);
      await documents.hydrateReferences();
      await $.pumpAndSettle();

      final currentSnapshot = LppEvidenceSelector.selectSelf(
        provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'],
        now: () => now,
      );
      expect(currentSnapshot, isNotNull);
      if (currentSnapshot == null) fail('Missing cold numeric LPP snapshot');
      final candidate = provider.profile!.lppCapitalNoticeDeadline;
      expect(candidate, isNotNull);
      final resolved = documents.resolveLppCapitalNotice(candidate);
      expect(resolved, isNotNull);
      final regulationCandidate = provider.profile!.lppRegulationReference;
      expect(regulationCandidate, isNotNull);
      final resolvedRegulation = documents.resolveLppRegulation(
        regulationCandidate,
      );
      expect(resolvedRegulation, isNotNull);
      final reference = documents.byId(candidate!.referenceId);
      expect(reference, isNotNull);
      expect(reference!.referenceId, candidate.referenceId);
      expect(reference.snapshotId, currentSnapshot.snapshotId);
      expect(reference.confirmedAt, candidate.confirmedAt);
      expect(reference.kind, LppCapitalNoticeDeadline.kind);
      expect(reference.ownerKind, LppEvidenceOwnerKind.self);
      expect(resolved!.sourceDate, candidate.sourceDate);
      expect(resolved.legalYear, candidate.legalYear);
      expect(resolved.deadlineDate, candidate.deadlineDate);

      Future<void> expectReport({
        required bool hasCapitalHandoff,
        required bool hasRegulationHandoff,
      }) async {
        testOnlyRootRouter.go('/rapport');
        await $.pumpAndSettle();
        await $(find.bySemanticsIdentifier('financial_report_screen'))
            .waitUntilVisible();
        final capitalHandoff = find.bySemanticsIdentifier(
          'financial_report_lpp_capital_notice_handoff',
        );
        final regulationHandoff = find.bySemanticsIdentifier(
          'financial_report_lpp_regulation_handoff',
        );
        expect(
          capitalHandoff,
          hasCapitalHandoff ? findsOneWidget : findsNothing,
        );
        expect(
          regulationHandoff,
          hasRegulationHandoff ? findsOneWidget : findsNothing,
        );
        if (hasCapitalHandoff && hasRegulationHandoff) {
          final capitalPosition = $.tester.getTopLeft(capitalHandoff);
          final regulationPosition = $.tester.getTopLeft(regulationHandoff);
          expect(capitalPosition.dy, lessThan(regulationPosition.dy));
        }
      }

      testOnlyRootRouter.go('/retraite');
      await $.pumpAndSettle();
      await $(find.bySemanticsIdentifier(
        'retirement_lpp_capital_notice_deadline_education',
      )).waitUntilVisible();
      await expectReport(
        hasCapitalHandoff: true,
        hasRegulationHandoff: true,
      );

      final capitalHandoff =
          LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
        capitalNoticeEvidence: resolved,
        regulationEvidence: resolvedRegulation,
      );
      final regulationHandoff = LppRegulationSpecialistHandoff.tryFromEvidence(
        resolvedRegulation,
      );
      expect(capitalHandoff, isNotNull);
      expect(regulationHandoff, isNotNull);
      final report = FinancialReportService().generateReport(
        provider.reportAnswersSnapshot,
        lppCapitalNoticeHandoff: capitalHandoff,
        lppRegulationHandoff: regulationHandoff,
      );
      final reportContext = $.tester.element(
        find.bySemanticsIdentifier('financial_report_screen'),
      );
      final pdfBytes = await PdfService.buildFinancialReportPdfBytes(
        report,
        l: S.of(reportContext)!,
      );
      expect(pdfBytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);
      expect(pdfBytes.length, greaterThan(1000));

      try {
        final missingCapitalReferences = originalDocumentReferences
            .where((stored) => stored.referenceId != candidate.referenceId)
            .toList(growable: false);
        await referenceStore.save(missingCapitalReferences);
        documents.clearLocalState();
        await documents.hydrateReferences();
        await $.pumpAndSettle();
        expect(documents.resolveLppCapitalNotice(candidate), isNull);
        expect(
          documents.resolveLppRegulation(
            provider.profile!.lppRegulationReference,
          ),
          isNotNull,
        );
        await expectReport(
          hasCapitalHandoff: false,
          hasRegulationHandoff: true,
        );

        final mismatchedCapitalReferences = originalDocumentReferences
            .map(
              (stored) => stored.referenceId == candidate.referenceId
                  ? ConfirmedDocumentReference(
                      referenceId: stored.referenceId,
                      kind: stored.kind,
                      snapshotId: stored.snapshotId,
                      ownerKind: stored.ownerKind,
                      confirmedAt:
                          stored.confirmedAt.add(const Duration(seconds: 1)),
                    )
                  : stored,
            )
            .toList(growable: false);
        await referenceStore.save(mismatchedCapitalReferences);
        documents.clearLocalState();
        await documents.hydrateReferences();
        await $.pumpAndSettle();
        expect(documents.resolveLppCapitalNotice(candidate), isNull);
        expect(
          documents.resolveLppRegulation(
            provider.profile!.lppRegulationReference,
          ),
          isNotNull,
        );
        await expectReport(
          hasCapitalHandoff: false,
          hasRegulationHandoff: true,
        );

        await referenceStore.save(
          List<ConfirmedDocumentReference>.of(originalDocumentReferences),
        );
        documents.clearLocalState();
        await documents.hydrateReferences();
        final legacyRoot = LppEvidenceRoot(
          self: persistedRoot.self,
          manualPartner: persistedRoot.manualPartner,
          legacyPartnerQuarantine: persistedRoot.legacyPartnerQuarantine,
          selfRegulationReference: null,
          selfRegulationRecoveryReason:
              LppRegulationRecoveryReason.legacyMissingFundRelationship,
        );
        final legacyAnswers = Map<String, dynamic>.from(originalAnswers)
          ..['_coach_lpp_evidence_v1'] = legacyRoot.toJsonString();
        await ReportPersistenceService.saveLppEvidenceAnswers(legacyAnswers);
        await provider.loadFromWizard();
        await $.pumpAndSettle();
        expect(provider.profile?.lppRegulationReference, isNull);
        expect(
          provider.lppRegulationRecoveryReason,
          LppRegulationRecoveryReason.legacyMissingFundRelationship,
        );
        expect(
          documents.resolveLppCapitalNotice(
            provider.profile?.lppCapitalNoticeDeadline,
          ),
          isNull,
        );
        expect(
          documents.resolveLppRegulation(
            provider.profile?.lppRegulationReference,
          ),
          isNull,
        );
        await expectReport(
          hasCapitalHandoff: false,
          hasRegulationHandoff: false,
        );
      } finally {
        await referenceStore.save(originalDocumentReferences);
        await ReportPersistenceService.saveLppEvidenceAnswers(originalAnswers);
        documents.clearLocalState();
        await documents.hydrateReferences();
        await provider.loadFromWizard();
        await $.pumpAndSettle();
        final restoredDocumentReferences = await referenceStore.load();
        expect(
          restoredDocumentReferences
              .map((stored) => stored.toJson())
              .toList(growable: false),
          originalDocumentReferences
              .map((stored) => stored.toJson())
              .toList(growable: false),
          reason: 'temporary report recovery states must restore the exact BND',
        );
        final restoredAnswers = await ReportPersistenceService.loadAnswers();
        expect(
          restoredAnswers['_coach_lpp_evidence_v1'],
          originalStrictRootJson,
        );
        final restoredCandidate = provider.profile!.lppCapitalNoticeDeadline;
        final restoredRegulation = provider.profile!.lppRegulationReference;
        expect(documents.resolveLppCapitalNotice(restoredCandidate), isNotNull);
        expect(documents.resolveLppRegulation(restoredRegulation), isNotNull);
        testOnlyRootRouter.go('/retraite');
        await $.pumpAndSettle();
        await $(find.bySemanticsIdentifier(
          'retirement_lpp_capital_notice_deadline_education',
        )).waitUntilVisible();
      }

      await expectReport(
        hasCapitalHandoff: true,
        hasRegulationHandoff: true,
      );

      final authorityBeforeReplacement =
          provider.profile!.lppRegulationReference;
      expect(authorityBeforeReplacement, isNotNull);
      if (authorityBeforeReplacement == null) {
        fail('Missing restored regulation authority');
      }
      final replacementAuthoritySourceDate =
          DateTime.utc(now.year, now.month, now.day).subtract(
        const Duration(days: 2),
      );
      final replacementAuthorityReceipt =
          await provider.acceptLppRegulationReference(
        LppRegulationReviewConfirmation(
          ownerKind: LppEvidenceOwnerKind.self,
          sourceDate: replacementAuthoritySourceDate,
          legalYear: replacementAuthoritySourceDate.year,
          fundRelationship: LppFundRelationship.currentFund,
          expectedPreviousReferenceId: authorityBeforeReplacement.referenceId,
        ),
      );
      await documents.recordLppRegulation(replacementAuthorityReceipt);
      await $.pumpAndSettle();
      expect(
        provider.profile!.lppRegulationReference?.referenceId,
        replacementAuthorityReceipt.referenceId,
      );
      expect(documents.resolveLppCapitalNotice(candidate), isNull);
      expect(
        documents.resolveLppCapitalNotice(
          provider.profile!.lppCapitalNoticeDeadline,
        ),
        isNull,
      );
      expect(
        documents.resolveLppRegulation(
          provider.profile!.lppRegulationReference,
        ),
        isNotNull,
      );
      await expectReport(
        hasCapitalHandoff: false,
        hasRegulationHandoff: true,
      );

      final replacementReceipt = await provider.acceptLppReview(
        _replacementReview(now),
      );
      await $.pumpAndSettle();
      final replacementSnapshot = provider.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      );
      expect(replacementSnapshot, isNotNull);
      if (replacementSnapshot == null) fail('Missing replacement LPP snapshot');
      expect(
        replacementSnapshot.snapshotId,
        isNot(currentSnapshot.snapshotId),
      );
      expect(replacementReceipt.snapshotId, replacementSnapshot.snapshotId);
      expect(replacementSnapshot.lppCapitalNoticeDeadline, isNull);
      expect(provider.profile!.lppCapitalNoticeDeadline, isNull);
      expect(documents.resolveLppCapitalNotice(candidate), isNull);
      expect(
        documents.resolveLppRegulation(
          provider.profile!.lppRegulationReference,
        ),
        isNotNull,
      );
      await expectReport(
        hasCapitalHandoff: false,
        hasRegulationHandoff: true,
      );
      testOnlyRootRouter.go('/retraite');
      await $.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_capital_notice_deadline_education',
        ),
        findsNothing,
      );
      final replacementFact = replacementSnapshot
          .facts[LppEvidenceFactKey.vestedBenefitsCapitalChf];
      expect(replacementFact, isNotNull);
      expect(
        replacementFact!.authorizationMode,
        LppEvidenceAuthorizationMode.self,
      );
      final encodedLedger =
          provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'] as String;
      expect(encodedLedger, isNot(contains(_replacementMarker)));
      expect(encodedLedger, isNot(contains('documentSha256')));
    },
  );
}
