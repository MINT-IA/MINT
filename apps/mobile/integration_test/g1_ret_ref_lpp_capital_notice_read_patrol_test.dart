import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/g1_ret_ref_lpp_capital_notice_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _replacementAcquisitionId = '71717171-7171-4171-8171-717171717171';
const _replacementMarker =
    '%PDF-1.7 MINT capital-notice invalidation synthetic bytes only';

Widget _dashboard({
  required CoachProfileProvider provider,
  required DocumentProvider documents,
}) =>
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider<DocumentProvider>.value(value: documents),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RetirementDashboardScreen(),
      ),
    );

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
    sourceDate: DateTime.utc(
      now.year,
      now.month,
      now.day,
    ),
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
    'cold reader hides notice after authority then numeric replacement',
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
      addTearDown(() async {
        await preferences.remove(g1LppCapitalNoticeWriterPidKey);
      });
      final provider = CoachProfileProvider(now: () => now);
      final documents = DocumentProvider(now: () => now);
      addTearDown(provider.dispose);
      addTearDown(documents.dispose);
      await provider.loadFromWizard();
      documents.bindLedger(provider);
      await documents.hydrateReferences();

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

      await $.pumpWidgetAndSettle(
        _dashboard(provider: provider, documents: documents),
      );
      await $(find.bySemanticsIdentifier(
        'retirement_lpp_capital_notice_deadline_education',
      )).waitUntilVisible();

      final authorityBeforeReplacement =
          provider.profile!.lppRegulationReference;
      expect(authorityBeforeReplacement, isNotNull);
      if (authorityBeforeReplacement == null) {
        fail('Missing cold regulation authority');
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
        find.bySemanticsIdentifier(
          'retirement_lpp_capital_notice_deadline_education',
        ),
        findsNothing,
      );

      final replacementReceipt = await provider.acceptLppReview(
        _replacementReview(now),
      );
      await $.pumpAndSettle();
      final replacementSnapshot = LppEvidenceSelector.selectSelf(
        provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'],
        now: () => now,
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
