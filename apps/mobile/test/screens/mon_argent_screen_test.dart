import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('uses MintState data spine budget before stored budget inputs',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());
    final budgetProvider = BudgetProvider();
    await budgetProvider.setInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 14000,
        housingCost: 5100,
        debtPayments: 0,
        healthInsurance: 880,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ton libre mensuel'), findsOneWidget);
    expect(find.text('Fiabilité'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('Estimation crédible.'), findsOneWidget);
    expect(find.text('Situation financière'), findsOneWidget);
    expect(find.text('Revenu brut annuel'), findsNothing);

    await tester.tap(find.byKey(const Key('mon_argent_situation_expand')));
    await tester.pumpAndSettle();

    expect(find.text('Revenu brut annuel'), findsOneWidget);
    expect(find.text('Logement'), findsOneWidget);
    expect(find.text('Primes maladie (LAMal)'), findsOneWidget);
    expect(find.text('Liquidités disponibles'), findsOneWidget);
    expect(find.text('Investissements'), findsOneWidget);
    expect(find.text("108'000\u00a0CHF"), findsOneWidget);
    expect(find.text("2'400\u00a0CHF"), findsOneWidget);
    expect(find.text("390\u00a0CHF"), findsOneWidget);
    expect(find.text("30'000\u00a0CHF"), findsWidgets);
    expect(find.text("12'000\u00a0CHF"), findsOneWidget);
    expect(find.text('saisi'), findsWidgets);
    expect(find.text('estimé'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('figure_trust_chip_gross_income')),
          )
          .identifier,
      'figure_trust_chip_gross_income',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('figure_trust_chip_investments')))
          .label,
      'estimé',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('figure_trust_chip_investments')))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );

    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.text('Ton budget ce mois'), findsOneWidget);
    expect(find.text("8'000\u00a0CHF"), findsOneWidget);
    expect(find.text("2'100\u00a0CHF"), findsWidgets);
    expect(find.text("14'000\u00a0CHF"), findsNothing);
    expect(find.text("5'100\u00a0CHF"), findsNothing);
    expect(find.text("880\u00a0CHF"), findsNothing);

    await tester.tap(find.text('Patrimoine'));
    await tester.pumpAndSettle();
    expect(find.text('Patrimoine libre'), findsOneWidget);
    expect(find.text('Prévoyance'), findsWidgets);
    expect(find.text("32'000\u00a0CHF"), findsWidgets);
    expect(find.text("184'000\u00a0CHF"), findsNothing);

    await tester.tap(find.text('Prévoyance').first);
    await tester.pumpAndSettle();
    expect(find.text('Extrait AVS'), findsOneWidget);
    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('3e pilier (3a)'), findsOneWidget);
    expect(find.text("120'000\u00a0CHF"), findsOneWidget);
    expect(find.text("32'000\u00a0CHF"), findsOneWidget);
    expect(find.text('manquant'), findsWidgets);
    expect(find.text("0\u00a0CHF"), findsNothing);
    expect(
      tester
          .getSemantics(
            find.byKey(
              const Key('figure_trust_chip_avs_estimated_pension_pension'),
            ),
          )
          .label,
      'manquant',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(
              const Key('figure_trust_chip_lpp_total_balance_pension'),
            ),
          )
          .label,
      'saisi',
    );

    await tester.ensureVisible(find.text('Futur'));
    await tester.tap(find.text('Futur'));
    await tester.pumpAndSettle();
    expect(find.text('Ta trajectoire'), findsOneWidget);
    expect(find.text('Cible'), findsOneWidget);
    expect(find.text('Libre aujourd’hui'), findsOneWidget);
    expect(find.text('Écart mensuel à combler'), findsOneWidget);
    expect(find.text('Prochaine étape'), findsOneWidget);
    expect(find.text("2'000\u00a0CHF"), findsOneWidget);
    expect(find.text("0\u00a0CHF"), findsOneWidget);
  });

  testWidgets('exposes Maestro semantics anchors for central money surfaces',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_screen')))
          .identifier,
      'mon_argent_screen',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_section_selector')))
          .identifier,
      'mon_argent_section_selector',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_data_spine_summary')))
          .identifier,
      'mon_argent_data_spine_summary',
    );
    expect(find.byKey(const Key('mon_argent_situation_map')), findsNothing);

    await tester.tap(find.byKey(const Key('mon_argent_situation_expand')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_situation_map')))
          .identifier,
      'mon_argent_situation_map',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('mon_argent_situation_group_month')),
          )
          .identifier,
      'mon_argent_situation_group_month',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('mon_argent_situation_group_wealth')),
          )
          .identifier,
      'mon_argent_situation_group_wealth',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('mon_argent_situation_group_pension')),
          )
          .identifier,
      'mon_argent_situation_group_pension',
    );

    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_budget_summary')))
          .identifier,
      'mon_argent_budget_summary',
    );

    await tester.tap(find.text('Patrimoine'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_patrimoine_summary')))
          .identifier,
      'mon_argent_patrimoine_summary',
    );

    await tester.tap(find.text('Prévoyance').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_pension_map')))
          .identifier,
      'mon_argent_pension_map',
    );

    await tester.ensureVisible(find.text('Futur'));
    await tester.tap(find.text('Futur'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_trajectory_map')))
          .identifier,
      'mon_argent_trajectory_map',
    );
  });

  testWidgets(
      'direct month section uses canonical BudgetSnapshot over stale budget cache',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 12345,
        housingCost: 2222,
        debtPayments: 0,
        taxProvision: 111,
        healthInsurance: 333,
      ),
    );
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(initialSection: 'month'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ton budget ce mois'), findsOneWidget);
    expect(find.text("8'000\u00a0CHF"), findsOneWidget);
    expect(find.text("5'900\u00a0CHF"), findsOneWidget);
    expect(find.text("2'100\u00a0CHF"), findsOneWidget);
    expect(find.text("12'345\u00a0CHF"), findsNothing);
  });

  testWidgets('refreshed profile budget overrides stale data spine snapshot',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());
    final coachProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1990,
          canton: 'VD',
          salaireBrutMensuel: 6000,
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 410,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
          },
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2055),
            label: 'Retraite',
          ),
        ),
      );
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(initialSection: 'month'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(budgetProvider.source, BudgetDataSource.profile);
    expect(budgetProvider.hasFreshInputs, isTrue);
    expect(find.text(_formatChf(budgetProvider.inputs!.netIncome)),
        findsOneWidget);
    expect(find.text("8'000\u00a0CHF"), findsNothing);
    expect(find.text("2'100\u00a0CHF"), findsNothing);
  });

  testWidgets(
      'refreshed profile budget keeps pension and future spine sections',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());
    final coachProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1990,
          canton: 'VD',
          salaireBrutMensuel: 6000,
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 410,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
          },
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2055),
            label: 'Retraite',
          ),
        ),
      );
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(budgetProvider.hasFreshInputs, isTrue);

    await tester.tap(find.text('Prévoyance').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mon_argent_pension_map')), findsOneWidget);
    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('3e pilier (3a)'), findsOneWidget);
    expect(find.text("120'000\u00a0CHF"), findsOneWidget);
    expect(find.text("32'000\u00a0CHF"), findsOneWidget);

    await tester.ensureVisible(find.text('Futur'));
    await tester.tap(find.text('Futur'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mon_argent_trajectory_map')), findsOneWidget);
    expect(find.text('Ta trajectoire'), findsOneWidget);
    expect(find.text('Libre aujourd’hui'), findsOneWidget);
    expect(find.text("2'000\u00a0CHF"), findsOneWidget);
  });

  testWidgets(
      'today section aligns budget detail rows with refreshed profile budget',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());
    final coachProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1990,
          canton: 'VD',
          salaireBrutMensuel: 6000,
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 410,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
          },
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2055),
            label: 'Retraite',
          ),
        ),
      );
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(budgetProvider.hasFreshInputs, isTrue);
    expect(find.text(_formatChf(_presentBudgetFree(budgetProvider))),
        findsOneWidget);
    expect(find.text("1'100\u00a0CHF"), findsNothing);

    await tester.tap(find.byKey(const Key('mon_argent_situation_expand')));
    await tester.pumpAndSettle();

    expect(find.text("1'100\u00a0CHF"), findsOneWidget);
    expect(find.text("410\u00a0CHF"), findsOneWidget);
    expect(find.text("2'400\u00a0CHF"), findsNothing);
    expect(find.text("390\u00a0CHF"), findsNothing);
  });

  testWidgets('refreshed profile budget also grounds coach whisper over spine',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine(
        spine: _dataSpineWithBudget(
          const BudgetSnapshot(
            present: PresentBudget(
              monthlyNet: 5000,
              monthlyCharges: 6500,
              monthlySavings: 0,
              monthlyFree: -1500,
            ),
            capImpacts: [],
            stage: BudgetStage.presentOnly,
            confidenceScore: 30,
          ),
        ),
      ));
    final coachProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1990,
          canton: 'VD',
          salaireBrutMensuel: 9000,
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 410,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
          },
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2055),
            label: 'Retraite',
          ),
        ),
      );
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(budgetProvider.hasFreshInputs, isTrue);
    expect(find.text(_formatChf(_presentBudgetFree(budgetProvider))),
        findsOneWidget);
    expect(find.text("-1'500\u00a0CHF"), findsNothing);
    expect(find.textContaining('Mois serré.'), findsNothing);
  });

  testWidgets('direct patrimoine section shows investments and debts in net',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(initialSection: 'wealth'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Patrimoine libre'), findsOneWidget);
    expect(find.text('Investissements'), findsOneWidget);
    expect(find.text('Dettes totales'), findsOneWidget);
    expect(find.text("12'000\u00a0CHF"), findsOneWidget);
    expect(find.text("-10'000\u00a0CHF"), findsOneWidget);
    expect(find.text("32'000\u00a0CHF"), findsWidgets);
    expect(find.text("184'000\u00a0CHF"), findsNothing);
  });

  testWidgets('compact section selector exposes Futur without horizontal hunt',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('mon_argent_section_chip_future')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_section_chip_future')))
          .identifier,
      'mon_argent_section_chip_future',
    );

    await tester.tap(find.byKey(const Key('mon_argent_section_chip_future')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_section_future')))
          .identifier,
      'mon_argent_section_future',
    );
    expect(find.text('Ta trajectoire'), findsOneWidget);
  });

  testWidgets('pillar trust chip exposes estimated state without tap action',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine(spine: _dataSpineEstimated3a()));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Prévoyance').first);
    await tester.pumpAndSettle();

    final chip = tester.getSemantics(
      find.byKey(const Key('figure_trust_chip_pillar3a_total_balance_pension')),
    );
    expect(chip.identifier, 'figure_trust_chip_pillar3a_total_balance_pension');
    expect(chip.label, 'estimé');
    expect(chip.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('prefers CoachProfile budget over stale budget cache',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 12345,
        housingCost: 2222,
        debtPayments: 0,
        taxProvision: 100,
        healthInsurance: 444,
      ),
    );

    final coachProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1990,
          canton: 'VD',
          salaireBrutMensuel: 6000,
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2055),
            label: 'Retraite',
          ),
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 390,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
          },
        ),
      );
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(budgetProvider.inputs, isNotNull);
    expect(budgetProvider.inputs!.housingCost, 1100);
    expect(budgetProvider.inputs!.healthInsurance, 390);
    expect(find.text(_formatChf(_presentBudgetFree(budgetProvider))),
        findsOneWidget);
    expect(find.text('Fiabilité'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text("12'345\u00a0CHF"), findsNothing);
  });

  testWidgets('keeps full budget cache when CoachProfile is partial',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 12345,
        housingCost: 2222,
        debtPayments: 0,
        taxProvision: 100,
        healthInsurance: 444,
      ),
    );

    final coachProvider = CoachProfileProvider()
      ..updateFromMiniOnboarding({
        'q_housing_cost_period_chf': 1100.0,
      });
    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(coachProvider.isPartialProfile, isTrue);
    expect(budgetProvider.inputs, isNotNull);
    expect(budgetProvider.inputs!.netIncome, 12345);
    expect(budgetProvider.inputs!.housingCost, 2222);
    expect(budgetProvider.inputs!.healthInsurance, 444);
  });

  testWidgets('loads without CoachProfileProvider', (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2100,
        debtPayments: 0,
        healthInsurance: 390,
      ),
    );

    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MonArgentScreen), findsOneWidget);
    expect(budgetProvider.inputs?.housingCost, 2100);
  });

  testWidgets('can open directly on monthly budget section', (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2100,
        debtPayments: 0,
        healthInsurance: 390,
      ),
    );

    final budgetProvider = BudgetProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(initialSection: 'month'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ton budget ce mois'), findsOneWidget);
    expect(find.byKey(const Key('mon_argent_budget_summary')), findsOneWidget);
  });

  testWidgets(
      'month section keeps canonical snapshot over fresh profile inputs',
      (tester) async {
    final budgetProvider = BudgetProvider();
    await budgetProvider.refreshFromProfile(
      _profileWithBudget(housingCost: 1100, healthInsurance: 390),
    );
    final providerPresent = PresentBudgetBuilder.fromInputs(
      inputs: budgetProvider.inputs!,
      plan: budgetProvider.plan!,
    );
    final canonicalSnapshot = BudgetSnapshot(
      present: PresentBudget(
        monthlyNet: providerPresent.monthlyNet,
        monthlyCharges: providerPresent.monthlyCharges,
        monthlySavings: 700,
        monthlyFree:
            providerPresent.monthlyNet - providerPresent.monthlyCharges - 700,
      ),
      capImpacts: const [],
      stage: BudgetStage.presentOnly,
      confidenceScore: 64,
    );
    final mintState = MintStateProvider()
      ..injectStateForTest(
        _stateWithDataSpine(spine: _dataSpineWithBudget(canonicalSnapshot)),
      );

    expect(budgetProvider.source, BudgetDataSource.profile);
    expect(budgetProvider.hasFreshInputs, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(initialSection: 'month'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_formatChf(providerPresent.monthlyFree)), findsNothing);
    expect(find.text(_formatChf(canonicalSnapshot.present.monthlyFree)),
        findsWidgets);
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_budget_summary')))
          .label,
      contains('Reste ${_formatChf(canonicalSnapshot.present.monthlyFree)}'),
    );
  });

  testWidgets('direct section aliases route to stable Mon Argent sections',
      (tester) async {
    Future<void> pumpSection(String? initialSection) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BudgetProvider>(
              create: (_) => BudgetProvider(),
            ),
            ChangeNotifierProvider<CoachProfileProvider>(
              create: (_) => CoachProfileProvider(),
            ),
            ChangeNotifierProvider<MintStateProvider>(
              create: (_) => MintStateProvider()
                ..injectStateForTest(_stateWithDataSpine()),
            ),
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
            home: MonArgentScreen(initialSection: initialSection),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await pumpSection('mois');
    expect(find.byKey(const Key('mon_argent_section_month')), findsOneWidget);
    expect(find.byKey(const Key('mon_argent_budget_summary')), findsOneWidget);

    await pumpSection('patrimoine');
    expect(find.byKey(const Key('mon_argent_section_wealth')), findsOneWidget);
    expect(
      find.byKey(const Key('mon_argent_patrimoine_summary')),
      findsOneWidget,
    );

    await pumpSection('prevoyance');
    expect(find.byKey(const Key('mon_argent_section_pension')), findsOneWidget);
    expect(find.byKey(const Key('mon_argent_pension_map')), findsOneWidget);

    await pumpSection('prévoyance');
    expect(find.byKey(const Key('mon_argent_section_pension')), findsOneWidget);
    expect(find.byKey(const Key('mon_argent_pension_map')), findsOneWidget);

    await pumpSection('futur');
    expect(find.byKey(const Key('mon_argent_section_future')), findsOneWidget);
    expect(find.byKey(const Key('mon_argent_trajectory_map')), findsOneWidget);

    await pumpSection('unknown');
    expect(find.byKey(const Key('mon_argent_section_today')), findsOneWidget);
    expect(
      find.byKey(const Key('mon_argent_data_spine_summary')),
      findsOneWidget,
    );
  });

  testWidgets('renders missing-data surface for pension without data spine',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Prévoyance').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ce bloc est encore incomplet. '
        'Ouvre la section dédiée pour ajouter les données manquantes.',
      ),
      findsOneWidget,
    );
  });
}

CoachProfile _profileWithBudget({
  required double housingCost,
  required double healthInsurance,
}) {
  return CoachProfile(
    birthYear: 1988,
    canton: 'VD',
    salaireBrutMensuel: 6000,
    depenses: DepensesProfile(
      loyer: housingCost,
      assuranceMaladie: healthInsurance,
    ),
    dataSources: const {
      'depenses.loyer': ProfileDataSource.userInput,
      'depenses.assuranceMaladie': ProfileDataSource.userInput,
    },
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite',
    ),
  );
}

MintUserState _stateWithDataSpine({DataSpineSnapshot? spine}) {
  final profile = CoachProfile(
    birthYear: 1988,
    canton: 'VD',
    salaireBrutMensuel: 9000,
    goalA: GoalA(
      type: GoalAType.achatImmo,
      targetDate: DateTime(2030),
      label: 'Logement',
    ),
  );
  spine ??= _dataSpine();
  return MintUserState(
    profile: profile,
    lifecyclePhase: LifecyclePhase.construction,
    archetype: FinancialArchetype.swissNative,
    budgetSnapshot: spine.budget,
    dataSpineSnapshot: spine,
    confidenceScore: 64,
    capMemory: const CapMemory(),
    computedAt: DateTime.utc(2026, 5, 24),
  );
}

DataSpineSnapshot _dataSpineEstimated3a() {
  const meta = SpineFieldMeta(
    source: ProfileDataSource.userInput,
    confidence: FieldConfidence.known,
    freshness: FieldFreshness.fresh,
  );
  const estimatedMeta = SpineFieldMeta(
    source: ProfileDataSource.estimated,
    confidence: FieldConfidence.estimated,
    freshness: FieldFreshness.fresh,
  );
  final base = _dataSpine();
  return DataSpineSnapshot(
    situation: base.situation,
    budget: base.budget,
    pillars: const PillarPosition(
      avs: AvsPosition(
        contributionYears: PillarFact.missing(),
        gaps: PillarFact.missing(),
        estimatedMonthlyPension: PillarFact.missing(),
        ramd: PillarFact.missing(),
      ),
      lpp: LppPosition(
        totalBalance: PillarFact(
          value: 120000,
          state: PillarFactState.known,
          meta: meta,
        ),
        mandatoryBalance: PillarFact.missing(),
        supplementaryBalance: PillarFact.missing(),
        insuredSalary: PillarFact.missing(),
        buybackMax: PillarFact.missing(),
      ),
      pillar3a: Pillar3aPosition(
        totalBalance: PillarFact(
          value: 32000,
          state: PillarFactState.estimated,
          meta: estimatedMeta,
        ),
        accountsCount: PillarFact.missing(),
        annualContribution: PillarFact.missing(),
        canContribute: true,
      ),
    ),
    trajectory: base.trajectory,
    computedAt: base.computedAt,
  );
}

DataSpineSnapshot _dataSpineWithBudget(BudgetSnapshot budget) {
  final base = _dataSpine();
  return DataSpineSnapshot(
    situation: base.situation,
    budget: budget,
    pillars: base.pillars,
    trajectory: base.trajectory,
    computedAt: base.computedAt,
  );
}

DataSpineSnapshot _dataSpine() {
  const meta = SpineFieldMeta(
    source: ProfileDataSource.userInput,
    confidence: FieldConfidence.known,
    freshness: FieldFreshness.fresh,
  );
  const estimatedMeta = SpineFieldMeta(
    source: ProfileDataSource.estimated,
    confidence: FieldConfidence.estimated,
    freshness: FieldFreshness.fresh,
  );

  return DataSpineSnapshot(
    situation: const FinancialSituation(
      firstName: SpineValue(value: 'Julien', meta: meta),
      birthYear: SpineValue(value: 1988, meta: meta),
      canton: SpineValue(value: 'VD', meta: meta),
      commune: SpineValue(value: 'Lausanne', meta: meta),
      grossAnnualIncome: SpineValue(value: 108000, meta: meta),
      employmentStatus: SpineValue(value: 'salarie', meta: meta),
      monthlyHousingCost: SpineValue(value: 2400, meta: meta),
      lamalPremiumMonthly: SpineValue(value: 390, meta: meta),
      liquidSavings: SpineValue(value: 30000, meta: meta),
      investments: SpineValue(value: 12000, meta: estimatedMeta),
      totalDebt: SpineValue(value: 10000, meta: meta),
      housingStatus: SpineValue(value: 'locataire', meta: meta),
      activeGoalType: SpineValue(value: GoalAType.achatImmo, meta: meta),
    ),
    budget: const BudgetSnapshot(
      present: PresentBudget(
        monthlyNet: 8000,
        monthlyCharges: 5200,
        monthlySavings: 700,
        monthlyFree: 2100,
      ),
      capImpacts: [],
      stage: BudgetStage.presentOnly,
      confidenceScore: 64,
    ),
    pillars: const PillarPosition(
      avs: AvsPosition(
        contributionYears: PillarFact.missing(),
        gaps: PillarFact.missing(),
        estimatedMonthlyPension: PillarFact.missing(),
        ramd: PillarFact.missing(),
      ),
      lpp: LppPosition(
        totalBalance: PillarFact(
          value: 120000,
          state: PillarFactState.known,
          meta: meta,
        ),
        mandatoryBalance: PillarFact.missing(),
        supplementaryBalance: PillarFact.missing(),
        insuredSalary: PillarFact.missing(),
        buybackMax: PillarFact.missing(),
      ),
      pillar3a: Pillar3aPosition(
        totalBalance: PillarFact(
          value: 32000,
          state: PillarFactState.known,
          meta: meta,
        ),
        accountsCount: PillarFact.missing(),
        annualContribution: PillarFact.missing(),
        canContribute: true,
      ),
    ),
    trajectory: const TrajectorySummary(
      status: TrajectoryStatus.onTrack,
      currentMonthlyFree: 2100,
      currentMonthlyCapacity: 2800,
      targetAmount: 120000,
      monthsToTarget: 48,
      monthlyRequired: 2000,
      monthlyGap: -100,
      nextLeverId: 'maintain_plan',
    ),
    computedAt: DateTime.utc(2026, 5, 24),
  );
}

String _formatChf(double amount) {
  final formatted = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => "${match[1]}'",
      );
  return "$formatted\u00a0CHF";
}

double _presentBudgetFree(BudgetProvider provider) {
  return PresentBudgetBuilder.fromInputs(
    inputs: provider.inputs!,
    plan: provider.plan!,
  ).monthlyFree;
}
