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
    'proves the bounded Mint Next 3a product handoff on native storage',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 3)),
    ($) async {
      expect(E2eRuntimeFlags.mintNext3aHarness, isTrue);
      expect(E2eRuntimeFlags.mintNext3aRemoteFlag, isTrue);
      expect(
        CoachProfileSeeds.activeSeed?.slug,
        'cadre_salarie_lpp_suisse_ready',
      );
      expect(
        E2eRuntimeFlags.mintNext3aScenario,
        isIn(const {
          'save_kill_relaunch_fresh_read',
          'delete_kill_relaunch_absent',
          'safe_exit_no_save',
          'cleanup_after_forced_scenario_failure',
        }),
      );
      final scenario = E2eRuntimeFlags.mintNext3aScenario;
      if (scenario == 'cleanup_after_forced_scenario_failure') {
        expect(E2eRuntimeFlags.mintNext3aForceScenarioFailure, isTrue);
        // This exact line is the runner-owned sentinel. The native runner only
        // exposes it through Patrol's real `Bad state:` failure line.
        throw StateError('MINT_E2E_EXPECTED_FORCED_SCENARIO_FAILURE');
      }
      final leg = E2eRuntimeFlags.mintNext3aLeg;
      final scenarioLeg = '$scenario|$leg';
      expect(
        scenarioLeg,
        isIn(const {
          'save_kill_relaunch_fresh_read|save',
          'save_kill_relaunch_fresh_read|fresh_saved_read',
          'delete_kill_relaunch_absent|delete',
          'delete_kill_relaunch_absent|post_delete_absence',
          'safe_exit_no_save|single',
        }),
      );

      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isTrue);

      const store = MintNext3aTaskStore();
      await $.pumpWidgetAndSettle(const MintApp());

      // Native plugins are registered only after the real app is pumped.
      const precleanPairs = {
        'save_kill_relaunch_fresh_read|save',
        'safe_exit_no_save|single',
      };
      if (precleanPairs.contains(scenarioLeg)) {
        try {
          await store.delete();
        } on MintNext3aTaskStorageException catch (error) {
          fail(
            'native owned-key cleanup failed: '
            '${error.cause.runtimeType} ${error.cause}',
          );
        }
      }

      // Use the production router only to install the local-mode fixture's
      // starting location. The journey itself enters through the real Today
      // card and all persistence uses the native plugin.
      testOnlyRootRouter.go('/home');
      await _pumpFrames($);
      if (_semantic('home_route_state').evaluate().isEmpty) {
        fail(
          'real Today fixture failed: '
          'route=${testOnlyRootRouter.routerDelegate.currentConfiguration.uri}',
        );
      }

      switch (scenarioLeg) {
        case 'save_kill_relaunch_fresh_read|save':
          await _saveTaskFromRealToday($);
          expect(await store.read(), isNotNull);
        case 'save_kill_relaunch_fresh_read|fresh_saved_read':
          expect(await store.read(), isNotNull,
              reason: 'the save leg must survive an external process stop');
          await _pumpUntil(
            $,
            _semantic('task:today.3a.verify_annual_credited_total'),
          );
        case 'delete_kill_relaunch_absent|delete':
          expect(await store.read(), isNotNull,
              reason: 'the prior native leg must have persisted the task');
          await _deleteRestoredTaskFromRealToday($);
          expect(await store.read(), isNull);
        case 'delete_kill_relaunch_absent|post_delete_absence':
          expect(await store.read(), isNull,
              reason: 'deletion must survive an external process stop');
          expect(
            _semantic('task:today.3a.verify_annual_credited_total'),
            findsNothing,
          );
        case 'safe_exit_no_save|single':
          await _leaveWithoutSavingFromRealToday($);
          expect(await store.read(), isNull);
      }
    },
  );
}

Future<void> _saveTaskFromRealToday(PatrolIntegrationTester $) async {
  await _tap($, 'action:today.open_mint_next_3a');
  expect(_semantic('status:tax.personal_unavailable'), findsOneWidget);
  await _tap($, 'choice:3a.teach_back.annual_total_all_accounts');
  await _tap($, 'action:3a.teach_back.check');
  expect(_semantic('feedback:3a.teach_back.correct'), findsOneWidget);
  await _tap($, 'action:3a.teach_back.continue');
  expect(_semantic('disclosure:3a.task.local_only'), findsOneWidget);
  await _tap($, 'action:3a.task.save');
  expect(_semantic('node:3a.task_saved'), findsOneWidget);
  await _tap($, 'action:3a.task.return_today');
  await _pumpUntil(
    $,
    _semantic('task:today.3a.verify_annual_credited_total'),
  );
}

Future<void> _deleteRestoredTaskFromRealToday(
  PatrolIntegrationTester $,
) async {
  await _pumpUntil(
    $,
    _semantic('task:today.3a.verify_annual_credited_total'),
  );
  await _tap($, 'action:today.3a_task.open');
  expect(_semantic('node:3a.task_detail'), findsOneWidget);
  await _tap($, 'action:3a.task.delete');
  expect(_semantic('overlay:3a.task.delete_confirm'), findsOneWidget);
  await _tap($, 'action:3a.task.delete_confirm');
  await _pumpUntil($, _semantic('home_route_state'));
}

Future<void> _leaveWithoutSavingFromRealToday(
  PatrolIntegrationTester $,
) async {
  await _tap($, 'action:today.open_mint_next_3a');
  await _tap($, 'action:3a.safe_exit.open');
  expect(_semantic('overlay:3a.safe_exit'), findsOneWidget);
  await _tap($, 'action:3a.safe_exit.leave_without_saving');
  await _pumpUntil($, _semantic('home_route_state'));
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
  await $.tester.pump();
  await _pumpFrames($);
}

Future<void> _pumpUntil(
  PatrolIntegrationTester $,
  Finder target,
) async {
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
