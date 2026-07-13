import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'keeps Expat AVS local and opens the verification guide',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 5)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      final before = await ReportPersistenceService.loadAnswers();
      expect(before.containsKey('q_avs_years_abroad'), isFalse);

      await $.pumpWidgetAndSettle(const MintApp());
      await $.platformAutomator.mobile.openUrl('mint:///expatriation');
      await $.pumpAndSettle();

      await $(#expat_avs_tab).waitUntilVisible();
      await $(#expat_avs_tab).tap();
      await $.pumpAndSettle();

      await $(#expat_avs_years_picker).waitUntilVisible();
      await $(#expat_avs_start_scenario).waitUntilVisible();
      expect(
        find.bySemanticsIdentifier('expat_avs_scenario_result'),
        findsNothing,
      );
      expect(
        $.tester
            .widget<MintPickerTile>(
              find.byKey(const Key('expat_avs_years_picker')),
            )
            .value,
        isNull,
      );
      expect(
        $.tester
            .widget<FilledButton>(
              find.byKey(const Key('expat_avs_start_scenario')),
            )
            .onPressed,
        isNull,
      );

      await $(#expat_avs_years_picker).tap();
      await $.pumpAndSettle();
      await $.tester.drag(
        find.byType(CupertinoPicker),
        const Offset(0, -160),
      );
      await $.pumpAndSettle();
      await $(find.text('OK')).tap();
      await $.pumpAndSettle();
      expect(
        $.tester
            .widget<MintPickerTile>(
              find.byKey(const Key('expat_avs_years_picker')),
            )
            .value,
        4,
      );
      expect(await ReportPersistenceService.loadAnswers(), equals(before));

      await $(#expat_avs_start_scenario).tap();
      await $.pumpAndSettle();
      await $(find.byKey(const Key('expat_avs_scenario_result'))).scrollTo();
      await $(#expat_avs_scenario_result).waitUntilVisible();
      await $(#expat_avs_gap_unknown).waitUntilVisible();
      expect(find.textContaining(RegExp(r'CHF\s*[0-9]')), findsNothing);
      expect(await ReportPersistenceService.loadAnswers(), equals(before));

      await $(
        find.byKey(const Key('expat_avs_verification_guide_cta')),
      ).scrollTo();
      await $(#expat_avs_verification_guide_cta).waitUntilVisible();
      await $(#expat_avs_verification_guide_cta).tap();
      await $.pumpAndSettle();

      await $(find.byKey(const Key('avs_official_ci_request_cta'))).scrollTo();
      await $(#avs_official_ci_request_cta).waitUntilVisible();
      await $(find.byKey(const Key('avs_official_form_cta'))).scrollTo();
      await $(#avs_official_form_cta).waitUntilVisible();
      expect(await ReportPersistenceService.loadAnswers(), equals(before));
    },
  );
}
