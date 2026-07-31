import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/deces_proche_screen.dart';
import 'package:mint_mobile/screens/demenagement_cantonal_screen.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:provider/provider.dart';

/// Tier B smoke — lot B4 Décès / Santé / Mobilité : preuve d'ancres régionales
/// C1 / C2 / C4.
///
/// Chaque écran life-event de ce lot porte des ancres `Semantics(identifier:
/// '<event>-…')` — motif PROFOND, JAMAIS le wrapper racine (leçon ADR AX iOS
/// 26.2) :
///   - `<event>-anchor`  posée sur le TITRE de l'AppBar (gate C1 « atteignable ») ;
///   - `<event>-back`     posée sur le bouton retour safePop (gate C4 « pas de
///                        cul-de-sac ») ;
///   - `<event>-result`   posée sur le rendu CHIFFRÉ, présente au repos
///                        (invalidité — falaise calculée seed-alone) ou après
///                        avoir renseigné les faits touch-only (décès —
///                        avoirs du défunt ; déménagement — destination +
///                        situation), JAMAIS sur une carte-gate vide.
///
/// Ce test prouve la PRÉSENCE des ancres dans l'arbre de widgets — INDÉPENDAMMENT
/// de l'effondrement AX runtime iOS 26.2 (invalidite = CustomScrollView +
/// SliverAppBar + wrapper racine = motif firstJob → C1/C5 rouges au runtime,
/// dette AX SÉPARÉE consignée Journey OS). Un renommage / retrait d'ancre casse
/// le flow Maestro `flow_tierb_b4_<event>.yaml` — ce test le rattrape avant.
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
/// de POLICE DE TEST (glyphes du font de test plus larges que le rendu réel).
/// Agit À LA SOURCE, exception PAR exception : seule « A RenderFlex overflowed »
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
    'disability_gap_screen (/invalidite) porte les ancres C1 + C4 + C2 '
    '(la falaise chiffrée au repos depuis le profil seedé, aucun gate)',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const DisabilityGapScreen());
      expect(_byIdentifier('disability-anchor'), findsOneWidget);
      expect(_byIdentifier('disability-back'), findsOneWidget);
      // C2 chiffré : la falaise (acte employeur / IJM / AI+LPP) est calculée au
      // repos depuis le salaire seedé (julien_swiss 9500/mois) — aucun gate.
      // (Runtime iOS 26.2 : l'arbre AX s'effondre → inatteignable au flow ;
      // ici la présence structurelle est prouvée. Dette AX séparée.)
      expect(_byIdentifier('disability-result'), findsOneWidget);
    },
  );

  testWidgets(
    'deces_proche_screen (/life-event/deces-proche) porte les ancres C1 + C4, '
    'et C2 après avoir renseigné les avoirs du défunt (touch-only)',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const DecesProcheScreen());
      expect(_byIdentifier('deces-anchor'), findsOneWidget);
      expect(_byIdentifier('deces-back'), findsOneWidget);
      // Au repos, aucun résultat : les avoirs LPP/3a du défunt sont TOUCH-ONLY
      // (aucune provenance profil — ce sont les avoirs du DÉFUNT), donc la carte
      // bénéficiaires est gatée. L'ancre est absente (gate, pas fabrication).
      expect(_byIdentifier('deces-result'), findsNothing);
      // C2 chiffré : renseigner les deux avoirs (touch) ouvre la carte
      // bénéficiaires (CHF LPP + CHF 3a du défunt).
      tester
          .widget<MintPremiumSlider>(find.byKey(const Key('deces_lpp_field')))
          .onChanged(300000);
      await tester.pump();
      tester
          .widget<MintPremiumSlider>(find.byKey(const Key('deces_3a_field')))
          .onChanged(60000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_byIdentifier('deces-result'), findsOneWidget);
    },
  );

  testWidgets(
    'demenagement_cantonal_screen (/life-event/demenagement-cantonal) porte les '
    'ancres C1 + C4, et C2 après situation + canton d\'arrivée (touch)',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, const DemenagementCantonalScreen());
      expect(_byIdentifier('demenagement-anchor'), findsOneWidget);
      expect(_byIdentifier('demenagement-back'), findsOneWidget);
      // Au repos : revenu + canton de départ sont amorcés (julien_swiss fournit
      // 'salary' + 'canton'), mais la situation familiale (pas de clé
      // 'civilStatus' pour julien_swiss) ET le canton d'arrivée (touch-only)
      // manquent → gate incomplet → l'ancre résultat est absente.
      expect(_byIdentifier('demenagement-result'), findsNothing);
      // C2 chiffré : confirmer la situation familiale + choisir la destination
      // complète le gate → le héros delta fiscal se calcule.
      tester
          .widget<SegmentedButton<String>>(
              find.byKey(const Key('demenagement_situation')))
          .onSelectionChanged!({'marie'});
      await tester.pump();
      tester
          .widget<DropdownButton<String>>(
              find.byKey(const Key('demenagement_canton_arrivee')))
          .onChanged!('GE');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_byIdentifier('demenagement-result'), findsOneWidget);
    },
  );
}
