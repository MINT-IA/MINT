import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
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
        supportedLocales: S.supportedLocales,
        home: child),
  );
}

Widget _realRouteHarness(CoachProfileProvider provider) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Column(
            children: [
              const Text('ledger-return-destination'),
              Builder(
                builder: (context) => FilledButton(
                  key: const Key('open_gender_collector'),
                  onPressed: () => context.push(
                    '/data-block/revenu?inputKey=q_gender',
                  ),
                  child: const Text('gender'),
                ),
              ),
              Builder(
                builder: (context) => FilledButton(
                  key: const Key('open_birth_date_collector'),
                  onPressed: () => context.push(
                    '/data-block/revenu?inputKey=q_date_of_birth',
                  ),
                  child: const Text('birth-date'),
                ),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => DataBlockEnrichmentScreen(
          blockType: state.pathParameters['type']!,
          initialInputKey: state.uri.queryParameters['inputKey'],
        ),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('stable cancel action returns through the real IconButton',
      (tester) async {
    final provider = CoachProfileProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_realRouteHarness(provider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_gender_collector')));
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      final cancel = find.bySemanticsIdentifier('data_block_cancel_return_cta');
      expect(cancel, findsOneWidget);
      final iconButton =
          find.descendant(of: cancel, matching: find.byType(IconButton));
      expect(iconButton, findsOneWidget);
      final cancelNode = tester.getSemantics(cancel);
      expect(
        cancelNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'the identified node must own the real cancel action',
      );
      expect(cancelNode.flagsCollection.isButton, isTrue);
      expect(
        tester.getSemantics(iconButton).id,
        cancelNode.id,
        reason: 'the IconButton must merge into one identified button node',
      );

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('ledger-return-destination'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('revenue block captures canonical first salary facts only',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'revenu'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('canton_picker')), 'ge');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.enterText(find.byKey(const Key('birth_year_input')), '2001');
    await tester.tap(find.byKey(const Key('has_pension_fund_switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect((answers['q_gross_salary_annual'] as num).toDouble(), 96000);
    expect(answers['q_canton'], 'GE');
    expect(answers['q_birth_year'], 2001);
    expect(answers['q_has_pension_fund'], 'yes');
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);

    expect(provider.profile?.revenuBrutAnnuel, 96000);
    expect(provider.profile?.canton, 'GE');
    expect(provider.profile?.birthYear, 2001);
  });

  testWidgets(
      'real gender and DOB routes save canonical provenance, return, and unlock no-LPP dependency',
      (tester) async {
    final provider = CoachProfileProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_realRouteHarness(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_gender_collector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gender_f_choice')), findsOneWidget);
    expect(find.byKey(const Key('gender_m_choice')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    await tester.tap(find.byKey(const Key('gender_f_choice')));
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();
    expect(provider.profile?.gender, 'F');
    expect(
        provider.profile?.dataSources['gender'], ProfileDataSource.userInput);
    expect(provider.profile?.dataTimestamps['gender'], isNotNull);
    expect(provider.profile?.dataSourceDates['gender'], isNull);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('ledger-return-destination'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_birth_date_collector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('date_of_birth_input')), findsOneWidget);
    expect(find.byKey(const Key('date_of_birth_picker')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('date_of_birth_input')),
      '1986-02-30',
    );
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();
    expect(provider.profile?.dateOfBirth, isNull);
    expect(
        find.text('Les informations saisies sont invalides.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('date_of_birth_input')),
      '1986-08-01',
    );
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();
    expect(provider.profile?.dateOfBirth, DateTime(1986, 8, 1));
    expect(
      provider.profile?.dataSources['dateOfBirth'],
      ProfileDataSource.userInput,
    );
    expect(provider.profile?.dataTimestamps['dateOfBirth'], isNotNull);
    expect(provider.profile?.dataSourceDates['dateOfBirth'], isNull);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_gender', 'F'));
    expect(answers, containsPair('q_date_of_birth', '1986-08-01'));
    final provenance = answers['__provenance'] as Map;
    expect((provenance['gender'] as Map)['source'], 'userInput');
    expect((provenance['dateOfBirth'] as Map)['source'], 'userInput');

    final collectedProfile = provider.profile!;
    final snapshotNow = DateTime.now().toUtc().add(const Duration(seconds: 1));
    final lppStamp = snapshotNow.subtract(const Duration(days: 1));
    final lppSourceDate = DateTime.utc(
      lppStamp.year,
      lppStamp.month,
      lppStamp.day,
    );
    const totalPath = 'prevoyance.avoirLppTotal';
    final lppProfile = CoachProfile(
      birthYear: collectedProfile.birthYear,
      dateOfBirth: collectedProfile.dateOfBirth,
      gender: collectedProfile.gender,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      prevoyance: const PrevoyanceProfile(
        hasPensionFund: true,
        avoirLppTotal: 150000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        label: 'Retraite synthétique',
        targetDate: DateTime(2051, 8, 1),
      ),
      inferDataSources: false,
      dataSources: {
        ...collectedProfile.dataSources,
        'prevoyance.hasPensionFund': ProfileDataSource.userInput,
        'salaireBrutMensuel': ProfileDataSource.userInput,
        totalPath: ProfileDataSource.certificate,
      },
      dataTimestamps: {
        ...collectedProfile.dataTimestamps,
        'prevoyance.hasPensionFund': lppStamp,
        'salaireBrutMensuel': lppStamp,
        totalPath: lppStamp,
      },
      dataSourceDates: {
        ...collectedProfile.dataSourceDates,
        'prevoyance.hasPensionFund': null,
        'salaireBrutMensuel': null,
        totalPath: lppSourceDate,
      },
    );
    final strictLpp = LppEvidenceSnapshot(
      snapshotId: '22222222-2222-4222-8222-222222222222',
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
          value: 150000,
          unit: LppEvidenceUnit.chf,
          profileOwnerId: '11111111-1111-4111-8111-111111111111',
          actorProfileOwnerId: '11111111-1111-4111-8111-111111111111',
          source: ProfileDataSource.certificate.name,
          sourceDate: lppSourceDate,
          updatedAt: lppStamp,
        ),
      },
    );
    final lppDependency = FinancialPlanDependencySnapshot.fromProfile(
      lppProfile,
      profileOwnerId: '11111111-1111-4111-8111-111111111111',
      goalCategory: 'goal_retirement_plan',
      goalAmount: 3000000,
      targetDate: DateTime(2051, 8, 1),
      prospectiveLppReturn: 0.02,
      selfLppSnapshot: strictLpp,
      now: snapshotNow,
    );
    expect(lppDependency.gender, 'F');

    await provider.mergeAnswers({'q_has_pension_fund': 'no'});
    final dependency = FinancialPlanDependencySnapshot.fromProfile(
      provider.profile!,
      profileOwnerId: '11111111-1111-4111-8111-111111111111',
      goalCategory: 'goal_retirement_plan',
      goalAmount: 3000000,
      targetDate: DateTime(2051, 8, 1),
      prospectiveLppReturn: null,
      selfLppSnapshot: null,
      now: snapshotNow,
    );
    expect(dependency.branch, FinancialPlanDependencyBranch.retirementNoLpp);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('ledger-return-destination'), findsOneWidget);
  });

  testWidgets('revenue block inputKey collects only the requested canton fact',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'canton',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canton_picker')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('birth_year_input')), findsNothing);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsNothing);

    await tester.enterText(find.byKey(const Key('canton_picker')), 'ge');
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_canton', 'GE'));
    expect(answers.containsKey('q_gross_salary_annual'), isFalse);
    expect(answers.containsKey('q_birth_year'), isFalse);
    expect(answers.containsKey('q_has_pension_fund'), isFalse);
    expect(provider.profile?.canton, 'GE');
  });

  testWidgets(
      'revenue block inputKey collects independent income as canonical ledger facts',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'q_self_employed_income',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('self_employed_income_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('canton_picker')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('self_employed_income_input')),
      '144000',
    );
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_self_employed_income', 144000));
    expect(answers, containsPair('q_net_income_period_chf', 144000));
    expect(answers, containsPair('q_pay_frequency', 'yearly'));
    expect(answers, containsPair('q_employment_status', 'independant'));
    expect(answers.containsKey('q_gross_salary_annual'), isFalse);
    expect(provider.profile?.selfEmployedNetIncome, 144000);
  });

  testWidgets(
      'revenue block inputKey collects company profit without independent income',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'q_company_profit_annual_chf',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('company_profit_input')), findsOneWidget);
    expect(find.byKey(const Key('self_employed_income_input')), findsNothing);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('canton_picker')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('company_profit_input')),
      '200000',
    );
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_company_profit_annual_chf', 200000));
    expect(answers.containsKey('q_self_employed_income'), isFalse);
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(provider.profile?.companyProfitAnnual, 200000);
    expect(
      provider.profile?.userProvidedFields,
      contains('companyProfitAnnual'),
    );
  });

  testWidgets(
      'revenue block inputKey collects LACI contribution months as a ledger fact',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'q_unemployment_contribution_months',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unemployment_contribution_months_input')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('birth_year_input')), findsNothing);
    expect(find.byKey(const Key('canton_picker')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('unemployment_contribution_months_input')),
      '22',
    );
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_unemployment_contribution_months', 22));
    expect(answers.containsKey('q_gross_salary_annual'), isFalse);
    expect(provider.profile?.unemploymentContributionMonths, 22);
    expect(
      provider.profile?.userProvidedFields,
      contains('unemploymentContributionMonths'),
    );
  });

  testWidgets('revenue block does not treat monthly income as annual input',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'incomeGrossMonthly',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('salary_input')), findsOneWidget);
    expect(find.byKey(const Key('canton_picker')), findsOneWidget);
    expect(find.byKey(const Key('birth_year_input')), findsOneWidget);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsOneWidget);
  });

  testWidgets('revenue block birth-year inputKey requires a value',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'birthYear',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('birth_year_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_birth_year'), isFalse);
    expect(provider.profile, isNull);
    expect(
        find.text('Les informations saisies sont invalides.'), findsOneWidget);
  });

  testWidgets('revenue block pension inputKey can persist default false',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'has2ndPillar',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('has_pension_fund_switch')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_pension_fund', 'no'));
    expect(provider.profile, isNotNull);
  });

  testWidgets('patrimoine block inputKey collects only liquid savings',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: 'totalSavings',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savings_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.enterText(find.byKey(const Key('savings_input')), '120000');
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 120000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(provider.profile?.patrimoine.epargneLiquide, 120000);
    expect(provider.profile?.userProvidedFields, contains('liquidSavings'));
    expect(
      provider.profile?.userProvidedFields,
      contains('liquidSavingsAmount'),
    );
  });

  testWidgets('patrimoine block without inputKey keeps liquid savings default',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'patrimoine'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savings_input')), findsOneWidget);
    expect(find.byKey(const Key('mortgage_balance_input')), findsNothing);

    await tester.enterText(find.byKey(const Key('savings_input')), '45000');
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 45000));
    expect(answers.containsKey('_coach_dettes_hypotheque'), isFalse);
    expect(provider.profile?.patrimoine.epargneLiquide, 45000);
  });

  testWidgets('patrimoine block inputKey collects only mortgage balance',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: '_coach_dettes_hypotheque',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mortgage_balance_input')), findsOneWidget);
    expect(find.byKey(const Key('savings_input')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('mortgage_balance_input')),
      '500000',
    );
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('_coach_dettes_hypotheque', 500000));
    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(provider.profile?.dettes.hypotheque, 500000);
    expect(provider.profile?.userProvidedFields, contains('mortgageBalance'));
  });

  testWidgets('patrimoine block inputKey collects monthly debt payments',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: 'q_debt_payments_period_chf',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_payments_input')), findsOneWidget);
    expect(find.byKey(const Key('savings_input')), findsNothing);
    expect(find.byKey(const Key('mortgage_balance_input')), findsNothing);

    await tester.enterText(find.byKey(const Key('debt_payments_input')), '650');
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_debt_payments_period_chf', 650));
    expect(provider.profile?.dettes.totalMensualite, 650);
    expect(
      provider.profile?.userProvidedFields,
      contains('monthlyDebtPayments'),
    );
  });

  testWidgets('patrimoine debt payment prefill excludes mortgage installment',
      (tester) async {
    final provider = CoachProfileProvider()
      ..updateProfile(CoachProfile.defaults().copyWith(
        dettes: const DetteProfile(
          mensualiteHypotheque: 2200,
          mensualiteCreditConso: 650,
          mensualiteLeasing: 120,
        ),
      ));

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: 'q_debt_payments_period_chf',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('debt_payments_input')),
    );
    expect(input.controller!.text, '770');
  });

  testWidgets('patrimoine block inputKey collects only property market value',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: 'q_property_market_value',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('property_market_value_input')), findsOneWidget);
    expect(find.byKey(const Key('savings_input')), findsNothing);
    expect(find.byKey(const Key('mortgage_balance_input')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('property_market_value_input')),
      '950000',
    );
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_save_success')), findsOneWidget);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_property_market_value', 950000));
    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(answers.containsKey('_coach_dettes_hypotheque'), isFalse);
    expect(provider.profile?.patrimoine.propertyMarketValue, 950000);
    expect(
      provider.profile?.userProvidedFields,
      contains('propertyMarketValue'),
    );
  });

  testWidgets('composition menage block collects children and housing status',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'composition_menage'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('children_count_input')), findsOneWidget);
    expect(find.byKey(const Key('civil_status_single_choice')), findsOneWidget);
    expect(
        find.byKey(const Key('housing_status_renter_choice')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('children_count_input')), '2');
    await tester.tap(find.byKey(const Key('civil_status_married_choice')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('housing_status_owner_choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('housing_status_owner_choice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_children', 2));
    expect(answers, containsPair('q_civil_status', 'marie'));
    expect(answers, containsPair('q_housing_status', 'owner'));
    expect(provider.profile?.nombreEnfants, 2);
    expect(provider.profile?.etatCivil, CoachCivilStatus.marie);
    expect(provider.profile?.housingStatus, 'owner');
    expect(provider.profile?.userProvidedFields, contains('children'));
    expect(provider.profile?.userProvidedFields, contains('civilStatus'));
    expect(provider.profile?.userProvidedFields, contains('housingStatus'));
  });

  testWidgets(
      'composition menage full form does not persist untouched default facts',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'composition_menage'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('children_count_input')), '1');
    await tester.ensureVisible(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_children', 1));
    expect(answers.containsKey('q_civil_status'), isFalse);
    expect(answers.containsKey('q_housing_status'), isFalse);
    expect(provider.profile?.userProvidedFields, contains('children'));
    expect(
        provider.profile?.userProvidedFields, isNot(contains('civilStatus')));
    expect(
      provider.profile?.userProvidedFields,
      isNot(contains('housingStatus')),
    );
  });

  testWidgets('composition menage inputKey collects only civil status',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'composition_menage',
        initialInputKey: 'q_civil_status',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('civil_status_married_choice')), findsOneWidget);
    expect(find.byKey(const Key('children_count_input')), findsNothing);
    expect(find.byKey(const Key('housing_status_renter_choice')), findsNothing);

    await tester.tap(find.byKey(const Key('civil_status_cohabiting_choice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_civil_status', 'concubinage'));
    expect(answers.containsKey('q_children'), isFalse);
    expect(answers.containsKey('q_housing_status'), isFalse);
    expect(provider.profile?.etatCivil, CoachCivilStatus.concubinage);
    expect(provider.profile?.userProvidedFields, contains('civilStatus'));
  });

  testWidgets(
      'composition menage offers and persists registered partnership distinctly',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'composition_menage',
        initialInputKey: 'q_civil_status',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    final choice =
        find.byKey(const Key('civil_status_registered_partner_choice'));
    expect(choice, findsOneWidget);

    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('household_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_civil_status', 'registered_partner'));
    expect(
      provider.profile?.etatCivil,
      CoachCivilStatus.registeredPartnership,
    );
    expect(provider.profile?.hasPartnerContext, isTrue);
    expect(provider.profile?.isAvsMarriageEquivalent, isTrue);
  });

  testWidgets('patrimoine inputKey collects only wealth estimate',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: 'q_wealth_estimate',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wealth_estimate_input')), findsOneWidget);
    expect(find.byKey(const Key('savings_input')), findsNothing);
    expect(find.byKey(const Key('property_market_value_input')), findsNothing);
    expect(find.byKey(const Key('mortgage_balance_input')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('wealth_estimate_input')),
      '1250000',
    );
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_wealth_estimate', 1250000));
    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(answers.containsKey('q_property_market_value'), isFalse);
    expect(provider.profile?.patrimoine.wealthEstimate, 1250000);
  });

  testWidgets('revenue block seeds pension switch from existing profile',
      (tester) async {
    final provider = CoachProfileProvider()
      ..updateFromAnswers({
        'q_gross_salary_annual': 96000,
        'q_canton': 'GE',
        'q_birth_year': 1990,
        'q_has_pension_fund': true,
      });

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'revenu'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('has_pension_fund_switch'));
    expect(tester.widget<SwitchListTile>(tile).value, true);
  });

  testWidgets('revenue block rejects underage birth year', (tester) async {
    final provider = CoachProfileProvider();
    final underageBirthYear = DateTime.now().year - 17;

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'revenu'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('canton_picker')), 'GE');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.enterText(
      find.byKey(const Key('birth_year_input')),
      '$underageBirthYear',
    );

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_gross_salary_annual'), isFalse);
    expect(answers.containsKey('q_canton'), isFalse);
    expect(answers.containsKey('q_birth_year'), isFalse);
    expect(provider.profile, isNull);
  });

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
}
