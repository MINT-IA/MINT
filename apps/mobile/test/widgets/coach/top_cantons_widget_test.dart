import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/top_cantons_widget.dart';

void main() {
  final rankings = [
    const CantonRanking(
      rank: 1,
      canton: 'Zoug',
      shortCode: 'ZG',
      annualTaxSaving: 12800,
      monthlyLamal: 380,
      monthlyRent: 2200,
      highlight: 'Fiscalité la plus favorable de Suisse',
    ),
    const CantonRanking(
      rank: 2,
      canton: 'Schwyz',
      shortCode: 'SZ',
      annualTaxSaving: 9600,
      monthlyLamal: 340,
      monthlyRent: 1900,
    ),
    const CantonRanking(
      rank: 3,
      canton: 'Nidwald',
      shortCode: 'NW',
      annualTaxSaving: 7400,
      monthlyLamal: 350,
      monthlyRent: 1700,
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TopCantonWidget(
              currentCanton: 'Vaud',
              rankings: rankings,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('cantons'), findsWidgets);
  });

  testWidgets('shows top canton', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Zoug'), findsWidgets);
  });

  testWidgets('shows savings amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("12'800"), findsWidgets);
  });

  testWidgets('shows ranking numbers', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('shows children toggle', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('cantons', caseSensitive: false)), findsOneWidget);
  });
}
