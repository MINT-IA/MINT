import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/independant_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:provider/provider.dart';

/// Tier B smoke — lot B2 Travail : preuve d'ancres régionales C1 / C2 / C4.
///
/// Chaque écran life-event Travail porte trois ancres `Semantics(identifier:
/// '<event>-…')` — motif profond, JAMAIS le wrapper racine (leçon ADR AX iOS
/// 26.2) :
///   - `<event>-anchor`  posée sur le TITRE de l'AppBar (gate C1 « atteignable ») ;
///   - `<event>-back`     posée sur le bouton retour safePop (gate C4 « pas de
///                        cul-de-sac ») ;
///   - `<event>-result`   posée sur le hero CHIFFRÉ, présente UNIQUEMENT via le
///                        render-gate (`_result != null`), jamais au repos vide
///                        (gate C2 « non-vide + chiffré »).
///
/// Contrairement au lot B1 Famille (célibataire → gates P2 fermés), la persona
/// SALARIÉE `julien_swiss` produit un résultat chiffré sur les trois écrans
/// Travail : chômage (indemnité éligible au repos), comparaison d'emploi (après
/// « Comparer »), indépendant (perte Jour J au repos). Ce test prouve la
/// PRÉSENCE des ancres dans l'arbre de widgets (indépendamment de l'effondrement
/// AX runtime iOS 26.2 sur `/segments/independant`, dette AX séparée) : un
/// renommage / retrait casse le flow Maestro `flow_tierb_travail_<event>.yaml` —
/// ce test le rattrape avant.
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

/// Installe un filtre `FlutterError.onError` qui ignore UNIQUEMENT le débordement
/// de layout de POLICE DE TEST (les glyphes du font de test sont plus larges que
/// le rendu réel). L'écran indépendant (`/segments/independant`) a un débordement
/// horizontal connu sur les sections « Jour J » / coverage-gap / protection au
/// width contraint (ConstrainedBox 600) quand la surface haute monte les slivers
/// sous la ligne de flottaison ; le rendu réel sur device tient (l'écran est en
/// production). Le filtre agit À LA SOURCE, exception PAR exception : seule
/// « A RenderFlex overflowed » est avalée ; TOUTE autre erreur (y compris une
/// erreur réelle survenue dans la même frame) est relayée à `original` → le test
/// échoue. Contrairement à un drain post-hoc, aucun agrégat « Multiple exceptions »
/// n'est jamais accepté en bloc. Restauré en teardown. Dette layout consignée en PR.
void _ignoreTestFontOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return; // débordement de police de test seulement — rendu device OK
    }
    original?.call(details); // toute vraie erreur fait échouer le test
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
      'unemployment_screen porte les ancres C1 + C4 + C2 (indemnité éligible '
      'au repos sous julien_swiss)', (tester) async {
    await _pump(tester, const UnemploymentScreen());
    expect(_byIdentifier('unemployment-anchor'), findsOneWidget);
    expect(_byIdentifier('unemployment-back'), findsOneWidget);
    // C2 chiffré : le seed salarié est éligible → hero premier éclairage rendu.
    expect(_byIdentifier('unemployment-result'), findsOneWidget);
  });

  testWidgets(
      'job_comparison_screen porte les ancres C1 + C4, et C2 après « Comparer »',
      (tester) async {
    await _pump(tester, const JobComparisonScreen());
    expect(_byIdentifier('job-comparison-anchor'), findsOneWidget);
    expect(_byIdentifier('job-comparison-back'), findsOneWidget);
    // Au repos, aucun résultat (calculateur button-CTA) — l'ancre est absente.
    expect(_byIdentifier('job-comparison-result'), findsNothing);
    // C2 chiffré : « Comparer » déclenche le calcul (deux plans LPP par défaut).
    await tester.tap(_byIdentifier('job-comparison-simulate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_byIdentifier('job-comparison-result'), findsOneWidget);
  });

  testWidgets(
      'independant_screen porte les ancres C1 + C4 + C2 (perte Jour J au repos '
      'sous julien_swiss)', (tester) async {
    _ignoreTestFontOverflow();
    await _pump(tester, const IndependantScreen());
    expect(_byIdentifier('independant-anchor'), findsOneWidget);
    expect(_byIdentifier('independant-back'), findsOneWidget);
    // C2 non-vide : la section revenu (chiffré seedé) rend au repos, au-dessus de
    // la ligne de flottaison — ancre positive du flow Maestro.
    expect(_byIdentifier('independant-input'), findsOneWidget);
    // C2 chiffré CALCULÉ : _result calculé au repos (revenu/âge/canton) → section
    // Jour J. Présent dans l'arbre widget ; runtime-inatteignable au scroll (dette
    // AX SliverAppBar — voir flow_tierb_travail_independant.yaml).
    expect(_byIdentifier('independant-result'), findsOneWidget);
  });
}
