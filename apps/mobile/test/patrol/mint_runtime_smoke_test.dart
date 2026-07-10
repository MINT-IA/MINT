import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'launches Mint through the Patrol runner',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 3)),
    ($) async {
      await $.pumpWidgetAndSettle(const MintApp());

      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );
}
