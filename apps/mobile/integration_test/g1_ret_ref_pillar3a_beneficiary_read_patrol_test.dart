import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_consumer.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_specialist_handoff.dart';
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

import 'support/g1_ret_ref_pillar3a_beneficiary_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

final class _NetworkForbiddenOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access is forbidden in the exact 3a PDF proof');
  }
}

List<Map<String, dynamic>> _referenceJson(
  List<ConfirmedDocumentReference> references,
) =>
    references.map((reference) => reference.toJson()).toList(growable: false);

void main() {
  patrolTest(
    'cold reader proves exact 3a handoff, PDF, recovery, and restoration',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
      addTearDown(() {
        FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.typedLppEvidence = false;
      });

      final preferences = await SharedPreferences.getInstance();
      final writerPid = preferences.getInt(g1Pillar3aBeneficiaryWriterPidKey);
      addTearDown(() async {
        await preferences.remove(g1Pillar3aBeneficiaryWriterPidKey);
      });
      if (writerPid == null || writerPid <= 0) {
        fail('Writer PID witness is missing or invalid; failing closed');
      }
      if (writerPid == pid) {
        fail('Reader reused the writer app process; failing closed');
      }

      final now = DateTime.now().toUtc();
      final originalAnswers = await ReportPersistenceService.loadAnswers();
      final originalRootJson =
          originalAnswers[Pillar3aBeneficiaryEvidenceRoot.answerKey];
      if (originalRootJson is! String) {
        fail('Missing strict exact 3a root before cold hydration');
      }
      final originalRoot = Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
        originalRootJson,
        now: () => now,
      );
      if (originalRoot == null || originalRoot.contracts.length != 1) {
        fail('Malformed exact 3a root before cold hydration');
      }
      final evidence = originalRoot.contracts.single;
      expect(
        evidence.relation,
        Pillar3aBeneficiaryRelation.currentActiveUnpaid,
      );
      final referenceStore = DocumentReferenceStore();
      final originalDocumentReferences = await referenceStore.load();
      final exactReferences = originalDocumentReferences.where(
        (reference) =>
            reference.kind == Pillar3aBeneficiaryEvidence.kind &&
            reference.referenceId == evidence.referenceId &&
            reference.contractReferenceId == evidence.contractReferenceId &&
            reference.documentAuthorityId == evidence.documentAuthorityId,
      );
      expect(exactReferences, hasLength(1));

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

      Pillar3aBeneficiaryConsumerResolution consumer() =>
          documents.resolvePillar3aBeneficiaryConsumer();

      Future<void> expectReport({required bool hasHandoff}) async {
        testOnlyRootRouter.go('/retraite');
        await $.pumpAndSettle();
        testOnlyRootRouter.go('/rapport');
        await $.pumpAndSettle();
        await $(find.bySemanticsIdentifier('financial_report_screen'))
            .waitUntilVisible();
        expect(
          find.bySemanticsIdentifier(
            'financial_report_pillar3a_beneficiary_handoff',
          ),
          hasHandoff ? findsOneWidget : findsNothing,
        );
      }

      expect(
        consumer().state,
        Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
      );
      expect(
        consumer().entries.single.renderablePreciseDocumentMetadata?.relation,
        Pillar3aBeneficiaryRelation.currentActiveUnpaid,
      );
      await expectReport(hasHandoff: true);
      final handoff =
          Pillar3aBeneficiarySpecialistHandoff.tryFromConsumerResolution(
        consumer(),
      );
      expect(handoff, isNotNull);
      final report = FinancialReportService().generateReport(
        provider.reportAnswersSnapshot,
        pillar3aBeneficiaryHandoff: handoff,
      );
      final reportContext = $.tester.element(
        find.bySemanticsIdentifier('financial_report_screen'),
      );
      final pdfBytes = await HttpOverrides.runZoned(
        () => PdfService.buildFinancialReportPdfBytes(
          report,
          l: S.of(reportContext)!,
        ),
        createHttpClient: _NetworkForbiddenOverrides().createHttpClient,
      );
      expect(utf8.decode(pdfBytes.take(5).toList()), '%PDF-');
      expect(pdfBytes.length, greaterThan(1000));

      try {
        final withoutExactReference = originalDocumentReferences
            .where(
              (reference) =>
                  reference.kind != Pillar3aBeneficiaryEvidence.kind ||
                  reference.referenceId != evidence.referenceId,
            )
            .toList(growable: false);
        await referenceStore.save(withoutExactReference);
        documents.clearLocalState();
        await documents.hydrateReferences();
        expect(
          documents.resolvePillar3aBeneficiaryReference(evidence),
          Pillar3aBeneficiaryReferenceResolution.missingDocumentReference,
        );
        expect(
          consumer().state,
          Pillar3aBeneficiaryConsumerState.missingDocumentReference,
        );
        expect(
          Pillar3aBeneficiarySpecialistHandoff.tryFromConsumerResolution(
            consumer(),
          ),
          isNull,
        );
        await expectReport(hasHandoff: false);

        final mismatchedDocumentReferences = originalDocumentReferences
            .map(
              (reference) => reference.referenceId == evidence.referenceId
                  ? ConfirmedDocumentReference(
                      referenceId: reference.referenceId,
                      kind: reference.kind,
                      snapshotId: reference.snapshotId,
                      contractReferenceId: reference.contractReferenceId,
                      documentAuthorityId: reference.documentAuthorityId,
                      ownerKind: reference.ownerKind,
                      confirmedAt: reference.confirmedAt.add(
                        const Duration(seconds: 1),
                      ),
                    )
                  : reference,
            )
            .toList(growable: false);
        await referenceStore.save(mismatchedDocumentReferences);
        documents.clearLocalState();
        await documents.hydrateReferences();
        expect(
          documents.resolvePillar3aBeneficiaryReference(evidence),
          Pillar3aBeneficiaryReferenceResolution.mismatchedDocumentReference,
        );
        expect(
          consumer().state,
          Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference,
        );
        await expectReport(hasHandoff: false);

        await referenceStore.save(originalDocumentReferences);
        documents.clearLocalState();
        await documents.hydrateReferences();
        final invalidPresenceAnswers = Map<String, dynamic>.from(
          originalAnswers,
        )
          ..['q_has_3a'] = false
          ..['__provenance'] = <String, dynamic>{
            ...((originalAnswers['__provenance'] as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{}),
            'hasPillar3a': <String, dynamic>{
              'source': 'userInput',
              'updatedAt': '2099-01-01T00:00:00.000Z',
              'sourceDate': null,
            },
          };
        await ReportPersistenceService.saveAnswers(invalidPresenceAnswers);
        await provider.loadFromWizard();
        await $.pumpAndSettle();
        expect(
          consumer().state,
          Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance,
        );
        await expectReport(hasHandoff: false);
        expect(
          await provider.resetInvalidPillar3aBeneficiaryPresenceProvenance(),
          isTrue,
        );
        await $.pumpAndSettle();
        final presenceResetAnswers =
            await ReportPersistenceService.loadAnswers();
        expect(presenceResetAnswers['q_has_3a'], isNull);
        final presenceResetProvenance =
            presenceResetAnswers['__provenance'] as Map?;
        expect(presenceResetProvenance?.containsKey('hasPillar3a'), isFalse);
        expect(
          presenceResetAnswers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
          originalRootJson,
        );
        expect(
          _referenceJson(await referenceStore.load()),
          _referenceJson(originalDocumentReferences),
        );
        expect(
          consumer().state,
          Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
        );
        await expectReport(hasHandoff: true);

        final invalidRootAnswers = Map<String, dynamic>.from(originalAnswers)
          ..[Pillar3aBeneficiaryEvidenceRoot.answerKey] = '{invalid';
        await ReportPersistenceService.saveAnswers(invalidRootAnswers);
        await provider.loadFromWizard();
        await $.pumpAndSettle();
        expect(
          provider.pillar3aBeneficiaryLedgerState,
          Pillar3aBeneficiaryLedgerState.invalid,
        );
        expect(consumer().state, Pillar3aBeneficiaryConsumerState.invalid);
        await expectReport(hasHandoff: false);
        expect(
          await documents.resetInvalidPillar3aBeneficiaryEvidence(),
          isTrue,
        );
        await $.pumpAndSettle();
        expect(
          (await referenceStore.load()).where(
            (reference) => reference.kind == Pillar3aBeneficiaryEvidence.kind,
          ),
          isEmpty,
        );
        final afterInvalidRootReset =
            await ReportPersistenceService.loadAnswers();
        expect(
          afterInvalidRootReset
              .containsKey(Pillar3aBeneficiaryEvidenceRoot.answerKey),
          isFalse,
        );
        expect(
          provider.pillar3aBeneficiaryLedgerState,
          Pillar3aBeneficiaryLedgerState.missing,
        );
        await expectReport(hasHandoff: false);
      } finally {
        await referenceStore.save(originalDocumentReferences);
        await ReportPersistenceService.saveAnswers(originalAnswers);
        documents.clearLocalState();
        await documents.hydrateReferences();
        await provider.loadFromWizard();
        await $.pumpAndSettle();

        final restoredAnswers = await ReportPersistenceService.loadAnswers();
        expect(restoredAnswers, originalAnswers);
        expect(
          restoredAnswers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
          originalRootJson,
        );
        expect(
          _referenceJson(await referenceStore.load()),
          _referenceJson(originalDocumentReferences),
        );
        expect(
          documents.resolvePillar3aBeneficiaryConsumer().state,
          Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
        );
        await expectReport(hasHandoff: true);
        expect(
          find.bySemanticsIdentifier(
            'financial_report_pillar3a_beneficiary_handoff',
          ),
          findsOneWidget,
          reason: 'handoff reappears after exact restoration',
        );
      }
    },
  );
}
