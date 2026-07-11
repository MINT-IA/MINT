import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'routes missing wealth fact to the patrimoine collector',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers({
        'q_birth_year': DateTime.now().year - 62,
        'q_canton': 'GE',
        'q_children': 2,
        'q_civil_status': 'marie',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///life-event/donation');
      await $.pumpAndSettle();

      await $(#donation_ledger_facts).waitUntilVisible();
      await $(#donation_wealth_missing_cta).scrollTo();
      await $(#donation_wealth_missing_cta).tap();
      await $.pumpAndSettle();

      await $(#wealth_estimate_input).waitUntilVisible();
      await $(#patrimoine_save_cta).waitUntilVisible();
    },
  );

  patrolTest(
    'opens donation from seeded ledger facts and shows results',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers({
        'q_birth_year': DateTime.now().year - 62,
        'q_canton': 'GE',
        'q_children': 2,
        'q_civil_status': 'marie',
        'q_wealth_estimate': 1250000,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///life-event/donation');
      await $.pumpAndSettle();

      await $(#donation_ledger_facts).waitUntilVisible();
      expect(find.textContaining("1'250'000"), findsWidgets);

      await $(#donation_simulate_cta).scrollTo();
      await $(#donation_simulate_cta).tap();
      await $.pumpAndSettle();

      await $(#donation_result_cards).scrollTo();
      await $(#donation_result_cards).waitUntilVisible();
      expect(find.text('IMPÔT SUR LA DONATION'), findsOneWidget);
    },
  );
}
