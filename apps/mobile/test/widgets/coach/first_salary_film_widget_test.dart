import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // grossMonthly = 5000
  // avsEmployee = 5000 * 0.053 = 265
  // lppEmployee = 5000 * 0.035 = 175
  // ac = 5000 * 0.011 = 55
  // aanp = 5000 * 0.013 = 65
  // totalDeductions = 560
  // net = 4440 → "4'440"
  // totalEmployerCost ≈ 5000 + 265 + 175 + 30 = 5470+

  Widget buildWidget() => const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSalaryFilmWidget(grossMonthly: 5000),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('salaire'), findsWidgets);
  });

  testWidgets('shows gross monthly in header', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("5'000"), findsWidgets);
  });

  testWidgets('shows act selector tabs', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Brut'), findsWidgets);
    expect(find.textContaining('3a'), findsWidgets);
  });

  testWidgets('shows act 1 net amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    // net = 5000 - 560 = 4440
    expect(find.textContaining("4'440"), findsWidgets);
  });

  testWidgets('shows LAVS reference in act 1', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LAVS'), findsWidgets);
  });

  testWidgets('switches to act 2 on tap', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('Invisible'));
    await tester.pumpAndSettle();
    expect(find.textContaining('invisible'), findsWidgets);
  });

  testWidgets('switches to act 3 and shows 3a projection', (tester) async {
    await tester.pumpWidget(buildWidget());
    // Tab label is exactly '3 · 3a'
    await tester.tap(find.text('3 · 3a'));
    await tester.pumpAndSettle();
    expect(find.textContaining("7'258"), findsWidgets);
  });

  testWidgets('switches to act 5 checklist', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('Action'));
    await tester.pumpAndSettle();
    expect(find.textContaining('checklist'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('film premier salaire', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
