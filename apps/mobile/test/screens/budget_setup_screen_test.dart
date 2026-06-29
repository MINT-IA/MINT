import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
      ChangeNotifierProvider(create: (_) => BudgetProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      initialRoute: '/budget/setup',
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/budget/setup': (_) => child,
      },
    ),
  );
}

Widget _wrapWithProviders({
  required Widget child,
  required CoachProfileProvider coachProvider,
  required BudgetProvider budgetProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProvider),
      ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      initialRoute: '/budget/setup',
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/budget/setup': (_) => child,
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) secureStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return secureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            secureStorage.remove(key);
            return null;
          case 'deleteAll':
            secureStorage.clear();
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

  testWidgets('persists canonical budget keys', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('salaire'), findsNothing);
    expect(find.text('Ressources mensuelles nettes'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('budgetIncomeField')), '6000');
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.tap(find.text("Ajouter d'autres postes"));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('budgetTransportField')), '120');
    await tester.enterText(
        find.byKey(const ValueKey('budgetTelecomField')), '80');
    await tester.enterText(
        find.byKey(const ValueKey('budgetElectricityField')), '90');
    await tester.enterText(
        find.byKey(const ValueKey('budgetMedicalField')), '110');
    await tester.enterText(
        find.byKey(const ValueKey('budgetOtherField')), '250');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_net_income_period_chf'], 6000.0);
    expect(answers['q_housing_cost_period_chf'], 2200.0);
    expect(answers['q_lamal_premium_monthly_chf'], 420.0);
    expect(answers['q_pay_frequency'], 'monthly');
    expect(answers['_coach_depenses_transport'], 120.0);
    expect(answers['_coach_depenses_telecom'], 80.0);
    expect(answers['_coach_depenses_electricite'], 90.0);
    expect(answers['_coach_depenses_frais_medicaux'], 110.0);
    expect(answers['_coach_depenses_autres'], 250.0);
  });

  testWidgets('creates direct budget inputs without a completed profile',
      (tester) async {
    final coachProvider = CoachProfileProvider();
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('budgetIncomeField')), '7400');
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final inputs = budgetProvider.inputs;
    expect(inputs, isNotNull);
    expect(inputs!.netIncome, 7400);
    expect(inputs.housingCost, 2200);
    expect(inputs.healthInsurance, 420);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_net_income_period_chf'], 7400.0);
    expect(answers['q_housing_cost_period_chf'], 2200.0);
    expect(answers['q_lamal_premium_monthly_chf'], 420.0);
  });

  test('budget-first answers hydrate a partial profile on restart', () async {
    await ReportPersistenceService.saveAnswers({
      'q_housing_cost_period_chf': 2200.0,
      'q_pay_frequency': 'monthly',
      'q_lamal_premium_monthly_chf': 420.0,
    });

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile, isNotNull);
    expect(provider.profile!.depenses.loyer, 2200);
    expect(provider.profile!.depenses.assuranceMaladie, 420);
  });

  test('completed wizard with budget keys stays a full profile', () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6000.0,
      'q_pay_frequency': 'monthly',
      'q_housing_cost_period_chf': 2200.0,
      'q_lamal_premium_monthly_chf': 420.0,
    });
    await ReportPersistenceService.setCompleted(true);

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile, isNotNull);
    expect(provider.isPartialProfile, isFalse);
    expect(provider.profile!.depenses.loyer, 2200);
    expect(provider.profile!.depenses.assuranceMaladie, 420);
  });

  testWidgets('manual budget edit after completed wizard survives restart',
      (tester) async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6000.0,
      'q_pay_frequency': 'monthly',
      'q_housing_cost_period_chf': 1100.0,
      'q_lamal_premium_monthly_chf': 390.0,
    });
    await ReportPersistenceService.setCompleted(true);

    final coachProvider = CoachProfileProvider();
    await coachProvider.loadFromWizard();
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ressources mensuelles nettes'), findsOneWidget);
    expect(find.textContaining('salaire'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();

    expect(reloaded.isPartialProfile, isFalse);
    expect(reloaded.profile!.depenses.loyer, 2200);
    expect(reloaded.profile!.depenses.assuranceMaladie, 420);
  });

  testWidgets('manual budget edit preserves persisted E2E seed income',
      (tester) async {
    final seedAnswers =
        CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers();
    await ReportPersistenceService.saveAnswers(seedAnswers);
    await ReportPersistenceService.setCompleted(true);

    final coachProvider = CoachProfileProvider();
    await coachProvider.loadFromWizard();
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ressources mensuelles nettes'), findsOneWidget);
    expect(find.textContaining('salaire'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_net_income_period_chf'],
        seedAnswers['q_net_income_period_chf']);
    expect(
        answers['q_gross_salary_annual'], seedAnswers['q_gross_salary_annual']);
    expect(answers['q_housing_cost_period_chf'], 2200.0);
    expect(answers['q_lamal_premium_monthly_chf'], 420.0);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();

    expect(reloaded.profile, isNotNull);
    expect(reloaded.profile!.explicitMonthlyNetIncome,
        seedAnswers['q_net_income_period_chf']);
    expect(reloaded.profile!.depenses.loyer, 2200);
    expect(reloaded.profile!.depenses.assuranceMaladie, 420);
  });

  testWidgets('cleared optional budget fields are removed from storage',
      (tester) async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6000.0,
      'q_pay_frequency': 'monthly',
      'q_housing_cost_period_chf': 2200.0,
      'q_lamal_premium_monthly_chf': 420.0,
      '_coach_depenses_transport': 180.0,
      '_coach_depenses_telecom': 90.0,
    });
    await ReportPersistenceService.setCompleted(true);

    final coachProvider = CoachProfileProvider();
    await coachProvider.loadFromWizard();
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ajouter d'autres postes"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('budgetTransportField')),
      '',
    );
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('_coach_depenses_transport'), isFalse);
    expect(answers['_coach_depenses_telecom'], 90.0);
  });

  testWidgets('refreshes BudgetProvider after save', (tester) async {
    final coachProvider = CoachProfileProvider();
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('budgetIncomeField')), '6000');
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.tap(find.text("Ajouter d'autres postes"));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('budgetTransportField')), '120');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(budgetProvider.inputs, isNotNull);
    expect(budgetProvider.inputs!.housingCost, 2200);
    expect(budgetProvider.inputs!.healthInsurance, 420);
    expect(budgetProvider.inputs!.otherFixedCosts, greaterThanOrEqualTo(120));
    expect(budgetProvider.plan, isNotNull);
  });

  testWidgets('save converges profile provider budget provider and storage',
      (tester) async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 5379.0,
      'q_pay_frequency': 'monthly',
    });
    await ReportPersistenceService.setCompleted(true);

    final coachProvider = CoachProfileProvider();
    await coachProvider.loadFromWizard();
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('budgetIncomeField')), '7400');
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_net_income_period_chf'], 7400.0);
    expect(answers['q_housing_cost_period_chf'], 2200.0);
    expect(answers['q_lamal_premium_monthly_chf'], 420.0);
    expect(answers.values, isNot(contains(19272200.0)));
    expect(answers.values, isNot(contains(420420.0)));

    expect(coachProvider.profile!.depenses.loyer, 2200);
    expect(coachProvider.profile!.depenses.assuranceMaladie, 420);
    expect(coachProvider.profile!.explicitMonthlyNetIncome, 7400);
    expect(budgetProvider.inputs, isNotNull);
    expect(budgetProvider.inputs!.netIncome, 7400);
    expect(budgetProvider.inputs!.housingCost, 2200);
    expect(budgetProvider.inputs!.healthInsurance, 420);
    expect(budgetProvider.inputs!.isTaxEstimated, isTrue);
    expect(budgetProvider.plan, isNotNull);
    expect(budgetProvider.plan!.available, greaterThan(0));
  });

  testWidgets(
      'secure-store failure keeps budget as direct inputs without plain wizard answers',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        if (call.method == 'write') {
          throw PlatformException(
            code: '-34018',
            message: 'errSecMissingEntitlement',
          );
        }
        return null;
      },
    );
    final coachProvider = CoachProfileProvider()
      ..updateFromAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 6000.0,
        'q_pay_frequency': 'monthly',
      });
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(_wrapWithProviders(
      child: const BudgetSetupScreen(),
      coachProvider: coachProvider,
      budgetProvider: budgetProvider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('budgetIncomeField')), '7400');
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, isEmpty);
    expect(budgetProvider.source, BudgetDataSource.directInput);
    expect(budgetProvider.inputs, isNotNull);
    expect(budgetProvider.inputs!.netIncome, 7400);
    expect(budgetProvider.inputs!.housingCost, 2200);
    expect(budgetProvider.inputs!.healthInsurance, 420);

    final reloadedBudgetProvider = BudgetProvider();
    final restored = await reloadedBudgetProvider.loadFromStorage();
    expect(restored, isTrue);
    expect(reloadedBudgetProvider.inputs!.housingCost, 2200);
    expect(reloadedBudgetProvider.inputs!.healthInsurance, 420);
  });

  testWidgets('rejects appended implausible monthly amounts', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('budgetIncomeField')), '6000');
    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '19272200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420420');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Montant mensuel trop élevé'), findsOneWidget);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_housing_cost_period_chf'), isFalse);
    expect(answers.containsKey('q_lamal_premium_monthly_chf'), isFalse);
  });

  testWidgets('exposes Maestro semantics anchors', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_setup_screen')))
          .identifier,
      'budget_setup_screen',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_income_field_semantics')))
          .identifier,
      'budget_income_field',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_income_field_semantics')))
          .label,
      contains('Ressources mensuelles nettes'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_income_field_semantics')))
          .label,
      contains('requis'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_housing_field_semantics')))
          .identifier,
      'budget_housing_field',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_housing_field_semantics')))
          .label,
      contains('Loyer'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_lamal_field_semantics')))
          .identifier,
      'budget_lamal_field',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_lamal_field_semantics')))
          .label,
      contains('Assurance maladie'),
    );

    await tester.enterText(
        find.byKey(const ValueKey('budgetHousingField')), '2200');
    await tester.enterText(
        find.byKey(const ValueKey('budgetLamalField')), '420');
    await tester.pumpAndSettle();

    expect(
      find.text('Postes saisis ici : 2620 CHF / mois'),
      findsOneWidget,
    );
    expect(
      find.textContaining('impôts estimés, dettes connues'),
      findsOneWidget,
    );
    expect(find.text('Total fixe : 2620 CHF / mois'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_setup_live_total')))
          .identifier,
      'budget_setup_live_total',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_setup_save_button')))
          .identifier,
      'budget_setup_save_button',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_setup_chat_fallback')))
          .identifier,
      'budget_setup_chat_fallback',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_setup_chat_fallback')))
          .label,
      'J\'en parle plutôt au coach',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_setup_chat_fallback')))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
  });

  testWidgets('chat fallback routes to Coach with budget topic',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/budget/setup',
      routes: [
        GoRoute(
          path: '/budget/setup',
          builder: (context, state) => const BudgetSetupScreen(),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (context, state) => Scaffold(
            key: const Key('coachRouteHit'),
            body: Text(state.uri.queryParameters['topic'] ?? ''),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budget_setup_chat_fallback')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coachRouteHit')), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/coach/chat?topic=budget',
    );
    expect(find.text('budget'), findsOneWidget);
  });
}
