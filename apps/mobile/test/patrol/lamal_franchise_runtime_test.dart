import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'opens LAMal franchise by deeplink and collects missing ledger facts',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      await ReportPersistenceService.saveAnswers(const {});
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///assurances/lamal');
      await $.pumpAndSettle();

      await $(#lamal_ledger_facts).waitUntilVisible();
      await $(#lamal_missing_facts_card).waitUntilVisible();
      await $(#lamal_enrich_cta).tap();

      await $(#budget_setup_housing_input).waitUntilVisible();
      await $(#budget_setup_housing_input).enterText('2200');
      await $(#budget_setup_lamal_input).enterText('390');
      await $(#budget_setup_lamal_franchise_input).tap();
      await $("CHF 2'500").tap();
      await $(#budget_setup_medical_input).waitUntilVisible();
      await $(#budget_setup_medical_input).scrollTo().enterText('120');
      await $(#budget_setup_save_cta).scrollTo().tap();

      await $(#lamal_ledger_facts).waitUntilVisible();
      await $(#lamal_premium_fact).waitUntilVisible();
      await $(#lamal_current_franchise_fact).waitUntilVisible();
      await $(#lamal_medical_fact).waitUntilVisible();
      await $(#lamal_result_section).scrollTo();
      await $(#lamal_result_section).waitUntilVisible();
    },
  );
}
