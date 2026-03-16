import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/rent_vs_buy_scoreboard_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // propertyPrice=800000, equity=160000 (20%), monthlyRent=2500, mortgageMonthly=3200
  // years=20, appreciationRate=0.02, investmentReturnRate=0.04
  //
  // Buyer:
  //   propertyValue = 800000 * 1.02^20 ≈ 1'188'756
  //   initialMortgage = 640000, annualAmort = 8000, amortized = 160000
  //   remaining = 480000
  //   buyerPatrimony ≈ 1'188'756 - 480000 ≈ 708'756
  //
  // Renter:
  //   equityFV = 160000 * 1.04^20 ≈ 350'418
  //   monthlySavings = 3200 - 2500 = 700
  //   r = 0.04/12, n = 240
  //   savingsFV ≈ 700 * ((1.003333)^240 - 1) / 0.003333 ≈ 257'936
  //   renterPatrimony ≈ 608'354
  //
  // Buyer wins (708'756 > 608'354)

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
            child: RentVsBuyScoreboardWidget(
              propertyPrice: 800000,
              equity: 160000,
              monthlyRent: 2500,
              mortgageMonthly: 3200,
              years: 20,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Match'), findsWidgets);
  });

  testWidgets('shows monthly mortgage payment', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("3'200"), findsWidgets);
  });

  testWidgets('shows PROPRIÉTAIRE score card', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('PROPRIÉTAIRE'), findsWidgets);
  });

  testWidgets('shows LOCATAIRE score card', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LOCATAIRE'), findsWidgets);
  });

  testWidgets('shows winner badge', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('GAGNANT'), findsWidgets);
  });

  testWidgets('shows break-even row', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Break-even'), findsWidgets);
  });

  testWidgets('shows monthly costs section', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Coûts mensuels'), findsWidgets);
    expect(find.textContaining("3'200"), findsWidgets);
    expect(find.textContaining("2'500"), findsWidgets);
  });

  testWidgets('shows key insight question', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('vraie question'), findsWidgets);
  });

  testWidgets('shows FINMA reference in disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('FINMA'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(
          RegExp('bilan de match louer acheter', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
