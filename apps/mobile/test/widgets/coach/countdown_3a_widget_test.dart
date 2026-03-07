import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/countdown_3a_widget.dart';

void main() {
  Widget buildWidget({
    double contributed = 3600,
    int daysRemaining = 87,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Countdown3aWidget(
            annualCeiling: 7258,
            amountContributed: contributed,
            taxSavingsIfFull: 1450,
            daysRemaining: daysRemaining,
            year: 2026,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('rebours 3a'), findsOneWidget);
  });

  testWidgets('shows contributed and remaining amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("3'600"), findsWidgets);
    expect(find.textContaining("3'658"), findsWidgets);
  });

  testWidgets('shows ceiling', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("7'258"), findsWidgets);
  });

  testWidgets('shows urgency label when > 90 days', (tester) async {
    await tester.pumpWidget(buildWidget(daysRemaining: 120));
    expect(find.textContaining('Confortable'), findsOneWidget);
  });

  testWidgets('shows warning label when 30-90 days', (tester) async {
    await tester.pumpWidget(buildWidget(daysRemaining: 60));
    expect(find.textContaining('Bient'), findsOneWidget);
  });

  testWidgets('shows urgent label when <= 30 days', (tester) async {
    await tester.pumpWidget(buildWidget(daysRemaining: 15));
    expect(find.textContaining('Urgent'), findsOneWidget);
  });

  testWidgets('shows tax savings chiffre-choc', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("1'450"), findsWidgets);
  });

  testWidgets('shows congratulation when ceiling full', (tester) async {
    await tester.pumpWidget(buildWidget(contributed: 7258));
    expect(find.textContaining('Bravo'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('rebours 3a')), findsOneWidget);
  });
}
