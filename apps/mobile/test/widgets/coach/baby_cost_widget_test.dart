import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/baby_cost_widget.dart';

void main() {
  final items = [
    const BabyCostItem(
      label: 'Crèche / garde',
      emoji: '🏫',
      monthlyCost: 2200,
      note: 'Canton de Vaud, subventionné',
    ),
    const BabyCostItem(
      label: 'Alimentation',
      emoji: '🍼',
      monthlyCost: 150,
    ),
    const BabyCostItem(
      label: 'Vêtements',
      emoji: '👕',
      monthlyCost: 100,
    ),
    const BabyCostItem(
      label: 'Santé / LAMal',
      emoji: '🏥',
      monthlyCost: 130,
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BabyCostWidget(
              items: items,
              yearsOfDependency: 25,
              canton: 'Vaud',
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('bonheur'), findsWidgets);
  });

  testWidgets('shows monthly total', (tester) async {
    await tester.pumpWidget(buildWidget());
    // Total = 2200+150+100+130 = 2580
    expect(find.textContaining("2'580"), findsWidgets);
  });

  testWidgets('shows lifetime total', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 2580 × 12 × 25 = 774'000
    expect(find.textContaining("774'000"), findsWidgets);
  });

  testWidgets('shows creche callout', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('crèche'), findsWidgets);
  });

  testWidgets('shows canton', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Vaud'), findsWidgets);
  });

  testWidgets('shows items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Alimentation'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('bonheur', caseSensitive: false)), findsOneWidget);
  });
}
