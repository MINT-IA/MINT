import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'opens coverage check from seeded ledger facts and shows result',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.saveAnswers(const {
        'q_canton': 'VD',
        'q_employment_status': 'self_employed',
        'q_children': 2,
        'q_housing_status': 'owner',
        '_coach_dettes_hypotheque': 500000,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///assurances/coverage');
      await $.pumpAndSettle();

      await $(#coverage_ledger_facts).waitUntilVisible();
      await $(#coverage_status_fact).waitUntilVisible();
      await $(#coverage_canton_fact).waitUntilVisible();
      await $(#coverage_family_fact).waitUntilVisible();
      await $(#coverage_housing_fact).waitUntilVisible();
      await $(#coverage_mortgage_fact).waitUntilVisible();
      await $(#coverage_result_section).scrollTo();
      await $(#coverage_result_section).waitUntilVisible();
    },
  );

  patrolTest(
    'routes missing household facts to composition menage collector',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.saveAnswers(const {
        'q_canton': 'VD',
        'q_employment_status': 'independant',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///assurances/coverage');
      await $.pumpAndSettle();

      await $(#coverage_ledger_facts).waitUntilVisible();
      await $(#coverage_profile_enrich_cta).tap();
      await $.pumpAndSettle();
      await $(#children_count_input).waitUntilVisible();
      await $(#housing_status_renter_choice).waitUntilVisible();
      await $(#household_save_cta).waitUntilVisible();
    },
  );

  patrolTest(
    'routes missing owner mortgage balance to patrimoine collector',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.saveAnswers(const {
        'q_canton': 'VD',
        'q_employment_status': 'independant',
        'q_children': 0,
        'q_housing_status': 'owner',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///assurances/coverage');
      await $.pumpAndSettle();

      await $(#coverage_ledger_facts).waitUntilVisible();
      await $(#coverage_profile_enrich_cta).tap();
      await $.pumpAndSettle();
      await $(#mortgage_balance_input).waitUntilVisible();
      await $(#patrimoine_save_cta).waitUntilVisible();
    },
  );
}
