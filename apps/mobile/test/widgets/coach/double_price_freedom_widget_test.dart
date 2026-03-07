import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/double_price_freedom_widget.dart';

void main() {
  final charges = [
    const ChargeLine(
      label: 'AVS / AI / APG',
      employeeAmount: 5300,
      selfEmployedAmount: 10600,
      note: 'Double pour ind\u00e9p.',
    ),
    const ChargeLine(
      label: 'LPP (part employeur)',
      employeeAmount: 4000,
      selfEmployedAmount: 0,
    ),
    const ChargeLine(
      label: 'IJM',
      employeeAmount: 0,
      selfEmployedAmount: 2400,
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: DoublePriceFreedomWidget(
            grossIncome: 100000,
            charges: charges,
            totalEmployee: 12300,
            totalSelfEmployed: 23400,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('double prix'), findsOneWidget);
  });

  testWidgets('shows income label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("100'000"), findsWidgets);
  });

  testWidgets('shows column headers', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Salari'), findsWidgets);
    expect(find.textContaining('p.'), findsWidgets);
  });

  testWidgets('shows charge line labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('AVS'), findsWidgets);
    expect(find.textContaining('LPP'), findsWidgets);
    expect(find.textContaining('IJM'), findsOneWidget);
  });

  testWidgets('shows total row', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('TOTAL'), findsOneWidget);
  });

  testWidgets('shows total amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("12'300"), findsOneWidget);
    expect(find.textContaining("23'400"), findsOneWidget);
  });

  testWidgets('shows chiffre-choc with multiplier', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('1.9'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('double prix')), findsOneWidget);
  });
}
