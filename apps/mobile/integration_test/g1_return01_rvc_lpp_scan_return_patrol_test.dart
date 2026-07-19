import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _rvcRoute = '/rente-vs-capital';
const _expectedSyntheticCertificateSha256 =
    '44e89678edff36f64383a75c37bdcaa3c7ca49e7cb7242a3bb9c1371df9780f2';
const _visualReadyMarkerName =
    'mint-g1-return01-rvc-lpp-visual-ready-v1.marker';
const _visualReadyMarkerPayload = 'MINT_G1_RETURN01_RVC_LPP_VISUAL_READY_V1\n';

void main() {
  patrolTest(
    'returns from an exact-SHA synthetic LPP review to the live RVC route',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      final semantics = $.tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final visualReadyMarker = File(
        '${Directory.systemTemp.path}/$_visualReadyMarkerName',
      );
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      addTearDown(() async {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        if (await visualReadyMarker.exists()) {
          await visualReadyMarker.delete();
        }
        await ReportPersistenceService.clearDiagnostic();
      });
      if (await visualReadyMarker.exists()) {
        await visualReadyMarker.delete();
      }

      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final appContext = $.tester.element(materialApp);
      final profile = appContext.read<CoachProfileProvider>();
      final sessions = appContext.read<ScanSessionProvider>();
      profile.updateProfile(_rvcProfile());

      testOnlyRootRouter.go(_rvcRoute);
      await $.pumpAndSettle();
      await $(find.bySemanticsIdentifier('rvc_screen')).waitUntilVisible();

      final indicatifCta = find.byKey(
        const Key('indicatif_banner_lpp_cta'),
      );
      await $(indicatifCta).scrollTo().tap();
      await $.pumpAndSettle();

      final collector = find.byType(DataBlockEnrichmentScreen);
      await $(collector).waitUntilVisible();
      final collectorUri = GoRouterState.of($.tester.element(collector)).uri;
      expect(collectorUri.path, '/data-block/lpp');
      expect(collectorUri.queryParameters, const <String, String>{
        'returnUri': _rvcRoute,
      });

      await $(find.byKey(const Key('data_block_lpp_scan_cta')))
          .scrollTo()
          .tap();
      await $.pumpAndSettle();

      final scan = find.byType(DocumentScanScreen);
      await $(scan).waitUntilVisible();
      final scanUri = GoRouterState.of($.tester.element(scan)).uri;
      expect(scanUri.path, '/scan');
      expect(scanUri.queryParameters.keys, const <String>['scanReturnId']);
      final scanReturnId = scanUri.queryParameters['scanReturnId'];
      expect(scanReturnId, isNotNull);

      await $(find.byKey(const Key('document_scan_lpp_example_cta')))
          .scrollTo()
          .tap();
      await $.pumpAndSettle();
      await $(find.byKey(const Key('lpp_acquisition_self_continue'))).tap();
      await $.pumpAndSettle();

      final review = find.byType(ExtractionReviewScreen);
      await $(review).waitUntilVisible();
      final reviewUri = GoRouterState.of($.tester.element(review)).uri;
      expect(reviewUri.path, '/scan/review');
      expect(
        reviewUri.queryParameters.keys.toSet(),
        const <String>{'scanSessionId', 'scanReturnId'},
      );
      expect(reviewUri.queryParameters['scanReturnId'], scanReturnId);
      final scanSessionId = reviewUri.queryParameters['scanSessionId'];
      expect(scanSessionId, isNotNull);
      expect(
        sessions.byId(scanSessionId)?.lppAuthorization?.documentSha256,
        _expectedSyntheticCertificateSha256,
      );

      await $(find.byKey(const Key('lpp_review_source_date')))
          .scrollTo()
          .enterText('2025-12-31');
      await $(find.byKey(const Key('lpp_review_confirm_cta'))).scrollTo().tap();

      final impact = find.byType(DocumentImpactScreen);
      await $(impact).waitUntilVisible();
      final impactUri = GoRouterState.of($.tester.element(impact)).uri;
      expect(impactUri.path, '/scan/impact');
      expect(
        impactUri.queryParameters,
        <String, String>{
          'scanSessionId': scanSessionId!,
          'scanReturnId': scanReturnId!,
        },
      );

      await $(find.byKey(const Key('lpp_impact_retirement_cta')))
          .scrollTo()
          .tap();

      final returnedRvc = find.byType(RenteVsCapitalScreen);
      await $(returnedRvc).waitUntilVisible();
      expect(
        GoRouterState.of($.tester.element(returnedRvc)).uri.toString(),
        _rvcRoute,
      );
      expect(
        sessions.dataBlockScanReturnIntentById(scanReturnId),
        isNull,
      );
      await $(find.bySemanticsIdentifier('rvc_screen')).waitUntilVisible();

      await visualReadyMarker.writeAsString(
        _visualReadyMarkerPayload,
        flush: true,
      );
      final visualAcknowledgementDeadline = DateTime.now().add(
        const Duration(seconds: 90),
      );
      while (await visualReadyMarker.exists()) {
        if (DateTime.now().isAfter(visualAcknowledgementDeadline)) {
          fail('Timed out waiting for visual evidence acknowledgement');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    },
  );
}

CoachProfile _rvcProfile() => CoachProfile(
      birthYear: 1976,
      canton: 'VD',
      salaireBrutMensuel: 9000,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 350000,
        tauxConversion: 0.06,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2041),
        label: 'Retraite',
      ),
    );
