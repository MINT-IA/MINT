import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
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

Map<String, dynamic> _answers({
  double? grossSalaryAnnual,
  double? cashTotal,
  String? emergencyFund,
  double? monthlyHousing,
  double? monthlyLamal,
}) {
  return {
    if (grossSalaryAnnual != null) 'q_gross_salary_annual': grossSalaryAnnual,
    if (cashTotal != null) 'q_cash_total': cashTotal,
    if (emergencyFund != null) 'q_emergency_fund': emergencyFund,
    if (monthlyHousing != null) 'q_housing_cost_period_chf': monthlyHousing,
    if (monthlyLamal != null) 'q_lamal_premium_monthly_chf': monthlyLamal,
    'q_employment_status': 'salarie',
  };
}

void main() {
  testWidgets('reads salary savings and expenses from ledger facts only',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      cashTotal: 42000,
      monthlyHousing: 2200,
      monthlyLamal: 420,
    ));

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilityInsuranceScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('disability_insurance_ledger_facts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_insurance_salary_fact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_insurance_savings_fact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_insurance_expenses_fact')),
      findsOneWidget,
    );
    expect(find.text("CHF 8'000"), findsOneWidget);
    expect(find.text("CHF 42'000"), findsOneWidget);
    expect(find.text("CHF 2'620"), findsOneWidget);
    expect(
      find.byKey(const Key('disability_insurance_result_section')),
      findsOneWidget,
    );
    expect(find.byType(MintPremiumSlider), findsNothing);
  });

  testWidgets('does not unlock results from missing monthly expenses',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      cashTotal: 42000,
    ));

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilityInsuranceScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('disability_insurance_ledger_facts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('disability_insurance_result_section')),
      findsNothing,
    );
    expect(find.text("CHF 8'000"), findsOneWidget);
    expect(find.text("CHF 42'000"), findsOneWidget);
    expect(find.text('Manquant'), findsOneWidget);
    expect(find.byType(MintPremiumSlider), findsNothing);
  });

  testWidgets('does not treat emergency-fund heuristic as known cash',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      emergencyFund: 'yes_6months',
      monthlyHousing: 2200,
      monthlyLamal: 420,
    ));

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilityInsuranceScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('disability_insurance_result_section')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('disability_insurance_savings_fact')),
      findsOneWidget,
    );
    expect(find.text("CHF 15'720"), findsNothing);
    expect(find.text('Manquant'), findsOneWidget);
    expect(find.byType(MintPremiumSlider), findsNothing);
  });

  testWidgets('explicit zero cash overrides emergency-fund heuristic',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      cashTotal: 0,
      emergencyFund: 'yes_6months',
      monthlyHousing: 2200,
      monthlyLamal: 420,
    ));

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilityInsuranceScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('disability_insurance_result_section')),
      findsOneWidget,
    );
    expect(find.text('CHF 0'), findsOneWidget);
    expect(find.text("CHF 15'720"), findsNothing);
    expect(find.byType(MintPremiumSlider), findsNothing);
  });

  testWidgets('routes missing expenses to budget setup', (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      cashTotal: 42000,
    ));

    await tester.pumpWidget(_buildWithRouter(
      provider,
      const DisabilityInsuranceScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('disability_insurance_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('budget-setup'), findsOneWidget);
  });
}
