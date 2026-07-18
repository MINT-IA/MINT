import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/g1_ret_ref_lpp_regulation_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _firstNumericAcquisitionId = '62626262-6262-4262-8262-626262626262';
const _replacementAcquisitionId = '72727272-7272-4272-8272-727272727272';
const _firstNumericMarker =
    '%PDF-1.7 MINT synthetic first numeric LPP bytes only';
const _replacementMarker =
    '%PDF-1.7 MINT synthetic replacement numeric LPP bytes only';
const _missingDocumentReferenceBodyFr =
    'Une déclaration non vérifiée existe, mais sa référence locale manque. '
    'Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni '
    'l’institution concernée, ni l’application du règlement à ta situation, '
    'ni tes droits ni aucun montant.';
const _mismatchedDocumentReferenceBodyFr =
    'Une déclaration non vérifiée ne correspond pas à sa référence locale et '
    'est masquée. Reconfirme-la à partir du document. MINT n’en déduit ni '
    'l’origine, ni l’institution concernée, ni l’application du règlement à '
    'ta situation, ni tes droits ni aucun montant.';
const _legacyMissingFundRelationshipBodyFr =
    'Une déclaration non vérifiée ne précise pas l’origine de ce règlement. '
    'Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni '
    'l’institution concernée, ni l’application du règlement à ta situation, '
    'ni tes droits ni aucun montant.';

void _requireRuntimeValue(Object? value, String message) {
  if (value == null) fail(message);
}

LppReviewConfirmation _replacementNumericReview(DateTime now) {
  final bytes = Uint8List.fromList(utf8.encode(_replacementMarker));
  return LppReviewConfirmation(
    authorization: LppAcquisitionAuthorization(
      acquisitionId: _replacementAcquisitionId,
      subject: LppEvidenceOwnerKind.self,
      partnerAttested: false,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: now.subtract(const Duration(minutes: 2)),
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

LppReviewConfirmation _firstNumericReview(DateTime now) {
  final bytes = Uint8List.fromList(utf8.encode(_firstNumericMarker));
  return LppReviewConfirmation(
    authorization: LppAcquisitionAuthorization(
      acquisitionId: _firstNumericAcquisitionId,
      subject: LppEvidenceOwnerKind.self,
      partnerAttested: false,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: now.subtract(const Duration(minutes: 3)),
      documentSha256: LppAcquisitionAuthorization.sha256Hex(bytes),
    ),
    sourceDate: DateTime.utc(now.year, now.month, now.day)
        .subtract(const Duration(days: 1)),
    facts: const <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
        value: 143287.50,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
        value: 72540,
        unit: LppEvidenceUnit.chfPerYear,
      ),
    },
  );
}

void main() {
  patrolTest(
    'cold reader proves regulation dossier, PDF, recovery, and preservation',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.lppRegulationReferenceEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.lppRegulationReferenceEnabled = false;
      });

      final now = DateTime.now().toUtc();
      final preferences = await SharedPreferences.getInstance();
      final writerPid = preferences.getInt(g1LppRegulationWriterPidKey);
      addTearDown(() async {
        await preferences.remove(g1LppRegulationWriterPidKey);
      });
      if (writerPid == null || writerPid <= 0) {
        fail('Writer PID witness is missing or invalid; failing closed');
      }
      if (writerPid == pid) {
        fail('Reader reused the writer app process; failing closed');
      }
      final encodedWizardCache = preferences.getString('wizard_answers_v2');
      if (encodedWizardCache == null) {
        fail('Missing wizard cache before the cold regulation reader');
      }
      final wizardCache = jsonDecode(encodedWizardCache);
      expect(wizardCache, isA<Map<String, dynamic>>());
      expect(
        (wizardCache as Map<String, dynamic>)['_coach_lpp_evidence_v1'],
        '__secure__',
        reason: 'the cache must retain only the secure LPP placeholder',
      );
      final activeAuthoritySlot =
          preferences.getString('coach_authority_active_slot_v1');
      if (activeAuthoritySlot == null) {
        fail('Missing strict authority pointer before the cold reader');
      }

      final originalAnswers = await ReportPersistenceService.loadAnswers();
      final originalStrictRootJson = originalAnswers['_coach_lpp_evidence_v1'];
      if (originalStrictRootJson is! String) {
        fail('Missing strict LPP root before provider hydration');
      }
      final persistedRoot = LppEvidenceRoot.fromJsonString(
        originalStrictRootJson,
        now: () => now,
      );
      if (persistedRoot == null) {
        fail('Missing or malformed strict LPP root before provider hydration');
      }
      expect(
        persistedRoot.self,
        isNull,
        reason: 'the process-death reader must start regulation-only',
      );
      final persistedRegulation = persistedRoot.selfRegulationReference;
      if (persistedRegulation == null) {
        fail('Missing strict regulation reference before provider hydration');
      }
      final referenceStore = DocumentReferenceStore();
      final originalDocumentReferences = await referenceStore.load();
      final hasPersistedDocumentReference =
          originalDocumentReferences.any((reference) {
        return reference.referenceId == persistedRegulation.referenceId &&
            reference.kind == ConfirmedDocumentReference.lppRegulationKind;
      });
      if (!hasPersistedDocumentReference) {
        fail('Missing opaque document reference before provider hydration');
      }

      await $.pumpWidgetAndSettle(const MintApp());
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final appContext = $.tester.element(materialApp);
      final provider = appContext.read<CoachProfileProvider>();
      final documents = appContext.read<DocumentProvider>();
      await provider.loadFromWizard();
      documents.bindLedger(provider);
      documents.clearLocalState();
      await documents.hydrateReferences();
      await $.pumpAndSettle();

      final currentSnapshot = provider.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      );
      expect(
        currentSnapshot,
        isNull,
        reason: 'cold regulation authority must not require numeric LPP facts',
      );
      expect(provider.isLoaded, isTrue);
      final coldProfile = provider.profile;
      if (coldProfile == null) {
        fail('Provider did not hydrate the valid regulation-only strict root');
      }
      final candidate = provider.profile!.lppRegulationReference;
      expect(candidate, isNotNull);
      _requireRuntimeValue(
        candidate,
        'Cold profile omitted the persisted regulation reference',
      );
      expect(candidate?.referenceId, persistedRegulation.referenceId);
      final dynamic typedCandidate = candidate;

      final resolved = documents.resolveLppRegulation(candidate);
      expect(resolved, isNotNull);
      final reference = documents.byId(candidate!.referenceId);
      expect(reference, isNotNull);
      expect(reference!.referenceId, candidate.referenceId);
      expect(reference.kind, ConfirmedDocumentReference.lppRegulationKind);
      final dynamic typedReference = reference;
      expect(typedReference.snapshotId, isNull);
      expect(reference.ownerKind, LppEvidenceOwnerKind.self);
      expect(reference.confirmedAt, candidate.confirmedAt);
      expect(resolved!.sourceDate, candidate.sourceDate);
      expect(resolved.legalYear, candidate.legalYear);

      Future<void> expectReport({required bool hasHandoff}) async {
        testOnlyRootRouter.go('/rapport');
        await $.pumpAndSettle();
        await $(find.bySemanticsIdentifier('financial_report_screen'))
            .waitUntilVisible();
        expect(
          find.bySemanticsIdentifier(
            'financial_report_lpp_regulation_handoff',
          ),
          hasHandoff ? findsOneWidget : findsNothing,
        );
      }

      Future<void> expectRecovery(String body) async {
        await expectReport(hasHandoff: false);
        testOnlyRootRouter.go('/retraite');
        await $.pumpAndSettle();
        final recovery = find.bySemanticsIdentifier(
          'retirement_lpp_regulation_reference_recovery',
        );
        await $(recovery).waitUntilVisible();
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_reference_education',
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_handoff_cta',
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_reconfirm_cta',
          ),
          findsOneWidget,
        );
        expect(find.text(body), findsOneWidget);
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_fund_relation',
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_handoff_reference_body',
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_handoff_fund_relation',
          ),
          findsNothing,
        );
        final rendered = $.tester
            .widgetList<Text>(
              find.descendant(of: recovery, matching: find.byType(Text)),
            )
            .map(
                (widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
            .join(' ');
        expect(rendered, isNot(contains(candidate.referenceId)));
        expect(
          rendered,
          isNot(contains(typedCandidate.fundRelationship.wireName)),
        );
      }

      testOnlyRootRouter.go('/retraite');
      await $.pumpAndSettle();
      await $(#retirement_lpp_regulation_reference_education)
          .waitUntilVisible();
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_regulation_fund_relation',
        ),
        findsOneWidget,
      );
      await $(#retirement_lpp_regulation_handoff_cta).scrollTo().tap();
      await $(find.bySemanticsIdentifier(
        'retirement_lpp_regulation_handoff_sheet',
      )).waitUntilVisible();
      for (final identifier in const <String>[
        'retirement_lpp_regulation_handoff_title',
        'retirement_lpp_regulation_handoff_reference_body',
        'retirement_lpp_regulation_handoff_fund_relation',
        'retirement_lpp_regulation_handoff_privacy',
        'retirement_lpp_regulation_applicability_question',
      ]) {
        expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
      }
      for (final topic in const <String>[
        'buyback',
        'conversion',
        'flexibleRetirement',
        'disability',
        'survivors',
        'divorce',
      ]) {
        expect(
          find.bySemanticsIdentifier('retirement_lpp_regulation_topic_$topic'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(
            'retirement_lpp_regulation_question_$topic',
          ),
          findsOneWidget,
        );
      }
      await $(#retirement_lpp_regulation_handoff_close).tap();
      await $.pumpAndSettle();

      await expectReport(hasHandoff: true);
      final handoff = LppRegulationSpecialistHandoff.tryFromEvidence(resolved);
      expect(handoff, isNotNull);
      final report = FinancialReportService().generateReport(
        provider.reportAnswersSnapshot,
        lppRegulationHandoff: handoff,
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
        await referenceStore.save(const <ConfirmedDocumentReference>[]);
        documents.clearLocalState();
        await documents.hydrateReferences();
        expect(
          documents.resolveLppRegulationReference(candidate),
          LppRegulationReferenceResolution.missingDocumentReference,
        );
        expect(documents.resolveLppRegulation(candidate), isNull);
        await expectRecovery(_missingDocumentReferenceBodyFr);
        expect(find.text(_missingDocumentReferenceBodyFr), findsOneWidget);

        final mismatchedDocumentReferences = originalDocumentReferences
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
        await referenceStore.save(mismatchedDocumentReferences);
        documents.clearLocalState();
        await documents.hydrateReferences();
        expect(
          documents.resolveLppRegulationReference(candidate),
          LppRegulationReferenceResolution.mismatchedDocumentReference,
        );
        expect(documents.resolveLppRegulation(candidate), isNull);
        await expectRecovery(_mismatchedDocumentReferenceBodyFr);
        expect(find.text(_mismatchedDocumentReferenceBodyFr), findsOneWidget);

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
        await ReportPersistenceService.saveLppEvidenceAnswers(
          legacyAnswers,
        );
        await provider.loadFromWizard();
        await $.pumpAndSettle();
        expect(provider.profile?.lppRegulationReference, isNull);
        expect(
          provider.lppRegulationRecoveryReason,
          LppRegulationRecoveryReason.legacyMissingFundRelationship,
        );
        expect(
          documents.resolveLppRegulationReference(
            provider.profile?.lppRegulationReference,
          ),
          LppRegulationReferenceResolution.unavailable,
        );
        await expectRecovery(_legacyMissingFundRelationshipBodyFr);
        expect(find.text(_legacyMissingFundRelationshipBodyFr), findsOneWidget);
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
          reason: 'temporary recovery states must restore the exact BND',
        );
        final restoredAnswers = await ReportPersistenceService.loadAnswers();
        expect(
            restoredAnswers['_coach_lpp_evidence_v1'], originalStrictRootJson);
        expect(
          provider.profile?.lppRegulationReference?.referenceId,
          candidate.referenceId,
        );
        expect(documents.resolveLppRegulation(candidate), isNotNull);
        testOnlyRootRouter.go('/retraite');
        await $.pumpAndSettle();
        await $(#retirement_lpp_regulation_reference_education)
            .waitUntilVisible();
      }

      final firstNumericReceipt =
          await provider.acceptLppReview(_firstNumericReview(now));
      await $.pumpAndSettle();
      final firstNumericSnapshot = provider.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      );
      expect(firstNumericSnapshot, isNotNull);
      if (firstNumericSnapshot == null) {
        fail('Missing first numeric LPP snapshot');
      }
      expect(firstNumericReceipt.snapshotId, firstNumericSnapshot.snapshotId);
      final afterAdditionReference = provider.profile!.lppRegulationReference;
      expect(afterAdditionReference, isNotNull);
      expect(afterAdditionReference!.referenceId, candidate.referenceId);
      final dynamic typedAfterAdditionReference = afterAdditionReference;
      expect(
        typedAfterAdditionReference.fundRelationship.wireName,
        typedCandidate.fundRelationship.wireName,
      );
      expect(
        documents.resolveLppRegulation(afterAdditionReference),
        isNotNull,
      );
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_regulation_reference_education',
        ),
        findsOneWidget,
      );

      final replacementReceipt =
          await provider.acceptLppReview(_replacementNumericReview(now));
      await $.pumpAndSettle();
      final replacementSnapshot = provider.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      );
      expect(replacementSnapshot, isNotNull);
      if (replacementSnapshot == null) fail('Missing replacement snapshot');
      expect(
        replacementSnapshot.snapshotId,
        isNot(firstNumericSnapshot.snapshotId),
      );
      expect(replacementReceipt.snapshotId, replacementSnapshot.snapshotId);
      final preservedReference = provider.profile!.lppRegulationReference;
      expect(preservedReference, isNotNull);
      expect(preservedReference!.referenceId, candidate.referenceId);
      final dynamic typedPreservedReference = preservedReference;
      expect(
        typedPreservedReference.fundRelationship.wireName,
        typedCandidate.fundRelationship.wireName,
      );
      expect(documents.resolveLppRegulation(preservedReference), isNotNull);
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_regulation_reference_education',
        ),
        findsOneWidget,
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
