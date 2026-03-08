import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/progressive_dashboard_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final metrics = [
    const DashboardMetric(
      label: 'Score de confiance',
      emoji: '📊',
      value: '62',
      unit: '%',
      minLevel: 1,
      color: Color(0xFF4CAF50),
    ),
    const DashboardMetric(
      label: 'Gap mensuel',
      emoji: '📉',
      value: '-450',
      unit: 'CHF',
      minLevel: 2,
      color: Color(0xFFFF5722),
      note: 'Entre projection et objectif',
    ),
    const DashboardMetric(
      label: 'Monte Carlo 90%',
      emoji: '🎲',
      value: '88',
      unit: '%',
      minLevel: 3,
      color: Color(0xFF2196F3),
    ),
  ];

  Widget buildWidget({int confidence = 62}) => MaterialApp(
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
            child: ProgressiveDashboardWidget(
              confidenceScore: confidence,
              metrics: metrics,
              heroMonthlyRente: 3200,
              nextActionLabel: 'Compléter ton profil LPP',
              nextActionDetail: 'Ajoute ton certificat LPP pour affiner la projection.',
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('tableau de bord'), findsWidgets);
  });

  testWidgets('shows confidence score', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('62%'), findsWidgets);
  });

  testWidgets('shows hero monthly rente', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("3'200"), findsWidgets);
  });

  testWidgets('auto-selects Intermédiaire at 62% confidence', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Intermédiaire'), findsWidgets);
  });

  testWidgets('shows level 1 and level 2 metrics at intermediate level', (tester) async {
    await tester.pumpWidget(buildWidget());
    // Level 1 metric (minLevel=1) should be visible
    expect(find.textContaining('Score de confiance'), findsWidgets);
    // Level 2 metric (minLevel=2) should also be visible at level 2
    expect(find.textContaining('Gap mensuel'), findsWidgets);
  });

  testWidgets('hides level 3 metrics at intermediate level', (tester) async {
    await tester.pumpWidget(buildWidget());
    // Monte Carlo is minLevel=3, should not show at level 2
    expect(find.textContaining('Monte Carlo'), findsNothing);
  });

  testWidgets('shows level 3 metric when Expert selected', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('Expert'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Monte Carlo'), findsWidgets);
  });

  testWidgets('shows next action', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LPP'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('dashboard progressif', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
