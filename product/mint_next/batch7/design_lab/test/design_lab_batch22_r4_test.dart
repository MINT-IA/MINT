// Batch22 R4 (FERMETURE DE LA BOUCLE — scenarios_versement + fact_etat_civil)
// expected-RED contract for the hidden design lab.
//
// HONEST expected-RED — the INTEGRATION-JOURNEY contract, one notch beyond R3.
// R3 is DONE and wired: the shared 3a entry path now routes fact_lieu ->
// fact_revenu -> eclairage_impot_3a (the attested batch21 GREEN boundary — it
// works, and this test drives it). R4 closes the loop with two nodes that the
// journey does NOT yet reach:
//   * scenarios_versement — reached by eclairage.continue, which today is a
//     kept boundary (action:eclairage.continue exists but NEVER routes in R3);
//   * fact_etat_civil — reached by a FUTURE refine affordance on the eclairage
//     situation row (display-only in R3, no refine action exists yet).
// Each obligation walks the already-green path to the delivered eclairage
// boundary, then asserts the R4 surface the journey does not yet reach, failing
// on its named reach assertion with a clean [R4_XX] TestFailure — never a
// route/late-init/range harness error, and never by mutating R1/R2/R3.
//
// COMPILES PRE-RUNTIME: only string ValueKeys and MintNextDesignLabApp — no R4
// Dart symbol (no batch22Harness, no scenarios/etat_civil widget import). The R4
// SCREENS land first (mint-mobile runtime), attested in the interim by the
// runtime dev tests named in registry.deferred_integration.interim_evidence
// (dev_scenarios_versement_r4_test.dart, dev_fact_etat_civil_r4_test.dart,
// reached via MintNextDesignLabApp.batch22Harness). This linear contract flips
// GREEN at the INTEGRATION BATCH — the declared next governance unit after the
// runtime lands — which wires eclairage.continue -> scenarios_versement and the
// eclairage situation row -> fact_etat_civil (refresh next_action / fact_household),
// keeps situation display-only until the married recompute exists, and re-gates
// the siblings. NOT at the screen-flip. Two positive controls pass: R4_01 (the
// wired arc reaches the delivered eclairage boundary and the R4 nodes are not yet
// there — holds in RED and after integration) and R4_16 (the registry keeps R4
// after R3 / before runtime_global).
// Expected machine summary: 2 passed, 14 failed, 0 load/harness errors.
//
// regle13 lesson (a) simulated-green smoke: this file mutates NO process-global
// state (no debugPrint reassignment, no un-restored overrides); the only
// addTearDown calls restore the test view.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

const _entryActions = <String>[
  'action:today_3a_intent.start',
  'action:orientation.continue',
  'action:fact_tax_year.confirm_current_year',
  'action:fact_tax_year.continue',
  'action:fact_lpp_affiliation.choose_yes',
];

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = _key(key);
  expect(finder, findsOneWidget, reason: 'precondition: $key must exist');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _editableUnder(Finder control) =>
    find.descendant(of: control, matching: find.byType(EditableText));

// Drive the attested GREEN arc all the way to the delivered eclairage_impot_3a
// payoff (batch21 R3 integration: fact_lieu.continue -> fact_revenu ->
// fact_revenu.continue -> eclairage). This boundary WORKS at this commit; the R4
// nodes open AFTER it.
Future<void> _reachEclairage(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp(locale: locale, currentYear: 2026, textScaler: textScaler),
  );
  for (final action in _entryActions) {
    await _tapVisible(tester, action);
  }
  await _tapVisible(tester, 'action:fact_contribution.choose_no');
  expect(
    _key('node:fact_lieu'),
    findsOneWidget,
    reason: 'precondition: the attested R2 fact_lieu boundary must be reachable',
  );
  await tester.enterText(_editableUnder(_key('field:fact_lieu.search')), 'Bern');
  await tester.pump();
  await _tapVisible(tester, 'choice:fact_lieu.351');
  await _tapVisible(tester, 'action:fact_lieu.continue');
  expect(
    _key('node:fact_revenu'),
    findsOneWidget,
    reason: 'precondition: the delivered R3 fact_revenu node must be reachable',
  );
  await _tapVisible(tester, 'choice:fact_revenu.b70_100');
  await _tapVisible(tester, 'action:fact_revenu.continue');
  expect(
    _key('node:eclairage_impot_3a'),
    findsOneWidget,
    reason: 'precondition: the delivered R3 eclairage payoff boundary must be reachable',
  );
}

// From the delivered eclairage boundary, tap the kept continue affordance and
// expect the R4 fermeture node. In RED eclairage.continue never routes (batch21
// kept boundary), so this fails with [R4_XX]; in green it lands on
// scenarios_versement.
Future<void> _reachScenarios(WidgetTester tester, {required String sentinel}) async {
  await _reachEclairage(tester);
  await _tapVisible(tester, 'action:eclairage.continue');
  expect(
    _key('node:scenarios_versement'),
    findsOneWidget,
    reason:
        '$sentinel scenarios_versement is unreachable: eclairage.continue does not '
        'yet route to the fermeture-de-boucle node (the R4 runtime is unimplemented '
        'and the wiring is the declared integration batch)',
  );
}

// From the delivered eclairage boundary, use the FUTURE situation-row refine
// affordance and expect the civil-status node. In RED the situation row is
// display-only (no refine action exists), so this fails with [R4_XX]; in green
// the refine action routes to fact_etat_civil.
Future<void> _reachEtatCivil(WidgetTester tester, {required String sentinel}) async {
  await _reachEclairage(tester);
  final refine = _key('action:eclairage.refine_situation');
  expect(
    refine,
    findsOneWidget,
    reason:
        '$sentinel fact_etat_civil is unreachable: the eclairage situation row is '
        'not yet a refine affordance routing to the civil-status node (display-only '
        'in R3; the upgrade is the declared integration batch)',
  );
  await tester.ensureVisible(refine);
  await tester.tap(refine);
  await tester.pumpAndSettle();
  expect(
    _key('node:fact_etat_civil'),
    findsOneWidget,
    reason: '$sentinel the civil-status collection node is absent (R4 runtime unimplemented)',
  );
}

void main() {
  // Positive control #1 — the wired arc reaches the delivered eclairage boundary
  // and neither R4 node is present there yet. Holds in RED and in a future GREEN
  // (before continue/refine, the R4 nodes are not on the eclairage screen). PASSES.
  testWidgets(
    'R4_01 the wired arc reaches the delivered eclairage boundary before the R4 fermeture runtime',
    (tester) async {
      await _reachEclairage(tester);
      expect(_key('node:eclairage_impot_3a'), findsOneWidget);
      expect(_key('node:scenarios_versement'), findsNothing);
      expect(_key('node:fact_etat_civil'), findsNothing);
    },
  );

  // --- R4a scenarios_versement (reached by eclairage.continue) ---

  testWidgets(
    'R4_02 scenarios_versement nominal shows the choose line at least two scenario effect ranges and never a single bare number',
    (tester) async {
      await _reachScenarios(tester, sentinel: '[R4_02]');
      expect(_key('text:scenarios.choose_line'), findsOneWidget);
      expect(_key('amount:scenarios.effect'), findsAtLeastNWidgets(2));
      expect(_key('amount:scenarios.single'), findsNothing);
    },
  );

  testWidgets(
    'R4_03 scenarios_versement arrival focuses the choose line heading not a scenario amount and carries the meaning without a body',
    (tester) async {
      await _reachScenarios(tester, sentinel: '[R4_03]');
      expect(_key('text:scenarios.choose_line'), findsOneWidget);
      expect(_key('text:scenarios.body'), findsNothing);
      expect(_key('action:scenarios.continue'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_04 scenarios_versement states the locked liquidity cost and the chef lieu commune caveat and the estimate not advice disclaimer',
    (tester) async {
      await _reachScenarios(tester, sentinel: '[R4_04]');
      expect(_key('text:scenarios.liquidity'), findsOneWidget);
      expect(_key('text:scenarios.commune_caveat'), findsOneWidget);
      expect(_key('text:scenarios.disclaimer'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_05 a scenario is a named announced region whose amount and effect are spoken as one utterance',
    (tester) async {
      await _reachScenarios(tester, sentinel: '[R4_05]');
      expect(_key('region:scenarios.scenario'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'R4_06 the plafond glossary sheet opens focus trapped and restores to the anchor',
    (tester) async {
      await _reachScenarios(tester, sentinel: '[R4_06]');
      await _tapVisible(tester, 'action:scenarios.open_plafond_glossary');
      expect(_key('sheet:scenarios.gloss.plafond'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_07 the own amount control is an optional named button pulled by value with no preselected amount',
    (tester) async {
      await _reachScenarios(tester, sentinel: '[R4_07]');
      expect(_key('action:scenarios.own_amount'), findsOneWidget);
      expect(_key('status:scenarios.own_amount_preselected'), findsNothing);
    },
  );

  testWidgets(
    'R4_08 compact 320x700 text scale two shows the choose line at least one scenario the liquidity note and the disclaimer without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _reachScenarios(tester, sentinel: '[R4_08]');
      expect(_key('text:scenarios.choose_line'), findsOneWidget);
      expect(_key('amount:scenarios.effect'), findsAtLeastNWidgets(1));
      expect(_key('text:scenarios.liquidity'), findsOneWidget);
      expect(_key('text:scenarios.disclaimer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // --- R4b fact_etat_civil (reached by the future eclairage situation refine) ---

  testWidgets(
    'R4_09 fact_etat_civil shows three civil status cards none preselected and no wheel or keyboard',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_09]');
      for (final s in ['celibataire', 'marie_pacse', 'concubinage']) {
        expect(_key('choice:etat_civil.$s'), findsOneWidget);
      }
      expect(_key('status:etat_civil.selection_none'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(_key('wheel:etat_civil'), findsNothing);
    },
  );

  testWidgets(
    'R4_10 fact_etat_civil arrival focuses the question and the 31 december determining hint without a body sentence',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_10]');
      expect(_key('text:etat_civil.question'), findsOneWidget);
      expect(_key('text:etat_civil.determining_hint'), findsOneWidget);
      expect(_key('text:etat_civil.body'), findsNothing);
    },
  );

  testWidgets(
    'R4_11 selecting the concubinage card announces the selection summary and marks it',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_11]');
      await _tapVisible(tester, 'choice:etat_civil.concubinage');
      expect(_key('status:etat_civil.selection'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_12 the splitting glossary sheet opens focus trapped and restored',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_12]');
      await _tapVisible(tester, 'action:etat_civil.open_splitting_glossary');
      expect(_key('sheet:etat_civil.gloss.splitting'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_13 the concubinage glossary states separate taxation never the married splitting',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_13]');
      await _tapVisible(tester, 'action:etat_civil.open_concubinage_glossary');
      expect(_key('sheet:etat_civil.gloss.concubinage'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_14 fact_etat_civil error no selection is announced and continue never routes in r4',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_14]');
      await _tapVisible(tester, 'action:etat_civil.continue');
      expect(_key('status:etat_civil.error_no_selection'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_15 compact 320x700 text scale two shows the question the three status cards and continue without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _reachEtatCivil(tester, sentinel: '[R4_15]');
      expect(_key('text:etat_civil.question'), findsOneWidget);
      for (final s in ['celibataire', 'marie_pacse', 'concubinage']) {
        expect(_key('choice:etat_civil.$s'), findsOneWidget);
      }
      expect(_key('action:etat_civil.continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Positive control #2 — the registry keeps R4 after R3 and before runtime_global
  // and forbids runtime/product claims. Reads the sealed registry; holds in RED and
  // GREEN. PASSES.
  testWidgets(
    'R4_16 registry keeps R4 after R3 before runtime_global and excludes later evidence',
    (tester) async {
      final registry =
          File('../../batch22/runtime-gates.yaml').readAsStringSync();
      expect(registry.contains('batch: 22'), isTrue);
      expect(registry.contains('R4:'), isTrue);
      expect(registry.contains('expected_red'), isTrue);
      expect(registry.contains('runtime_implemented'), isTrue);
      expect(registry.contains('runtime_global'), isTrue);
    },
  );
}
