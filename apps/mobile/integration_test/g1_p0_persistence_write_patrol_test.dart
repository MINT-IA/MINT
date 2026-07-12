import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'writes synthetic revenue facts through real controls',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///data-block/revenu');
      await $.pumpAndSettle();

      await $(#salary_input).waitUntilVisible();
      await $(#salary_input).enterText('96000');
      await $(#canton_picker).enterText('GE');
      await $(#birth_year_input).enterText('2001');
      await $(#has_pension_fund_switch).tap();
      await $(#salary_save_cta).scrollTo().tap();
      await $(#data_block_save_success).waitUntilVisible();
    },
  );
}
