import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/fiscal_superpower_widget.dart';

void main() {
  final superpowers = [
    const FiscalSuperpower(
      label: 'Déduction enfant',
      emoji: '👶',
      annualDeduction: 6700,
      taxSaving: 1675,
      legalRef: 'LIFD art. 213',
    ),
    const FiscalSuperpower(
      label: 'Frais de garde',
      emoji: '🏫',
      annualDeduction: 25500,
      taxSaving: 6375,
      legalRef: 'LIFD art. 212',
      note: 'max CHF 25\'500/an',
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FiscalSuperpowerWidget(
              superpowers: superpowers,
              taxRate: 0.25,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('fiscal'), findsWidgets);
  });

  testWidgets('shows LIFD legal ref', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LIFD'), findsWidgets);
  });

  testWidgets('shows slider for children count', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows total saving callout', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 1 child: 1675+6375 = 8050
    expect(find.textContaining("8'050"), findsWidgets);
  });

  testWidgets('shows superpower items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Déduction enfant'), findsOneWidget);
    expect(find.textContaining('garde'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('fiscal', caseSensitive: false)), findsOneWidget);
  });
}
