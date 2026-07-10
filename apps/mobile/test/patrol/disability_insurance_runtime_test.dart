import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'opens employee disability by deeplink and collects missing facts',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///disability/insurance');
      await $.pumpAndSettle();

      await $(#disability_insurance_ledger_facts).waitUntilVisible();
      await $(#disability_insurance_enrich_cta).tap();

      await $(#salary_input).waitUntilVisible();
      await $(#salary_input).enterText('96000');
      await $(#salary_save_cta).scrollTo().tap();
      await $(#data_block_save_success).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///disability/insurance');
      await $.pumpAndSettle();

      await $(#disability_insurance_ledger_facts).waitUntilVisible();
      await $(#disability_insurance_salary_fact).waitUntilVisible();
      await $(#disability_insurance_enrich_cta).tap();

      await $(#savings_input).waitUntilVisible();
      await $(#savings_input).enterText('42000');
      await $(#patrimoine_save_cta).tap();
      await $(#data_block_save_success).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///disability/insurance');
      await $.pumpAndSettle();

      await $(#disability_insurance_ledger_facts).waitUntilVisible();
      await $(#disability_insurance_enrich_cta).tap();

      await $(#budget_setup_housing_input).waitUntilVisible();
      await $(#budget_setup_housing_input).enterText('2200');
      await $(#budget_setup_lamal_input).enterText('420');
      await $(#budget_setup_save_cta).scrollTo().tap();

      await $(#disability_insurance_ledger_facts).waitUntilVisible();
      await $(#disability_insurance_expenses_fact).waitUntilVisible();
      await $(#disability_insurance_result_section).scrollTo();
      await $(#disability_insurance_result_section).waitUntilVisible();
    },
  );
}
