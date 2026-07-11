import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  Widget child, {
  CoachProfileProvider? coachProfileProvider,
}) {
  return MultiProvider(
    providers: [
      if (coachProfileProvider == null)
        ChangeNotifierProvider(create: (_) => CoachProfileProvider())
      else
        ChangeNotifierProvider.value(value: coachProfileProvider),
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
      home: child,
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
    expect(answers, containsPair('q_pay_frequency', 'monthly'));
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
}
