import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart'; // Ensure correct imports
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('BudgetScreen smoke test - renders correctly',
      (WidgetTester tester) async {
    // 1. Setup Inputs
    final inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 5000,
      housingCost: 1500,
      debtPayments: 0,
      style: BudgetStyle.envelopes3,
    );

    // 2. Build UI with Provider
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => BudgetProvider(),
          child: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    // 3. Pump to allow init
    await tester.pumpAndSettle();

    // 4. Verify Header
    expect(find.text('Disponible cette période'), findsOneWidget);
    // 5000 - 1500 = 3500
    expect(find.textContaining('3500'), findsOneWidget);

    // 5. Verify Sliders presence (since style is envelopes3)
    expect(find.textContaining('Futur'), findsOneWidget);
    expect(find.textContaining('Variables'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('BudgetScreen Stop Rule triggers warning',
      (WidgetTester tester) async {
    final inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 2000,
      housingCost: 2000, // Available = 0
      debtPayments: 0,
      style: BudgetStyle.envelopes3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => BudgetProvider(),
          child: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Available 0 => Variables 0 => Stop Rule Warning
    expect(find.textContaining('Stop Rule Triggered'), findsOneWidget);
  });
}
