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
  // annualTaxSingle-annualTaxMarried = 12400-11200 = 1200 → monthlyTaxDelta 100
  // monthlyPension is the REAL service value (income-gap), passed in — the film
  // no longer fabricates childrenCount×1500 + 500.

  Widget buildWidget({
    int children = 1,
    double pension = 1100,
    double lppTransfer = 50000,
    String lppTransferDirection = '1 → 2',
  }) =>
      MaterialApp(
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
              lppTransfer: lppTransfer,
              lppTransferDirection: lppTransferDirection,
              annualTaxMarried: 11200,
              annualTaxSingle: 12400,
              childrenCount: children,
              monthlyPension: pension,
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
    // lppMonthlyLoss = 50000 * 0.068 / 12 ≈ 283 CHF/mois (on the PASSED transfer)
    expect(find.textContaining('283'), findsWidgets);
  });

  testWidgets(
      'LPP transfer is the PASSED service value, never (myLpp+partnerLpp)/2',
      (tester) async {
    // Service transfer 20000, direction "2 → 1" (you RECEIVE). The old widget
    // recompute would have shown 50000 (= (180000+80000)/2 vs 180000) and an
    // "après" of 130000 — both must be absent.
    await tester.pumpWidget(buildWidget(
      lppTransfer: 20000,
      lppTransferDirection: '2 → 1',
    ));
    expect(find.textContaining("20'000"), findsWidgets,
        reason: 'the real service transfer renders');
    expect(find.textContaining("50'000"), findsNothing,
        reason: 'no total-balance recompute');
    // "après" = myLpp + transfer (you receive) = 180000 + 20000 = 200000.
    expect(find.textContaining("200'000"), findsWidgets);
    expect(find.textContaining("130'000"), findsNothing);
    // Direction '2 → 1' = you RECEIVE : la phrase dit « tu reçois », jamais
    // « tu transfères » (vérité métier : ta rente augmente, ne baisse pas).
    expect(find.textContaining('Tu reçois'), findsOneWidget);
    expect(find.textContaining('Tu transfères'), findsNothing);
    expect(find.textContaining('augmente'), findsOneWidget);
  });

  testWidgets('LPP direction 1 → 2 = you PAY : « tu transfères / baisse »',
      (tester) async {
    await tester.pumpWidget(buildWidget(
      lppTransfer: 20000,
      lppTransferDirection: '1 → 2',
    ));
    expect(find.textContaining('Tu transfères'), findsOneWidget);
    expect(find.textContaining('Tu reçois'), findsNothing);
    expect(find.textContaining('baisse'), findsOneWidget);
  });

  testWidgets(
      'acte 3 pension tax note is direction-NEUTRAL (never a false « TES impôts »)',
      (tester) async {
    // The service pension is unsigned (income-gap + children); payer direction
    // is unknown (custody not captured). The note must state the general rule,
    // never claim the user pays/deducts — false when the user is the recipient.
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('TES impôts'), findsNothing,
        reason: 'no false personal payer claim');
    expect(find.textContaining('déductible du revenu de la personne qui la verse'),
        findsOneWidget,
        reason: 'general, always-true tax rule');
  });

  testWidgets(
      'acte 2 tax delta is attributed to the MÉNAGE, never to the user personally',
      (tester) async {
    // annualTaxSingle (12400) = C1 + C2 (both ex-spouses) > annualTaxMarried
    // (11200) → the delta is a household figure. The statement must say « pour le
    // ménage », never « tu perds » (the per-person share depends on each income
    // and is not computed here).
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('pour le ménage'), findsOneWidget);
    expect(find.textContaining('tu perds'), findsNothing);
    expect(find.textContaining('tu gagnes'), findsNothing);
    // Childcare note is CONDITIONAL (custody + real childcare costs unconfirmed),
    // never a « avec la garde … tu peux déduire » that presumes custody.
    expect(find.textContaining('Si tu as la garde'), findsOneWidget);
    expect(find.textContaining('Avec la garde des enfants, tu peux déduire'),
        findsNothing);
  });

  testWidgets('shows acte 2 tax amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("11'200"), findsWidgets);
    expect(find.textContaining("12'400"), findsWidgets);
  });

  testWidgets('acte 3 shows the REAL monthly pension, not a per-child forfait',
      (tester) async {
    await tester.pumpWidget(buildWidget(children: 1, pension: 1100));
    expect(find.textContaining("1'100"), findsWidgets,
        reason: 'the single real service pension is rendered');
    expect(find.textContaining("1'500"), findsNothing,
        reason: 'no fabricated childrenCount × 1500 per-child forfait');
  });

  testWidgets('a fabricated per-child + alimony total is gone', (tester) async {
    // Old code with 3 children → 3×1500 + 500 = 5000 (or 4500 children-only).
    // New code renders ONLY the real pension, whatever the child count.
    await tester.pumpWidget(buildWidget(children: 3, pension: 1100));
    expect(find.textContaining("1'100"), findsWidgets);
    expect(find.textContaining("5'000"), findsNothing);
    expect(find.textContaining("4'500"), findsNothing);
  });

  testWidgets('the « pension indicative CHF 1500/500 » footer text is gone',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('indicative'), findsNothing);
    expect(find.textContaining('1\'500/enfant'), findsNothing);
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
