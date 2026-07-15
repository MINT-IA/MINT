import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _initialAnswers = <String, dynamic>{
  'q_birth_year': 1985,
  'q_canton': 'VD',
  'q_civil_status': 'single',
  'q_children': 0,
  'q_pay_frequency': 'monthly',
  'q_gross_salary_annual': 120000.0,
  'q_net_income_period_chf': 7600.0,
  'q_housing_cost_period_chf': 1800.0,
  'q_lamal_premium_monthly_chf': 400.0,
  'q_debt_payments_period_chf': 300.0,
  'q_has_consumer_debt': true,
};

const _budgetMutation = <String, dynamic>{
  'q_housing_cost_period_chf': 2200.0,
  'q_lamal_premium_monthly_chf': 450.0,
  'q_debt_payments_period_chf': 500.0,
};

const _openBankingNetMutation = <String, dynamic>{
  'q_net_income_period_chf': 6400.0,
  'q_pay_frequency': 'monthly',
};

const _yearlyIncomeAnswers = <String, dynamic>{
  'q_birth_year': 1985,
  'q_canton': 'VD',
  'q_civil_status': 'single',
  'q_pay_frequency': 'yearly',
  'q_net_income_period_chf': 91200.0,
};

const _staleBudgetInputs = <String, dynamic>{
  'q_pay_frequency': 'monthly',
  'q_net_income_period_chf': 1111.0,
  'q_housing_cost_period_chf': 9999.0,
  'q_debt_payments_period_chf': 888.0,
  'q_tax_provision_monthly_chf': 777.0,
  'q_lamal_premium_monthly_chf': 666.0,
  'q_other_fixed_costs_monthly_chf': 555.0,
  'q_budget_style': 'envelopes3',
  'emergency_fund_months': 0.0,
};

Future<void> _pumpFrames(WidgetTester tester, {int frames = 24}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

double? _delta(double? before, double? after) {
  if (before == null || after == null) return null;
  return ((after - before) * 1000).round() / 1000;
}

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return null;
  }
}

Future<BuildContext> _pumpProductionApp(
  WidgetTester tester, {
  double? futureOverride,
}) async {
  SharedPreferences.setMockInitialValues({
    'wizard_answers_v2': jsonEncode(_initialAnswers),
    'wizard_completed': true,
    'budget_inputs_v1': jsonEncode(_staleBudgetInputs),
    if (futureOverride != null) 'budget_override_future': futureOverride,
  });
  FlutterSecureStorage.setMockInitialValues({});
  FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  try {
    await tester.pumpWidget(const MintApp());
    await _pumpFrames(tester);
    return tester.element(find.byType(MaterialApp));
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _budgetSetupHarness() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) {
        final provider = CoachProfileProvider();
        provider.loadFromWizard();
        return provider;
      }),
      ChangeNotifierProvider(create: (_) => BudgetProvider()),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: BudgetSetupScreen(initialFocus: 'housing'),
    ),
  );
}

void main() {
  testWidgets(
    'cold start eagerly derives BudgetProvider from CoachProfile, not stale cache',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final budgetProvider = context.read<BudgetProvider>();
      await budgetProvider.loadFromStorage();
      final inputs = budgetProvider.inputs;

      expect(
        (
          eager: inputs != null,
          housing: inputs?.housingCost,
          health: inputs?.healthInsurance,
          debt: inputs?.debtPayments,
        ),
        const (
          eager: true,
          housing: 1800.0,
          health: 400.0,
          debt: 300.0,
        ),
      );
    },
  );

  testWidgets(
    'cold start restores budget overrides without visiting MonArgent',
    (tester) async {
      final context = await _pumpProductionApp(tester, futureOverride: 123.0);
      final budgetProvider = context.read<BudgetProvider>();
      final inputs = budgetProvider.inputs;
      final plan = budgetProvider.plan;

      expect(
        (
          housing: inputs?.housingCost,
          health: inputs?.healthInsurance,
          debt: inputs?.debtPayments,
          future: plan?.future,
          variables: plan?.variables,
        ),
        (
          housing: 1800.0,
          health: 400.0,
          debt: 300.0,
          future: 123.0,
          variables: plan?.available == null ? null : plan!.available - 123.0,
        ),
      );
    },
  );

  testWidgets(
    'BudgetSetupScreen preserves yearly income cadence and stores monthly housing cadence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await ReportPersistenceService.saveAnswers(_yearlyIncomeAnswers);

      await tester.pumpWidget(_budgetSetupHarness());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('budget_setup_housing_input')),
        '2100',
      );
      await tester
          .ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
      await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
      await tester.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(
        (
          incomeCadence: answers['q_pay_frequency'],
          housingCadence: answers['q_housing_pay_frequency'],
          housing: answers['q_housing_cost_period_chf'],
        ),
        const (
          incomeCadence: 'yearly',
          housingCadence: 'monthly',
          housing: 2100.0,
        ),
      );
    },
  );

  testWidgets(
    'mergeAnswers rehydrates BudgetProvider inputs and plan exactly once',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final profileProvider = context.read<CoachProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final beforeInputs = budgetProvider.inputs;
      final beforePlan = budgetProvider.plan;
      var notifications = 0;
      budgetProvider.addListener(() => notifications++);

      await profileProvider.mergeAnswers(_budgetMutation);
      await _pumpFrames(tester);

      final afterInputs = budgetProvider.inputs;
      final afterPlan = budgetProvider.plan;
      expect(
        (
          notifications: notifications,
          housingDelta:
              _delta(beforeInputs?.housingCost, afterInputs?.housingCost),
          healthDelta: _delta(
            beforeInputs?.healthInsurance,
            afterInputs?.healthInsurance,
          ),
          debtDelta:
              _delta(beforeInputs?.debtPayments, afterInputs?.debtPayments),
          availableDelta: _delta(beforePlan?.available, afterPlan?.available),
        ),
        const (
          notifications: 1,
          housingDelta: 400.0,
          healthDelta: 50.0,
          debtDelta: 200.0,
          availableDelta: -650.0,
        ),
      );
      await _pumpFrames(tester, frames: 60);
    },
  );

  testWidgets(
    'open banking declared net overrides computed own net exactly once',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final profileProvider = context.read<CoachProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final stateProvider = context.read<MintStateProvider>();
      await profileProvider.mergeAnswersWithProvenance(
        const {'q_tax_provision_monthly_chf': 1200.0},
        source: ProfileDataSource.userInput,
      );
      await _pumpFrames(tester);
      final beforePlan = budgetProvider.plan;
      final beforePresent = stateProvider.state?.budgetSnapshot?.present;
      var notifications = 0;
      budgetProvider.addListener(() => notifications++);

      await profileProvider.mergeAnswersWithProvenance(
        _openBankingNetMutation,
        source: ProfileDataSource.openBanking,
      );
      await _pumpFrames(tester);

      final profile = profileProvider.profile;
      final afterPlan = budgetProvider.plan;
      final afterPresent = stateProvider.state?.budgetSnapshot?.present;
      expect(
        (
          notifications: notifications,
          grossStillPresent: profile?.salaireBrutMensuel == 10000.0,
          declared: profile?.monthlyNetIncomeDeclared,
          source: profile?.dataSources['monthlyNetIncomeDeclared'],
          budgetNet: budgetProvider.inputs?.netIncome,
          mintStateNet: afterPresent?.monthlyNet,
          freeDelta:
              _delta(beforePresent?.monthlyFree, afterPresent?.monthlyFree),
          planChanged: beforePlan?.available != afterPlan?.available,
        ),
        const (
          notifications: 1,
          grossStillPresent: true,
          declared: 6400.0,
          source: ProfileDataSource.openBanking,
          budgetNet: 6400.0,
          mintStateNet: 6400.0,
          freeDelta: -1200.0,
          planChanged: true,
        ),
      );
      await _pumpFrames(tester, frames: 60);
    },
  );

  testWidgets(
    'manual bank import writes income only and never launders charges',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final profileProvider = context.read<CoachProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final stateProvider = context.read<MintStateProvider>();
      await profileProvider.mergeAnswersWithProvenance(
        const {'q_tax_provision_monthly_chf': 1200.0},
        source: ProfileDataSource.userInput,
      );
      await _pumpFrames(tester);
      final beforeInputs = budgetProvider.inputs;
      final beforeCharges =
          stateProvider.state?.budgetSnapshot?.present.monthlyCharges;
      final preview = BudgetImportPreview.fromStatementResult(
        BankStatementResult(
          bankName: 'Test',
          periodStart: DateTime(2026, 6, 1),
          periodEnd: DateTime(2026, 6, 30),
          transactions: const [],
          totalCredits: 6400.0,
          totalDebits: -1850.0,
          confidence: 0.9,
          recurringMonthly: [
            BankTransaction(
              date: DateTime(2026, 6, 25),
              description: 'Salaire',
              amount: 6400.0,
              category: 'Revenu',
              isRecurring: true,
            ),
            BankTransaction(
              date: DateTime(2026, 6, 2),
              description: 'Loyer',
              amount: -1850.0,
              category: 'Logement',
              isRecurring: true,
            ),
          ],
        ),
      );

      await importManualBankPreview(
        profileProvider: profileProvider,
        preview: preview,
      );
      await _pumpFrames(tester);

      final profile = profileProvider.profile;
      final afterInputs = budgetProvider.inputs;
      final afterCharges =
          stateProvider.state?.budgetSnapshot?.present.monthlyCharges;
      expect(
        (
          recurringCount: preview.recurringCharges.length,
          recurringDebit: preview.recurringCharges.single.amount,
          source: profile?.dataSources['monthlyNetIncomeDeclared'],
          net: afterInputs?.netIncome,
          housingDelta:
              _delta(beforeInputs?.housingCost, afterInputs?.housingCost),
          otherDelta: _delta(
            beforeInputs?.otherFixedCosts,
            afterInputs?.otherFixedCosts,
          ),
          chargesDelta: _delta(beforeCharges, afterCharges),
        ),
        const (
          recurringCount: 1,
          recurringDebit: -1850.0,
          source: ProfileDataSource.userInput,
          net: 6400.0,
          housingDelta: 0.0,
          otherDelta: 0.0,
          chargesDelta: 0.0,
        ),
      );
    },
  );

  testWidgets(
    'MintUserState budget snapshot moves charges and free by one exact delta',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final profileProvider = context.read<CoachProfileProvider>();
      final stateProvider = context.read<MintStateProvider>();
      final before = stateProvider.state?.budgetSnapshot?.present;
      var notifications = 0;
      stateProvider.addListener(() => notifications++);

      await profileProvider.mergeAnswers(_budgetMutation);
      await _pumpFrames(tester);

      final after = stateProvider.state?.budgetSnapshot?.present;
      expect(
        (
          notifications: notifications,
          chargesDelta: _delta(before?.monthlyCharges, after?.monthlyCharges),
          freeDelta: _delta(before?.monthlyFree, after?.monthlyFree),
        ),
        const (
          notifications: 1,
          chargesDelta: 650.0,
          freeDelta: -650.0,
        ),
      );
      await _pumpFrames(tester, frames: 60);
    },
  );

  testWidgets(
    'mounted budget hero follows the live MintState budget snapshot',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final profileProvider = context.read<CoachProfileProvider>();
      final stateProvider = context.read<MintStateProvider>();
      testOnlyRootRouter.go('/budget');
      await _pumpFrames(tester, frames: 60);

      final beforeHero = tester.widget<MintCountUp>(
        find.byType(MintCountUp),
      );
      final beforeFree = stateProvider.state?.budgetSnapshot?.present.monthlyFree;
      expect(beforeHero.value, beforeFree);

      await profileProvider.mergeAnswers(_budgetMutation);
      await _pumpFrames(tester, frames: 60);

      final afterHero = tester.widget<MintCountUp>(
        find.byType(MintCountUp),
      );
      final afterFree = stateProvider.state?.budgetSnapshot?.present.monthlyFree;
      expect(
        (
          heroMatchesState: afterHero.value == afterFree,
          heroDelta: _delta(beforeHero.value, afterHero.value),
          stateDelta: _delta(beforeFree, afterFree),
        ),
        const (
          heroMatchesState: true,
          heroDelta: -650.0,
          stateDelta: -650.0,
        ),
      );

      testOnlyRootRouter.go('/');
      await _pumpFrames(tester);
    },
  );

  testWidgets(
    'explicit tax provision stays separate from other fixed costs',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final profileProvider = context.read<CoachProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      var notifications = 0;
      budgetProvider.addListener(() => notifications++);

      await profileProvider.mergeAnswersWithProvenance(
        const {
          'q_tax_provision_monthly_chf': 300.0,
          'q_other_fixed_costs_monthly_chf': 100.0,
        },
        source: ProfileDataSource.userInput,
      );
      await _pumpFrames(tester);

      final profile = profileProvider.profile!;
      final inputs = budgetProvider.inputs!;
      final roundTrip = CoachProfile.fromJson(profile.toJson());
      final copied = profile.copyWith(monthlyTaxProvisionDeclared: 350.0);
      final coldProvider = CoachProfileProvider();
      await coldProvider.loadFromWizard();
      final cold = coldProvider.profile!;

      expect(
        (
          notifications: notifications,
          profileTax: profile.monthlyTaxProvisionDeclared,
          otherFixed: inputs.otherFixedCosts,
          tax: inputs.taxProvision,
          taxEstimated: inputs.isTaxEstimated,
          source: profile.dataSources['monthlyTaxProvisionDeclared'],
          timestamped:
              profile.dataTimestamps['monthlyTaxProvisionDeclared'] != null,
          sourceDate: profile.dataSourceDates['monthlyTaxProvisionDeclared'],
          userProvided: profile.userProvidedFields
              .contains('monthlyTaxProvisionDeclared'),
          roundTripTax: roundTrip.monthlyTaxProvisionDeclared,
          copyTax: copied.monthlyTaxProvisionDeclared,
          coldTax: cold.monthlyTaxProvisionDeclared,
          coldSource: cold.dataSources['monthlyTaxProvisionDeclared'],
          coldTimestampMatches: cold.dataTimestamps[
                  'monthlyTaxProvisionDeclared'] ==
              profile.dataTimestamps['monthlyTaxProvisionDeclared'],
          coldSourceDate:
              cold.dataSourceDates['monthlyTaxProvisionDeclared'],
        ),
        (
          notifications: 1,
          profileTax: 300.0,
          otherFixed: 100.0,
          tax: 300.0,
          taxEstimated: false,
          source: ProfileDataSource.userInput,
          timestamped: true,
          sourceDate: null,
          userProvided: true,
          roundTripTax: 300.0,
          copyTax: 350.0,
          coldTax: 300.0,
          coldSource: ProfileDataSource.userInput,
          coldTimestampMatches: true,
          coldSourceDate: null,
        ),
      );
      await _pumpFrames(tester, frames: 60);
    },
  );

  testWidgets(
    'MintUserState keeps retirement budgetGap null without official AVS facts',
    (tester) async {
      final context = await _pumpProductionApp(tester);
      final state = context.read<MintStateProvider>().state;

      expect(
        (ready: state != null, budgetGap: state?.budgetGap),
        const (ready: true, budgetGap: null),
      );
    },
  );
}
