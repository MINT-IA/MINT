import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:provider/provider.dart';

/// Tier B smoke — lots B5 (crise & international) + retraite : preuve d'ancres
/// régionales C1 / C2 / C4 pour les 3 écrans-événements seedés (un build = un
/// seed) :
///   - `/debt/ratio`     (debtCrisis)  — seed `julien_swiss`.
///   - `/expatriation`   (countryMove) — seed `frontalier_geneve` (cross_border).
///   - `/retraite`       (retirement)  — seed `retraite_lausanne` (retraité 68).
///
/// Chaque écran porte des ancres `Semantics(identifier: '<event>-…')` — motif
/// profond, JAMAIS le wrapper racine (leçon ADR AX iOS 26.2) :
///   - `<event>-anchor`  posée sur le TITRE de l'AppBar (gate C1 « atteignable ») ;
///   - `<event>-back`     posée sur le bouton retour safePop (gate C4 « pas de
///                        cul-de-sac ») ;
///   - `<event>-result`   posée sur le rendu CHIFFRÉ, jamais sur une carte-gate
///                        vide.
///
/// Ce test prouve la PRÉSENCE des ancres dans l'arbre de widgets (indépendamment
/// de l'effondrement AX runtime iOS 26.2 sur les écrans à SliverAppBar — dette AX
/// séparée) : un renommage / retrait casse le flow Maestro
/// `flow_tierb_{debt_ratio,expat,retraite}.yaml` — ce test le rattrape avant.
///
/// Les personas sont hydratées par le chemin de PRODUCTION
/// (`CoachProfileProvider.updateFromAnswers(seed.toWizardAnswers())`), identique à
/// celui que le build sim seedé emprunte via `MINT_E2E_ARCHETYPE=<seedKey>`.
///
/// RETRAITE — contrat C2 CORRECT : l'ancre `retraite-result` est posée sur la
/// rente LPP (avoir 2e pilier × taux de conversion ≈ 1'800/mois), un chiffre
/// JUSTE. Elle n'est VOLONTAIREMENT PAS posée sur la ligne AVS : la ventilation
/// AVS de la projection est recalculée depuis un salaire nul (≈ 0), défaut moteur
/// connu et documenté (seed #1138) — hors périmètre de ce lot smoke.

/// Filtre `FlutterError.onError` qui ignore UNIQUEMENT le débordement de layout
/// (RenderFlex) : les rangées label ⇄ montant (jauge dette, hero retraite à Row
/// de largeur fixe) débordent au width de test quand une surface haute monte tout
/// l'arbre ; le rendu réel device tient. Le filtre agit exception PAR exception :
/// seule « A RenderFlex overflowed » est avalée ; TOUTE autre erreur est relayée
/// à `original` → le test échoue (motif Codex B2, jamais de drain agrégé).
void _ignoreTestFontOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

CoachProfileProvider _seeded(String seedKey) => CoachProfileProvider()
  ..updateFromAnswers(CoachProfileSeeds.registry[seedKey]!.toWizardAnswers());

Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    );

Widget _harness(CoachProfileProvider coach, Widget screen) => MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ],
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
    );

Future<void> _pump(WidgetTester tester, CoachProfileProvider coach,
    Widget screen) async {
  // Surface haute : le hero résultat (sous la ligne de flottaison) est monté
  // sans scroll (motif des *_anchors_test.dart existants).
  await tester.binding.setSurfaceSize(const Size(1200, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_harness(coach, screen));
  // postFrameCallback (hydratation debt) + MintEntrance (200-400 ms) + count-up.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = call.arguments is Map ? call.arguments['key'] as String? : null;
      switch (call.method) {
        case 'write':
          final value = call.arguments['value'] as String?;
          if (key != null && value != null) secureStorage[key] = value;
          return null;
        case 'read':
          return key == null ? null : secureStorage[key];
        case 'delete':
          if (key != null) secureStorage.remove(key);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets(
    'debt_ratio_screen (/debt/ratio) porte les ancres C1 + C4 + C2 '
    '(ratio d\'endettement calculé au repos, aucun gate) — seed julien_swiss',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(tester, _seeded('julien_swiss'), const DebtRatioScreen());
      expect(_byIdentifier('debt-ratio-anchor'), findsOneWidget);
      expect(_byIdentifier('debt-ratio-back'), findsOneWidget);
      // C2 chiffré : la jauge rend TOUJOURS le ratio (dettes / revenus × 100)
      // depuis le profil seedé — présente au repos, aucun gate.
      expect(_byIdentifier('debt-ratio-result'), findsOneWidget);
    },
  );

  testWidgets(
    'expat_screen (/expatriation) porte les ancres C1 + C4 + C2 '
    '(classement cantonal chiffré SEED-ALONE) — seed julien_swiss',
    (tester) async {
      _ignoreTestFontOverflow();
      // Repointé sur julien_swiss (swissNative, calibré) : la persona
      // frontalier_geneve (cross_border) est HARD-GATÉE vers /waitlist par la
      // cohorte produit (route_metadata.dart:143) et n'atteint jamais
      // /expatriation — découverte produit consignée, la seed frontalier reste
      // pour les tests backend. julien_swiss fournit salary + canton (VD).
      await _pump(tester, _seeded('julien_swiss'), const ExpatScreen());
      expect(_byIdentifier('expat-anchor'), findsOneWidget);
      expect(_byIdentifier('expat-back'), findsOneWidget);
      // C2 chiffré : `_topCantonsGate` s'ouvre seed-alone (revenu `salary` +
      // canton VD dans userProvidedFields) → le classement (économie d'impôt
      // annuelle CHF) rend au repos sur l'onglet Forfait, jamais la carte-gate.
      expect(_byIdentifier('expat-result'), findsOneWidget);
    },
  );

  testWidgets(
    'retirement_dashboard_screen (/retraite) porte les ancres C1 + C4 + C2 '
    '(rente LPP correcte, PAS la ventilation AVS) — seed retraite_lausanne',
    (tester) async {
      _ignoreTestFontOverflow();
      await _pump(
          tester, _seeded('retraite_lausanne'), const RetirementDashboardScreen());
      expect(_byIdentifier('retraite-anchor'), findsOneWidget);
      expect(_byIdentifier('retraite-back'), findsOneWidget);
      // C2 chiffré CORRECT : ancre sur la rente LPP (≈ 1'800/mois, dérivée de
      // l'avoir seedé × taux de conversion). PAS la ligne AVS (recalculée depuis
      // salaire nul ≈ 0 — défaut moteur documenté #1138).
      expect(_byIdentifier('retraite-result'), findsOneWidget);
    },
  );
}
