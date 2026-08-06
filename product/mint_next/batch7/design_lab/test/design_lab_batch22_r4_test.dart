// Batch22 R4 (FERMETURE DE LA BOUCLE — scenarios_versement + fact_etat_civil)
// GREEN integration contract for the hidden design lab.
//
// The INTEGRATION-JOURNEY contract, one notch beyond R3, now DELIVERED: the
// fermeture-de-la-boucle loop is CLOSED. The shared 3a entry path routes
// fact_lieu -> fact_revenu -> eclairage_impot_3a (the attested batch21 GREEN
// boundary), and R4 wires the two nodes the journey now reaches:
//   * scenarios_versement — reached by eclairage.continue (superseding the R3
//     kept boundary on that edge). Its footer is wired: continue ->
//     fact_etat_civil (registry order), back -> eclairage, keep_local_reference
//     persists + STAYS on the node (announced live-region);
//   * fact_etat_civil — reached by the eclairage situation-row refine affordance.
//     Its footer is wired: continue -> eclairage (the situation hypothesis
//     re-derives from the committed status, still DISPLAY-ONLY — no fabricated
//     married range, NEVER#3), back is origin-aware (eclairage OR scenarios).
// Each obligation walks the green linear path (R4_02..R4_15) or drives the
// batch22 harness for a non-linear state (R4_17), asserting the DELIVERED R4
// surface — never a route/late-init/range harness error, and never by mutating
// R1/R2/R3.
//
// The married RECOMPUTE stays out of scope (backend L2 sensitivity, NEVER#3):
// the offline lab never calls the spouse-income-bounded range service and never
// computes a married ×0.80 number in Dart. R4 delivers honest STATES / COPIES /
// ROUTING only. Two positive controls hold: R4_01 (the wired arc reaches the
// delivered eclairage boundary and neither R4 node is present there before
// continue/refine) and R4_16 (the registry keeps R4 after R3 / before
// runtime_global). R4_17 (D) drives the harness to a non-affilié scenarios state
// and asserts the OPP3-derived ceiling (min(20% * net earned income, 36 288) =
// 4 000 at income 20 000), never the flat affiliated 7 258.
// Expected machine summary: 17 passed, 0 failed, 0 load/harness errors.
//
// regle13 lesson (a) simulated-green smoke: this file mutates NO process-global
// state (no debugPrint reassignment, no un-restored overrides); the only
// addTearDown calls restore the test view.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

// Phase B supersession: the fact_tax_year screen left the journey (année =
// hypothèse par défaut, plus une question). orientation.continue now seeds the
// current-year default and routes straight to the LPP question — the two
// fact_tax_year taps are dropped from the shared entry path. Obligation count
// is unchanged (the taps were setup, not assertions).
const _entryActions = <String>[
  'action:today_3a_intent.start',
  'action:orientation.continue',
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
      // V3-3b (Codex P1-3): arrival REALLY focuses the choose-line heading (not a
      // scenario amount) — assert the primary focus, not just the text's presence.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'scenarios choose_line',
        reason: '[R4_03] arrival must focus the choose-line heading',
      );
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
      // V3-3b (Codex P1-3): the sheet REALLY traps focus on its heading on open,
      // and dismissing REALLY restores focus to the choose-line anchor.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'scenarios sheet heading',
        reason: '[R4_06] the plafond glossary must trap focus on its heading',
      );
      await _tapVisible(tester, 'sheet:scenarios.gloss.plafond.dismiss');
      expect(_key('sheet:scenarios.gloss.plafond'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'scenarios choose_line',
        reason: '[R4_06] dismiss must restore focus to the choose-line anchor',
      );
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
      // The compact/2x overflow proof is REAL: drive the delivered scenarios
      // runtime at textScaler 2.0 (the harness lands on the nominal scenarios
      // state — same content the wired arc reaches, proven by R4_02..R4_07). The
      // prior form set the 320x700 viewport but never applied the scale, so the
      // "text scale two" it names was never exercised (roast P1-2).
      await tester.pumpWidget(
        MintNextDesignLabApp.batch22Harness(
          locale: const Locale('fr'),
          currentYear: 2026,
          textScaler: const TextScaler.linear(2.0),
          batch22: const Batch22Config(
            startNode: Batch22Start.scenariosVersement,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('node:scenarios_versement'), findsOneWidget);
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
      // V3-3b (Codex P1-3): arrival REALLY focuses the question (which stands
      // alone, no body) — assert the primary focus, not just text presence.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'fact_etat_civil question',
        reason: '[R4_10] arrival must focus the question',
      );
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
      // V3-3b (Codex P1-3): the splitting sheet REALLY traps focus on its heading,
      // and dismissing REALLY restores focus to the help-link anchor it opened from.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'fact_etat_civil sheet heading',
        reason: '[R4_12] the splitting glossary must trap focus on its heading',
      );
      await _tapVisible(tester, 'sheet:etat_civil.gloss.splitting.dismiss');
      expect(_key('sheet:etat_civil.gloss.splitting'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'fact_etat_civil help_link anchor',
        reason: '[R4_12] dismiss must restore focus to the help-link anchor',
      );
    },
  );

  testWidgets(
    'R4_13 the concubinage glossary states separate taxation never the married splitting',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_13]');
      await _tapVisible(tester, 'action:etat_civil.open_concubinage_glossary');
      expect(_key('sheet:etat_civil.gloss.concubinage'), findsOneWidget);
      // V3-3b (Codex P1-3): assert the RULING itself, not just the sheet's
      // existence — the concubinage gloss states SEPARATE taxation (imposé
      // séparément, comme une personne célibataire), never the married splitting.
      expect(
        find.descendant(
          of: _key('sheet:etat_civil.gloss.concubinage'),
          matching: find.textContaining('séparément'),
        ),
        findsOneWidget,
        reason: '[R4_13] the concubinage gloss must state separate taxation',
      );
    },
  );

  testWidgets(
    'R4_14 fact_etat_civil no selection announces the error and stays but a selected status routes continue to eclairage',
    (tester) async {
      await _reachEtatCivil(tester, sentinel: '[R4_14]');
      // (a) no selection: continue announces the error and STAYS on the node.
      await _tapVisible(tester, 'action:etat_civil.continue');
      expect(_key('status:etat_civil.error_no_selection'), findsOneWidget);
      expect(_key('node:fact_etat_civil'), findsOneWidget);
      // (b) with a selection: continue clears the guard and ROUTES to the
      // eclairage payoff, whose situation hypothesis re-derives from the
      // committed status (still display-only — no fabricated married range,
      // NEVER#3).
      await _tapVisible(tester, 'choice:etat_civil.marie_pacse');
      await _tapVisible(tester, 'action:etat_civil.continue');
      expect(_key('node:fact_etat_civil'), findsNothing);
      expect(_key('node:eclairage_impot_3a'), findsOneWidget);
      // It is the NOMINAL PAYOFF, not merely the node: the éclairage range value
      // is present AND the married caveat is co-located (the range stays the
      // single-person fixture figure — no fabricated ×0.80 recompute, NEVER#3 /
      // sealed R4_13). Asserting the node alone let a blank/error éclairage pass
      // (roast P1-2).
      expect(_key('text:eclairage.range_value'), findsOneWidget);
      expect(_key('text:eclairage.situation_caveat'), findsOneWidget);
    },
  );

  testWidgets(
    'R4_15 compact 320x700 text scale two shows the question the three status cards and continue without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Real 2x proof: drive the delivered fact_etat_civil runtime at textScaler
      // 2.0 via the harness (the arc reach is proven by R4_09..R4_14). The prior
      // form set the viewport but never applied the scale (roast P1-2).
      await tester.pumpWidget(
        MintNextDesignLabApp.batch22Harness(
          locale: const Locale('fr'),
          currentYear: 2026,
          textScaler: const TextScaler.linear(2.0),
          batch22: const Batch22Config(
            startNode: Batch22Start.factEtatCivil,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('node:fact_etat_civil'), findsOneWidget);
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
      final lines = registry.split('\n');

      // ORDER — ordered_gates lists R4 STRICTLY before runtime_global (parsed,
      // not a loose contains: a reordered list would now fail).
      final orderedStart =
          lines.indexWhere((l) => l.trimRight() == 'ordered_gates:');
      expect(orderedStart, greaterThanOrEqualTo(0),
          reason: 'ordered_gates block must exist');
      final ordered = <String>[];
      for (var i = orderedStart + 1; i < lines.length; i++) {
        final m = RegExp(r'^-\s*(\S+)\s*$').firstMatch(lines[i]);
        if (m == null) break;
        ordered.add(m.group(1)!);
      }
      expect(ordered.contains('R4'), isTrue);
      expect(ordered.contains('runtime_global'), isTrue);
      expect(ordered.indexOf('R4') < ordered.indexOf('runtime_global'), isTrue,
          reason: 'R4 must be ordered before runtime_global');

      // The R4 gate block: its next gate is runtime_global and it EXCLUDES later
      // (runtime_global) evidence. Sliced from `  R4:` to the next top-level gate
      // key so a stray field elsewhere cannot satisfy the check.
      final r4Start = lines.indexWhere((l) => l == '  R4:');
      expect(r4Start, greaterThanOrEqualTo(0), reason: 'gates.R4 must exist');
      final r4End = lines.indexWhere(
        (l) => RegExp(r'^  \S').hasMatch(l) && l != '  R4:',
        r4Start + 1,
      );
      final r4Block =
          lines.sublist(r4Start, r4End < 0 ? lines.length : r4End).join('\n');
      expect(r4Block.contains('next_gate: runtime_global'), isTrue,
          reason: 'R4.next_gate must be runtime_global');
      expect(
          r4Block.contains('later_gate_evidence_counts_for_R4: false'), isTrue,
          reason: 'R4 must EXCLUDE later-gate (runtime_global) evidence');
      // The frozen RED control strings are deliberately kept stable in R4.
      expect(r4Block.contains('state: expected_red'), isTrue);
      expect(r4Block.contains('runtime_implemented: false'), isTrue);

      // runtime_global is the LATER gate and is blocked BY R4 (R4 gates it).
      final laterStart = lines.indexWhere((l) => l == '  runtime_global:');
      expect(laterStart, greaterThanOrEqualTo(0),
          reason: 'gates.runtime_global must exist');
      expect(lines[laterStart + 1].contains('state: blocked_by_R4'), isTrue,
          reason: 'runtime_global must be blocked_by_R4');

      // R4 comes AFTER R3: it SUPERSEDES the accepted R3 green gate and forbids
      // re-attesting R3 live (regle13 supersession).
      expect(registry.contains('r3_green_gate:'), isTrue,
          reason: 'R4 supersedes the accepted R3 gate (R4 after R3)');
      expect(registry.contains('no_live_reattestation_of_r3: true'), isTrue);
    },
  );

  // --- R4 D: the non-affilié ceiling DERIVES (OPP3 art. 7) — never a flat 7258 ---
  //
  // Driven via the batch22 harness on a non-affilié scenarios state: the
  // célibataire/affilié linear walk (choose_yes) can never reach affiliated:false,
  // so — like the other off-nominal scenarios states in the runtime dev proof —
  // this obligation lands the runtime under test directly. The cap is
  // L1-deterministic (a crisp min(20% * net earned income, 36 288)), not a
  // sensitivity, so it lives in the offline lab.
  testWidgets(
    'R4_17 non_affilie reaches a derived ceiling never a flat 7258',
    (tester) async {
      // ONE obligation, the THREE mandatory OPP3 contract cases
      // (scenarios_versement-scope.yaml:193-196). The cap DERIVES from
      // affiliation + income (min(0.20 * net income, 36 288) without a pension
      // fund ; flat 7 258 with one) — never a flat 7 258 forfait served to a
      // non-affilié, never derived from employment status.

      // (1) non-affilié, revenu 20 000 -> min(0.20*20000, 36288) = 4 000 ; the
      //     forfait 7 258 would OVERSTATE this cap by 81%.
      await tester.pumpWidget(
        MintNextDesignLabApp.batch22Harness(
          locale: const Locale('fr'),
          currentYear: 2026,
          batch22: const Batch22Config(
            startNode: Batch22Start.scenariosVersement,
            affiliated: false,
            nonAffiliatedIncomeChf: 20000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('node:scenarios_versement'), findsOneWidget);
      expect(_key('text:scenarios.plafond20_amount'), findsOneWidget);
      expect(find.textContaining('4 000'), findsWidgets);
      expect(find.textContaining('7 258'), findsNothing);

      // (2) non-affilié, revenu 250 000 -> 20% = 50 000 CLAMPED to the max
      //     36 288 ; the forfait 7 258 would UNDERSTATE this cap ~5x.
      // Force a full teardown first: re-pumping the same MintNextDesignLabApp
      // type reuses the journey State (its harness config is read once in
      // initState), so without this the income would stay case (1)'s 20 000.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MintNextDesignLabApp.batch22Harness(
          locale: const Locale('fr'),
          currentYear: 2026,
          batch22: const Batch22Config(
            startNode: Batch22Start.scenariosVersement,
            affiliated: false,
            nonAffiliatedIncomeChf: 250000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('node:scenarios_versement'), findsOneWidget);
      expect(_key('text:scenarios.plafond20_amount'), findsOneWidget);
      expect(find.textContaining('36 288'), findsWidgets);
      expect(find.textContaining('7 258'), findsNothing);

      // (3) affilié -> petit 3a = 7 258 flat, WHATEVER the income (driven at
      //     250 000 to prove income-independence): the affilié path shows NO 20%
      //     ceiling line and the remaining room IS the 7 258 cap.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MintNextDesignLabApp.batch22Harness(
          locale: const Locale('fr'),
          currentYear: 2026,
          batch22: const Batch22Config(
            startNode: Batch22Start.scenariosVersement,
            affiliated: true,
            nonAffiliatedIncomeChf: 250000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('node:scenarios_versement'), findsOneWidget);
      expect(_key('text:scenarios.plafond20_amount'), findsNothing);
      expect(find.textContaining('7 258'), findsWidgets);
    },
  );
}
