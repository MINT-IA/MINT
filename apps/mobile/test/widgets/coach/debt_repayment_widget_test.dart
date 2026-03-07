import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/debt_repayment_widget.dart';

void main() {
  final debts = [
    const DebtEntry(
      label: 'Carte de crédit',
      emoji: '💳',
      balance: 8000,
      monthlyRate: 0.015,
      minimumPayment: 200,
    ),
    const DebtEntry(
      label: 'Leasing voiture',
      emoji: '🚗',
      balance: 15000,
      monthlyRate: 0.004,
      minimumPayment: 350,
    ),
    const DebtEntry(
      label: 'Prêt personnel',
      emoji: '🏦',
      balance: 5000,
      monthlyRate: 0.008,
      minimumPayment: 150,
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DebtRepaymentWidget(
              debts: debts,
              extraMonthly: 300,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Avalanche'), findsWidgets);
  });

  testWidgets('shows strategy toggle buttons', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Boule de neige'), findsWidgets);
  });

  testWidgets('shows debt labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Carte de crédit'), findsOneWidget);
    expect(find.textContaining('Leasing'), findsWidgets);
  });

  testWidgets('shows total debt', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 8000+15000+5000 = 28000
    expect(find.textContaining("28'000"), findsWidgets);
  });

  testWidgets('shows comparison callout', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('économise'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('Avalanche', caseSensitive: false)),
      findsWidgets,
    );
  });
}
