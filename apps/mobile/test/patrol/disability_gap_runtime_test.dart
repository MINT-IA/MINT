import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'opens disability gap by deeplink and collects missing facts',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///invalidite');
      await $.pumpAndSettle();

      await $(#disability_gap_ledger_facts).waitUntilVisible();
      await $(#disability_gap_enrich_cta).tap();

      await $(#salary_input).waitUntilVisible();
      await $(#salary_input).enterText('96000');
      await $(#salary_save_cta).scrollTo().tap();
      await $(#data_block_save_success).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///invalidite');
      await $.pumpAndSettle();

      await $(#disability_gap_ledger_facts).waitUntilVisible();
      await $(#disability_gap_salary_fact).waitUntilVisible();
      await $(#disability_gap_enrich_cta).tap();

      await $(#birth_year_input).waitUntilVisible();
      await $(#birth_year_input).enterText('1981');
      await $(#salary_save_cta).scrollTo().tap();
      await $(#data_block_save_success).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///invalidite');
      await $.pumpAndSettle();

      await $(#disability_gap_ledger_facts).waitUntilVisible();
      await $(#disability_gap_age_fact).waitUntilVisible();
      await $(#disability_gap_enrich_cta).tap();

      await $(#savings_input).waitUntilVisible();
      await $(#savings_input).enterText('42000');
      await $(#patrimoine_save_cta).tap();
      await $(#data_block_save_success).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///invalidite');
      await $.pumpAndSettle();

      await $(#disability_gap_ledger_facts).waitUntilVisible();
      await $(#disability_gap_enrich_cta).tap();

      await $(#budget_setup_housing_input).waitUntilVisible();
      await $(#budget_setup_housing_input).enterText('2200');
      await $(#budget_setup_lamal_input).enterText('420');
      await $(#budget_setup_save_cta).scrollTo().tap();

      await $(#disability_gap_ledger_facts).waitUntilVisible();
      await $(#disability_gap_expenses_fact).waitUntilVisible();
      await $(#disability_gap_result_section).scrollTo();
      await $(#disability_gap_result_section).waitUntilVisible();
    },
  );
}
