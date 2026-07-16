import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

const _staleBudgetInputs = <String, dynamic>{
  'q_pay_frequency': 'monthly',
  'q_net_income_period_chf': 999999.0,
  'q_housing_cost_period_chf': 888888.0,
  'q_debt_payments_period_chf': 777777.0,
  'q_tax_provision_monthly_chf': 666666.0,
  'q_lamal_premium_monthly_chf': 555555.0,
  'q_other_fixed_costs_monthly_chf': 444444.0,
  'q_budget_style': 'envelopes3',
};

void main() {
  patrolTest(
    'writes canonical budget facts and UI overrides before stale-cache death',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await $.pumpWidgetAndSettle(const MintApp());

      await $.platformAutomator.mobile.openUrl('mint:///budget');
      await $.pumpAndSettle();
      await $(#budget_setup_start_cta).waitUntilVisible();
      await $(#budget_setup_start_cta).tap();
      await $(#budget_setup_housing_input).waitUntilVisible();
      await $(#budget_setup_housing_input).enterText('2100');
      await $(#budget_setup_lamal_input).enterText('420');
      await $(#budget_setup_save_cta).scrollTo().tap();
      await $.pumpAndSettle();
      await $(#budget_available_hero).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///data-block/revenu');
      await $.pumpAndSettle();
      await $(#salary_input).waitUntilVisible();
      await $(#salary_input).enterText('96000');
      await $(#canton_picker).enterText('GE');
      await $(#birth_year_input).enterText('2001');
      await $(#salary_save_cta).scrollTo().tap();
      await $(#data_block_save_success).waitUntilVisible();

      await $.platformAutomator.mobile.openUrl('mint:///budget');
      await $.pumpAndSettle();
      await $(#budget_available_hero).waitUntilVisible();
      await $(#budget_future_input).scrollTo().enterText('700');
      await $(#budget_variables_input).scrollTo().enterText('1200');
      await $.pumpAndSettle();

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final element = $.tester.element(materialApp);
      final profileProvider = element.read<CoachProfileProvider>();
      final budgetProvider = element.read<BudgetProvider>();
      final mintStateProvider = element.read<MintStateProvider>();
      await budgetProvider.waitForOverridePersistence();
      for (var attempt = 0; attempt < 80; attempt++) {
        if (mintStateProvider.state?.budgetSnapshot != null) break;
        await $.tester.pump(const Duration(milliseconds: 100));
      }
      final profile = profileProvider.profile;
      expect(profile, isNotNull);
      expect(
          profileProvider.reportAnswersSnapshot,
          containsPair(
            'q_gross_salary_annual',
            96000,
          ));
      expect(
          profileProvider.reportAnswersSnapshot,
          containsPair(
            'q_housing_cost_period_chf',
            2100.0,
          ));
      expect(
          profileProvider.reportAnswersSnapshot,
          containsPair(
            'q_lamal_premium_monthly_chf',
            420.0,
          ));
      expect(budgetProvider.inputs?.housingCost, 2100.0);
      expect(budgetProvider.inputs?.healthInsurance, 420.0);
      expect(mintStateProvider.state?.budgetSnapshot, isNotNull);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getDouble('budget_override_future'), isNull);
      expect(preferences.getDouble('budget_override_variables'), 1200.0);
      expect(budgetProvider.plan?.variables, 1200.0);
      expect(
        budgetProvider.plan?.future,
        budgetProvider.plan!.available - 1200.0,
      );

      // Deliberately write the legacy derived cache last. Only the cold reader
      // may discard it; the process-death boundary proves it never wins.
      await preferences.setString(
        'budget_inputs_v1',
        jsonEncode(_staleBudgetInputs),
      );
      expect(preferences.getString('budget_inputs_v1'), contains('999999'));
    },
  );
}
