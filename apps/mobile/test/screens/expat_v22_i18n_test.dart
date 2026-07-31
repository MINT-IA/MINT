import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/widgets/coach/expat_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_rights_loss_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Cluster 12D V2-2 — contrat de non-régression du drain expat (écran #1).
///
/// Deux vérités séparées (0-trust) :
///   • D3/D6 : le bloc Tab 2 (échéances + droits perdus) ne porte plus de FR
///     codé en dur — il consomme les clés `l.expat*`. On l'assert au NIVEAU du
///     widget de données (ExpatCountdownWidget/ExpatRightsLossWidget), jamais
///     sur un `find.text` accentué (normalisation Unicode fragile).
///   • D2 : le pourcentage de réduction AVS n'est plus un littéral nu (~2.3 % /
///     −23 %) — il est DÉRIVÉ de `ExpatService.reductionPerMissingYear`
///     (registre `avs.full_contribution_years`). Le test relie la valeur rendue
///     à la source : changer la durée de cotisation change les deux ensemble.
///   • D10 : la lacune AVS (Tab 3) rend une bande de confiance MintTrameConfiance.

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: ExpatScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Tab 2 échéances + droits sont localisés (aucun FR codé en dur)',
      (tester) async {
    await _pump(tester);
    final l = S.of(tester.element(find.byType(ExpatScreen)))!;
    await _goToTab(tester, l.expatTabDeparture);

    final countdown =
        tester.widget<ExpatCountdownWidget>(find.byType(ExpatCountdownWidget));
    expect(countdown.deadlines, hasLength(3));
    expect(countdown.deadlines[0].label, l.expatDeadline3aLabel);
    expect(countdown.deadlines[0].action, l.expatDeadline3aAction);
    expect(countdown.deadlines[0].consequence, l.expatDeadline3aConsequence);
    expect(countdown.deadlines[1].label, l.expatDeadlineLppLabel);
    expect(countdown.deadlines[2].label, l.expatDeadlineAvsLabel);

    final rights =
        tester.widget<ExpatRightsLossWidget>(find.byType(ExpatRightsLossWidget));
    expect(rights.destination, l.expatDestinationAbroad);
    expect(rights.rights[0].label, l.expatRightAvsLabel);
    expect(rights.rights[0].before, l.expatRightAvsBefore);
    expect(rights.rights[1].label, l.expatRightLppLabel);
    expect(rights.rights[3].label, l.expatRightLamalLabel);
    // Le libellé LAMal « after » portait un lint-ignore no_hardcoded_fr : il
    // passe désormais par l'ARB.
    expect(rights.rights[3].after, l.expatRightLamalAfter);
  });

  testWidgets('D2 — la réduction AVS Tab 2 est dérivée du registre, pas un nombre nu',
      (tester) async {
    await _pump(tester);
    final l = S.of(tester.element(find.byType(ExpatScreen)))!;
    await _goToTab(tester, l.expatTabDeparture);

    final rights =
        tester.widget<ExpatRightsLossWidget>(find.byType(ExpatRightsLossWidget));
    final perYear =
        (ExpatService.reductionPerMissingYear * 100).toStringAsFixed(1);
    final tenYear =
        (ExpatService.reductionPerMissingYear * 10 * 100).toStringAsFixed(0);

    // La valeur rendue == la chaîne paramétrée construite sur les % DÉRIVÉS.
    // Un retour au littéral nu casserait cette égalité.
    expect(rights.rights[0].impact, l.expatRightAvsImpact(perYear, tenYear));
    // Sanity : le registre par défaut (44 ans) donne bien ~2.3 % / 23 %.
    expect(perYear, '2.3');
    expect(tenYear, '23');
  });

  testWidgets('D10 — la lacune AVS (Tab 3) rend une bande MintTrameConfiance',
      (tester) async {
    await _pump(tester);
    final l = S.of(tester.element(find.byType(ExpatScreen)))!;
    await _goToTab(tester, l.expatTabAvs);

    // Gate dur : sans faits confirmés, aucun résultat → aucune bande.
    expect(find.byType(MintTrameConfiance), findsNothing);

    // Confirme les deux faits que la lacune consomme (années CH + étranger).
    final pickers = tester.widgetList<MintPickerTile>(
        find.byWidgetPredicate((w) => w is MintPickerTile && w.maxValue == 44));
    expect(pickers.length, greaterThanOrEqualTo(2));
    pickers.elementAt(0).onChanged(30); // yearsInCh
    await tester.pump(const Duration(milliseconds: 400));
    pickers.elementAt(1).onChanged(5); // yearsAbroad
    await tester.pump(const Duration(milliseconds: 400));

    // Résultat déverrouillé → la bande de confiance est rendue.
    expect(find.byType(MintTrameConfiance), findsWidgets);
  });
}
