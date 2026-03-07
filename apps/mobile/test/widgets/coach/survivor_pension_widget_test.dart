import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';

void main() {
  // partnerAvsRente=2000, partnerLppMonthly=1000
  // _avsMarried = 2000 * 0.80 = 1600
  // _lppMarried = 1000 * 0.60 = 600
  // _totalMarried = 2200 → "2'200"
  // _totalConcubin = 0
  // _marriageBonus = 2200 → "2'200"

  Widget buildWidget({bool isConcubin = false}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SurvivorPensionWidget(
              partnerAvsRente: 2000,
              partnerLppMonthly: 1000,
              isConcubin: isConcubin,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('survivant'), findsWidgets);
  });

  testWidgets('shows married total', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("2'200"), findsWidgets);
  });

  testWidgets('shows concubin zero amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('0 CHF'), findsWidgets);
  });

  testWidgets('shows marriage bonus chiffre-choc', (tester) async {
    await tester.pumpWidget(buildWidget());
    // _marriageBonus = 2200
    expect(find.textContaining("2'200"), findsWidgets);
  });

  testWidgets('shows LAVS legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LAVS'), findsWidgets);
  });

  testWidgets('shows LPP legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LPP'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('rente survivant', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
