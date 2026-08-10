import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/mint_next_3a_task_store.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.hasEnvironment('PATROL_APP_BUNDLE_ID') ||
    bool.hasEnvironment('PATROL_TEST_LABEL') ||
    bool.hasEnvironment('PATROL_WAIT');

void main() {
  patrolTest(
    'proves flag-off keeps only task deletion then durable absence',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 3)),
    ($) async {
      expect(E2eRuntimeFlags.mintNext3aHarness, isTrue);
      expect(
        CoachProfileSeeds.activeSeed?.slug,
        'cadre_salarie_lpp_suisse_ready',
      );
      final leg = E2eRuntimeFlags.mintNext3aFlagOffLeg;
      expect(
        leg,
        isIn(const {'seed_on', 'delete_only_off', 'fresh_absence_off'}),
      );
      final expectedFlag = leg == 'seed_on';
      expect(E2eRuntimeFlags.mintNext3aRemoteFlag, expectedFlag);
      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNext3aProductHandoff, expectedFlag);

      const store = MintNext3aTaskStore();
      await $.pumpWidgetAndSettle(const MintApp());

      // Native plugins are registered only after the real app is pumped.
      if (leg == 'seed_on') {
        try {
          await store.delete();
        } on MintNext3aTaskStorageException catch (error) {
          fail(
            'native owned-key cleanup failed: '
            '${error.cause.runtimeType} ${error.cause}',
          );
        }
      }

      testOnlyRootRouter.go('/home');
      await _pumpFrames($);
      expect(_semantic('home_route_state'), findsOneWidget);

      switch (leg) {
        case 'seed_on':
          await _saveTaskFromRealToday($);
          expect(await store.read(), isNotNull);
          expect(
            _semantic('task:today.3a.verify_annual_credited_total'),
            findsOneWidget,
          );
        case 'delete_only_off':
          expect(await store.read(), isNotNull,
              reason: 'the flag-on seed must survive the process stop');
          expect(_semantic('action:today.open_mint_next_3a'), findsNothing);
          await _pumpUntil(
            $,
            _semantic('task:today.3a.verify_annual_credited_total'),
          );
          await _tap($, 'action:today.3a_task.open');
          expect(_semantic('node:3a.task_detail'), findsOneWidget);
          expect(_semantic('action:3a.task.delete'), findsOneWidget);
          for (final forbidden in const {
            'node:3a.teach_back',
            'node:3a.task_preview',
            'action:3a.task.save',
            'action:3a.safe_exit.open',
          }) {
            expect(_semantic(forbidden), findsNothing);
          }
          await _tap($, 'action:3a.task.delete');
          expect(_semantic('overlay:3a.task.delete_confirm'), findsOneWidget);
          await _tap($, 'action:3a.task.delete_confirm');
          await _pumpUntil($, _semantic('home_route_state'));
          expect(await store.read(), isNull);
          expect(
            _semantic('task:today.3a.verify_annual_credited_total'),
            findsNothing,
          );
          expect(_semantic('action:today.open_mint_next_3a'), findsNothing);
        case 'fresh_absence_off':
          expect(await store.read(), isNull,
              reason: 'flag-off deletion must survive the process stop');
          expect(
            _semantic('task:today.3a.verify_annual_credited_total'),
            findsNothing,
          );
          expect(_semantic('action:today.open_mint_next_3a'), findsNothing);
          expect(_semantic('action:today.3a_task.recover'), findsNothing);
      }
    },
  );
}

Future<void> _saveTaskFromRealToday(PatrolIntegrationTester $) async {
  await _tap($, 'action:today.open_mint_next_3a');
  expect(_semantic('status:tax.personal_unavailable'), findsOneWidget);
  await _tap($, 'choice:3a.teach_back.annual_total_all_accounts');
  await _tap($, 'action:3a.teach_back.check');
  await _tap($, 'action:3a.teach_back.continue');
  await _tap($, 'action:3a.task.save');
  expect(_semantic('node:3a.task_saved'), findsOneWidget);
  await _tap($, 'action:3a.task.return_today');
  await _pumpUntil(
    $,
    _semantic('task:today.3a.verify_annual_credited_total'),
  );
}

Finder _semantic(String identifier) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
      description: 'Semantics identifier "$identifier"',
    );

Future<void> _tap(PatrolIntegrationTester $, String identifier) async {
  final target = _semantic(identifier);
  await _pumpUntil($, target);
  await $.tester.ensureVisible(target);
  await $.tester.pump();
  await $.tester.tap(target);
  await _pumpFrames($);
}

Future<void> _pumpUntil(PatrolIntegrationTester $, Finder target) async {
  for (var attempt = 0; attempt < 40; attempt += 1) {
    await $.tester.pump(const Duration(milliseconds: 100));
    if (target.evaluate().isNotEmpty) return;
  }
  expect(target, findsOneWidget);
}

Future<void> _pumpFrames(PatrolIntegrationTester $) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await $.tester.pump(const Duration(milliseconds: 100));
  }
}
