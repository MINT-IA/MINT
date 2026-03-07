import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/unemployment_counter_widget.dart';

void main() {
  Widget buildWidget({int age = 35, int daysConsumed = 0}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UnemploymentCounterWidget(
              age: age,
              monthlyBenefit: 4200,
              daysConsumed: daysConsumed,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('capital temps'), findsOneWidget);
  });

  testWidgets('shows 260 days for age 35', (tester) async {
    await tester.pumpWidget(buildWidget(age: 35));
    expect(find.textContaining('260'), findsWidgets);
  });

  testWidgets('shows 200 days for age under 25', (tester) async {
    await tester.pumpWidget(buildWidget(age: 22));
    expect(find.textContaining('200'), findsWidgets);
  });

  testWidgets('shows 400 days for age 57', (tester) async {
    await tester.pumpWidget(buildWidget(age: 57));
    expect(find.textContaining('400'), findsWidgets);
  });

  testWidgets('shows days consumed and remaining', (tester) async {
    await tester.pumpWidget(buildWidget(age: 35, daysConsumed: 50));
    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('210'), findsWidgets); // 260-50
  });

  testWidgets('shows age table', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('25'), findsWidgets);
    expect(find.textContaining('55'), findsWidgets);
  });

  testWidgets('shows zero CHF chiffre-choc', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('0 CHF'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('capital temps')), findsOneWidget);
  });
}
