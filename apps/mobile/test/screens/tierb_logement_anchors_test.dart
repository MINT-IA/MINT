import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:mint_mobile/screens/housing_sale_screen.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:provider/provider.dart';

/// Tier B smoke — lot B3 Logement & Patrimoine : preuve d'ancres régionales
/// C1 / C2 / C4.
///
/// Chaque écran life-event Patrimoine porte des ancres `Semantics(identifier:
/// '<event>-…')` — motif profond, JAMAIS le wrapper racine (leçon ADR AX iOS
/// 26.2) :
///   - `<event>-anchor`  posée sur le TITRE de l'AppBar (gate C1 « atteignable ») ;
///   - `<event>-back`     posée sur le bouton retour safePop (gate C4 « pas de
///                        cul-de-sac ») ;
///   - `<event>-result`   posée sur le rendu CHIFFRÉ, présente au repos (hypotheque
///                        / succession, calcul non-gaté) ou après le bouton CTA
///                        (housing-sale / donation), jamais sur une carte-gate vide.
///
/// Ce test prouve la PRÉSENCE des ancres dans l'arbre de widgets (indépendamment
/// de l'effondrement AX runtime iOS 26.2 sur les écrans à SliverAppBar — dette AX
/// séparée) : un renommage / retrait casse le flow Maestro
/// `flow_tierb_logement_<event>.yaml` — ce test le rattrape avant.
///
/// La persona est hydratée par le chemin de production
/// (`CoachProfile.fromWizardAnswers(seed.toWizardAnswers())`), identique à celui
/// que le build sim seedé emprunte via `MINT_E2E_ARCHETYPE=julien_swiss`.
class _SeededProvider extends CoachProfileProvider {
  _SeededProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
  @override
  bool get hasProfile => _injected != null;
}

CoachProfile _julienSwiss() => CoachProfile.fromWizardAnswers(
  CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers(),
);

Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == identifier,
);

/// Filtre `FlutterError.onError` qui ignore UNIQUEMENT le débordement de layout
/// de POLICE DE TEST (les glyphes du font de test sont plus larges que le rendu
/// réel). Les écrans Patrimoine (lignes de résultat label ⇄ montant serrées)
/// débordent horizontalement au width contraint quand une surface haute monte
/// tout l'arbre ; le rendu réel device tient (écrans en production). Le filtre
/// agit À LA SOURCE, exception PAR exception : seule « A RenderFlex overflowed »
/// est avalée ; TOUTE autre erreur est relayée à `original` → le test échoue.
void _ignoreTestFontOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return; // débordement de police de test seulement — rendu device OK
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  // Surface haute : le hero résultat (sous la ligne de flottaison) est monté
  // sans scroll (motif des *_anchors_test.dart existants).
  await tester.binding.setSurfaceSize(const Size(1200, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: _SeededProvider(_julienSwiss()),
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets(
    'affordability_screen (/hypotheque) porte les ancres C1 + C4 + C2 '
    '(capacité calculée au repos, aucun gate)',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const AffordabilityScreen());
      expect(_byIdentifier('hypotheque-anchor'), findsOneWidget);
      expect(_byIdentifier('hypotheque-back'), findsOneWidget);
      // C2 chiffré : le hero capacité (prix max OU manque de fonds propres) est
      // calculé au repos depuis le profil seedé — présent sans interaction.
      expect(_byIdentifier('hypotheque-result'), findsOneWidget);
    },
  );

  testWidgets(
    'succession_patrimoine_screen (/succession) porte les ancres C1 + C4 + C2 '
    '(patrimoine chiffré au repos, écran éducatif)',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const SuccessionPatrimoineScreen());
      expect(_byIdentifier('succession-anchor'), findsOneWidget);
      expect(_byIdentifier('succession-back'), findsOneWidget);
      // C2 chiffré : le widget « testament invisible » rend « Patrimoine :
      // CHF 500'000 » + répartition légale au repos (aucun gate).
      expect(_byIdentifier('succession-result'), findsOneWidget);
    },
  );

  testWidgets(
    'housing_sale_screen (/life-event/housing-sale) porte les ancres C1 + C4, '
    'et C2 après « Calculer »',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const HousingSaleScreen());
      expect(_byIdentifier('housing-sale-anchor'), findsOneWidget);
      expect(_byIdentifier('housing-sale-back'), findsOneWidget);
      // Au repos, aucun résultat (calculateur button-CTA) — l'ancre est absente.
      expect(_byIdentifier('housing-sale-result'), findsNothing);
      // C2 chiffré : « Calculer » déclenche le calcul (plus-value chiffrée).
      await tester.tap(_byIdentifier('housing-sale-simulate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_byIdentifier('housing-sale-result'), findsOneWidget);
    },
  );

  testWidgets(
    'donation_screen (/life-event/donation) porte les ancres C1 + C4, et C2 '
    'après « Calculer » (gate fiscal ouvert seed-alone via le canton du profil)',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const DonationScreen());
      expect(_byIdentifier('donation-anchor'), findsOneWidget);
      expect(_byIdentifier('donation-back'), findsOneWidget);
      // Au repos, aucun résultat (aucun calcul lancé) — l'ancre est absente.
      expect(_byIdentifier('donation-result'), findsNothing);
      // C2 chiffré : le gate fiscal (canton) s'ouvre seed-alone (julien_swiss
      // fournit q_canton → userProvidedFields['canton']). Le bouton calcule le
      // verdict fiscal + montant CHF (la réserve / quotité restent gatées sur
      // nbEnfants+régime, faits sans provenance profil — dette documentée).
      await tester.tap(_byIdentifier('donation-simulate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_byIdentifier('donation-result'), findsOneWidget);
    },
  );
}
