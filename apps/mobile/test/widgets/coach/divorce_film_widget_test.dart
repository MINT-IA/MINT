import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/divorce_film_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // myLpp=180000, partnerLpp=80000
  // equalShare = (180000+80000)/2 = 130000
  // transfer = 180000-130000 = 50000 → "50'000"
  // lppMonthlyLoss = 50000 * 0.068 / 12 = 283.33 → "283"
  // annualTaxSingle-annualTaxMarried = 12400-11200 = 1200
  // monthlyTaxDelta = 100 → "100"
  // childPension = 1*1500 → "1'500"
  // alimony = 500, total = 2000 → "2'000"

  Widget buildWidget({int children = 1, bool alimony = true}) => MaterialApp(
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
            child: DivorceFilmWidget(
              myLpp: 180000,
              partnerLpp: 80000,
              annualTaxMarried: 11200,
              annualTaxSingle: 12400,
              childrenCount: children,
              hasAlimony: alimony,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('divorce'), findsWidgets);
  });

  testWidgets('shows acte 1 LPP split transfer amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    // transfer = 50000 → "50'000"
    expect(find.textContaining("50'000"), findsWidgets);
  });

  testWidgets('shows acte 1 LPP rente loss', (tester) async {
    await tester.pumpWidget(buildWidget());
    // lppMonthlyLoss ≈ 283 CHF/mois
    expect(find.textContaining('283'), findsWidgets);
  });

  testWidgets('shows acte 2 tax amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("11'200"), findsWidgets);
    expect(find.textContaining("12'400"), findsWidgets);
  });

  testWidgets('shows acte 3 with children pension', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("1'500"), findsWidgets);
  });

  testWidgets('shows total monthly pension', (tester) async {
    await tester.pumpWidget(buildWidget());
    // total = 1500 + 500 = 2000 → "2'000"
    expect(find.textContaining("2'000"), findsWidgets);
  });

  testWidgets('shows CC legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('CC'), findsWidgets);
  });

  testWidgets('shows LIFD legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LIFD'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('film du divorce', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
