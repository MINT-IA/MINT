import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/budget_sandwich_chart.dart';

void main() {
  final incomes = [
    const BudgetLineItem(label: 'AVS', amount: 1934),
    const BudgetLineItem(label: 'LPP', amount: 2410),
    const BudgetLineItem(label: '3a', amount: 540),
    const BudgetLineItem(label: '\u00c9pargne', amount: 350),
  ];

  final expenses = [
    const BudgetLineItem(label: 'Imp\u00f4ts', amount: 650),
    const BudgetLineItem(label: 'Loyer', amount: 1500),
    const BudgetLineItem(label: 'LAMal', amount: 450),
    const BudgetLineItem(label: 'Quotidien', amount: 2200),
  ];

  Widget buildTestWidget({
    List<BudgetLineItem>? customIncomes,
    List<BudgetLineItem>? customExpenses,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BudgetSandwichChart(
            incomes: customIncomes ?? incomes,
            expenses: customExpenses ?? expenses,
          ),
        ),
      ),
    );
  }

  group('BudgetSandwichChart', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(BudgetSandwichChart), findsOneWidget);
    });

    testWidgets('shows header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('budget'), findsWidgets);
    });

    testWidgets('shows "Ce qui rentre" and "Ce qui sort"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('rentre'), findsWidgets);
      expect(find.textContaining('sort'), findsWidgets);
    });

    testWidgets('shows income items', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('AVS'), findsWidgets);
      expect(find.textContaining('LPP'), findsWidgets);
    });

    testWidgets('shows margin when positive', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // 5234 - 4800 = 434 → "Marge"
      expect(find.textContaining('Marge'), findsWidgets);
      expect(find.textContaining('vert'), findsWidgets);
    });

    testWidgets('shows deficit when negative', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        customIncomes: [const BudgetLineItem(label: 'AVS', amount: 2000)],
        customExpenses: [const BudgetLineItem(label: 'Loyer', amount: 3000)],
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('ficit'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil'), findsWidgets);
    });

    testWidgets('handles empty items', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        customIncomes: const [],
        customExpenses: const [],
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetSandwichChart), findsOneWidget);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
