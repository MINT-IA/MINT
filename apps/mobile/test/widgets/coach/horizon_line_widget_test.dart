import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/horizon_line_widget.dart';

void main() {
  Widget buildWidget({int daysConsumed = 0}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HorizonLineWidget(
              monthlyBenefit: 5833,
              totalDays: 260,
              daysConsumed: daysConsumed,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('horizon'), findsWidgets);
  });

  testWidgets('shows monthly benefit', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("5'833"), findsWidgets);
  });

  testWidgets('shows 0 CHF label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('0 CHF'), findsWidgets);
  });

  testWidgets('shows days remaining when not 0', (tester) async {
    await tester.pumpWidget(buildWidget(daysConsumed: 100));
    expect(find.textContaining('160'), findsWidgets); // 260-100
  });

  testWidgets('shows after-line section', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('sociale'), findsOneWidget);
  });

  testWidgets('shows chiffre-choc', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('instantané'), findsOneWidget);
  });

  testWidgets('shows safe zone label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Zone'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('horizon')), findsOneWidget);
  });
}
