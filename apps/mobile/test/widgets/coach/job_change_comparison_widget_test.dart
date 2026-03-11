import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/job_change_comparison_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final axes = [
    const JobAxis(
      label: 'Salaire net',
      emoji: '💰',
      currentValue: 4200,
      newValue: 4700,
      unit: 'CHF/mois',
    ),
    const JobAxis(
      label: 'Contribution LPP employeur',
      emoji: '🏦',
      currentValue: 400,
      newValue: 280,
      unit: 'CHF/mois',
    ),
    const JobAxis(
      label: 'Jours de vacances',
      emoji: '🌴',
      currentValue: 25,
      newValue: 20,
      unit: 'jours',
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
            child: JobChangeComparisonWidget(
              currentJobLabel: 'Poste actuel',
              newJobLabel: 'Nouvelle offre',
              axes: axes,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('changement'), findsWidgets);
  });

  testWidgets('shows both job labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Poste actuel'), findsWidgets);
    expect(find.textContaining('Nouvelle offre'), findsWidgets);
  });

  testWidgets('shows axis items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Salaire net'), findsWidgets);
    expect(find.textContaining('LPP'), findsWidgets);
  });

  testWidgets('shows net callout', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Impact réel'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('changement', caseSensitive: false)), findsOneWidget);
  });
}
