import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/debt_survival_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // totalDebt=25000, monthlyMargin=150, daysSinceLastLate=7, monthlyIncome=4500
  // debtRatio = 25000 / (4500*12) = 25000/54000 ≈ 46% > 30% → ACTIVÉ

  Widget buildWidget({double margin = 150, int lateDays = 7}) => MaterialApp(
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
            child: DebtSurvivalWidget(
              totalDebt: 25000,
              monthlyMargin: margin,
              daysSinceLastLate: lateDays,
              monthlyIncome: 4500,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('survie'), findsWidgets);
  });

  testWidgets('shows ACTIVÉ when ratio critical', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('ACTIVÉ'), findsWidgets);
  });

  testWidgets('shows total debt KPI', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("25'000"), findsWidgets);
  });

  testWidgets('shows monthly margin KPI', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('150'), findsWidgets);
  });

  testWidgets('shows days since late KPI', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('7'), findsWidgets);
  });

  testWidgets('shows 3 action cards', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('loisirs'), findsWidgets);
    expect(find.textContaining('3a'), findsWidgets);
    expect(find.textContaining('Dettes Conseils'), findsWidgets);
  });

  testWidgets('shows helpline number', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('0800 40 40 40'), findsWidgets);
  });

  testWidgets('shows LP legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LP'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('mode survie dette', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
