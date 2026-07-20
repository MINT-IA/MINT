import 'dart:io';

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
    'cold process resumes at inheritance pact without seeding the reader',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      expect(FeatureFlags.successionEvidenceCollectionEnabled, isTrue);
      final preferences = await SharedPreferences.getInstance();
      final writerPid = preferences.getInt(successionWriterPid);
      final writerState = preferences.getString(successionWriterStateWitness);
      expect(writerPid, isNotNull);
      expect(writerState, isNotNull);
      expect(pid, isNot(writerPid));
      if (writerPid == null || writerPid <= 0 || writerPid == pid) {
        fail('Reader did not cross the required writer process boundary');
      }

      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted[coachEstateEvidenceRootKey], writerState);
      final root = EstateEvidenceRoot.fromJsonString(
        persisted[coachEstateEvidenceRootKey],
        now: DateTime.now,
      );
      final will = root!.estateInstruments
          .singleWhere((slot) => slot.kind == EstateInstrumentKind.will);
      expect(will.state, EstateInstrumentSlotState.confirmedAbsent);

      await $.pumpWidgetAndSettle(const MintApp());
      await $.platformAutomator.mobile.openUrl('mint:///succession');
      await $.pumpAndSettle();
      await $(#succession_instrument_inheritancePact_question).scrollTo();
      await $(#succession_instrument_inheritancePact_question)
          .waitUntilVisible();
    },
  );
}
