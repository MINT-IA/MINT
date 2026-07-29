import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/divorce_film_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

void main() {
  // myLpp=180000, partnerLpp=80000
  // equalShare = (180000+80000)/2 = 130000
  // transfer = 180000-130000 = 50000 → "50'000"
  // annualTaxSingle-annualTaxMarried = 12400-11200 = 1200 → monthlyTaxDelta 100
  // Acte 3 renders NO maintenance amount at all: the amount of a Swiss
  // maintenance contribution cannot be derived from income + children, so the
  // widget takes no pension param and states the factors instead.

  Widget buildWidget({
    int children = 1,
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

  testWidgets('acte 1 states the rente MECHANISM, never a fabricated CHF/mois',
      (tester) async {
    // Le taux de conversion s'applique au capital À LA RETRAITE, pas au
    // transfert d'aujourd'hui : 50'000 × 6.8 % / 12 ≈ 283 CHF/mois était une
    // fabrication (elle suppose zéro intérêt jusqu'à la retraite et le taux
    // actuel de la caisse). On explique le mécanisme à la place.
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('283'), findsNothing,
        reason: 'no fabricated monthly rente effect');
    expect(find.textContaining('converti en rente'), findsOneWidget,
        reason: 'the mechanism (capital at retirement → rente) is explained');
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
    expect(find.textContaining('rejoint ton avoir'), findsOneWidget,
        reason: 'receiving side states the mechanism, not a CHF/mois');
  });

  testWidgets('LPP direction 1 → 2 = you PAY : « tu transfères / baisse »',
      (tester) async {
    await tester.pumpWidget(buildWidget(
      lppTransfer: 20000,
      lppTransferDirection: '1 → 2',
    ));
    expect(find.textContaining('Tu transfères'), findsOneWidget);
    expect(find.textContaining('Tu reçois'), findsNothing);
    expect(find.textContaining('ne travaillera plus pour toi'), findsOneWidget,
        reason: 'paying side states the mechanism, not a CHF/mois');
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
        reason: 'general tax rule');
    // Exception réelle : pour un enfant MAJEUR la contribution n'est ni
    // déductible ni imposable (LIFD art. 33). L'écran ignore l'âge des
    // enfants → énoncer la règle sans l'exception serait faux pour ces parents.
    expect(find.textContaining('enfant MAJEUR'), findsOneWidget,
        reason: 'the adult-child exception is stated, not generalised away');
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
    expect(find.textContaining('art. 33 al. 3'), findsWidgets);
    expect(find.textContaining('Avec la garde des enfants, tu peux déduire'),
        findsNothing);
    // Frais de garde = LIFD art. 33 al. 3 (pas l'art. 35, qui vise les
    // déductions sociales) + conditions réelles (frais justifiés, âge limite,
    // lien avec l'activité/formation/incapacité).
    expect(find.textContaining('art. 35'), findsNothing,
        reason: 'wrong article would make a parent reason wrongly');
    expect(find.textContaining('sous conditions'), findsWidgets);
  });

  testWidgets('shows acte 2 tax amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("11'200"), findsWidgets);
    expect(find.textContaining("12'400"), findsWidgets);
  });

  testWidgets('acte 2 married/separated cards are NEUTRAL, not green/red steering',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    // LSFin: married-vs-separated is an informative comparison, not a verdict.
    // Coloring married green (success) / separated red (danger) would steer —
    // marriage always "better" — even when separation is cheaper (Heiratsstrafe).
    // Both value texts must be neutral info, never scoreExcellent/scoreCritique.
    final married = tester.widget<Text>(find.text("CHF 11'200/an"));
    final separated = tester.widget<Text>(find.text("CHF 12'400/an"));
    expect(married.style?.color, MintColors.info);
    expect(separated.style?.color, MintColors.info);
    expect(married.style?.color, isNot(MintColors.scoreExcellent));
    expect(separated.style?.color, isNot(MintColors.scoreCritique));
  });

  testWidgets('acte 3 shows NO maintenance amount, only the factors',
      (tester) async {
    await tester.pumpWidget(buildWidget(children: 1));
    // The income-gap service value (1'100) is no longer passed nor rendered.
    expect(find.textContaining("1'100"), findsNothing,
        reason: 'a maintenance amount is not derivable from income + children');
    expect(find.textContaining("1'500"), findsNothing,
        reason: 'nor the older childrenCount × 1500 per-child forfait');
    expect(find.textContaining('Il n\'existe pas de barème'), findsOneWidget,
        reason: 'acte 3 says why, it does not just go silent');
    expect(find.textContaining('revenus disponibles nets'), findsNothing,
        reason: 'the full mechanism lives on the screen card, not the film');
    // The referral names what is genuinely the court's / a specialist's job:
    // fixing the binding amount — never a substitute for the explanation.
    expect(find.textContaining('par le tribunal'), findsOneWidget);
    expect(find.textContaining('chiffre le cas concret'), findsOneWidget);
  });

  testWidgets('no per-child total is rendered whatever the child count',
      (tester) async {
    // Old code with 3 children → 3×1500 + 500 = 5000 (or 4500 children-only);
    // the income-gap rule gave 2'300. None of them may appear.
    await tester.pumpWidget(buildWidget(children: 3));
    expect(find.textContaining("2'300"), findsNothing);
    expect(find.textContaining("5'000"), findsNothing);
    expect(find.textContaining("4'500"), findsNothing);
    expect(find.textContaining('/mois'), findsWidgets,
        reason: 'acte 1 rente + acte 2 tax still carry real monthly figures');
  });

  testWidgets('the « pension indicative CHF 1500/500 » footer text is gone',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('indicative'), findsNothing);
    expect(find.textContaining('1\'500/enfant'), findsNothing);
  });

  testWidgets('acte 1 does NOT present the LPP split as absolute', (tester) async {
    // Le partage par moitié est la règle PAR DÉFAUT : le juge peut s'en écarter
    // et une renonciation reste possible si la prévoyance de chacun reste
    // suffisante (CC art. 124b). Dire « non négociable » / « Point. » ferait
    // raisonner l'utilisateur sur une fatalité qui n'existe pas.
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('non négociable'), findsNothing);
    expect(find.textContaining('coupés en deux. Point'), findsNothing);
    expect(find.textContaining('124b'), findsWidgets,
        reason: 'the possible judicial departure / waiver is stated '
            '(acte 1 message + the sources footer)');
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
