import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart'; // Ensure correct imports
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

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
    await tester.pump(const Duration(milliseconds: 100)); // allow async storage calls
    await tester.pump(const Duration(seconds: 2)); // advance animations

    // 4. Verify Header — hero uses MintHeroNumber with CHF amount
    // Caption is i18n budgetChiffreChocCaption (not "Disponible ce mois")
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
    await tester.pump(const Duration(milliseconds: 100)); // allow async storage calls
    await tester.pump(const Duration(seconds: 2)); // advance animations

    // Available 0 => Variables 0 => Stop Rule Warning
    expect(find.textContaining('Stop Rule Triggered'), findsOneWidget);
  });
}
