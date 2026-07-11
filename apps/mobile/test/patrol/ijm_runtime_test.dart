import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'opens IJM with missing ledger facts',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///independants/ijm');
      await $.pumpAndSettle();

      await $(#ijm_ledger_facts).waitUntilVisible();
      await $(#ijm_income_fact).waitUntilVisible();
      await $(#ijm_age_fact).waitUntilVisible();
      expect(find.byKey(const Key('ijm_result_cards')), findsNothing);
    },
  );
}
