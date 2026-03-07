import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';

void main() {
  final categories = [
    const BudgetCategory(
      label: 'FIXE',
      emoji: '\ud83c\udfe0',
      percent: 50,
      amount: 2105,
      examples: ['loyer', 'LAMal', 'transport'],
    ),
    const BudgetCategory(
      label: 'VIE',
      emoji: '\ud83c\udf89',
      percent: 30,
      amount: 1263,
      examples: ['sorties', 'resto', 'sport'],
    ),
    const BudgetCategory(
      label: 'FUTUR',
      emoji: '\ud83d\udcb0',
      percent: 20,
      amount: 842,
      examples: ['3a', '\u00e9pargne'],
    ),
  ];

  Widget buildWidget({String? chiffreChoc}) => MaterialApp(
        home: Scaffold(
          body: Budget503020Widget(
            netSalary: 4210,
            categories: categories,
            chiffreChoc: chiffreChoc,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('50 / 30 / 20'), findsOneWidget);
  });

  testWidgets('shows net salary', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("4'210"), findsWidgets);
  });

  testWidgets('shows all 3 category labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('FIXE'), findsOneWidget);
    expect(find.textContaining('VIE'), findsOneWidget);
    expect(find.textContaining('FUTUR'), findsOneWidget);
  });

  testWidgets('shows percentages', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('50%'), findsWidgets);
    expect(find.textContaining('20%'), findsWidgets);
  });

  testWidgets('shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("2'105"), findsOneWidget);
    expect(find.textContaining('842'), findsWidgets);
  });

  testWidgets('shows chiffre-choc when provided', (tester) async {
    await tester.pumpWidget(buildWidget(chiffreChoc: 'Test chiffre-choc'));
    expect(find.textContaining('Test chiffre-choc'), findsOneWidget);
  });

  testWidgets('hides chiffre-choc when null', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Test'), findsNothing);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Budget 50/30/20')), findsOneWidget);
  });
}
