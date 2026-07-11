import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'opens job comparison from seeded ledger facts and shows result',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      await ReportPersistenceService.saveAnswers({
        'q_gross_salary_annual': 96000,
        'q_birth_year': DateTime.now().year - 40,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl(
        'mint:///simulator/job-comparison',
      );
      await $.pumpAndSettle();

      await $(#job_compare_ledger_facts).waitUntilVisible();
      await $(#job_compare_salary_fact).waitUntilVisible();
      await $(#job_compare_age_fact).waitUntilVisible();
      await $(#job_compare_compare_cta).scrollTo().tap();
      await $(#job_compare_result).scrollTo();
      await $(#job_compare_result).waitUntilVisible();
    },
  );
}
