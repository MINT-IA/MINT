import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _rawMarker = '%PDF-1.7 MINT BND-05 synthetic runtime bytes only';
const _expectedReferenceKeys = <String>{
  'referenceId',
  'kind',
  'snapshotId',
  'ownerKind',
  'confirmedAt',
};

List<TimelineNode> _documentNodes(TimelineProvider timeline) => timeline.months
    .expand((month) => month.nodes)
    .where((node) => node.type == NodeType.document)
    .toList(growable: false);

void main() {
  patrolTest(
    'cold reader reopens the exact strict reference then deletes metadata only',
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
      final element = $.tester.element(materialApp);
      final ledger = element.read<CoachProfileProvider>();
      final documents = element.read<DocumentProvider>();
      final timeline = element.read<TimelineProvider>();
      await ledger.waitForReportAnswers();
      await documents.hydrateReferences();

      final stored = await documents.referenceStore.load();
      expect(stored, hasLength(1));
      final reference = stored.single;
      expect(reference.toJson().keys.toSet(), _expectedReferenceKeys);
      expect(reference.ownerKind, LppEvidenceOwnerKind.self);
      expect(documents.currentReferences, hasLength(1));
      expect(documents.byId(reference.referenceId), isNotNull);

      final snapshot = ledger.currentLppSnapshot(LppEvidenceOwnerKind.self);
      expect(snapshot, isNotNull);
      expect(snapshot!.snapshotId, reference.snapshotId);
      expect(snapshot.facts.keys.toSet(), <LppEvidenceFactKey>{
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
        LppEvidenceFactKey.insuredSalaryAnnualChf,
        LppEvidenceFactKey.disabilityPensionAnnualChf,
      });
      final strictRootBeforeDelete =
          ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'] as String;
      expect(strictRootBeforeDelete, isNot(contains(_rawMarker)));
      expect(strictRootBeforeDelete, isNot(contains('sourceText')));
      expect(strictRootBeforeDelete, isNot(contains('rawOcr')));

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

      await $(#document_reference_remove).tap();
      await $.pumpAndSettle();
      final context = $.tester.element(find.byType(AlertDialog));
      final l10n = S.of(context)!;
      expect(find.text(l10n.documentReferenceRemoveMessage), findsOneWidget);
      await $.tester.tap(find.text(l10n.documentReferenceRemoveButton).last);
      await $.pumpAndSettle();

      expect(documents.hasStoredReference(reference.referenceId), isFalse);
      expect(documents.currentReferences, isEmpty);
      expect(await documents.referenceStore.load(), isEmpty);
      expect(
        ledger.currentLppSnapshotId(LppEvidenceOwnerKind.self),
        reference.snapshotId,
      );
      expect(
        ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'],
        strictRootBeforeDelete,
      );
      final retainedRoot = LppEvidenceRoot.fromJsonString(
        ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'],
      );
      expect(
          retainedRoot?.self?.facts.keys.toSet(), snapshot.facts.keys.toSet());

      final preferences = await SharedPreferences.getInstance();
      final encodedReferences = preferences.getString(
        DocumentReferenceStore.storageKey,
      );
      expect(encodedReferences, isNotNull);
      final referenceRoot =
          jsonDecode(encodedReferences!) as Map<String, dynamic>;
      expect(referenceRoot['references'], isEmpty);
      expect(encodedReferences, isNot(contains(_rawMarker)));
    },
  );
}
