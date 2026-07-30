import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';
import 'package:provider/provider.dart';

/// Tier B smoke — lot B1 Famille SEEDÉ : preuve d'ancre de RÉSULTAT chiffré C2.
///
/// Sous le seed `famille_bern` (couple marié BE double-revenu, 1 enfant, LPP
/// certificat — #1135), les gates P2 « dur » qui restaient fermés pour la
/// persona célibataire `julien_swiss` s'ouvrent, et chaque écran famille rend
/// une SORTIE CALCULÉE. Ce test prouve que l'ancre régionale `Semantics(
/// identifier: '<event>-result')` — posée sur le hero chiffré, motif profond,
/// jamais le wrapper racine (leçon ADR AX iOS 26.2) — est PRÉSENTE dans l'arbre
/// de widgets quand le résultat existe. Les flows Maestro
/// `flow_tierb_famille_seeded_<event>.yaml` s'appuient dessus pour le gate C2
/// « non-vide + chiffré ». Un renommage / retrait de l'ancre casse le flow — ce
/// test le rattrape avant. Il double aussi de garde de non-régression du seed :
/// si `famille_bern` cessait d'ouvrir un gate, l'ancre disparaîtrait ici.
///
/// La persona est hydratée par le chemin de production
/// (`CoachProfile.fromWizardAnswers(seed.toWizardAnswers())`), identique à celui
/// que le build sim seedé emprunte via `MINT_E2E_ARCHETYPE=famille_bern`.
class _SeededProvider extends CoachProfileProvider {
  _SeededProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _familleBern() => CoachProfile.fromWizardAnswers(
      CoachProfileSeeds.registry['famille_bern']!.toWizardAnswers(),
    );

Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    );

Future<void> _pump(WidgetTester tester, Widget screen) async {
  // Surface haute : le slot résultat de chaque onglet (lazy) est monté sans
  // scroll (motif des *_gate_test.dart).
  await tester.binding.setSurfaceSize(const Size(1200, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: _SeededProvider(_familleBern()),
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
      'naissance : congé APG chiffré (onglet Congé) → ancre naissance-result',
      (tester) async {
    await _pump(tester, const NaissanceScreen());
    // Diagnostic gate-open : le hero APG keyé rend seul (salaire + rôle F seedés).
    expect(find.byKey(const Key('naissanceCongeHero')), findsOneWidget,
        reason: 'congé APG chiffré seed-alone sous famille_bern (salaire + F)');
    expect(_byIdentifier('naissance-result'), findsOneWidget);
  });

  testWidgets(
      'concubinage : cluster fiscal chiffré (onglet Comparateur) → ancre '
      'concubinage-result', (tester) async {
    await _pump(tester, const ConcubinageScreen());
    // Diagnostic gate-open : la matrice de décision rend seule (revenu1 +
    // revenu2 conjoint + canton BE seedés).
    expect(find.byType(ConcubinageDecisionMatrix), findsOneWidget,
        reason: 'matrice fiscale chiffrée seed-alone sous famille_bern');
    expect(_byIdentifier('concubinage-result'), findsOneWidget);
  });

  testWidgets(
      'mariage : rente de survivant chiffrée (onglet Protection) → ancre '
      'mariage-result', (tester) async {
    await _pump(tester, const MariageScreen());
    await tester.tap(find.text('Protection'));
    await tester.pumpAndSettle();
    // Diagnostic gate-open : le hero survivant keyé rend seul (rente LPP dérivée
    // de l'avoir LPP certificat seedé).
    expect(find.byKey(const Key('mariageSurvivorHero')), findsOneWidget,
        reason: 'rente survivant chiffrée seed-alone sous famille_bern (avoirLpp)');
    expect(_byIdentifier('mariage-result'), findsOneWidget);
  });

  testWidgets(
      'divorce : impact fiscal /an chiffré après le seul tap ex-conjoint → '
      'ancre divorce-result', (tester) async {
    await _pump(tester, const DivorceSimulatorScreen());
    // income1 + canton BE seedés ; income2 (ex-conjoint) = seul tap irréductible
    // (doctrine anti-contamination : le profil ne décrit pas l'ex).
    final fields =
        tester.widgetList<MintAmountField>(find.byType(MintAmountField)).toList();
    // Section Revenus : [0]=conjoint1 (seedé), [1]=conjoint2 (ex, touch-only).
    fields[1].onChanged(60000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Simuler'));
    await tester.pumpAndSettle();
    expect(_byIdentifier('divorce-result'), findsOneWidget);
  });
}
