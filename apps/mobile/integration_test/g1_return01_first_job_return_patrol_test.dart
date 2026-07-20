import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _firstJobProofEnabled = bool.fromEnvironment('MINT_TEST_FIRST_JOB');
const _visualReadyMarkerName = 'mint-g1-return01-visual-ready-v1.marker';
const _visualReadyMarkerPayload = 'MINT_G1_RETURN01_VISUAL_READY_V1\n';

void main() {
  patrolTest(
    'uses the live First Job CTA and returns to its exact route after save',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      if (!_firstJobProofEnabled || !FeatureFlags.enableFirstJobScreen) {
        fail(
          'First Job runtime proof requires '
          '--dart-define=MINT_TEST_FIRST_JOB=true',
        );
      }
      final visualReadyMarker = File(
        '${Directory.systemTemp.path}/$_visualReadyMarkerName',
      );
      addTearDown(() async {
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

      testOnlyRootRouter.go('/first-job');
      await $.pumpAndSettle();
      final firstJob = find.byType(FirstJobScreen);
      await $(firstJob).waitUntilVisible();

      final enrichCta = find.byKey(
        const Key('first_job_enrich_profile_cta'),
      );
      await $(enrichCta).scrollTo();
      await $(enrichCta).tap();
      await $.pumpAndSettle();

      final collector = find.byType(DataBlockEnrichmentScreen);
      await $(collector).waitUntilVisible();
      final collectorUri = GoRouterState.of($.tester.element(collector)).uri;
      expect(collectorUri.path, '/data-block/revenu');
      expect(collectorUri.queryParameters['returnUri'], '/first-job');

      await $(find.byKey(const Key('salary_input'))).enterText('96000');
      await $(find.byKey(const Key('canton_picker'))).enterText('GE');
      await $(find.byKey(const Key('birth_year_input'))).enterText('2001');
      final saveCta = find.byKey(const Key('salary_save_cta'));
      await $(saveCta).scrollTo();
      await $(saveCta).tap();
      await $.pumpAndSettle();

      final returnedScreen = find.byType(FirstJobScreen);
      await $(returnedScreen).waitUntilVisible();
      final returnedUri = GoRouterState.of(
        $.tester.element(returnedScreen),
      ).uri;
      expect(returnedUri.toString(), '/first-job');

      Map<String, dynamic> persisted = const <String, dynamic>{};
      for (var attempt = 0; attempt < 80; attempt++) {
        persisted = await ReportPersistenceService.loadAnswers();
        if (persisted['q_gross_salary_annual'] == 96000.0 &&
            persisted['q_canton'] == 'GE' &&
            persisted['q_birth_year'] == 2001) {
          break;
        }
        await $.tester.pump(const Duration(milliseconds: 100));
      }
      expect(persisted['q_gross_salary_annual'], 96000.0);
      expect(persisted['q_canton'], 'GE');
      expect(persisted['q_birth_year'], 2001);

      final salaryAuthority = find.byKey(
        const Key('first_job_salary_authority'),
      );
      await $(salaryAuthority).scrollTo();
      await $(salaryAuthority).waitUntilVisible();

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
