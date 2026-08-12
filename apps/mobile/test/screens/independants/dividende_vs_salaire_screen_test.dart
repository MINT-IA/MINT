import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/independants/dividende_vs_salaire_screen.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Cluster 12D V2-1 — écran `dividende_vs_salaire` (#37).
///
/// Preuve D10 (lucidité) : l'écran ne rend plus un chiffre nu d'« économie ».
/// Il rend, sous l'ancre `dividende-confidence` :
///   - une bande d'incertitude cantonale (bornes conservatrice/optimiste via
///     `dividendeFourchette`) ;
///   - l'appareil de confiance canonique `MintTrameConfiance` (Phase 8a) dont
///     l'hypothèse NOMME les simplifications du modèle (impôt sur le bénéfice
///     représentatif, part imposable simplifiée, droits AVS/LPP non valorisés).
/// L'ancre `dividende-economie` porte le hero.
///
/// Un renommage/retrait de ces ancres ou de leur wiring casse ce test avant le
/// runtime. L'écran est un simulateur pur (pas de provider) : au défaut
/// (bénéfice 200'000, part 70%, taux 30%), economie > 0 -> le bloc D10 rend.
Finder _byIdentifier(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Widget _host([Locale locale = const Locale('fr')]) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      locale: locale,
      home: const DividendeVsSalaireScreen(),
    );

/// Grande surface : l'écran est un CustomScrollView lazy — les enfants sous la
/// ligne de flottaison (le bloc D10, après hero + 3 sliders) restent offstage,
/// donc NON construits, à la surface test par défaut (800×600). On étend la
/// surface pour tout mettre en page (cf. mémoire RetirementHeroZone overflow).
void _bigSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('rend le hero économie + l\'appareil de confiance D10 au défaut',
      (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    // Entrées animées (MintEntrance) + hero -> laisser converger.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Ancre hero.
    expect(_byIdentifier('dividende-economie'), findsOneWidget);

    // Ancre D10 : appareil de confiance canonique (MTC) + fourchette.
    expect(_byIdentifier('dividende-confidence'), findsOneWidget);
    expect(find.byType(MintTrameConfiance), findsOneWidget);
  });

  testWidgets('le message de confiance nomme les simplifications du modèle',
      (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Le « pourquoi ce chiffre » (D10) est accessible et honnête : l'hypothèse
    // MTC.detail rend le caveat (impôt bénéfice représentatif, part imposable
    // simplifiée, droits AVS/LPP non valorisés). On vérifie l'appareil canonique
    // + une sous-chaîne UNIQUE au caveat (« fiduciaire »).
    expect(find.byType(MintTrameConfiance), findsOneWidget);
    final ctx = tester.element(find.byType(MintTrameConfiance));
    final msg = S.of(ctx)!.dividendeConfidenceMessage;
    expect(msg, contains('fiduciaire'));
    expect(find.textContaining('fiduciaire'), findsOneWidget);
  });

  testWidgets('pas d\'alerte de requalification au défaut (part 70%, salaire '
      '140k >= 60k)', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Défaut : part 70% >= 60% ET salaire 140'000 >= 60'000 -> pas d'alerte.
    expect(_byIdentifier('dividende-economie'), findsOneWidget);
    expect(
      find.textContaining('Risque de requalification'),
      findsNothing,
    );
  });

  testWidgets(
      'légendes du graphe localisées (« Split adapté » accentué) + titres en '
      'casse normale (VOICE_SYSTEM, plus d\'UPPERCASE)', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final ctx = tester.element(find.byType(DividendeVsSalaireScreen));
    final l = S.of(ctx)!;

    // Légende : accent corrigé (audit #1185, « Split adapte » -> « Split adapté »)
    // et strings sorties du code vers l'ARB 6 langues.
    expect(l.dividendeLegendSplitAdapte, 'Split adapté');
    expect(find.text('Split adapté'), findsOneWidget);
    expect(find.text('Split adapte'), findsNothing); // plus de variante ASCII
    expect(find.text(l.dividendeLegendChargeTotale), findsWidgets);
    expect(find.text(l.dividendeLegendPositionActuelle), findsOneWidget);

    // Casse normale : l'UPPERCASE non conforme VOICE_SYSTEM a disparu.
    expect(find.text('CHARGE TOTALE PAR SPLIT'), findsNothing);
    expect(find.text('À RETENIR'), findsNothing);
    expect(find.text(l.dividendeChargeCurveTitle), findsOneWidget);
    expect(find.text(l.dividendeEducationTitle), findsOneWidget);
  });

  // ── FR-residuals PR : extraction i18n de l'en-tête, des lignes de résultat,
  // des cartes édu et des disclaimers (audit #1185 / rapport #1190). ──────────
  testWidgets('en-tête : accent corrigé « le plus adapté » (plus « adapte ») '
      'et sorti vers l\'ARB', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final ctx = tester.element(find.byType(DividendeVsSalaireScreen));
    final l = S.of(ctx)!;

    // Bug accent de l'audit #1185 corrigé dans l'ARB.
    expect(l.dividendeHeaderIntro, contains('le plus adapté'));
    expect(l.dividendeHeaderIntro.contains('adapte.'), isFalse);
    // L'en-tête rendu vient bien de l'ARB.
    expect(find.text(l.dividendeHeaderIntro), findsOneWidget);
  });

  testWidgets('lignes de résultat + cartes édu + disclaimers rendus depuis '
      'l\'ARB (locale fr)', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final ctx = tester.element(find.byType(DividendeVsSalaireScreen));
    final l = S.of(ctx)!;

    // Lignes de résultat (dont les 2 clés orphelines ré-câblées).
    expect(find.text(l.dividendeResultPartDividende), findsOneWidget);
    expect(find.text(l.dividendeVsSalaireChargeSalaire), findsOneWidget);
    expect(find.text(l.dividendeResultChargeTotale), findsOneWidget);
    expect(find.text(l.dividendeVsSalaireCharge100Salaire), findsOneWidget);
    // Cartes éducatives.
    expect(find.text(l.dividendeEduImpotBeneficeTitle), findsOneWidget);
    expect(find.text(l.dividendeEduAvsTitle), findsOneWidget);
    expect(find.text(l.dividendeEduCantonalTitle), findsOneWidget);
    // Disclaimer conformité (scénario pédagogique, pas conseil).
    expect(find.text(l.dividendeComplianceEducatif), findsOneWidget);
    expect(find.text(l.dividendeComplianceSources), findsOneWidget);
  });

  testWidgets('locale en : en-tête ANGLAIS rendu, en-tête FR absent '
      '(vraie localisation, pas chaîne FR en dur)', (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host(const Locale('en')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final ctx = tester.element(find.byType(DividendeVsSalaireScreen));
    final l = S.of(ctx)!;
    expect(l.dividendeHeaderIntro, contains('If you own an SA'));

    expect(find.textContaining('If you own an SA'), findsOneWidget);
    // La chaîne FR en dur (HEAD) ne doit plus s'afficher en locale en.
    expect(find.textContaining('Si tu possèdes'), findsNothing);
    // Carte édu en anglais présente ; le titre FR absent.
    expect(find.text(l.dividendeEduCantonalTitle), findsOneWidget);
    expect(find.text('Pratique cantonale'), findsNothing);
  });
}
