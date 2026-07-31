import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Cluster 12D V2-2 — contrat de non-régression du drain frontalier.
///
///   • D3 : les postes de charges sociales étrangères sont localisés (concept)
///     et non plus affichés en snake_case technique brut (`vieillesse_base`,
///     `krankenversicherung`…).
///   • D10 : le résultat d'impôt à la source (modèle taux moyen simplifié) rend
///     une bande de confiance MintTrameConfiance qui nomme le barème A/B/C et le
///     statut quasi-résident non modélisés.

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
      home: FrontalierScreen(),
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
  testWidgets('D10 — le résultat impôt source (GE) rend une bande de confiance',
      (tester) async {
    await _pump(tester);
    // Tab 1 par défaut (GE, 7000) → résultat non-Tessin → bande MTC rendue.
    expect(find.byType(MintTrameConfiance), findsWidgets);
  });

  testWidgets('D3 — les charges étrangères (France) affichent des libellés localisés',
      (tester) async {
    await _pump(tester);
    final l = S.of(tester.element(find.byType(FrontalierScreen)))!;
    await _goToTab(tester, l.frontalierTabCharges);

    // Les concepts localisés apparaissent…
    expect(find.text(l.frontalierChargeRetraite), findsWidgets);
    expect(find.text(l.frontalierChargeChomage), findsWidgets);
    expect(find.text(l.frontalierChargeCsgCrds), findsWidgets);
    // …et le libellé CH 'LPP (est.)' passe par l'ARB.
    expect(find.text(l.frontalierChargeLppEstimated), findsOneWidget);
    // Plus aucun snake_case technique brut à l'écran.
    expect(find.text('Vieillesse base'), findsNothing);
    expect(find.text('Csg crds'), findsNothing);
  });
}
