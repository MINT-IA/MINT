import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'native metadata input persists the strict will reference',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      expect(FeatureFlags.successionEvidenceCollectionEnabled, isTrue);
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers(const {
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_property_market_value': 900000,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///succession');
      await $.pumpAndSettle();
      await $(#succession_instrument_will_question).scrollTo();
      await $(#succession_instrument_will_present).tap();
      await $(#succession_instrument_will_source_date).enterText('2026-01-15');
      await $(#succession_instrument_will_legal_year).enterText('2026');
      await $(#succession_instrument_will_save).tap();
      await $(#succession_answer_saved).waitUntilVisible();

      final persisted = await ReportPersistenceService.loadAnswers();
      final root = EstateEvidenceRoot.fromJsonString(
        persisted[coachEstateEvidenceRootKey],
        now: DateTime.now,
      );
      final will = root!.estateInstruments
          .singleWhere((slot) => slot.kind == EstateInstrumentKind.will);
      expect(will.state, EstateInstrumentSlotState.confirmedPresent);
      expect(will.evidence!.sourceDate, DateTime.utc(2026, 1, 15));
      expect(will.evidence!.legalYear, 2026);
    },
  );
}
