import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart'; // Ensure correct imports
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_sandwich_chart.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openCalculationDetail(WidgetTester tester) async {
    final toggle = find.byKey(const Key('budget_calculation_detail_toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  testWidgets('BudgetScreen smoke test - renders correctly',
      (WidgetTester tester) async {
    // 1. Setup Inputs
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5000,
      housingCost: 1500,
      debtPayments: 0,
      isOtherFixedMissing: true,
      style: BudgetStyle.envelopes3,
    );

    // 2. Build UI with Provider
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ChangeNotifierProvider(
          create: (_) => BudgetProvider(),
          child: const BudgetScreen(inputs: inputs),
        ),
      ),
    );

    // 3. Pump to allow init: post-frame callback → async setInputs → rebuild
    await tester.pump(); // trigger post-frame callback
    await tester
        .pump(const Duration(milliseconds: 100)); // allow async storage calls
    await tester.pump(const Duration(seconds: 2)); // advance animations

    // 4. Verify Header — hero uses MintHeroNumber with CHF amount
    // Caption is i18n budgetPremierEclairageCaption (not "Disponible ce mois")
    expect(find.textContaining('3500'), findsWidgets);

    // 5. Verify tap-to-type envelope fields (replaced MintPremiumSlider)
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('BudgetScreen empty state uses income-inclusive copy',
      (WidgetTester tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 0,
      housingCost: 0,
      debtPayments: 0,
      style: BudgetStyle.envelopes3,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ChangeNotifierProvider(
          create: (_) => BudgetProvider(),
          child: const BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Ajouter mes revenus'), findsOneWidget);
    expect(
      find.text('Renseigne tes revenus pour créer ton budget personnalisé'),
      findsOneWidget,
    );
    expect(find.textContaining('salaire'), findsNothing);
  });

  testWidgets('BudgetScreen Stop Rule triggers warning',
      (WidgetTester tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 2000,
      housingCost: 2000, // Available = 0
      debtPayments: 0,
      style: BudgetStyle.envelopes3,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ChangeNotifierProvider(
          create: (_) => BudgetProvider(),
          child: const BudgetScreen(inputs: inputs),
        ),
      ),
    );

    // Pump to allow init: post-frame callback → async setInputs → rebuild
    await tester.pump(); // trigger post-frame callback
    await tester
        .pump(const Duration(milliseconds: 100)); // allow async storage calls
    await tester.pump(const Duration(seconds: 2)); // advance animations

    // Available 0 => Variables 0 => Stop Rule Warning
    expect(find.textContaining('Stop Rule Triggered'), findsOneWidget);
  });

  testWidgets(
      'BudgetScreen monthly flow uses explicit inputs, not stale MintState',
      (tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5379,
      housingCost: 2200,
      debtPayments: 0,
      taxProvision: 519.6,
      healthInsurance: 420,
      isOtherFixedMissing: true,
      style: BudgetStyle.envelopes3,
    );
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithBudgetSnapshot());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    await openCalculationDetail(tester);
    await tester.ensureVisible(find.byKey(const Key('budget_formula_proof')));

    expect(find.text('Revenu net'), findsWidgets);
    expect(find.text('Charges'), findsWidgets);
    expect(find.text('Futur'), findsWidgets);
    expect(find.text('Disponible'), findsWidgets);
    expect(find.text("CHF\u00a05'379"), findsWidgets);
    expect(find.text("CHF\u00a03'140"), findsWidgets);
    expect(find.text("CHF\u00a02'239"), findsWidgets);
    expect(find.text("CHF\u00a08'000"), findsNothing);
    expect(find.text("CHF\u00a05'200"), findsNothing);
    expect(find.text("CHF\u00a02'100"), findsNothing);
    expect(find.text("CHF\u00a02'240"), findsNothing);
    expect(find.text('58%'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets(
      'BudgetScreen secondary visuals use displayed charges including other fixed',
      (tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5000.4,
      housingCost: 1200.5,
      debtPayments: 200.49,
      taxProvision: 300.5,
      healthInsurance: 410.49,
      otherFixedCosts: 100.5,
      style: BudgetStyle.envelopes3,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();

    final sandwich = find.byType(BudgetSandwichChart);
    final rule503020 = find.byType(Budget503020Widget);
    final crashTest = find.byType(CrashTestBudgetWidget);

    expect(
      find.descendant(
        of: sandwich,
        matching: find.textContaining('Autres charges fixes'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: sandwich,
        matching: find.textContaining("CHF\u00a02'213"),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: rule503020,
        matching: find.textContaining("1'394"),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: rule503020,
        matching: find.textContaining('836'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: rule503020,
        matching: find.textContaining('557'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: crashTest,
        matching: find.textContaining('Autres charges fixes'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: crashTest,
        matching: find.text('101'),
      ),
      findsWidgets,
    );
    expect(find.textContaining("CHF\u00a02'112"), findsNothing);

    expect(
      PresentBudgetBuilder.fixedChargesFromInputs(inputs),
      2213,
    );
  });

  testWidgets('BudgetScreen monthly flow preserves deficit instead of clamping',
      (tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5000,
      housingCost: 5200,
      debtPayments: 0,
      taxProvision: 500,
      healthInsurance: 420,
      style: BudgetStyle.envelopes3,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    await openCalculationDetail(tester);
    await tester.ensureVisible(find.byKey(const Key('budget_formula_proof')));

    expect(find.text('Disponible'), findsWidgets);
    expect(find.text("CHF\u00a0-1'120"), findsWidgets);
  });

  testWidgets(
      'BudgetScreen hero formula subtracts future envelope from available',
      (tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5379,
      housingCost: 2200,
      debtPayments: 0,
      taxProvision: 520,
      healthInsurance: 420,
      style: BudgetStyle.envelopes3,
    );
    await BudgetLocalStore().saveOverride('future', 700);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('budget_hero_formula')), findsOneWidget);
    expect(
      find.text(
          "CHF\u00a05'379 − CHF\u00a03'140 − CHF\u00a0700 = CHF\u00a01'539"),
      findsOneWidget,
    );
    expect(find.text("– CHF\u00a0700"), findsNothing);
    expect(find.text("CHF\u00a02'939"), findsNothing);
    expect(find.text("CHF\u00a02'239"), findsNothing);
  });

  testWidgets('BudgetScreen hero formula omits zero future envelope',
      (tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5379,
      housingCost: 2200,
      debtPayments: 0,
      taxProvision: 520,
      healthInsurance: 420,
      style: BudgetStyle.envelopes3,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('budget_hero_formula')), findsOneWidget);
    expect(
      find.text("CHF\u00a05'379 − CHF\u00a03'140 = CHF\u00a02'239"),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'impôts estimés, dettes connues et épargne planifiée',
      ),
      findsOneWidget,
    );
    expect(find.textContaining("− CHF\u00a00"), findsNothing);
    expect(find.byKey(const Key('budget_debt_disclosure')), findsNothing);
  });

  testWidgets('BudgetScreen exposes Maestro semantics anchors', (tester) async {
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5000,
      housingCost: 1500,
      debtPayments: 0,
      isOtherFixedMissing: true,
      style: BudgetStyle.envelopes3,
    );
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithBudgetSnapshot());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('budget_flow_map')), findsNothing);
    expect(find.byKey(const Key('budget_formula_proof')), findsNothing);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('budget_calculation_detail_toggle')),
          )
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    await openCalculationDetail(tester);
    await tester.ensureVisible(find.byKey(const Key('budget_formula_proof')));

    expect(
      tester.getSemantics(find.byKey(const Key('budget_screen'))).identifier,
      'budget_screen',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_data_quality_banner')))
          .identifier,
      'budget_data_quality_banner',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_hero_summary')))
          .identifier,
      'budget_hero_summary',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('budget_flow_map'))).identifier,
      'budget_flow_map',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('budget_calculation_detail_toggle')),
          )
          .identifier,
      'budget_calculation_detail_toggle',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_formula_proof')))
          .identifier,
      'budget_formula_proof',
    );
  });

  testWidgets('BudgetContainerScreen restores saved inputs on direct open',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 950,
        healthInsurance: 420,
        isTaxEstimated: true,
        isOtherFixedMissing: true,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
          home: BudgetContainerScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_data_quality_banner')))
          .identifier,
      'budget_data_quality_banner',
    );
    expect(find.text("CHF\u00a08'000"), findsWidgets);
  });

  testWidgets('BudgetContainerScreen prefers CoachProfile over stale cache',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 950,
        healthInsurance: 420,
        isTaxEstimated: true,
        isOtherFixedMissing: true,
      ),
    );

    final profileProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1988,
          canton: 'VD',
          salaireBrutMensuel: 6000,
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 390,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
          },
          goalA: GoalA(
            type: GoalAType.achatImmo,
            targetDate: DateTime(2030),
            label: 'Logement',
          ),
        ),
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: profileProvider,
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
          home: BudgetContainerScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(BudgetScreen), findsOneWidget);
    final budgetProvider = Provider.of<BudgetProvider>(
      tester.element(find.byType(BudgetContainerScreen)),
      listen: false,
    );
    expect(budgetProvider.inputs?.housingCost, 1100);
    expect(budgetProvider.inputs?.healthInsurance, 390);
    expect(find.text("CHF\u00a08'000"), findsNothing);
    expect(find.text("CHF\u00a02'200"), findsNothing);
  });

  testWidgets('BudgetContainerScreen hydrates debts from CoachProfile',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 950,
        healthInsurance: 420,
      ),
    );

    final profileProvider = CoachProfileProvider()
      ..updateProfile(
        CoachProfile(
          birthYear: 1988,
          canton: 'VD',
          salaireBrutMensuel: 6000,
          depenses: const DepensesProfile(
            loyer: 1100,
            assuranceMaladie: 390,
          ),
          dettes: const DetteProfile(
            creditConsommation: 12000,
          ),
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
            'dettes.totalDettes': ProfileDataSource.userInput,
          },
          goalA: GoalA(
            type: GoalAType.achatImmo,
            targetDate: DateTime(2030),
            label: 'Logement',
          ),
        ),
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: profileProvider,
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
          home: BudgetContainerScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    final budgetProvider = Provider.of<BudgetProvider>(
      tester.element(find.byType(BudgetContainerScreen)),
      listen: false,
    );
    // BudgetInputs.fromCoachProfile currently spreads total debts over 36 months.
    expect(budgetProvider.inputs?.debtPayments, closeTo(333.33, 0.01));
    expect(find.text('Remboursement dettes: CHF\u00a0333'), findsWidgets);
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_debt_disclosure')))
          .identifier,
      'budget_debt_disclosure',
    );
  });

  testWidgets('BudgetContainerScreen routeExtra emits Tier A return on pop',
      (tester) async {
    await ScreenCompletionTracker.clear('budget');
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 8000.4,
      housingCost: 2200.5,
      debtPayments: 333.5,
      taxProvision: 950.5,
      healthInsurance: 420.5,
    );
    final expectedCharges = PresentBudgetBuilder.fixedChargesFromInputs(inputs);
    expect(expectedCharges, 3907);
    await BudgetLocalStore().saveInputs(
      inputs,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
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
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BudgetContainerScreen(
                    routeExtra: {
                      'runId': 'run-budget-1',
                      'stepId': 'step-budget-1',
                    },
                  ),
                ),
              ),
              child: const Text('open budget'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open budget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(BudgetScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(BudgetScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final screenReturn = await ScreenCompletionTracker.lastReturn('budget');
    expect(screenReturn?.route, '/budget');
    expect(screenReturn?.outcome, ScreenOutcome.completed);
    expect(screenReturn?.runId, 'run-budget-1');
    expect(screenReturn?.stepId, 'step-budget-1');
    expect(
      screenReturn?.stepOutputs?['revenu_net'],
      PresentBudgetBuilder.displayChf(inputs.netIncome),
    );
    expect(screenReturn?.stepOutputs?['charges_totales'], expectedCharges);
  });

  testWidgets('BudgetContainerScreen keeps full cache over partial profile',
      (tester) async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 950,
        healthInsurance: 420,
      ),
    );

    final profileProvider = CoachProfileProvider()
      ..updateFromMiniOnboarding({
        'q_housing_cost_period_chf': 1100.0,
      });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: profileProvider,
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
          home: BudgetContainerScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    final budgetProvider = Provider.of<BudgetProvider>(
      tester.element(find.byType(BudgetContainerScreen)),
      listen: false,
    );
    expect(profileProvider.isPartialProfile, isTrue);
    expect(budgetProvider.inputs?.netIncome, 8000);
    expect(budgetProvider.inputs?.housingCost, 2200);
    expect(budgetProvider.inputs?.healthInsurance, 420);
  });

  testWidgets(
      'BudgetContainerScreen hydrates budget-first wizard answers after profile load',
      (tester) async {
    final profileProvider = CoachProfileProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: profileProvider,
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
          home: BudgetContainerScreen(),
        ),
      ),
    );

    profileProvider.updateFromMiniOnboarding({
      'q_gross_salary_annual': 90000.0,
      'q_housing_cost_period_chf': 2200.0,
      'q_lamal_premium_monthly_chf': 420.0,
      'q_pay_frequency': 'monthly',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    final budgetProvider = Provider.of<BudgetProvider>(
      tester.element(find.byType(BudgetContainerScreen)),
      listen: false,
    );
    expect(profileProvider.isPartialProfile, isTrue);
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(budgetProvider.inputs?.housingCost, 2200);
    expect(budgetProvider.inputs?.healthInsurance, 420);
  });
}

MintUserState _stateWithBudgetSnapshot() {
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
  return MintUserState(
    profile: profile,
    lifecyclePhase: LifecyclePhase.construction,
    archetype: FinancialArchetype.swissNative,
    budgetSnapshot: const BudgetSnapshot(
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
    confidenceScore: 64,
    capMemory: const CapMemory(),
    computedAt: DateTime.utc(2026, 5, 24),
  );
}
