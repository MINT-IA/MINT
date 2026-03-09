import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/career_timelapse_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final scenarios = [
    const TimeLapseScenario(startAge: 22, capitalAt65: 680000),
    const TimeLapseScenario(startAge: 25, capitalAt65: 610000),
    const TimeLapseScenario(startAge: 30, capitalAt65: 450000),
    const TimeLapseScenario(startAge: 35, capitalAt65: 310000),
  ];

  Widget buildWidget({int initialAge = 25}) => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: CareerTimeLapseWidget(
            scenarios: scenarios,
            monthly3aContribution: 605,
            initialAge: initialAge,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('commenc'), findsWidgets);
  });

  testWidgets('shows age labels for all scenarios', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('22 ans'), findsOneWidget);
    expect(find.textContaining('35 ans'), findsOneWidget);
  });

  testWidgets('shows compact capital amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('680k'), findsOneWidget);
    expect(find.textContaining('310k'), findsOneWidget);
  });

  testWidgets('renders slider', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows chiffre-choc when age is not minimum', (tester) async {
    await tester.pumpWidget(buildWidget(initialAge: 30));
    await tester.pump();
    expect(find.textContaining('attente'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('returns SizedBox for empty scenarios', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: CareerTimeLapseWidget(scenarios: const [], monthly3aContribution: 605),
      ),
    ));
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Time-lapse')), findsOneWidget);
  });
}
