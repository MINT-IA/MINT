import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'cold reader rejects stale budget inputs and converges every consumer',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      await $.pumpWidgetAndSettle(const MintApp());

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final element = $.tester.element(materialApp);
      final profileProvider = element.read<CoachProfileProvider>();
      await profileProvider.waitForReportAnswers();

      final preferences = await SharedPreferences.getInstance();
      final budgetProvider = element.read<BudgetProvider>();
      final mintStateProvider = element.read<MintStateProvider>();
      for (var attempt = 0; attempt < 80; attempt++) {
        if (budgetProvider.inputs != null &&
            mintStateProvider.state?.budgetSnapshot != null &&
            !preferences.containsKey('budget_inputs_v1')) {
          break;
        }
        await $.tester.pump(const Duration(milliseconds: 100));
      }
      await budgetProvider.waitForOverridePersistence();

      final profile = profileProvider.profile;
      expect(profile, isNotNull);
      final canonical = BudgetInputs.fromCoachProfile(profile!);
      final budgetInputs = budgetProvider.inputs;
      final plan = budgetProvider.plan;
      final snapshot = mintStateProvider.state?.budgetSnapshot;
      final expectedSnapshot = BudgetLivingEngine.compute(profile);

      expect(preferences.containsKey('budget_inputs_v1'), isFalse);
      expect(preferences.getDouble('budget_override_future'), isNull);
      expect(preferences.getDouble('budget_override_variables'), 1200.0);
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

      expect(budgetInputs, isNotNull);
      expect(budgetInputs!.netIncome, closeTo(canonical.netIncome, 1e-9));
      expect(budgetInputs.netIncome, isNot(999999.0));
      expect(budgetInputs.housingCost, 2100.0);
      expect(budgetInputs.healthInsurance, 420.0);
      expect(budgetInputs.taxProvision, closeTo(canonical.taxProvision, 1e-9));

      expect(plan, isNotNull);
      expect(plan!.variables, math.min(1200.0, plan.available));
      expect(plan.future, plan.available - plan.variables);
      expect(snapshot, isNotNull);
      expect(
        snapshot!.present.monthlyNet,
        closeTo(canonical.netIncome, 1e-9),
      );
      expect(
        snapshot.present.monthlyCharges,
        closeTo(expectedSnapshot.present.monthlyCharges, 1e-9),
      );
      expect(
        snapshot.present.monthlyFree,
        closeTo(expectedSnapshot.present.monthlyFree, 1e-9),
      );

      await $.platformAutomator.mobile.openUrl('mint:///budget');
      await $.pumpAndSettle();
      await $(#budget_available_hero).waitUntilVisible();
      final hero = $.tester.widget<MintCountUp>(
        find.byKey(const Key('budget_available_hero')),
      );
      expect(hero.value, closeTo(snapshot.present.monthlyFree, 1e-9));
      await $(#budget_future_input).scrollTo();
      await $(#budget_future_input).waitUntilVisible();
      await $(#budget_variables_input).scrollTo();
      await $(#budget_variables_input).waitUntilVisible();
    },
  );
}
