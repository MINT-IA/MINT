import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

  _RecordingCoachProfileProvider(Map<String, dynamic> initialAnswers)
      : _answers = Map<String, dynamic>.from(initialAnswers) {
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
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

Widget _buildWithRouter(CoachProfileProvider provider) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ChangeNotifierProvider<CoachProfileProvider>.value(
          value: provider,
          child: const DebtRatioScreen(),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Text(
          'data-block:${state.pathParameters['type']}:'
          '${state.uri.queryParameters['inputKey'] ?? 'none'}',
          key: const Key('data_block_route_probe'),
        ),
      ),
      GoRoute(
        path: '/budget/setup',
        builder: (_, state) => Text(
          'budget:${state.uri.queryParameters['focus'] ?? 'none'}',
          key: const Key('budget_route_probe'),
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

void _setReliableViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('missing ledger facts block debt ratio instead of local sliders',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {});

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_ratio_missing_facts')), findsOneWidget);
    expect(find.byKey(const Key('debt_ratio_result_section')), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Revenu net'), findsWidgets);
    expect(find.text('Crédits/leasing'), findsWidgets);
  });

  testWidgets('missing income routes to the revenue DataBlock', (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {});

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debt_ratio_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(
        find.text('data-block:revenu:q_gross_salary_annual'), findsOneWidget);
  });

  testWidgets('missing debt payments route to the patrimoine DataBlock',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debt_ratio_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:patrimoine:q_debt_payments_period_chf'),
      findsOneWidget,
    );
  });

  testWidgets('mortgage payment alone does not satisfy consumer debt fact',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 2200,
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });
    final profile = provider.profile!;
    provider._profileOverride = profile.copyWith(
      dettes: profile.dettes.copyWith(mensualiteHypotheque: 2200),
    );

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_ratio_missing_facts')), findsOneWidget);

    await tester.tap(find.byKey(const Key('debt_ratio_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:patrimoine:q_debt_payments_period_chf'),
      findsOneWidget,
    );
  });

  testWidgets('known no consumer debt remains known when mortgage exists',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 2200,
      'q_has_consumer_debt': 'no',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });
    final profile = provider.profile!;
    provider._profileOverride = profile.copyWith(
      dettes: profile.dettes.copyWith(mensualiteHypotheque: 2200),
    );

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_ratio_result_section')), findsOneWidget);
    expect(find.byKey(const Key('debt_ratio_missing_facts')), findsNothing);
    expect(find.text('Crédits/leasing'), findsWidgets);
    expect(find.text('CHF\u00a00'), findsWidgets);
  });

  testWidgets('missing housing routes to budget setup with housing focus',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debt_ratio_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('budget:housing'), findsOneWidget);
  });

  testWidgets('missing children route to composition menage DataBlock',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_debt_payments_period_chf': 0,
      'q_has_consumer_debt': 'no',
      'q_civil_status': 'celibataire',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debt_ratio_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:composition_menage:q_children'),
      findsOneWidget,
    );
  });

  testWidgets('missing civil status routes to composition menage DataBlock',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_debt_payments_period_chf': 0,
      'q_has_consumer_debt': 'no',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debt_ratio_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:composition_menage:q_civil_status'),
      findsOneWidget,
    );
  });

  testWidgets('complete ledger facts compute debt ratio without local inputs',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_ratio_missing_facts')), findsNothing);
    expect(find.byKey(const Key('debt_ratio_result_section')), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('CHF\u00a0650'), findsWidgets);
    expect(find.text('CHF\u00a01\'800'), findsWidgets);
  });

  testWidgets('gross-income-derived net is marked as estimated',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.text('Estimé — à confirmer'), findsOneWidget);
  });

  testWidgets('concubinage is explicit in UI and uses single LP base',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'concubinage',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.text('Concubinage'), findsOneWidget);
    expect(find.text("CHF 1'200 / mois"), findsOneWidget);
    expect(find.text("CHF 1'700 / mois"), findsNothing);
  });

  testWidgets('known living charges included in LP margin are visible',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_lamal_premium_monthly_chf': 380,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('debt_ratio_known_charges_fact')),
      findsOneWidget,
    );
    expect(find.text('Charges connues'), findsOneWidget);
    expect(find.text('Inclus dans la marge LP'), findsOneWidget);
    expect(find.text('CHF\u00a0380'), findsWidgets);
  });

  testWidgets('complete sequence return emits ratio outputs on pop',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 1800,
      'q_lamal_premium_monthly_chf': 380,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Text('home'),
        ),
        GoRoute(
          path: '/debt/ratio',
          builder: (_, __) =>
              ChangeNotifierProvider<CoachProfileProvider>.value(
            value: provider,
            child: const DebtRatioScreen(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    router.push('/debt/ratio', extra: const {
      'runId': 'run-debt',
      'stepId': 'tension_01_diagnostic',
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_ratio_result_section')), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    final ret = await ScreenCompletionTracker.lastReturn('debt_ratio');
    expect(ret, isNotNull);
    expect(ret!.outcome, ScreenOutcome.completed);
    expect(ret.runId, 'run-debt');
    expect(ret.stepId, 'tension_01_diagnostic');
    expect(ret.stepOutputs, contains('ratio_endettement'));
    expect(ret.stepOutputs, contains('marge_mensuelle'));
    expect(ret.stepOutputs, containsPair('revenu_estime', true));
    expect(ret.stepOutputs, containsPair('base_lp', 'individuelle'));
    expect(
        ret.stepOutputs, containsPair('supplement_enfant_hypothese', 'none'));
    expect(ret.stepOutputs, containsPair('charges_connues_lp', 380.0));

    final profile = provider.profile!;
    final expected = DebtRatioCalculator.calculate(
      revenusMensuels: profile.toBudgetInputs().netIncome,
      chargesDetteMensuelles: profile.dettes.totalMensualite,
      loyer: profile.depenses.loyer,
      autresChargesFixes: profile.depenses.assuranceMaladie,
      estCelibataire: true,
      nombreEnfants: 0,
    );
    expect(ret.stepOutputs!['ratio_endettement'], expected.ratio);
    expect(ret.stepOutputs!['marge_mensuelle'], expected.margeDisponible);
  });
}
