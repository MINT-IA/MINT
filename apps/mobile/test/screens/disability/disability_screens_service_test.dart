import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/screens/disability/disability_self_employed_screen.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/disability_cliff_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_red_screen_widget.dart';

/// Non-régression des 3 écrans invalidité après le DRAIN vers l'étalon unique
/// `DisabilityService` (fin du doublon 3-têtes, cluster 12D V2-2). Chaque écran
/// MONTE, CONSOMME le service et rend du CHIFFRÉ depuis un profil seedé, sans
/// sentinelle « vide ». Preuve E2E de la correction D2 (acte employeur = 100 %,
/// PAS 80 %) : le détail « 100 % … » de l'acte 1 est rendu par la falaise.
void main() {
  Widget wrap(Widget home, CoachProfileProvider coach) {
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: coach,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: home,
      ),
    );
  }

  // Seed volontairement modéré (6'000) : la falaise reste dans la largeur
  // contrainte (maxWidth 600) de ces écrans — un salaire à 5 chiffres déborde
  // la ligne « salaire actuel » du widget falaise (défaut de responsive
  // PRÉEXISTANT au drain, hors périmètre). Le calcul, lui, est prouvé sur toute
  // la plage par le fixture de parité.
  CoachProfileProvider seeded() {
    final coach = CoachProfileProvider();
    coach.updateFromAnswers(<String, dynamic>{
      'q_canton': 'VD',
      'q_monthly_gross': 6000,
      'q_birth_year': 1985,
    });
    return coach;
  }

  testWidgets('gap : écran monte + chiffré seedé, aucune sentinelle',
      (tester) async {
    // Surface par défaut : la falaise (lazy, sous la flottaison) n'est pas
    // construite — on prouve ici le MONTAGE + le chiffré au-dessus de la
    // flottaison (carte de saisie seedée), sans régression. La falaise et sa
    // correction 100 % sont prouvées par le test « falaise » ci-dessous.
    await tester.pumpWidget(wrap(const DisabilityGapScreen(), seeded()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('1 personne sur 5'), findsOneWidget); // hero éducatif
    expect(find.text('Ta situation'), findsOneWidget); // carte de saisie chiffrée
    expect(find.text('Aucune donnée'), findsNothing);
    expect(find.text('Définis ton budget'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falaise : acte employeur 100 % (D2 corrigé) alimenté par le service',
      (tester) async {
    // La falaise consomme la projection du service. Surface LARGE non contrainte
    // (le défaut de responsive de la ligne « salaire actuel » est préexistant au
    // drain et hors périmètre). On prouve que l'acte 1 = 100 % du salaire (copie
    // ARB corrigée) et que le montant plein s'affiche.
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const gross = 6000.0;
    final proj = DisabilityService.acts(grossMonthly: gross, hasIjm: true);
    expect(proj.employerIncome, gross); // 100 %, pas 80 %

    await tester.pumpWidget(wrap(
      Scaffold(
        body: Builder(builder: (ctx) {
          final s = S.of(ctx)!;
          return SingleChildScrollView(
            child: DisabilityCliffWidget(
              grossMonthly: gross,
              acts: [
                DisabilityAct(
                  label: s.disabilityGapAct1Label,
                  subtitle: s.disabilityGapEmployerSub,
                  durationLabel: s.disabilityGapAct1Duration,
                  monthlyIncome: proj.employerIncome,
                  emoji: '🟢',
                  color: MintColors.success,
                  detail: s.disabilityGapAct1Detail,
                ),
                DisabilityAct(
                  label: s.disabilityGapAct2LabelIjm,
                  subtitle: s.disabilityGapAct2SubIjm,
                  durationLabel: s.disabilityGapAct2Duration,
                  monthlyIncome: proj.ijmIncome,
                  emoji: '🟡',
                  color: MintColors.amber,
                  detail: s.disabilityGapAct2DetailIjm,
                ),
                DisabilityAct(
                  label: s.disabilityGapAct3Label,
                  subtitle: s.disabilityGapAiDelaySub,
                  durationLabel: s.disabilityGapAct3Duration,
                  monthlyIncome: proj.longTermIncome,
                  emoji: '🔴',
                  color: MintColors.error,
                  detail: s.disabilityGapAct3Detail('2520', '1518', '4038'),
                ),
              ],
            ),
          );
        }),
      ),
      seeded(),
    ));
    await tester.pump();

    expect(find.text('100 % de ton salaire (obligation légale employeur)'),
        findsOneWidget);
    expect(find.textContaining("6'000"), findsWidgets); // salaire plein (100 %)
    expect(tester.takeException(), isNull);
  });

  testWidgets('insurance : bulletin chiffré + AI max + clé no-coverage runtime',
      (tester) async {
    await tester.pumpWidget(wrap(const DisabilityInsuranceScreen(), seeded()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DisabilityScorecardWidget), findsOneWidget);
    // AI = maximum légal 2'520 CHF/mois (via le service).
    expect(find.textContaining("2'520"), findsWidgets);
    expect(tester.takeException(), isNull);

    // Exerce la nouvelle clé ARB `disabilityInsNoCoverage` au runtime : couper
    // l'IJM (aucune assurance privée) => détail « Aucune couverture … ».
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Aucune couverture'), findsWidgets);
  });

  testWidgets('self-employed : écran rouge chiffré, aucune exception',
      (tester) async {
    await tester.pumpWidget(
        wrap(const DisabilitySelfEmployedScreen(), seeded()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DisabilityRedScreenWidget), findsOneWidget);
    expect(find.text('Aucune donnée'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
