import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'cold synthetic reader recovers without reverse writes then invalidates',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.financialPlanSetupEnabled = true;
      addTearDown(() {
        FeatureFlags.financialPlanSetupEnabled = false;
      });

      await $.pumpWidgetAndSettle(const MintApp());
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final element = $.tester.element(materialApp);
      final ledger = element.read<CoachProfileProvider>();
      final plans = element.read<FinancialPlanProvider>();
      await ledger.waitForReportAnswers();
      await plans.loadFromPersistence();

      expect(ledger.profile, isNotNull);
      expect(plans.currentPlan, isNotNull);
      expect(plans.isPlanStale, isTrue);

      await $.platformAutomator.mobile.openUrl('mint:///home');
      await $.pumpAndSettle();
      await $(find.bySemanticsIdentifier('financial_plan_stale_state'))
          .waitUntilVisible();
      await $(find.bySemanticsIdentifier('financial_plan_stale_recalculate'))
          .waitUntilVisible();
      expect(find.text('54’321 CHF / mois'), findsNothing);

      final initialPlan = plans.currentPlan!;
      final initialPlanId = initialPlan.id;
      final goalDescriptionBefore = initialPlan.goalDescription;
      final goalCategoryBefore = initialPlan.goalCategory;
      final targetDateBefore = initialPlan.targetDate;
      final finalTargetBefore = initialPlan.milestones.last.targetAmount;
      final ledgerJsonBeforeRegeneration = jsonEncode(
        ledger.reportAnswersSnapshot,
      );

      await $(
        find.bySemanticsIdentifier('financial_plan_stale_recalculate'),
      ).tap();
      final reviewButton = $(
        find.bySemanticsIdentifier('financial_plan_setup_review'),
      );
      await reviewButton.scrollTo();
      await reviewButton.waitUntilVisible();
      await reviewButton.tap();
      await $(
        find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
      ).waitUntilVisible();
      final confirmButton = $(
        find.bySemanticsIdentifier('financial_plan_setup_confirm'),
      );
      await confirmButton.scrollTo();
      await confirmButton.waitUntilVisible();
      await confirmButton.tap();
      for (var attempt = 0; attempt < 120; attempt++) {
        if (!plans.isPlanStale && plans.currentPlan?.id != initialPlanId) break;
        await $.tester.pump(const Duration(milliseconds: 100));
      }

      final regenerated = plans.currentPlan;
      expect(regenerated, isNotNull);
      expect(regenerated!.id, isNot(initialPlanId));
      expect(
        regenerated.dependencyHash,
        regenerated.profileHashAtGeneration,
      );
      final ledgerJsonAfterRegeneration = jsonEncode(
        ledger.reportAnswersSnapshot,
      );
      expect(ledgerJsonAfterRegeneration, ledgerJsonBeforeRegeneration);
      expect(regenerated.goalDescription, goalDescriptionBefore);
      expect(regenerated.goalCategory, goalCategoryBefore);
      expect(regenerated.targetDate, targetDateBefore);
      expect(regenerated.milestones.last.targetAmount, finalTargetBefore);
      expect(regenerated.monthlyTarget, 54321);
      expect(plans.isPlanStale, isFalse);

      final applied = await ledger.applySaveFact('incomeGrossMonthly', 10000.0);
      expect(applied, isTrue);
      await $.tester.pump();
      expect(plans.isPlanStale, isTrue);
      await $(find.bySemanticsIdentifier('financial_plan_stale_state'))
          .waitUntilVisible();
      await $(find.bySemanticsIdentifier('financial_plan_stale_recalculate'))
          .waitUntilVisible();
      expect(find.text('54’321 CHF / mois'), findsNothing);
    },
  );
}
