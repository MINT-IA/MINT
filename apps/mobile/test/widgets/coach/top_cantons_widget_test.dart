import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/top_cantons_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final rankings = [
    const CantonRanking(
      rank: 1,
      canton: 'Zoug',
      shortCode: 'ZG',
      annualTaxSaving: 12800,
      monthlyLamal: 380,
      monthlyRent: 2200,
      highlight: 'Fiscalité la plus favorable de Suisse',
    ),
    const CantonRanking(
      rank: 2,
      canton: 'Schwyz',
      shortCode: 'SZ',
      annualTaxSaving: 9600,
      monthlyLamal: 340,
      monthlyRent: 1900,
    ),
    const CantonRanking(
      rank: 3,
      canton: 'Nidwald',
      shortCode: 'NW',
      annualTaxSaving: 7400,
      monthlyLamal: 350,
      monthlyRent: 1700,
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
            child: TopCantonWidget(
              currentCanton: 'Vaud',
              rankings: rankings,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Cantons à simuler'), findsOneWidget);
  });

  testWidgets('shows top canton', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Zoug'), findsWidgets);
  });

  testWidgets('shows estimated difference amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Écart fiscal estimé'), findsOneWidget);
    expect(find.textContaining('Écart estimé'), findsWidgets);
    expect(find.textContaining("12'800"), findsWidgets);
  });

  testWidgets('shows ranking numbers', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('shows children toggle', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Comparaison indicative de cantons pour déménagement',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not promise fiscal savings', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Ton top'), findsNothing);
    expect(find.textContaining('Ton n°1'), findsNothing);
    expect(find.textContaining('meilleur'), findsNothing);
    expect(find.textContaining('Tu économises'), findsNothing);
    expect(find.textContaining('économies fiscales'), findsNothing);
    expect(find.textContaining('moins cher'), findsNothing);
  });
}
