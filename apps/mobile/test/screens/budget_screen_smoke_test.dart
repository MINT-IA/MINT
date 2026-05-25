import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart'; // Ensure correct imports
import 'package:mint_mobile/providers/budget/budget_provider.dart';
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
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
