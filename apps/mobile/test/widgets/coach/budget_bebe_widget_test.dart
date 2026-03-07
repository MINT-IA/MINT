import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/budget_bebe_widget.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BudgetBebeWidget(
              monthlyIncome: 6000,
              costPerChild: 1200,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Budget'), findsWidgets);
  });

  testWidgets('shows 50/30/20 labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Besoins'), findsWidgets);
    expect(find.textContaining('Envies'), findsWidgets);
    expect(find.textContaining('Épargne'), findsWidgets);
  });

  testWidgets('shows slider', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows no children state', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Sans enfant'), findsOneWidget);
  });

  testWidgets('shows correct needs amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 6000 × 50% = 3000
    expect(find.textContaining("3'000"), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('bébé', caseSensitive: false)), findsOneWidget);
  });
}
