import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  Widget child, {
  CoachProfileProvider? coachProfileProvider,
}) {
  final router = GoRouter(
    initialLocation: '/budget/setup',
    routes: [
      GoRoute(path: '/budget/setup', builder: (_, __) => child),
      GoRoute(
        path: '/budget',
        builder: (_, __) => const SizedBox(key: Key('budget_route_probe')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MultiProvider(
    providers: [
      if (coachProfileProvider == null)
        ChangeNotifierProvider(create: (_) => CoachProfileProvider())
      else
        ChangeNotifierProvider.value(value: coachProfileProvider),
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('budget setup exposes runtime ids and saves fixed charges',
      (tester) async {
    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budget_setup_housing_input')), findsOneWidget);
    expect(find.byKey(const Key('budget_setup_lamal_input')), findsOneWidget);
    expect(
      find.byKey(const Key('budget_setup_lamal_franchise_input')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('budget_setup_save_cta')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('budget_setup_housing_input')),
      '2400',
    );
    await tester.enterText(
      find.byKey(const Key('budget_setup_lamal_input')),
      '380',
    );
    await tester
        .tap(find.byKey(const Key('budget_setup_lamal_franchise_input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("CHF 2'500").last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_housing_cost_period_chf', 2400.0));
    expect(answers, containsPair('q_lamal_premium_monthly_chf', 380.0));
    expect(answers, containsPair('q_lamal_franchise', '2500'));
    expect(answers, containsPair('q_housing_pay_frequency', 'monthly'));
    expect(answers, isNot(contains('q_pay_frequency')));
  });

  testWidgets(
      'root GoRouter setup save falls back deterministically to budget',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/budget/setup',
      routes: [
        GoRoute(
          path: '/budget/setup',
          builder: (_, __) => const BudgetSetupScreen(),
        ),
        GoRoute(
          path: '/budget',
          builder: (_, __) => const Text(
            'budget-route',
            key: Key('budget_route_probe'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CoachProfileProvider(),
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

    await tester.enterText(
      find.byKey(const Key('budget_setup_housing_input')),
      '2100',
    );
    await tester.enterText(
      find.byKey(const Key('budget_setup_lamal_input')),
      '420',
    );
    await tester.ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('budget_route_probe')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/budget');
  });

  testWidgets('budget CTA push setup save pops back to budget', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/budget',
      routes: [
        GoRoute(
          path: '/budget',
          builder: (_, __) => const BudgetContainerScreen(),
        ),
        GoRoute(
          path: '/budget/setup',
          builder: (_, __) => const BudgetSetupScreen(),
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

    final startCta = find.byKey(const Key('budget_setup_start_cta'));
    await tester.ensureVisible(startCta);
    await tester.tap(startCta);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetSetupScreen), findsOneWidget);
    expect(router.canPop(), isTrue);
    await tester.enterText(
      find.byKey(const Key('budget_setup_housing_input')),
      '2100',
    );
    await tester.enterText(
      find.byKey(const Key('budget_setup_lamal_input')),
      '420',
    );
    await tester.ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.routeInformationProvider.value.uri.path, '/budget');
    expect(find.byType(BudgetContainerScreen), findsOneWidget);
  });

  testWidgets(
      'budget setup exposes optional medical runtime id and persists it',
      (tester) async {
    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('budget_setup_add_optional_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budget_setup_medical_input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('budget_setup_housing_input')),
      '2400',
    );
    await tester.enterText(
      find.byKey(const Key('budget_setup_lamal_input')),
      '380',
    );
    await tester
        .tap(find.byKey(const Key('budget_setup_lamal_franchise_input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHF 300').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('budget_setup_medical_input')),
      '120',
    );
    await tester.ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('_coach_depenses_frais_medicaux', 120.0));
    expect(answers, containsPair('q_lamal_franchise', '300'));
  });

  testWidgets('lamal focus exposes medical costs without extra disclosure',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const BudgetSetupScreen(initialFocus: 'lamal')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budget_setup_medical_input')), findsOneWidget);
    expect(
        find.byKey(const Key('budget_setup_add_optional_cta')), findsNothing);
    expect(find.text('*'), findsOneWidget);
  });

  testWidgets('housing focus requests keyboard focus on housing input',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const BudgetSetupScreen(initialFocus: 'housing')),
    );
    await tester.pumpAndSettle();

    final housing = tester.widget<TextField>(
      find.byKey(const Key('budget_setup_housing_input')),
    );
    expect(housing.focusNode?.hasFocus, isTrue);
  });

  testWidgets('housing focus can save housing fact without LAMal',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const BudgetSetupScreen(initialFocus: 'housing')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('budget_setup_housing_input')),
      '1800',
    );
    await tester.ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_housing_cost_period_chf', 1800.0));
    expect(answers, containsPair('q_housing_pay_frequency', 'monthly'));
    expect(answers, isNot(contains('q_pay_frequency')));
    expect(answers, isNot(contains('q_lamal_premium_monthly_chf')));
  });

  testWidgets('lamal focus can save LAMal facts without housing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const BudgetSetupScreen(initialFocus: 'lamal')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('budget_setup_lamal_input')),
      '390',
    );
    await tester
        .tap(find.byKey(const Key('budget_setup_lamal_franchise_input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("CHF 2'500").last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('budget_setup_medical_input')),
      '120',
    );
    await tester.ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, isNot(contains('q_housing_cost_period_chf')));
    expect(answers, containsPair('q_lamal_premium_monthly_chf', 390.0));
    expect(answers, containsPair('q_lamal_franchise', '2500'));
    expect(answers, containsPair('_coach_depenses_frais_medicaux', 120.0));
  });

  testWidgets('budget setup does not prefill derived expense defaults',
      (tester) async {
    const answersWithoutExpenses = <String, dynamic>{
      'q_canton': 'VD',
      'q_salaire': 6000,
    };
    await ReportPersistenceService.saveAnswers(answersWithoutExpenses);

    final provider = CoachProfileProvider()
      ..updateFromAnswers(answersWithoutExpenses);

    await tester.pumpWidget(_wrap(
      const BudgetSetupScreen(),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    final housing = tester.widget<TextField>(
      find.byKey(const Key('budget_setup_housing_input')),
    );
    final lamal = tester.widget<TextField>(
      find.byKey(const Key('budget_setup_lamal_input')),
    );

    expect(housing.controller!.text, isEmpty);
    expect(lamal.controller!.text, isEmpty);
  });

  testWidgets('budget setup hydrates persisted canonical answers',
      (tester) async {
    await ReportPersistenceService.saveAnswers(const {
      'q_housing_cost_period_chf': 2100,
      'q_lamal_premium_monthly_chf': 390,
      'q_lamal_franchise': '2500',
    });

    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();

    final housing = tester.widget<TextField>(
      find.byKey(const Key('budget_setup_housing_input')),
    );
    final lamal = tester.widget<TextField>(
      find.byKey(const Key('budget_setup_lamal_input')),
    );

    expect(housing.controller!.text, '2100');
    expect(lamal.controller!.text, '390');
    expect(find.text("CHF 2'500"), findsOneWidget);
  });

  testWidgets('budget setup migrates legacy other costs to the canonical key',
      (tester) async {
    await ReportPersistenceService.saveAnswers(const {
      'q_housing_cost_period_chf': 2100.0,
      'q_lamal_premium_monthly_chf': 390.0,
      '_coach_depenses_autres': 90.0,
    });

    await tester.pumpWidget(_wrap(const BudgetSetupScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budget_setup_add_optional_cta')));
    await tester.pumpAndSettle();

    final other = find.byType(TextField).last;
    expect(tester.widget<TextField>(other).controller!.text, '90');
    await tester.enterText(other, '110');
    await tester.ensureVisible(find.byKey(const Key('budget_setup_save_cta')));
    await tester.tap(find.byKey(const Key('budget_setup_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_other_fixed_costs_monthly_chf', 110.0));
    expect(answers, isNot(contains('_coach_depenses_autres')));
  });
}
