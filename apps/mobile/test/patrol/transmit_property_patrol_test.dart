import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  GoRouter router, {
  required CoachProfileProvider coachProfileProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: coachProfileProvider,
      ),
      ChangeNotifierProvider<BudgetProvider>(
        create: (_) => BudgetProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(),
      ),
      ChangeNotifierProvider<SlmProvider>(
        create: (_) => SlmProvider(),
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

String? _semanticsValue(WidgetTester tester, String identifier) {
  final semantics = tester.widget<Semantics>(
    find.bySemanticsIdentifier(identifier),
  );
  return semantics.properties.value;
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  for (final delta in const [Offset(0, -350), Offset(0, 350)]) {
    for (var i = 0; i < 20; i++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(scrollable, delta);
      await tester.pump(const Duration(milliseconds: 80));
    }
  }
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    return;
  }
  expect(target, findsOneWidget);
}

void main() {
  final mockSecureStorage = <String, String>{};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) mockSecureStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  patrolTest(
    'transmit property collects owned property value before modelling',
    ($) async {
      final provider = CoachProfileProvider();
      final router = GoRouter(
        initialLocation: '/succession',
        routes: [
          GoRoute(
            path: '/succession',
            builder: (_, __) => const SuccessionPatrimoineScreen(),
          ),
          GoRoute(
            path: '/data-block/:type',
            builder: (_, state) => DataBlockEnrichmentScreen(
              blockType: state.pathParameters['type'] ?? 'objectifRetraite',
            ),
          ),
          GoRoute(
            path: '/budget/setup',
            builder: (_, __) => const BudgetSetupScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await $.pumpWidgetAndSettle(
        _wrap(
          router,
          coachProfileProvider: provider,
        ),
      );

      expect($(#succession_parents_note), findsOneWidget);
      expect($(find.bySemanticsIdentifier('succession_data_quest_next_ask')),
          findsOneWidget);
      expect(
        _semanticsValue($.tester, 'succession_data_quest_runtime_proof'),
        'mobile-transmit-property-patrol',
      );
      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'propertyMarketValue',
      );

      final input = find.byKey(const Key('property_value_input'));
      await $.tester.ensureVisible(input);
      await $.pumpAndSettle();
      await $(input).enterText('1200000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        if (provider.profile?.dataSources['patrimoine.propertyMarketValue'] ==
            ProfileDataSource.userInput) {
          break;
        }
        await $.tester.pump(const Duration(milliseconds: 50));
      }

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_property_market_value'], 1200000);
      expect(answers.containsKey('q_target_property_value'), isFalse);
      expect(provider.profile!.patrimoine.propertyMarketValue, 1200000);
      expect(provider.profile!.patrimoine.targetPropertyValue, isNull);
      expect(
        provider.profile!.dataSources['patrimoine.propertyMarketValue'],
        ProfileDataSource.userInput,
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'targetRetirementAge',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#target_retirement_age_input), findsOneWidget);
      await $(#target_retirement_age_input).enterText('64');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester.ensureVisible(
        find.byKey(const Key('retirement_goal_save_cta')),
      );
      await $(#retirement_goal_save_cta).tap();
      await $.pumpAndSettle();

      final retirementAgeAnswers = await ReportPersistenceService.loadAnswers();
      expect(retirementAgeAnswers['q_target_retirement_age'], 64);
      expect(retirementAgeAnswers.containsKey('targetRetirementAge'), isFalse);
      expect(provider.profile!.targetRetirementAge, 64);
      expect(
        retirementAgeAnswers.keys.where((key) => key.startsWith('q_')).toSet(),
        {'q_property_market_value', 'q_target_retirement_age'},
      );

      await $(find.byIcon(Icons.arrow_back)).tap();
      await $.pumpAndSettle();
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'avoirLpp',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#lpp_balance_input), findsOneWidget);
      await $(#lpp_balance_input).enterText('650000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester.ensureVisible(find.byKey(const Key('lpp_save_cta')));
      await $(#lpp_save_cta).tap();
      await $.pumpAndSettle();

      final lppAnswers = await ReportPersistenceService.loadAnswers();
      expect(lppAnswers['_coach_avoir_lpp'], 650000);
      expect(lppAnswers.containsKey('q_avoir_lpp'), isFalse);
      expect(lppAnswers.containsKey('avoirLpp'), isFalse);
      expect(provider.profile!.prevoyance.avoirLppTotal, 650000);
      expect(
        provider.profile!.dataSources['prevoyance.avoirLppTotal'],
        ProfileDataSource.userInput,
      );

      await $(find.byIcon(Icons.arrow_back)).tap();
      await $.pumpAndSettle();
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'pillar3aBalance',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#pillar3a_balance_input), findsOneWidget);
      await $(#pillar3a_balance_input).enterText('180000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester.ensureVisible(find.byKey(const Key('pillar3a_save_cta')));
      await $(#pillar3a_save_cta).tap();
      await $.pumpAndSettle();

      final pillar3aAnswers = await ReportPersistenceService.loadAnswers();
      expect(pillar3aAnswers['q_3a_total'], 180000);
      expect(pillar3aAnswers.containsKey('_coach_total_3a'), isFalse);
      expect(pillar3aAnswers.containsKey('pillar3aBalance'), isFalse);
      expect(provider.profile!.prevoyance.totalEpargne3a, 180000);
      expect(
        provider.profile!.dataSources['prevoyance.totalEpargne3a'],
        ProfileDataSource.userInput,
      );

      await $(find.byIcon(Icons.arrow_back)).tap();
      await $.pumpAndSettle();
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'parentLiquidAssets',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#savings_input), findsOneWidget);
      await $(#savings_input).enterText('120000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
      await $(#patrimoine_save_cta).tap();
      await $.pumpAndSettle();

      final liquidityAnswers = await ReportPersistenceService.loadAnswers();
      expect(liquidityAnswers['q_cash_total'], 120000);
      expect(liquidityAnswers.containsKey('parentLiquidAssets'), isFalse);
      expect(
        liquidityAnswers.containsKey('patrimoine.epargneLiquide'),
        isFalse,
      );
      expect(provider.profile!.patrimoine.epargneLiquide, 120000);
      expect(
        provider.profile!.dataSources['patrimoine.epargneLiquide'],
        ProfileDataSource.userInput,
      );

      await $(find.byIcon(Icons.arrow_back)).tap();
      await $.pumpAndSettle();
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'parentAnnualRetirementIncome',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#parent_annual_retirement_income_input), findsOneWidget);
      await $(#parent_annual_retirement_income_input).enterText('76000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester.ensureVisible(
        find.byKey(const Key('parent_retirement_income_save_cta')),
      );
      await $(#parent_retirement_income_save_cta).tap();
      await $.pumpAndSettle();

      final retirementIncomeAnswers =
          await ReportPersistenceService.loadAnswers();
      expect(
          retirementIncomeAnswers['q_parent_annual_retirement_income'], 76000);
      expect(
        retirementIncomeAnswers.containsKey(
          '_transmit_property_parent_annual_retirement_income',
        ),
        isFalse,
      );
      expect(
        retirementIncomeAnswers.containsKey('parentAnnualRetirementIncome'),
        isFalse,
      );
      expect(
        provider.profile!.dataSources['parentAnnualRetirementIncome'],
        ProfileDataSource.userInput,
      );

      await $(find.byIcon(Icons.arrow_back)).tap();
      await $.pumpAndSettle();
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'parentAnnualLivingCosts',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#budget_housing_cost_input), findsOneWidget);
      await $(#budget_housing_cost_input).enterText('6600');
      await $(#budget_lamal_premium_input).enterText('400');
      await $.tester.ensureVisible(
        find.byKey(const Key('budget_setup_show_optional_cta')),
      );
      await $(#budget_setup_show_optional_cta).tap();
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('budget_transport_input')));
      await $(#budget_transport_input).enterText('350');
      await $.tester
          .ensureVisible(find.byKey(const Key('budget_telecom_input')));
      await $(#budget_telecom_input).enterText('120');
      await $.tester
          .ensureVisible(find.byKey(const Key('budget_electricity_input')));
      await $(#budget_electricity_input).enterText('180');
      await $.tester
          .ensureVisible(find.byKey(const Key('budget_medical_input')));
      await $(#budget_medical_input).enterText('150');
      await $.tester.ensureVisible(find.byKey(const Key('budget_other_input')));
      await $(#budget_other_input).enterText('200');
      await $.tester
          .ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
      await $(#budget_setup_save_cta).tap();
      await $.pumpAndSettle();

      final livingCostAnswers = await ReportPersistenceService.loadAnswers();
      expect(livingCostAnswers['q_housing_cost_period_chf'], 6600);
      expect(livingCostAnswers['q_housing_cost_frequency'], 'monthly');
      expect(livingCostAnswers['q_lamal_premium_monthly_chf'], 400);
      expect(livingCostAnswers['_coach_depenses_transport'], 350);
      expect(livingCostAnswers['_coach_depenses_telecom'], 120);
      expect(livingCostAnswers['_coach_depenses_electricite'], 180);
      expect(livingCostAnswers['_coach_depenses_frais_medicaux'], 150);
      expect(livingCostAnswers['_coach_depenses_autres'], 200);
      expect(livingCostAnswers.containsKey('q_parent_annual_living_costs'),
          isFalse);
      expect(
        livingCostAnswers.containsKey(
          '_transmit_property_parent_annual_living_costs',
        ),
        isFalse,
      );
      expect(livingCostAnswers.containsKey('parentAnnualLivingCosts'), isFalse);
      expect(
        provider.profile!.dataSources['depenses.loyer'],
        ProfileDataSource.userInput,
      );
      expect(
        provider.profile!.dataSources['depenses.assuranceMaladie'],
        ProfileDataSource.userInput,
      );

      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'mortgageBalance',
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(
          const ValueKey('succession_data_quest_next_question_cta'),
        ),
      );
      await $(#succession_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#mortgage_balance_input), findsOneWidget);
      await $(#mortgage_balance_input).enterText('420000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
      await $(#patrimoine_save_cta).tap();
      await $.pumpAndSettle();

      final mortgageAnswers = await ReportPersistenceService.loadAnswers();
      expect(mortgageAnswers['q_mortgage_balance'], 420000);
      expect(mortgageAnswers.containsKey('_coach_dettes_hypotheque'), isFalse);
      expect(mortgageAnswers.containsKey('mortgageBalance'), isFalse);
      expect(
        mortgageAnswers.containsKey('patrimoine.mortgageBalance'),
        isFalse,
      );
      expect(provider.profile!.patrimoine.mortgageBalance, 420000);
      expect(
        provider.profile!.dataSources['patrimoine.mortgageBalance'],
        ProfileDataSource.userInput,
      );

      await $(find.byIcon(Icons.arrow_back)).tap();
      await $.pumpAndSettle();
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_data_quest_next_ask'),
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'heirsCount',
      );
      expect($(find.textContaining('next_ask:')), findsNothing);
      await $.tester.ensureVisible(
        find.bySemanticsIdentifier('succession_scenario_preview'),
      );
      await $.pumpAndSettle();
      expect($(find.bySemanticsIdentifier('succession_scenario_preview')),
          findsOneWidget);
      expect(
        $(find.bySemanticsIdentifier('succession_scenario_retirement_status')),
        findsOneWidget,
      );
      expect(
        $(find
            .bySemanticsIdentifier('succession_scenario_equalization_status')),
        findsOneWidget,
      );
      expect($(#succession_scenario_confidence), findsOneWidget);
    },
  );

  patrolTest(
    'transmit property reuses collected facts for Raiffeisen values',
    ($) async {
      final provider = CoachProfileProvider();
      await provider.mergeAnswers(
        const {
          'q_canton': 'VD',
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          'q_property_market_value': 1200000,
          'q_mortgage_balance': 420000,
          'q_children': 2,
          '_coach_avs_rente_estimee': 4000,
          '_coach_projected_rente_lpp': 28000,
          'q_pay_frequency': 'monthly',
          'q_housing_cost_period_chf': 6600,
          'q_lamal_premium_monthly_chf': 400,
          '_transmit_property_cash_paid_by_recipient': 50000,
          '_transmit_property_mortgage_assumed_by_recipient': 420000,
          '_transmit_property_recipient_relationship': 'descendant',
          '_transmit_property_retained_right': 'habitation',
          '_transmit_property_avancement_hoirie': true,
        },
        source: ProfileDataSource.userInput,
      );
      final router = GoRouter(
        initialLocation: '/succession',
        routes: [
          GoRoute(
            path: '/succession',
            builder: (_, __) => const SuccessionPatrimoineScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await $.pumpWidgetAndSettle(
        _wrap(
          router,
          coachProfileProvider: provider,
        ),
      );

      await _scrollUntilVisible(
        $.tester,
        find.byKey(const ValueKey('succession_scenario_retirement_status')),
      );
      expect(
        _semanticsValue($.tester, 'succession_scenario_retirement_status'),
        'needs_review',
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('succession_scenario_retirement_status'),
          ),
          matching: find.text("CHF -8'000"),
        ),
        findsOneWidget,
      );
      await _scrollUntilVisible(
        $.tester,
        find.byKey(const ValueKey('succession_scenario_equalization_status')),
      );
      expect(
        _semanticsValue($.tester, 'succession_scenario_equalization_status'),
        'at_risk',
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('succession_scenario_equalization_status'),
          ),
          matching: find.text("CHF 195'000"),
        ),
        findsOneWidget,
      );
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_runtime_scenario_statuses'),
      );

      expect(
        $(find.textContaining(
          "scenario_statuses: needs_review | CHF -8'000 | at_risk | CHF 195'000",
        )),
        findsOneWidget,
      );
      expect(
        $(find.textContaining('scenario_confidence: medium')),
        findsOneWidget,
      );
    },
  );
}
