import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/disability_cliff_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final acts = [
    const DisabilityAct(
      label: 'Le filet',
      subtitle: 'Ton employeur paie 80%',
      durationLabel: 'Jours 1–30',
      monthlyIncome: 6667,
      emoji: '🛡️',
      color: Colors.green,
    ),
    const DisabilityAct(
      label: 'L\'attente',
      subtitle: 'L\'AI évalue ton cas',
      durationLabel: 'Mois 2–24',
      monthlyIncome: 4200,
      emoji: '⏳',
      color: Colors.orange,
      detail: 'Délai moyen : 14 mois',
    ),
    const DisabilityAct(
      label: 'Le plateau',
      subtitle: 'Après décision AI',
      durationLabel: 'Long terme',
      monthlyIncome: 4320,
      emoji: '📊',
      color: Colors.red,
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
            child: DisabilityCliffWidget(
              grossMonthly: 8333,
              acts: acts,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('travailler'), findsOneWidget);
  });

  testWidgets('shows current income', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("8'333"), findsWidgets);
  });

  testWidgets('shows all 3 acts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('ACTE 1'), findsOneWidget);
    expect(find.textContaining('ACTE 2'), findsOneWidget);
    expect(find.textContaining('ACTE 3'), findsOneWidget);
  });

  testWidgets('shows act incomes', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("6'667"), findsOneWidget);
    expect(find.textContaining("4'200"), findsOneWidget);
  });

  testWidgets('shows chiffre-choc', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Chiffre-choc'), findsOneWidget);
  });

  testWidgets('shows loss in monthly income', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 8333 - 4320 = 4013
    expect(find.textContaining("4'013"), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Falaise')), findsOneWidget);
  });
}
