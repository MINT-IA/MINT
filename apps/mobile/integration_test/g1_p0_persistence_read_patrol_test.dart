import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'reads persisted revenue in the mortgage consumer after process death',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///hypotheque');
      await $.pumpAndSettle();

      await $(#mortgage_afford_result).waitUntilVisible();
      await $(#mortgage_income_amount).scrollTo();
      await $(#mortgage_income_amount).waitUntilVisible();
      expect(find.textContaining("96'000"), findsAtLeastNWidgets(1));
      expect(find.textContaining('GE'), findsAtLeastNWidgets(1));
    },
  );
}
