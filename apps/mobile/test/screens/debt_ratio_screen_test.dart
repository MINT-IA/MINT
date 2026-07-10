import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';

Future<GoRouter> _pumpDebtRatio(
  WidgetTester tester, {
  Map<String, dynamic> answers = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final provider = CoachProfileProvider();
  if (answers.isNotEmpty) {
    provider.updateFromAnswers(answers);
  }
  Widget debtRatioScreen() =>
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: provider,
        child: const DebtRatioScreen(),
      );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => debtRatioScreen(),
      ),
      GoRoute(
        path: '/debt/ratio',
        builder: (_, __) => debtRatioScreen(),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Scaffold(
          body: Text(
            'data-block:${state.pathParameters['type']}:${state.uri.queryParameters['inputKey']}',
            key: const Key('data_block_route_probe'),
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
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
  await tester.pump();
  return router;
}

void main() {
  testWidgets('gates the debt ratio when profile income is missing',
      (tester) async {
    await _pumpDebtRatio(tester);

    expect(find.byKey(const Key('debt_ratio_missing_income_gate')),
        findsOneWidget);
    expect(find.byKey(const Key('debt_ratio_income_fact_card')), findsNothing);
    expect(find.textContaining("6'000"), findsNothing);
  });

  testWidgets('uses ledger income instead of a local default slider',
      (tester) async {
    await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'VD',
        'q_gross_salary_annual': 120000,
      },
    );

    final expectedNetMonthly = NetIncomeBreakdown.compute(
      grossSalary: 120000,
      canton: 'VD',
      age: DateTime.now().year - 1986,
    ).monthlyNetPayslip;

    expect(
        find.byKey(const Key('debt_ratio_income_fact_card')), findsOneWidget);
    expect(find.textContaining(formatChf(expectedNetMonthly)), findsOneWidget);
    expect(find.textContaining('Estimé'), findsOneWidget);
    expect(find.textContaining('Données connues'), findsNothing);
    expect(find.textContaining("6'000"), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('preserves exact net income facts from the ledger',
      (tester) async {
    await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
      },
    );

    expect(
        find.byKey(const Key('debt_ratio_income_fact_card')), findsOneWidget);
    expect(find.textContaining(formatChf(7200)), findsOneWidget);
    expect(find.textContaining('Données connues'), findsOneWidget);
    expect(find.textContaining('Estimé'), findsNothing);

    await tester.tap(find.byKey(const Key('debt_ratio_edit_income_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:revenu:q_net_income_period_chf'),
      findsOneWidget,
    );
  });

  testWidgets('prefers exact net income when gross salary also exists',
      (tester) async {
    await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_gross_salary_annual': 120000,
      },
    );

    expect(
        find.byKey(const Key('debt_ratio_income_fact_card')), findsOneWidget);
    expect(find.textContaining(formatChf(7200)), findsOneWidget);
    expect(find.textContaining('Données connues'), findsOneWidget);
    expect(find.textContaining('Estimé'), findsNothing);
  });

  testWidgets('taxes concubinage as two single persons for estimates',
      (tester) async {
    await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'VD',
        'q_gross_salary_annual': 120000,
        'q_civil_status': 'concubinage',
      },
    );

    final expectedNetMonthly = NetIncomeBreakdown.compute(
      grossSalary: 120000,
      canton: 'VD',
      age: DateTime.now().year - 1986,
      etatCivil: 'celibataire',
    ).monthlyNetPayslip;

    expect(
        find.byKey(const Key('debt_ratio_income_fact_card')), findsOneWidget);
    expect(find.textContaining(formatChf(expectedNetMonthly)), findsOneWidget);
    expect(find.textContaining('Estimé'), findsOneWidget);
  });

  testWidgets('seeds minimum vital family defaults from ledger',
      (tester) async {
    await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'VD',
        'q_gross_salary_annual': 120000,
        'q_civil_status': 'marie',
        'q_children': 2,
      },
    );

    final minimumVitalValue =
        find.byKey(const Key('debt_ratio_minimum_vital_value'));
    await tester.scrollUntilVisible(minimumVitalValue, 400);
    await tester.pumpAndSettle();

    final valueText = tester.widget<Text>(minimumVitalValue);
    expect(valueText.data, 'CHF ${formatChf(2550)} / mois');
  });

  testWidgets('routes missing income to the revenue data block',
      (tester) async {
    await _pumpDebtRatio(tester);

    await tester.tap(find.byKey(const Key('debt_ratio_missing_income_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_route_probe')), findsOneWidget);
    expect(
      find.text('data-block:revenu:q_gross_salary_annual'),
      findsOneWidget,
    );
  });

  testWidgets('uses self-employed ledger income without asking for salary',
      (tester) async {
    await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'GE',
        'q_employment_status': 'independant',
        'q_self_employed_income': 96000,
        'q_gross_salary_annual': 120000,
      },
    );

    expect(
        find.byKey(const Key('debt_ratio_income_fact_card')), findsOneWidget);
    expect(
        find.byKey(const Key('debt_ratio_missing_income_gate')), findsNothing);
    expect(find.textContaining(formatChf(8000)), findsOneWidget);
    expect(find.textContaining('Données connues'), findsOneWidget);
    expect(find.textContaining('Estimé'), findsNothing);

    await tester.tap(find.byKey(const Key('debt_ratio_edit_income_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:revenu:q_self_employed_income'),
      findsOneWidget,
    );
  });

  testWidgets('records completed return when a ledger result is rendered',
      (tester) async {
    final router = await _pumpDebtRatio(
      tester,
      answers: const {
        'q_birth_year': 1986,
        'q_canton': 'VD',
        'q_gross_salary_annual': 120000,
      },
    );

    final pushed = router.push('/debt/ratio', extra: {
      'runId': 'run_debt',
      'stepId': 'step_ratio',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.byKey(const Key('debt_ratio_income_fact_card')), findsOneWidget);

    router.pop();
    await pushed;
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    final screenReturn =
        await ScreenCompletionTracker.lastReturn('debt_ratio', prefs: prefs);

    expect(screenReturn?.outcome, ScreenOutcome.completed);
    expect(screenReturn?.stepOutputs?['ratio_endettement'], isA<double>());
    expect(screenReturn?.runId, 'run_debt');
    expect(screenReturn?.stepId, 'step_ratio');
  });
}
