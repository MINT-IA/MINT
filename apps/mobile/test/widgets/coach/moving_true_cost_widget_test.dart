import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/moving_true_cost_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final items = [
    const MovingCostItem(
      label: 'Impôts cantonaux',
      emoji: '📊',
      monthlyBefore: 2100,
      monthlyAfter: 1200,
      note: 'Taux effectif 34% → 19%',
    ),
    const MovingCostItem(
      label: 'Loyer',
      emoji: '🏠',
      monthlyBefore: 1800,
      monthlyAfter: 2200,
    ),
    const MovingCostItem(
      label: 'LAMal (primes)',
      emoji: '🏥',
      monthlyBefore: 520,
      monthlyAfter: 420,
    ),
  ];

  Widget buildWidget() => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MovingTrueCostWidget(
              fromCanton: 'Vaud',
              toCanton: 'Zoug',
              items: items,
              movingFees: 4000,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Déménager'), findsWidgets);
  });

  testWidgets('shows canton names', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Vaud'), findsWidgets);
    expect(find.textContaining('Zoug'), findsWidgets);
  });

  testWidgets('shows items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Impôts'), findsWidgets);
    expect(find.textContaining('Loyer'), findsWidgets);
  });

  testWidgets('shows net result', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('net'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('déménagement', caseSensitive: false)), findsOneWidget);
  });
}
