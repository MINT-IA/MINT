import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
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
      FeatureFlags.financialPlanSetupEnabled = true;
      addTearDown(() {
        FeatureFlags.financialPlanSetupEnabled = false;
      });

      await ReportPersistenceService.clearDiagnostic();
      await FinancialPlanService.clear();
      final inputAsOf = DateTime.now().toUtc();
      final targetDate = DateTime.utc(
        inputAsOf.year,
        inputAsOf.month + 1,
      );
      final dateOfBirth = DateTime.utc(
        targetDate.year - 58,
        targetDate.month,
        targetDate.day,
      );
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_firstname': 'Runtime synthetic',
        'q_birth_year': dateOfBirth.year,
        'q_date_of_birth': '${dateOfBirth.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth.day.toString().padLeft(2, '0')}',
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_gross_salary_annual': 96000.0,
        'q_nombre_mois': 12.0,
        'q_has_pension_fund': false,
        '_coach_updated_at': inputAsOf.toIso8601String(),
        '__provenance': {
          'dateOfBirth': {
            'source': 'userInput',
            'updatedAt': inputAsOf.toIso8601String(),
            'sourceDate': null,
          },
          'prevoyance.hasPensionFund': {
            'source': 'userInput',
            'updatedAt': inputAsOf.toIso8601String(),
            'sourceDate': null,
          },
        },
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

      final confirmationTime = DateTime.now();
      final owner = await ledger.ensureCanonicalProfileOwner();
      final generated = await PlanGenerationService.generate(
        goalDescription: 'Objectif retraite synthétique BND-06',
        goalCategory: 'goal_retirement_plan',
        targetDate: targetDate,
        profile: profile!,
        profileOwnerId: owner,
        selfLppSnapshot: null,
        goalAmount: 54321,
        now: confirmationTime,
      );
      expect(generated.monthlyTarget, 54321);
      expect(generated.dependencyBranch, 'retirementNoLpp');
      expect(generated.dependencyHash, generated.profileHashAtGeneration);
      await plans.setPlan(generated.copyWith(confirmedAt: confirmationTime));
      expect(plans.currentPlan?.id, generated.id);
      expect(plans.isPlanStale, isFalse);

      final changedDateOfBirth = DateTime.utc(
        targetDate.year - 59,
        targetDate.month,
        targetDate.day,
      );
      final applied = await ledger.applySaveFact(
        'dateOfBirth',
        '${changedDateOfBirth.year.toString().padLeft(4, '0')}-'
            '${changedDateOfBirth.month.toString().padLeft(2, '0')}-'
            '${changedDateOfBirth.day.toString().padLeft(2, '0')}',
      );
      expect(applied, isTrue);
      await $.tester.pump();
      expect(plans.isPlanStale, isTrue);
      expect(
        plans.currentPlan?.profileHashAtGeneration,
        generated.profileHashAtGeneration,
      );

      await $.platformAutomator.mobile.openUrl('mint:///home');
      await $.pumpAndSettle();
      await $(find.bySemanticsIdentifier('financial_plan_stale_state'))
          .waitUntilVisible();
      await $(find.bySemanticsIdentifier('financial_plan_stale_recalculate'))
          .waitUntilVisible();
      expect(find.text('54’321 CHF / mois'), findsNothing);
    },
  );
}
