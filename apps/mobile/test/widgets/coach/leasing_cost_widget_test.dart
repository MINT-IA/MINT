import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/leasing_cost_widget.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LeasingCostWidget(
              vehiclePrice: 40000,
              monthlyLeasing: 600,
              leasingDurationMonths: 48,
              annualReturnRate: 0.05,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('leasing'), findsWidgets);
  });

  testWidgets('shows vehicle price', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("40'000"), findsWidgets);
  });

  testWidgets('shows leasing total', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 600 × 48 = 28800
    expect(find.textContaining("28'800"), findsWidgets);
  });

  testWidgets('shows monthly slider', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows opportunity cost section', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("opportunité"), findsWidgets);
  });

  testWidgets('shows CO legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('CO'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('leasing', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
