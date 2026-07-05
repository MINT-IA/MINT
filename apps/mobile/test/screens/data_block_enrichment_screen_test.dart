import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {CoachProfileProvider? coachProfileProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => coachProfileProvider ?? CoachProfileProvider(),
      ),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
    child: MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: S.supportedLocales,home: child),
  );
}

Widget _wrapRouter(String initialLocation, CoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => DataBlockEnrichmentScreen(
          blockType: state.pathParameters['type']!,
        ),
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const Scaffold(body: Text('coach')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => provider),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
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
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPatrimoine(WidgetTester tester, CoachProfileProvider provider) async {
    await tester.pumpWidget(_wrap(const DataBlockEnrichmentScreen(blockType: 'patrimoine'), coachProfileProvider: provider));
    await tester.pumpAndSettle();
  }

  Future<void> pumpObjectifRetraite(
    WidgetTester tester,
    CoachProfileProvider provider,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'objectifRetraite'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpLpp(
    WidgetTester tester,
    CoachProfileProvider provider,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'lpp'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpPillar3a(
    WidgetTester tester,
    CoachProfileProvider provider,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: '3a'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpRetirementIncome(
    WidgetTester tester,
    CoachProfileProvider provider,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'revenuRetraite'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<CoachProfileProvider> staleRevenueProvider() async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers(
      const {
        'q_gross_salary_annual': 96000,
        'q_canton': 'VD',
        'q_birth_year': 1990,
        'q_has_pension_fund': true,
      },
      source: ProfileDataSource.userInput,
      sourceDate: DateTime.utc(2020, 1, 1),
    );
    final profile = provider.profile!;
    provider.updateProfile(
      profile.copyWith(
        dataTimestamps: {
          ...profile.dataTimestamps,
          'salaireBrutMensuel': DateTime.utc(2020, 1, 1),
        },
      ),
    );
    return provider;
  }

  testWidgets('maps pension alias to LPP block metadata', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'pension')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('maps accented prevoyance alias to LPP block metadata',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'Prévoyance-LPP')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('unknown block shows migration-safe fallback', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'legacy_unknown')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Données'), findsWidgets);
    expect(find.textContaining('n’est plus à jour'), findsOneWidget);
    expect(find.text('Ouvrir le diagnostic'), findsOneWidget);
  });

  testWidgets('revenue block captures canonical first salary facts only',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'revenu'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canton_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsOneWidget);
    expect(find.byKey(const Key('birth_year_input')), findsOneWidget);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('canton_input')), 'GE');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.enterText(find.byKey(const Key('birth_year_input')), '2001');
    await tester.ensureVisible(
      find.byKey(const Key('has_pension_fund_switch')),
    );
    await tester.tap(find.byKey(const Key('has_pension_fund_switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('salary_save_cta')));
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 96000);
    expect(answers['q_canton'], 'GE');
    expect(answers['q_birth_year'], 2001);
    expect(answers['q_has_pension_fund'], true);
    expect(
      answers.keys.where((key) => key.startsWith('q_')).toSet(),
      {
        'q_gross_salary_annual',
        'q_canton',
        'q_birth_year',
        'q_has_pension_fund',
      },
    );
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
    expect(provider.profile?.revenuBrutAnnuel, 96000);
    expect(provider.profile?.canton, 'GE');
    expect(provider.profile?.birthYear, 2001);
  });

  testWidgets('revenue block reconfirms stale salary without duplicate fields',
      (tester) async {
    final provider = await staleRevenueProvider();

    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'revenu'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_reconfirm_card')), findsOneWidget);
    expect(find.text('Oui, toujours'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
    expect(find.text('Rescanner'), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('canton_input')), findsNothing);
    expect(find.byKey(const Key('birth_year_input')), findsNothing);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsNothing);

    await tester.tap(find.byKey(const Key('data_block_reconfirm_yes_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 96000);
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
    expect(
      provider.profile!.dataTimestamps['salaireBrutMensuel']!
          .isAfter(DateTime.utc(2020, 1, 1)),
      isTrue,
    );
  });

  testWidgets('revenue block updates only the stale Data Quest field',
      (tester) async {
    final provider = await staleRevenueProvider();

    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'revenu'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('data_block_reconfirm_update_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('salary_input')), findsOneWidget);
    expect(find.byKey(const Key('canton_input')), findsNothing);
    expect(find.byKey(const Key('birth_year_input')), findsNothing);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsNothing);

    await tester.enterText(find.byKey(const Key('salary_input')), '102000');
    await tester.ensureVisible(find.byKey(const Key('salary_save_cta')));
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 102000);
    expect(answers['q_canton'], 'VD');
    expect(answers['q_birth_year'], 1990);
    expect(answers['q_has_pension_fund'], true);
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
  });

  testWidgets('patrimoine stale salary update routes to revenue owner block',
      (tester) async {
    final provider = await staleRevenueProvider();

    await tester.pumpWidget(_wrapRouter('/data-block/patrimoine', provider));
    await tester.pumpAndSettle();

    expect(find.text('Patrimoine'), findsOneWidget);
    expect(find.byKey(const Key('data_block_reconfirm_card')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.tap(find.byKey(const Key('data_block_reconfirm_update_cta')));
    await tester.pumpAndSettle();

    expect(find.text('Revenu'), findsOneWidget);
    expect(find.byKey(const Key('data_block_reconfirm_card')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.tap(find.byKey(const Key('data_block_reconfirm_update_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('salary_input')), findsOneWidget);
    expect(find.byKey(const Key('canton_input')), findsNothing);
    expect(find.byKey(const Key('birth_year_input')), findsNothing);
  });

  testWidgets('compositionMenage block captures household type only',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'compositionMenage'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('household_type_single')), findsOneWidget);
    expect(find.byKey(const Key('household_type_cohabiting')), findsOneWidget);
    expect(find.byKey(const Key('household_type_married')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('savings_input')), findsNothing);

    await tester.tap(find.byKey(const Key('household_type_cohabiting')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('household_save_cta')));
    await tester.tap(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_civil_status'], 'cohabiting');
    expect(
      answers.keys.where((key) => key.startsWith('q_')).toSet(),
      {'q_civil_status'},
    );
    expect(answers.containsKey('q_household_type'), isFalse);
    expect(provider.profile?.etatCivil, CoachCivilStatus.concubinage);
  });

  testWidgets('patrimoine block captures mortgage project facts only', (tester) async {
    final provider = CoachProfileProvider();
    await pumpPatrimoine(tester, provider);

    expect(find.byKey(const Key('savings_input')), findsOneWidget);
    expect(find.byKey(const Key('target_property_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('canton_input')), findsNothing);

    await tester.enterText(find.byKey(const Key('savings_input')), '250000');
    await tester.enterText(find.byKey(const Key('target_property_input')), '950000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_cash_total'], 250000);
    expect(answers['q_target_property_value'], 950000);
    expect(answers.keys.where((key) => key.startsWith('q_')).toSet(), {'q_cash_total', 'q_target_property_value'});
    expect(answers.containsKey('q_property_market_value'), isFalse);
    expect(provider.profile?.patrimoine.epargneLiquide, 250000);
    expect(provider.profile?.patrimoine.targetPropertyValue, 950000);
    expect(provider.profile?.patrimoine.propertyMarketValue, isNull);
  });

  testWidgets('patrimoine block captures mortgage rate as decimal only',
      (tester) async {
    final provider = CoachProfileProvider();
    await pumpPatrimoine(tester, provider);

    expect(find.byKey(const Key('mortgage_rate_input')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mortgage_rate_input')), '1.8');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_mortgage_rate'], 0.018);
    expect(
      answers.keys.where((key) => key.startsWith('q_')).toSet(),
      {'q_mortgage_rate'},
    );
    expect(answers.containsKey('q_mortgage_rate_percent'), isFalse);
    expect(provider.profile?.patrimoine.mortgageRate, 0.018);
  });

  testWidgets('objectifRetraite block captures target retirement age only',
      (tester) async {
    final provider = CoachProfileProvider();
    await pumpObjectifRetraite(tester, provider);

    expect(find.byKey(const Key('target_retirement_age_input')),
        findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('target_retirement_age_input')),
      '64',
    );
    await tester.ensureVisible(
      find.byKey(const Key('retirement_goal_save_cta')),
    );
    await tester.tap(find.byKey(const Key('retirement_goal_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_target_retirement_age'], 64);
    expect(
      answers.keys.where((key) => key.startsWith('q_')).toSet(),
      {'q_target_retirement_age'},
    );
    expect(answers.containsKey('targetRetirementAge'), isFalse);
    expect(provider.profile?.targetRetirementAge, 64);
  });

  testWidgets('lpp block captures pension assets only', (tester) async {
    final provider = CoachProfileProvider();
    await pumpLpp(tester, provider);

    expect(find.byKey(const Key('lpp_balance_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('target_retirement_age_input')),
        findsNothing);

    await tester.enterText(find.byKey(const Key('lpp_balance_input')), '650000');
    await tester.ensureVisible(find.byKey(const Key('lpp_save_cta')));
    await tester.tap(find.byKey(const Key('lpp_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['_coach_avoir_lpp'], 650000);
    expect(answers.containsKey('q_avoir_lpp'), isFalse);
    expect(answers.containsKey('avoirLpp'), isFalse);
    expect(provider.profile?.prevoyance.avoirLppTotal, 650000);
    expect(
      provider.profile?.dataSources['prevoyance.avoirLppTotal'],
      ProfileDataSource.userInput,
    );
  });

  testWidgets('3a block captures pillar balance only', (tester) async {
    final provider = CoachProfileProvider();
    await pumpPillar3a(tester, provider);

    expect(find.byKey(const Key('pillar3a_balance_input')), findsOneWidget);
    expect(find.byKey(const Key('lpp_balance_input')), findsNothing);
    expect(find.byKey(const Key('target_retirement_age_input')),
        findsNothing);

    await tester.enterText(
      find.byKey(const Key('pillar3a_balance_input')),
      '180000',
    );
    await tester.ensureVisible(find.byKey(const Key('pillar3a_save_cta')));
    await tester.tap(find.byKey(const Key('pillar3a_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_3a_total'], 180000);
    expect(answers.containsKey('_coach_total_3a'), isFalse);
    expect(answers.containsKey('pillar3aBalance'), isFalse);
    expect(provider.profile?.prevoyance.totalEpargne3a, 180000);
    expect(
      provider.profile?.dataSources['prevoyance.totalEpargne3a'],
      ProfileDataSource.userInput,
    );
  });

  testWidgets('patrimoine block saves liquid assets without target price', (tester) async {
    final provider = CoachProfileProvider();
    await pumpPatrimoine(tester, provider);

    await tester.enterText(find.byKey(const Key('savings_input')), '250000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_cash_total'], 250000);
    expect(answers.containsKey('q_target_property_value'), isFalse);
  });

  testWidgets('patrimoine block stores parent liquidity as the cash fact only',
      (tester) async {
    final provider = CoachProfileProvider();
    await pumpPatrimoine(tester, provider);

    await tester.enterText(find.byKey(const Key('savings_input')), '120000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_cash_total'], 120000);
    expect(answers.containsKey('parentLiquidAssets'), isFalse);
    expect(answers.containsKey('patrimoine.epargneLiquide'), isFalse);
    expect(answers.containsKey('q_target_property_value'), isFalse);
    expect(provider.profile?.patrimoine.epargneLiquide, 120000);
    expect(
      provider.profile?.dataSources['patrimoine.epargneLiquide'],
      ProfileDataSource.userInput,
    );
  });

  testWidgets('retirement income block stores direct scenario income only',
      (tester) async {
    final provider = CoachProfileProvider();
    await pumpRetirementIncome(tester, provider);

    expect(
      find.byKey(const Key('parent_annual_retirement_income_input')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('target_retirement_age_input')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('parent_annual_retirement_income_input')),
      '76000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('parent_retirement_income_save_cta')),
    );
    await tester.tap(find.byKey(const Key('parent_retirement_income_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_parent_annual_retirement_income'], 76000);
    expect(
      answers.containsKey('_transmit_property_parent_annual_retirement_income'),
      isFalse,
    );
    expect(answers.containsKey('parentAnnualRetirementIncome'), isFalse);
    expect(
      provider.profile?.dataSources['parentAnnualRetirementIncome'],
      ProfileDataSource.userInput,
    );
  });

  testWidgets('patrimoine block does not seed estimated liquid assets', (tester) async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers(const {
      'q_canton': 'GE',
      'q_gross_salary_annual': 96000,
      'q_housing_cost_period_chf': 2000,
      'q_lamal_premium_monthly_chf': 400,
      'q_emergency_fund': 'yes_6months',
    });
    expect(provider.profile?.patrimoine.epargneLiquide, greaterThan(0));

    await pumpPatrimoine(tester, provider);

    final savingsField = tester.widget<TextField>(find.byKey(const Key('savings_input')));
    expect(savingsField.controller?.text, isEmpty);

    await tester.enterText(find.byKey(const Key('target_property_input')), '950000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_target_property_value'], 950000);
    expect(answers.containsKey('q_cash_total'), isFalse);
  });
}
