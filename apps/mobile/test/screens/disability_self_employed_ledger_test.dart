import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_self_employed_screen.dart';
import 'package:provider/provider.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

  _RecordingCoachProfileProvider(
    Map<String, dynamic> initialAnswers, {
    CoachProfile? profileOverride,
  }) : _answers = Map<String, dynamic>.from(initialAnswers) {
    _profileOverride =
        profileOverride ?? CoachProfile.fromWizardAnswers(_answers);
  }

  @override
  CoachProfile? get profile => _profileOverride;

  @override
  bool get hasProfile => _profileOverride != null;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    _answers.addAll(partial);
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
    notifyListeners();
  }
}

Map<String, dynamic> _answers({
  double? selfEmployedIncome,
  double? cashTotal,
  double? monthlyHousing,
  double? monthlyLamal,
}) {
  return {
    if (selfEmployedIncome != null) ...{
      'q_self_employed_income': selfEmployedIncome,
      'q_net_income_period_chf': selfEmployedIncome,
      'q_pay_frequency': 'yearly',
    },
    if (cashTotal != null) 'q_cash_total': cashTotal,
    if (monthlyHousing != null) 'q_housing_cost_period_chf': monthlyHousing,
    if (monthlyLamal != null) 'q_lamal_premium_monthly_chf': monthlyLamal,
    'q_employment_status': 'independant',
  };
}

Widget _buildWithProvider(
  CoachProfileProvider provider,
  Widget child,
) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: child,
    ),
  );
}

Widget _buildWithRouter(
  CoachProfileProvider provider,
  Widget child,
) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ChangeNotifierProvider<CoachProfileProvider>.value(
          value: provider,
          child: child,
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Text(
          'data-block:${state.pathParameters['type']}:'
          '${state.uri.queryParameters['inputKey']}',
          key: const Key('data_block_route_probe'),
        ),
      ),
      GoRoute(
        path: '/budget/setup',
        builder: (_, __) => const Text(
          'budget-setup',
          key: Key('budget_setup_route_probe'),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  test('keeps monthly housing expenses independent from income frequency', () {
    final profile = CoachProfile.fromWizardAnswers(_answers(
      selfEmployedIncome: 120000,
      cashTotal: 30000,
      monthlyHousing: 2200,
      monthlyLamal: 420,
    ));

    expect(profile.depenses.loyer, 2200);
    expect(profile.depenses.assuranceMaladie, 420);
    expect(profile.depenses.totalMensuel, 2620);
    expect(profile.userProvidedFields, contains('monthlyExpenses'));
  });

  testWidgets('renders independent income from ledger without local sliders',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      selfEmployedIncome: 120000,
      cashTotal: 30000,
      monthlyHousing: 2200,
      monthlyLamal: 420,
    ));

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilitySelfEmployedScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('disability_self_ledger_facts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_self_income_fact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_self_savings_fact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_self_expenses_fact')),
      findsOneWidget,
    );
    expect(find.text("CHF 2'620"), findsOneWidget);
    expect(
      find.byKey(const Key('disability_self_result_cards')),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('does not unlock from unprovided independent income defaults',
      (tester) async {
    final phantomProfile = CoachProfile.defaults().copyWith(
      employmentStatus: 'independant',
      selfEmployedNetIncome: 120000,
      userProvidedFields: const {},
    );
    final provider = _RecordingCoachProfileProvider(
      const {'q_employment_status': 'independant'},
      profileOverride: phantomProfile,
    );

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilitySelfEmployedScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('disability_self_ledger_facts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_self_result_cards')),
      findsNothing,
    );
    expect(find.text("CHF 120'000"), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('routes missing income to the independent income data block',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(
      const {'q_employment_status': 'independant'},
    );

    await tester.pumpWidget(_buildWithRouter(
      provider,
      const DisabilitySelfEmployedScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:revenu:q_self_employed_income'),
      findsOneWidget,
    );
  });

  testWidgets('routes missing savings to the wealth data block',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      selfEmployedIncome: 120000,
      monthlyHousing: 2200,
      monthlyLamal: 420,
    ));

    await tester.pumpWidget(_buildWithRouter(
      provider,
      const DisabilitySelfEmployedScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:patrimoine:q_cash_total'),
      findsOneWidget,
    );
  });

  testWidgets('routes missing expenses to budget setup', (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      selfEmployedIncome: 120000,
      cashTotal: 30000,
    ));

    await tester.pumpWidget(_buildWithRouter(
      provider,
      const DisabilitySelfEmployedScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text('budget-setup'), findsOneWidget);
  });
}
