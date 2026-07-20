import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/g1_succession_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'writes explicit arrangement and will absence before process death',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      expect(FeatureFlags.successionEvidenceCollectionEnabled, isTrue);
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers(const {
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'marie',
        'q_property_market_value': 1200000,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///succession');
      await $.pumpAndSettle();
      await $(#succession_arrangement_question).scrollTo();
      await $(#succession_arrangement_enum).tap();
      await $.pumpAndSettle();
      final participation = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem<Enum> &&
            widget.value == MatrimonialRegimeKind.participationInAcquests,
        description: 'participation-in-acquests arrangement option',
      );
      expect(participation, findsWidgets);
      await $.tester.tap(participation.last);
      await $.pumpAndSettle();
      await $(#succession_arrangement_save).tap();
      await $(#succession_answer_saved).waitUntilVisible();
      await $(#succession_next_question).tap();

      await $(#succession_instrument_will_question).waitUntilVisible();
      await $(#succession_instrument_will_absent).tap();
      await $(#succession_answer_saved).waitUntilVisible();
      await $(#succession_next_question).tap();
      await $(#succession_instrument_inheritancePact_question)
          .waitUntilVisible();

      final persisted = await ReportPersistenceService.loadAnswers();
      final strictRoot = persisted[coachEstateEvidenceRootKey];
      expect(strictRoot, isA<String>());
      final preferences = await SharedPreferences.getInstance();
      expect(await preferences.setInt(successionWriterPid, pid), isTrue);
      expect(
        await preferences.setString(
          successionWriterStateWitness,
          strictRoot as String,
        ),
        isTrue,
      );
      expect(preferences.getInt(successionWriterPid), pid);
    },
  );
}
