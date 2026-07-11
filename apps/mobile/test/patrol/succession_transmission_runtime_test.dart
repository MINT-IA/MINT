import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'routes missing property value to the patrimoine collector',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///succession');
      await $.pumpAndSettle();

      await $(#succession_property_missing).waitUntilVisible();
      await $('Renseigner mon patrimoine').tap();
      await $.pumpAndSettle();
      await $(#property_market_value_input).waitUntilVisible();
      await $(#patrimoine_save_cta).waitUntilVisible();
    },
  );

  patrolTest(
    'opens succession from seeded property ledger facts',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers(const {
        'q_property_market_value': 1200000,
        '_coach_dettes_hypotheque': 450000,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///succession');
      await $.pumpAndSettle();

      await $(#succession_parents_note).waitUntilVisible();
      expect(find.textContaining("1'200'000"), findsWidgets);
      expect(find.textContaining("450'000"), findsWidgets);
      expect(find.textContaining("750'000"), findsWidgets);
    },
  );
}
