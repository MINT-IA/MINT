import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _acquisitionId = '51515151-5151-4151-8151-515151515151';
const _rawMarker = '%PDF-1.7 MINT BND-05 synthetic runtime bytes only';
const _expectedReferenceKeys = <String>{
  'referenceId',
  'kind',
  'snapshotId',
  'ownerKind',
  'confirmedAt',
};
final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final _syntheticBytes = Uint8List.fromList(utf8.encode(_rawMarker));
final _documentSha256 = LppAcquisitionAuthorization.sha256Hex(_syntheticBytes);

LppReviewConfirmation _syntheticSelfReview(DateTime now) {
  return LppReviewConfirmation(
    authorization: LppAcquisitionAuthorization(
      acquisitionId: _acquisitionId,
      subject: LppEvidenceOwnerKind.self,
      partnerAttested: false,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: now.subtract(const Duration(minutes: 5)),
      documentSha256: _documentSha256,
    ),
    sourceDate: DateTime.utc(2026, 6, 30),
    facts: const <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
        value: 143287.50,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
        value: 72540,
        unit: LppEvidenceUnit.chfPerYear,
      ),
      LppEvidenceFactKey.disabilityPensionAnnualChf: LppReviewedFact(
        value: 24120,
        unit: LppEvidenceUnit.chfPerYear,
      ),
    },
  );
}

List<TimelineNode> _documentNodes(TimelineProvider timeline) => timeline.months
    .expand((month) => month.nodes)
    .where((node) => node.type == NodeType.document)
    .toList(growable: false);

void _expectNoRawPayload(String encoded) {
  for (final forbidden in <String>[
    _rawMarker,
    base64Encode(_syntheticBytes),
    _documentSha256,
    _acquisitionId,
    'sourceText',
    'rawOcr',
    'rawText',
    'documentSha256',
    'acquisitionId',
    'scanSessionId',
    'filename',
  ]) {
    expect(encoded, isNot(contains(forbidden)), reason: forbidden);
  }
}

void main() {
  patrolTest(
    'writes one opaque LPP reference and renders its live timeline detail',
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
      await DocumentReferenceStore().save(const []);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_has_pension_fund': 'yes',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      await $.pumpWidgetAndSettle(const MintApp());
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final element = $.tester.element(materialApp);
      final ledger = element.read<CoachProfileProvider>();
      final documents = element.read<DocumentProvider>();
      final timeline = element.read<TimelineProvider>();
      await ledger.waitForReportAnswers();
      await documents.hydrateReferences();

      final receipt = await ledger.acceptLppReview(
        _syntheticSelfReview(DateTime.now().toUtc()),
      );
      expect(receipt.ownerKind, LppEvidenceOwnerKind.self);
      expect(receipt.snapshotId, matches(_uuidV4Pattern));
      expect(receipt.factKeys, <LppEvidenceFactKey>{
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
        LppEvidenceFactKey.insuredSalaryAnnualChf,
        LppEvidenceFactKey.disabilityPensionAnnualChf,
      });
      final snapshot = ledger.currentLppSnapshot(LppEvidenceOwnerKind.self);
      expect(snapshot, isNotNull);
      expect(snapshot!.snapshotId, receipt.snapshotId);
      expect(snapshot.facts.keys.toSet(), receipt.factKeys);

      final reference = await documents.recordConfirmedLppReview(receipt);
      final idempotentRetry = await documents.recordConfirmedLppReview(receipt);
      expect(idempotentRetry.referenceId, reference.referenceId);
      expect(reference.referenceId, matches(_uuidV4Pattern));
      expect(reference.referenceId, isNot(_acquisitionId));
      expect(reference.snapshotId, receipt.snapshotId);
      expect(reference.ownerKind, LppEvidenceOwnerKind.self);
      expect(documents.currentReferences, hasLength(1));

      final preferences = await SharedPreferences.getInstance();
      final encodedReferences = preferences.getString(
        DocumentReferenceStore.storageKey,
      );
      expect(encodedReferences, isNotNull);
      final referenceRoot =
          jsonDecode(encodedReferences!) as Map<String, dynamic>;
      expect(referenceRoot.keys.toSet(), <String>{
        'schemaVersion',
        'references',
      });
      expect(
        referenceRoot['schemaVersion'],
        DocumentReferenceStore.schemaVersion,
      );
      final persistedReferences = referenceRoot['references'] as List;
      expect(persistedReferences, hasLength(1));
      final persistedReference =
          Map<String, dynamic>.from(persistedReferences.single as Map);
      expect(persistedReference.keys.toSet(), _expectedReferenceKeys);
      expect(persistedReference, reference.toJson());
      for (final forbidden in <String>[
        '143287.5',
        '72540',
        '24120',
        'value',
        'facts',
      ]) {
        expect(encodedReferences, isNot(contains(forbidden)));
      }
      _expectNoRawPayload(encodedReferences);

      final encodedLedger =
          ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'] as String;
      _expectNoRawPayload(encodedLedger);

      for (var attempt = 0; attempt < 80; attempt++) {
        if (_documentNodes(timeline).length == 1) break;
        await $.tester.pump(const Duration(milliseconds: 100));
      }
      final nodes = _documentNodes(timeline);
      expect(nodes, hasLength(1));
      expect(nodes.single.id, 'document_${reference.referenceId}');
      expect(nodes.single.deepLink, '/documents/${reference.referenceId}');
      expect(nodes.single.subtitle, isEmpty);

      await $.platformAutomator.mobile.openUrl(
        'mint://${nodes.single.deepLink}',
      );
      await $.pumpAndSettle();
      await $(#document_reference_remove).waitUntilVisible();
      expect(find.text("CHF 143'287"), findsOneWidget);
      expect(find.text("CHF 72'540/an"), findsOneWidget);
      expect(find.text("CHF 24'120/an"), findsOneWidget);
      expect(find.text("CHF 91'919"), findsNothing);
      expect(
        find.byKey(const Key('document_reference_stale_state')),
        findsNothing,
      );
    },
  );
}
