import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/independants/dividende_vs_salaire_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';

/// Cluster 12D V2-1 — écran `dividende_vs_salaire` (#37).
///
/// Preuve D10 (lucidité) : l'écran ne rend plus un chiffre nu d'« économie ».
/// Il rend, sous l'ancre `dividende-confidence` :
///   - une bande d'incertitude (fourchette 50–70% via `dividendeFourchette`) ;
///   - un appareil de confiance (`MintConfidenceNotice`) qui NOMME les
///     exclusions (impôt sur le bénéfice, taux d'imposition partielle indicatif).
/// L'ancre `dividende-economie` porte le hero.
///
/// Un renommage/retrait de ces ancres ou de leur wiring casse ce test avant le
/// runtime. L'écran est un simulateur pur (pas de provider) : au défaut
/// (bénéfice 200'000, part 70%, taux 30%), economie > 0 -> le bloc D10 rend.
Finder _byIdentifier(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Widget _host() => const MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('fr')],
      locale: Locale('fr'),
      home: DividendeVsSalaireScreen(),
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

    // Ancre D10 : appareil de confiance + fourchette.
    expect(_byIdentifier('dividende-confidence'), findsOneWidget);
    expect(find.byType(MintConfidenceNotice), findsOneWidget);
  });

  testWidgets('le message de confiance nomme l\'exclusion de l\'impôt bénéfice',
      (tester) async {
    _bigSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Le « pourquoi ce chiffre » (D10) est accessible et honnête. On compare le
    // GETTER localisé au widget rendu (normalisation-proof : pas de littéral
    // accentué côté test), puis on vérifie sur le getter (sous-chaîne ASCII)
    // qu'il explique la part imposable retenue.
    final ctx = tester.element(find.byType(MintConfidenceNotice));
    final msg = S.of(ctx)!.dividendeConfidenceMessage;
    expect(find.text(msg), findsOneWidget);
    expect(msg, contains('part imposable du dividende'));
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
}
