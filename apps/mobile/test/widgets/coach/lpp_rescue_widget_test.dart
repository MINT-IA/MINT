import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/lpp_rescue_widget.dart';

void main() {
  final options = [
    const LppTransferOption(
      label: 'Nouveau employeur',
      emoji: '🏢',
      description: 'Transfert direct au LPP du nouvel employeur.',
      fiveYearGain: 0,
    ),
    const LppTransferOption(
      label: 'Libre passage (recommandé)',
      emoji: '🏦',
      description: '2 comptes pour optimiser la fiscalité au retrait.',
      fiveYearGain: 9000,
      recommended: true,
      legalRef: 'LFLP art. 3-4',
    ),
    const LppTransferOption(
      label: 'Institution supplétive',
      emoji: '⚠️',
      description: 'Taux technique bas, frais élevés.',
      fiveYearGain: -9000,
    ),
  ];

  Widget buildWidget({int daysElapsed = 5}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LppRescueWidget(
              lppBalance: 185000,
              options: options,
              daysElapsed: daysElapsed,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('sauvetage'), findsOneWidget);
  });

  testWidgets('shows days remaining', (tester) async {
    await tester.pumpWidget(buildWidget(daysElapsed: 5));
    expect(find.textContaining('25 jours'), findsOneWidget);
  });

  testWidgets('shows LPP balance', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("185'000"), findsWidgets);
  });

  testWidgets('shows recommended badge', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Recommandé'), findsOneWidget);
  });

  testWidgets('shows all 3 options', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Option 1'), findsOneWidget);
    expect(find.textContaining('Option 2'), findsOneWidget);
    expect(find.textContaining('Option 3'), findsOneWidget);
  });

  testWidgets('shows chiffre-choc about institution supplétive', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('supplétive'), findsWidgets);
  });

  testWidgets('shows disclaimer with sfbvg', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('sfbvg'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('sauvetage LPP', caseSensitive: false)), findsOneWidget);
  });
}
