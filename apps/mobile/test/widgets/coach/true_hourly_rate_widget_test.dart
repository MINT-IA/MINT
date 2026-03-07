import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/true_hourly_rate_widget.dart';

void main() {
  final layers = [
    const RateLayer(label: 'Imp\u00f4ts', amount: 25000, emoji: '\ud83c\udfe6'),
    const RateLayer(label: 'Cotisations AVS', amount: 10600, emoji: '\ud83e\uddf1'),
    const RateLayer(label: 'Assurances', amount: 4000, emoji: '\ud83c\udfe5'),
    const RateLayer(label: 'Vacances / maladie', amount: 9940, emoji: '\ud83c\udfd6'),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: TrueHourlyRateWidget(
            desiredNetAnnual: 100000,
            layers: layers,
            requiredRevenue: 149540,
            billableHours: 1600,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('tarif horaire'), findsOneWidget);
  });

  testWidgets('shows hero hourly rate', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 149540 / 1600 = ~93.46 → displayed as "93 CHF/h" (multiple occurrences)
    expect(find.textContaining('93 CHF/h'), findsWidgets);
  });

  testWidgets('shows "minimum" label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('minimum'), findsOneWidget);
  });

  testWidgets('shows desired net label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('souhait'), findsOneWidget);
  });

  testWidgets('shows layer labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Imp'), findsWidgets);
    expect(find.textContaining('AVS'), findsWidgets);
  });

  testWidgets('shows required revenue', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("149'540"), findsWidgets);
  });

  testWidgets('shows billable hours', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('1600'), findsWidgets);
  });

  testWidgets('shows chiffre-choc text', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('appauvris'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('horaire v')), findsOneWidget);
  });
}
