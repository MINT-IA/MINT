import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'writes a synthetic plan then hides it after a canonical ledger mutation',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      await FinancialPlanService.clear();
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_firstname': 'Runtime synthetic',
        'q_birth_year': 1990,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_gross_salary_annual': 96000.0,
        'q_nombre_mois': 12.0,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      await $.pumpWidgetAndSettle(const MintApp());
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final element = $.tester.element(materialApp);
      final ledger = element.read<CoachProfileProvider>();
      final plans = element.read<FinancialPlanProvider>();
      await ledger.waitForReportAnswers();
      await plans.loadFromPersistence();

      final profile = ledger.profile;
      expect(profile, isNotNull);
      expect(plans.currentPlan, isNull);

      final generated = await PlanGenerationService.generate(
        goalDescription: 'Objectif logement synthétique BND-06',
        goalCategory: 'goal_house',
        targetDate: DateTime.now().add(const Duration(days: 7)),
        profile: profile!,
        goalAmount: 54321,
      );
      expect(generated.monthlyTarget, 54321);
      expect(generated.profileHashAtGeneration, computeProfileHash(profile));
      await plans.setPlan(generated);
      expect(plans.currentPlan?.id, generated.id);
      expect(plans.isPlanStale, isFalse);

      final applied = await ledger.applySaveFact('incomeGrossMonthly', 9000.0);
      expect(applied, isTrue);
      await $.tester.pump();
      expect(plans.isPlanStale, isTrue);
      expect(
        plans.currentPlan?.profileHashAtGeneration,
        isNot(computeProfileHash(ledger.profile!)),
      );

      await $.platformAutomator.mobile.openUrl('mint:///home');
      await $.pumpAndSettle();
      await $(#financial_plan_stale_state).waitUntilVisible();
      await $(#financial_plan_stale_recalculate).waitUntilVisible();
      expect(find.text('54’321 CHF / mois'), findsNothing);
    },
  );
}
