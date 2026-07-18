import 'dart:convert';
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
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _firstNumericAcquisitionId = '62626262-6262-4262-8262-626262626262';
const _replacementAcquisitionId = '72727272-7272-4272-8272-727272727272';
const _firstNumericMarker =
    '%PDF-1.7 MINT synthetic first numeric LPP bytes only';
const _replacementMarker =
    '%PDF-1.7 MINT synthetic replacement numeric LPP bytes only';

void _requireRuntimeValue(Object? value, String message) {
  if (value == null) fail(message);
}

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
    'cold reader preserves regulation through numeric addition and replacement',
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

      final persistedAnswers = await ReportPersistenceService.loadAnswers();
      final persistedRoot = LppEvidenceRoot.fromJsonString(
        persistedAnswers['_coach_lpp_evidence_v1'],
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
      final persistedDocumentReferences = await DocumentReferenceStore().load();
      final hasPersistedDocumentReference =
          persistedDocumentReferences.any((reference) {
        return reference.referenceId == persistedRegulation.referenceId &&
            reference.kind == ConfirmedDocumentReference.lppRegulationKind;
      });
      if (!hasPersistedDocumentReference) {
        fail('Missing opaque document reference before provider hydration');
      }

      final provider = CoachProfileProvider(now: () => now);
      final documents = DocumentProvider(now: () => now);
      addTearDown(provider.dispose);
      addTearDown(documents.dispose);
      await provider.loadFromWizard();
      documents.bindLedger(provider);
      await documents.hydrateReferences();

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

      await $.pumpWidgetAndSettle(
        _dashboard(provider: provider, documents: documents),
      );
      await $(#retirement_lpp_regulation_reference_education)
          .waitUntilVisible();
      await $(#retirement_lpp_regulation_handoff_cta).scrollTo().tap();
      await $(find.bySemanticsIdentifier(
        'retirement_lpp_regulation_handoff_sheet',
      )).waitUntilVisible();
      expect(
        find.bySemanticsIdentifier('retirement_lpp_regulation_handoff_title'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_regulation_handoff_privacy',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_regulation_applicability_question',
        ),
        findsOneWidget,
      );
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
