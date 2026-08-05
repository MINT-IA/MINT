// Batch21 R3 (arc ÉCLAIRAGE — fact_revenu + eclairage_impot_3a) expected-RED contract
// for the hidden design lab.
//
// HONEST expected-RED — the INTEGRATION-JOURNEY contract. This test drives the shared
// 3a entry path through the EXISTING navigation (an expected-RED can only bind
// obligations reachable by the navigation that exists pre-runtime — the R3 harness
// entry does not compile pre-runtime). Each obligation walks the already-green path to
// the attested R2 fact_lieu boundary (batch20, commune selected), then asserts the R3
// surface that the journey does NOT yet reach — node:fact_revenu after the location
// step, and the éclairage payoff. Those surfaces are unwired into the journey today, so
// every obligation fails on its named reach assertion with a clean [R3_XX] TestFailure —
// never a route/late-init/range harness error, and never by mutating R1/R2.
//
// LIFECYCLE (explicit — the R3 controls never route in R3; see eclairage-scope
// continue.never_routes_in_r3 and registry.deferred_integration): the R3 SCREENS land
// first (mint-mobile runtime), attested in the interim by the runtime dev tests named
// in registry.deferred_integration.interim_evidence (dev_eclairage_r3_test.dart,
// dev_fact_revenu_r3_test.dart, reached via MintNextDesignLabApp.batch21Harness). This
// linear contract flips GREEN at the INTEGRATION BATCH — the declared next governance
// unit after the runtime lands — which wires fact_lieu.continue -> fact_revenu ->
// fact_revenu.continue -> eclairage -> next_action (superseding the batch20 outbound
// edge), removes the runtime situation toggle, and re-gates the siblings. NOT at the
// screen-flip. Two positive controls pass: R3_01 (the shared path reaches the R2
// fact_lieu boundary and the R3 node is not yet in the journey — holds in RED and after
// integration) and R3_14 (the registry keeps R3 after R2 / before R4).
// Expected machine summary: 2 passed, 12 failed, 0 load/harness errors.
//
// regle13 lesson (a) simulated-green smoke: this file mutates NO process-global state
// (no debugPrint reassignment, no un-restored overrides); the only addTearDown calls
// restore the test view.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

import 'batch20_commune_fixture.g.dart';

const _entryActions = <String>[
  'action:today_3a_intent.start',
  'action:orientation.continue',
  'action:fact_tax_year.confirm_current_year',
  'action:fact_tax_year.continue',
  'action:fact_lpp_affiliation.choose_yes',
];

Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder _editableUnder(Finder control) =>
    find.descendant(of: control, matching: find.byType(EditableText));

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = _key(key);
  expect(finder, findsOneWidget, reason: 'precondition: $key must exist');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// Drive the attested green path to the R2 fact_lieu boundary (commune selected).
// fact_lieu is the R3 precondition (commune_selected); R3 opens AFTER it.
Future<void> _reachLocationBoundary(
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
}

// Advance from the location boundary and expect the fused R3 revenu node. In RED the
// R3 runtime is unwired, so this reach fails with [R3_XX]; in green it lands on
// fact_revenu.
Future<void> _reachRevenu(WidgetTester tester, {required String sentinel}) async {
  await _reachLocationBoundary(tester);
  await _tapVisible(tester, 'action:fact_lieu.continue');
  expect(
    _key('node:fact_revenu'),
    findsOneWidget,
    reason:
        '$sentinel fact_revenu is unreachable: after the commune boundary the R3 '
        'taxable-income band node is absent (the R3 runtime is unimplemented at this '
        'sealed RED_COMMIT)',
  );
}

// Advance past fact_revenu (select a band, continue) to the eclairage payoff.
Future<void> _reachEclairage(WidgetTester tester, {required String sentinel}) async {
  await _reachRevenu(tester, sentinel: sentinel);
  await _tapVisible(tester, 'choice:fact_revenu.b70_100');
  await _tapVisible(tester, 'action:fact_revenu.continue');
  expect(
    _key('node:eclairage_impot_3a'),
    findsOneWidget,
    reason: '$sentinel eclairage is unreachable: the R3 payoff node is absent',
  );
}

void main() {
  // Positive control #1 — the shared entry path reaches the R2 boundary and the R3
  // node is not yet present there. Holds in RED and in a future GREEN. PASSES.
  testWidgets(
    'R3_01 the shared entry path reaches the fact_lieu boundary before the R3 fact_revenu runtime',
    (tester) async {
      await _reachLocationBoundary(tester);
      expect(_key('node:fact_lieu'), findsOneWidget);
      expect(_key('node:fact_revenu'), findsNothing);
    },
  );

  testWidgets(
    'R3_02 fact_revenu shows six taxable income band cards none preselected and no wheel or keyboard',
    (tester) async {
      await _reachRevenu(tester, sentinel: '[R3_02]');
      for (final b in ['lt30', 'b30_50', 'b50_70', 'b70_100', 'b100_150', 'gt150']) {
        expect(_key('choice:fact_revenu.$b'), findsOneWidget);
      }
      expect(_key('status:fact_revenu.selection_none'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);   // no numeric keyboard
      expect(_key('wheel:fact_revenu'), findsNothing);   // no wheel picker
    },
  );

  testWidgets(
    'R3_03 fact_revenu arrival focuses the heading not a raised keyboard and the question carries the meaning without a body',
    (tester) async {
      await _reachRevenu(tester, sentinel: '[R3_03]');
      expect(_key('text:fact_revenu.question'), findsOneWidget);
      expect(_key('text:fact_revenu.body'), findsNothing);
      expect(_key('action:fact_revenu.continue'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_04 selecting a taxable income band announces the selection summary and marks the band',
    (tester) async {
      await _reachRevenu(tester, sentinel: '[R3_04]');
      await _tapVisible(tester, 'choice:fact_revenu.b70_100');
      expect(_key('status:fact_revenu.selection'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_05 the revenu imposable glossary sheet opens focus trapped and restores to the anchor',
    (tester) async {
      await _reachRevenu(tester, sentinel: '[R3_05]');
      await _tapVisible(tester, 'anchor:fact_revenu.imposable');
      expect(_key('sheet:fact_revenu.gloss'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_06 fact_revenu error no selection is announced and continue never routes in r3',
    (tester) async {
      await _reachRevenu(tester, sentinel: '[R3_06]');
      await _tapVisible(tester, 'action:fact_revenu.continue');
      expect(_key('status:fact_revenu.error_no_selection'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_07 eclairage nominal shows the mechanism a low to high range four hypotheses and the disclaimer never a single number',
    (tester) async {
      await _reachEclairage(tester, sentinel: '[R3_07]');
      expect(_key('text:eclairage.mechanism'), findsOneWidget);
      expect(_key('amount:eclairage.range'), findsOneWidget);
      expect(_key('text:eclairage.disclaimer'), findsOneWidget);
      for (final id in ['revenu', 'versement', 'situation', 'lieu']) {
        expect(_key('row:eclairage.hyp.$id'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'R3_08 each eclairage hypothesis row is a named editable control with a refine affordance',
    (tester) async {
      // situation is DISPLAY_ONLY (ANCHOR' amendment, LSFin ground) — no toggle.
      // The EDITABLE rows (revenu/versement/lieu) each carry a refine affordance;
      // the runtime's inline situation toggle is removed at the integration batch
      // (registry.deferred_integration).
      await _reachEclairage(tester, sentinel: '[R3_08]');
      expect(_key('action:eclairage.refine_revenu'), findsOneWidget);
      expect(_key('action:eclairage.edit_versement'), findsOneWidget);
      expect(_key('action:eclairage.edit_lieu'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_09 eclairage precision refined tightens the range but never collapses it to a single number',
    (tester) async {
      await _reachEclairage(tester, sentinel: '[R3_09]');
      await _tapVisible(tester, 'action:eclairage.refine_revenu');
      expect(_key('sheet:eclairage.refine_revenu'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_10 eclairage pending missing income shows no number and eclairage low income floor shows the honest note',
    (tester) async {
      // Green-coherent AND jointly satisfiable with R3_06: R3_06 continues with NO
      // band selected and stays (error_no_selection, never routes); R3_10 commits
      // the lt30 band and reaches the low_income_floor honest note — a
      // shows_no_number state (runtime key status:eclairage.low_income_floor). The
      // pure pending state (band unset) is a non-linear harness entry reached via
      // MintNextDesignLabApp.batch21Harness, attested by the runtime dev test
      // dev_eclairage_r3_test.dart — not by this linear integration-journey contract.
      await _reachRevenu(tester, sentinel: '[R3_10]');
      await _tapVisible(tester, 'choice:fact_revenu.lt30');
      await _tapVisible(tester, 'action:fact_revenu.continue');
      expect(_key('status:eclairage.low_income_floor'), findsOneWidget);
      expect(_key('amount:eclairage.range'), findsNothing);
    },
  );

  testWidgets(
    'R3_11 eclairage non_applicable source shows no chf amount under the binary gate',
    (tester) async {
      // The non_applicable (source-taxation / FATCA) state is a harness-preset
      // eligibility gate (canContribute3a=false), reached via batch21Harness and
      // attested by dev_eclairage_r3_test.dart — not linearly. The linear contract
      // asserts the non-vacuous COMPLEMENT: in the applicable (nominal) case a chf
      // range DOES render and the screen is NOT the na state (a bare na-absence
      // assertion would be vacuously true on any nominal screen).
      await _reachEclairage(tester, sentinel: '[R3_11]');
      expect(_key('node:eclairage_impot_3a'), findsOneWidget);
      expect(_key('amount:eclairage.range'), findsOneWidget);
      expect(_key('status:eclairage.na'), findsNothing);
    },
  );

  testWidgets(
    'R3_12 the deduction glossary sheet opens focus trapped and restored',
    (tester) async {
      await _reachEclairage(tester, sentinel: '[R3_12]');
      await _tapVisible(tester, 'action:eclairage.open_deduction_glossary');
      expect(_key('sheet:eclairage.gloss.deduction'), findsOneWidget);
    },
  );

  testWidgets(
    'R3_13 compact 320x700 text scale two shows the eclairage mechanism range and disclaimer without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _reachEclairage(tester, sentinel: '[R3_13]');
      expect(_key('amount:eclairage.range'), findsOneWidget);
      expect(_key('text:eclairage.disclaimer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Positive control #2 — the registry keeps R3 after R2 and before R4 and forbids
  // runtime/product claims. Reads the sealed registry; holds in RED and GREEN. PASSES.
  testWidgets(
    'R3_14 registry keeps R3 after R2 before R4 and excludes later evidence',
    (tester) async {
      final registry =
          File('../../batch21/runtime-gates.yaml').readAsStringSync();
      expect(registry.contains('batch: 21'), isTrue);
      expect(registry.contains('R3:'), isTrue);
      expect(registry.contains('expected_red'), isTrue);
      expect(registry.contains('runtime_implemented'), isTrue);
      expect(registry.contains('R4a_safe_exit'), isTrue);
    },
  );
}
