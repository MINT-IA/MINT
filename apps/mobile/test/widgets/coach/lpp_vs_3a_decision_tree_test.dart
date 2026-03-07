import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/lpp_vs_3a_decision_tree.dart';

void main() {
  final lppOption = const DecisionOption(
    title: 'LPP volontaire',
    emoji: '\ud83c\udfe6',
    subtitle: 'Rente garantie + protection invalidit\u00e9',
    pros: ['Rente garantie', 'Invalidit\u00e9 couverte'],
    cons: ['3a limit\u00e9 \u00e0 7\u2019258', 'Co\u00fbteux seul'],
    annualTaxSavings: 1815,
  );

  final grand3aOption = const DecisionOption(
    title: 'Grand 3a',
    emoji: '\ud83d\udcb0',
    subtitle: 'Plafond 36\u2019288 CHF, flexibilit\u00e9 totale',
    pros: ['Plafond 36\u2019288', 'Flexibilit\u00e9'],
    cons: ['Capital seulement', 'AI seule'],
    annualTaxSavings: 9070,
  );

  Widget buildWidget({double income = 80000}) => MaterialApp(
        home: Scaffold(
          body: LppVs3aDecisionTree(
            expectedIncome: income,
            lppOption: lppOption,
            grand3aOption: grand3aOption,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LPP'), findsWidgets);
    expect(find.textContaining('3a'), findsWidgets);
  });

  testWidgets('shows income in decision node', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("80'000"), findsWidgets);
  });

  testWidgets('shows both options for high income', (tester) async {
    await tester.pumpWidget(buildWidget(income: 80000));
    expect(find.textContaining('LPP volontaire'), findsWidgets);
    expect(find.textContaining('Grand 3a'), findsWidgets);
  });

  testWidgets('shows low-income card for income below threshold', (tester) async {
    await tester.pumpWidget(buildWidget(income: 40000));
    expect(find.textContaining('pilier retraite'), findsOneWidget);
  });

  testWidgets('tapping an option expands it', (tester) async {
    await tester.pumpWidget(buildWidget());
    // .last avoids matching the main title "LPP volontaire ou Grand 3a ?"
    await tester.tap(find.textContaining('LPP volontaire').last);
    await tester.pump();
    expect(find.textContaining('Rente garantie'), findsWidgets);
  });

  testWidgets('tapping expanded option collapses it', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('LPP volontaire').last);
    await tester.pumpAndSettle();
    // 'couverte' is only in pros list, not in subtitle
    expect(find.textContaining('couverte'), findsOneWidget);
    await tester.tap(find.textContaining('LPP volontaire').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('couverte'), findsNothing);
  });

  testWidgets('shows tax savings when expanded', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('Grand 3a').last);
    await tester.pumpAndSettle();
    // Tax savings label visible when expanded
    expect(find.textContaining('conomie fiscale'), findsWidgets);
  });

  testWidgets('shows chiffre-choc panel', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('mauvais choix'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('d.cision LPP')), findsOneWidget);
  });
}
