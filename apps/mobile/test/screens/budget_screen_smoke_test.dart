import 'dart:ui' show SemanticsAction, Tristate;

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
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_sandwich_chart.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/widgets/budget/emergency_fund_ring.dart';
import 'package:mint_mobile/widgets/action_insight_widget.dart';

import '../semantics_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    E2eRuntimeFlags.resetForTest();
  });

  tearDown(E2eRuntimeFlags.resetForTest);

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

    final fallbackActionInsight =
        tester.getSemantics(find.byType(ActionInsightWidget));
    expect(fallbackActionInsight.flagsCollection.isButton, isTrue);
    expect(
      fallbackActionInsight.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      fallbackActionInsight.label,
      "Complète ton profil pour voir l'impact exact",
    );
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
    expect(find.textContaining('Ton budget mensuel'), findsOneWidget);
    expect(find.textContaining('Ton budget retraite'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Budget mensuel')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Budget retraite')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Revenu net')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Salaire net')), findsNothing);
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
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('budget_calculation_detail_toggle')),
          )
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isFalse,
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
    final heroSummary = tester.widget<Semantics>(
      find.byKey(const Key('budget_hero_summary')),
    );
    expect(heroSummary.properties.label, contains('Disponible ce mois'));
    expect(heroSummary.properties.label, contains("CHF\u00a03'500"));
    expect(
      heroSummary.properties.label,
      contains('charges fixes, impôts estimés, dettes connues'),
    );
    final qualityBanner = tester.widget<Semantics>(
      find.byKey(const Key('budget_data_quality_banner')),
    );
    expect(
      qualityBanner.properties.label,
      contains('Certaines charges sont encore manquantes'),
    );
    expect(
      qualityBanner.properties.label,
      contains('Compléter mes données'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_data_quality_banner')))
          .flagsCollection
          .isButton,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_data_quality_banner')))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('budget_flow_map'))).identifier,
      'budget_flow_map',
    );
    final detailToggleNode = tester.getSemantics(
      find.byKey(const Key('budget_calculation_detail_toggle')),
    );
    final detailToggleData = detailToggleNode.getSemanticsData();
    expect(detailToggleNode.identifier, 'budget_calculation_detail_toggle');
    expect(detailToggleNode.flagsCollection.isButton, isTrue);
    expect(detailToggleData.hasAction(SemanticsAction.tap), isTrue);
    expect(detailToggleData.flagsCollection.isExpanded, Tristate.isTrue);
    expect(detailToggleData.label, 'Détail du calcul');
    expect(detailToggleData.label, isNot(contains('Revenu net')));
    expect(detailToggleData.label, isNot(contains('Charges')));
    expect(detailToggleNode.childrenCountInTraversalOrder, 0);
    expect(
      tester
          .getSemantics(find.byKey(const Key('budget_formula_proof')))
          .identifier,
      'budget_formula_proof',
    );
  });

  testWidgets('BudgetScreen independent no-LPP semantics traverse cashflow',
      (tester) async {
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final profile = CoachProfile.fromWizardAnswers(
      seed.toWizardAnswers(now: DateTime(2026, 6, 6)),
    );
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 7200,
      housingCost: 1872,
      debtPayments: 0,
      taxProvision: 1350,
      healthInsurance: 420,
      otherFixedCosts: 480,
      isTaxEstimated: true,
      style: BudgetStyle.envelopes3,
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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

      final quality = tester
          .getSemantics(find.byKey(const Key('budget_data_quality_banner')));
      final hero =
          tester.getSemantics(find.byKey(const Key('budget_hero_summary')));
      final toggle = tester.getSemantics(
        find.byKey(const Key('budget_calculation_detail_toggle')),
      );
      final flowMap =
          tester.getSemantics(find.byKey(const Key('budget_flow_map')));
      final formula =
          tester.getSemantics(find.byKey(const Key('budget_formula_proof')));
      final actionInsight =
          tester.getSemantics(find.byType(ActionInsightWidget));

      expect(quality.identifier, 'budget_data_quality_banner');
      expect(quality.flagsCollection.isButton, isTrue);
      expect(
        quality.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      expect(hero.identifier, 'budget_hero_summary');
      expect(hero.label, contains('Disponible ce mois'));
      expect(hero.label, contains('CHF'));
      expect(hero.label, contains('charges fixes'));

      expect(toggle.identifier, 'budget_calculation_detail_toggle');
      expect(toggle.flagsCollection.isButton, isTrue);
      expect(toggle.getSemanticsData().flagsCollection.isExpanded,
          Tristate.isTrue);
      expect(toggle.getSemanticsData().label, 'Détail du calcul');
      expect(toggle.childrenCountInTraversalOrder, 0);

      expect(flowMap.identifier, 'budget_flow_map');
      expect(flowMap.label, contains('Revenu net'));
      expect(flowMap.label, contains('Charges'));
      expect(flowMap.label, contains('Futur'));
      expect(flowMap.label, contains('Disponible'));
      expect(flowMap.label, isNot(contains('Salaire net')));
      expect(flowMap.label, isNot(contains('Budget retraite')));

      expect(formula.identifier, 'budget_formula_proof');
      expect(formula.label, contains('Revenu net'));
      expect(formula.label, contains('Disponible'));

      expect(actionInsight.flagsCollection.isButton, isTrue);
      expect(
        actionInsight.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(actionInsight.label, contains('l’AI'));
      expect(actionInsight.label, contains('Voir l’écart'));
      expect(actionInsight.label, contains('~70'));
      expect(
        RegExp('Voir l’écart').allMatches(actionInsight.label).length,
        1,
      );

      final traversal = semanticIdentifiersInTraversalOrder(tester);
      expect(traversal, isNot(contains('budget_income_basis')));
      expectIdentifierSubsequence(
        traversal,
        [
          'budget_screen',
          'budget_data_quality_banner',
          'budget_hero_summary',
          'budget_calculation_detail_toggle',
          'budget_flow_map',
          'budget_formula_proof',
        ],
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('BudgetScreen independent no-LPP exposes 3a capacity guard',
      (tester) async {
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final profile = CoachProfile.fromWizardAnswers(
      seed.toWizardAnswers(now: DateTime(2026, 6, 6)),
    );
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 7200,
      housingCost: 1872,
      debtPayments: 0,
      taxProvision: 1350,
      healthInsurance: 420,
      otherFixedCosts: 480,
      isTaxEstimated: true,
      style: BudgetStyle.envelopes3,
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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

      final capacityGuard = tester.getSemantics(
        find.byKey(const Key('budget_independent_no_lpp_capacity_guard')),
      );
      final label = capacityGuard.label.replaceAll('\u00a0', ' ');

      expect(
          capacityGuard.identifier, 'budget_independent_no_lpp_capacity_guard');
      expect(
        label,
        contains('Clarifier mon statut indépendant avant d’augmenter le 3a'),
      );
      expect(label, contains('statut AVS indépendant'));
      expect(label, contains('revenu imposable'));
      expect(label, contains('volatilité de tes revenus'));
      expect(label, contains('couvertures risque'));
      expect(label, contains('LPP facultative'));
      expect(label, contains('liquidité'));
      expect(label, contains('Marge 3a à vérifier'));
      expect(label, contains("CHF 11'280/an"));
      expect(label, contains('CHF 940/mois'));
      expect(label, contains("CHF 2'578/mois"));
      expect(label, contains('Marge légale ≠ capacité mensuelle'));
      expect(
        label,
        isNot(contains('Budget libre insuffisant')),
      );
      for (final fragment in [
        'Plafond 3a salarié',
        '7’258',
        'ouvrir',
        'Ouvre',
        'fintech',
        'UBS',
        'Raiffeisen',
        'Swiss Life',
        '60% actions',
      ]) {
        expect(label, isNot(contains(fragment)), reason: fragment);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'BudgetScreen independent no-LPP warns when monthly 3a room exceeds free budget',
      (tester) async {
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final profile = CoachProfile.fromWizardAnswers(
      seed.toWizardAnswers(now: DateTime(2026, 6, 6)),
    );
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 4500,
      housingCost: 1872,
      debtPayments: 0,
      taxProvision: 1350,
      healthInsurance: 420,
      otherFixedCosts: 480,
      isTaxEstimated: true,
      style: BudgetStyle.envelopes3,
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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

      final capacityGuard = tester.getSemantics(
        find.byKey(const Key('budget_independent_no_lpp_capacity_guard')),
      );
      final label = capacityGuard.label.replaceAll('\u00a0', ' ');

      expect(label, contains('CHF 940/mois'));
      expect(
        label,
        contains(
          'Budget libre insuffisant pour couvrir cet équivalent mensuel',
        ),
      );
      expect(label, contains('vérifie la trésorerie avant tout versement'));
      expect(label, isNot(contains('ouvrir un compte')));
      expect(label, isNot(contains('UBS')));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'BudgetScreen independent no-LPP shortfall warning follows displayed monthly values',
      (tester) async {
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final answers = seed.toWizardAnswers(now: DateTime(2026, 6, 6))
      ..['q_self_employed_net_income_annual_chf'] = 86418.0;
    final profile = CoachProfile.fromWizardAnswers(answers);
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5562,
      housingCost: 1872,
      debtPayments: 0,
      taxProvision: 1350,
      healthInsurance: 420,
      otherFixedCosts: 480,
      isTaxEstimated: true,
      style: BudgetStyle.envelopes3,
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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

      final capacityGuard = tester.getSemantics(
        find.byKey(const Key('budget_independent_no_lpp_capacity_guard')),
      );
      final label = capacityGuard.label.replaceAll('\u00a0', ' ');

      expect(label, contains('CHF 940/mois'));
      expect(
        label,
        isNot(contains('Budget libre insuffisant')),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'BudgetScreen independent no-LPP updated-income semantics reject stale cashflow',
      (tester) async {
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final answers = seed.toWizardAnswers(now: DateTime(2026, 6, 6))
      ..['q_self_employed_net_income_annual_chf'] = 96000.0
      ..['q_net_income_period_chf'] = 8000.0
      ..['q_3a_annual_contribution'] = 6000.0;
    final profile = CoachProfile.fromWizardAnswers(answers);
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 8000,
      housingCost: 1872,
      debtPayments: 0,
      taxProvision: 1350,
      healthInsurance: 420,
      otherFixedCosts: 480,
      isTaxEstimated: true,
      style: BudgetStyle.envelopes3,
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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

      final hero =
          tester.getSemantics(find.byKey(const Key('budget_hero_summary')));
      final formula =
          tester.getSemantics(find.byKey(const Key('budget_formula_proof')));
      final flowMap =
          tester.getSemantics(find.byKey(const Key('budget_flow_map')));
      final heroLabel = hero.label.replaceAll('\u00a0', ' ');
      final formulaLabel = formula.label.replaceAll('\u00a0', ' ');
      final flowMapLabel = flowMap.label.replaceAll('\u00a0', ' ');

      expect(hero.identifier, 'budget_hero_summary');
      expect(heroLabel, contains('Disponible ce mois'));
      expect(heroLabel, isNot(contains("CHF 7'200")));

      expect(formula.identifier, 'budget_formula_proof');
      expect(formulaLabel, contains("CHF 8'000"));
      expect(formulaLabel, isNot(contains("CHF 7'200")));

      expect(flowMap.identifier, 'budget_flow_map');
      expect(flowMapLabel, contains("CHF 8'000"));
      expect(flowMapLabel, isNot(contains("CHF 7'200")));
      expect(flowMapLabel, isNot(contains('Salaire net')));

      final traversal = semanticIdentifiersInTraversalOrder(tester);
      expect(traversal, isNot(contains('budget_income_basis')));
      expectIdentifierSubsequence(
        traversal,
        [
          'budget_screen',
          'budget_data_quality_banner',
          'budget_hero_summary',
          'budget_calculation_detail_toggle',
          'budget_flow_map',
          'budget_formula_proof',
        ],
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('BudgetScreen E2E proof anchor exposes income basis when enabled',
      (tester) async {
    E2eRuntimeFlags.proofAnchorsOverride = true;
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final profile = CoachProfile.fromWizardAnswers(
      seed.toWizardAnswers(now: DateTime(2026, 6, 6)),
    );
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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
            home: BudgetScreen(
              inputs: BudgetInputs(
                payFrequency: PayFrequency.monthly,
                netIncome: 8000,
                housingCost: 1872,
                debtPayments: 0,
                taxProvision: 1350,
                healthInsurance: 420,
                otherFixedCosts: 480,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('source=derived_self_employed_annual_proxy'),
        findsOneWidget,
      );
      expect(
        find.textContaining('q_self_employed_net_income_annual_chf=86400'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('EmergencyFundRing exposes value without false button role',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmergencyFundRing(months: 3.5),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(EmergencyFundRing));

      expect(node.label, contains('Fonds d’urgence'));
      expect(node.label, contains('3.5 mois sur 6'));
      expect(node.label, isNot('interactive element'));
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'BudgetScreen E2E proof anchor tracks updated independent no-LPP income',
      (tester) async {
    E2eRuntimeFlags.proofAnchorsOverride = true;
    final seed =
        CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
    final answers = seed.toWizardAnswers(now: DateTime(2026, 6, 6))
      ..['q_self_employed_net_income_annual_chf'] = 96000.0
      ..['q_net_income_period_chf'] = 8000.0
      ..['q_3a_annual_contribution'] = 6000.0;
    final profile = CoachProfile.fromWizardAnswers(answers);
    final profileProvider = CoachProfileProvider()..updateProfile(profile);

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
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
            home: BudgetScreen(
              inputs: BudgetInputs(
                payFrequency: PayFrequency.monthly,
                netIncome: 8000,
                housingCost: 1872,
                debtPayments: 0,
                taxProvision: 1350,
                healthInsurance: 420,
                otherFixedCosts: 480,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final anchor = find.byKey(const Key('budget_income_basis'));
      final basisText = tester
          .widget<Text>(
            find.textContaining('source=derived_self_employed_annual_proxy'),
          )
          .data!
          .replaceAll('\u00a0', ' ');
      expect(
        find.textContaining('source=derived_self_employed_annual_proxy'),
        findsOneWidget,
      );
      expect(
          basisText, contains('q_self_employed_net_income_annual_chf=96000'));
      expect(basisText, contains("monthly_net=CHF 8'000"));
      expect(basisText,
          isNot(contains('q_self_employed_net_income_annual_chf=86400')));
      expect(basisText, isNot(contains("monthly_net=CHF 7'200")));
      expect(anchor, findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('EmergencyFundRing exposes tap action only when tappable',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyFundRing(
              months: 2,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(EmergencyFundRing));

      expect(node.label, contains('Fonds d’urgence'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.byType(EmergencyFundRing));
      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
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
