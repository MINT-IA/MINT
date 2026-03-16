import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/sale_surprises_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // salePrice=800000, purchasePrice=600000, eplWithdrawn=50000, holdingYears=12
  // _capitalGain = 200000
  // _gainTaxRate = 0.18 (10 <= 12 < 15)
  // _gainTax = 36000 → "36'000"
  // salePrice shown: "800'000"

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
            child: SaleSurprisesWidget(
              salePrice: 800000,
              purchasePrice: 600000,
              eplWithdrawn: 50000,
              holdingYears: 12,
              canton: 'Vaud',
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('surprises'), findsWidgets);
  });

  testWidgets('shows sale price', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("800'000"), findsWidgets);
  });

  testWidgets('shows gain tax act', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Acte 1'), findsWidgets);
    expect(find.textContaining("36'000"), findsWidgets);
  });

  testWidgets('shows EPL reimbursement act', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Acte 2'), findsWidgets);
    expect(find.textContaining("50'000"), findsWidgets);
  });

  testWidgets('shows remploi act', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Acte 3'), findsWidgets);
  });

  testWidgets('shows net cascade row', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Net réel'), findsWidgets);
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
      find.bySemanticsLabel(RegExp('surprises vente', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
