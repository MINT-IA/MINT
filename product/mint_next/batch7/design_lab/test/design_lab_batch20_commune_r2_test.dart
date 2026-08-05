// Batch20 R2 (fact_lieu, COMMUNE DIRECTE) expected-RED contract for the hidden
// design lab.
//
// HONEST + GREEN-REACHABLE expected-RED: the fused fact_lieu runtime does NOT
// exist yet. The commune-directe pivot (Julien 2026-08-04) folds fact_canton
// into fact_lieu — the user answers "Ou habites-tu ?" with a NATIONAL commune
// search and the canton is DERIVED from the chosen commune, never asked. At the
// sealed RED_COMMIT the fused fact_lieu node is unwired after the contribution
// boundary (in the green build both contribution branches reach fact_lieu and
// the standalone fact_canton screen is condemned). So each behavioural
// obligation drives the real MintNextDesignLabApp through the already-green
// shared 3a entry path to the contribution boundary (attested R1 green — see
// product/mint_next/batch20/runtime-gates.yaml authority.supersedes), chooses
// "no contribution" to advance, and then asserts the fused fact_lieu surface.
// That node is absent today, so every obligation fails on its named reach
// assertion with a clean [R2_XX] TestFailure — never a route/late-init/range
// harness error, and never by mutating the attested R1 surface. When R2 wires
// the fused node, the same green path lands directly on fact_lieu and each test
// proceeds past the reach to validate the real behaviour. Two positive controls
// pass: R2_01 (the shared entry path reaches the contribution boundary before
// the fused runtime exists) and R2_15 (the registry keeps R2 first). R2_16 adds
// the positive contribution branch reaching the same fused node. Expected
// machine summary: 2 passed, 14 failed, 0 load/harness errors.
//
// regle13 lesson (a) simulated-green smoke: this file mutates NO process-global
// state (no debugPrint reassignment, no un-restored overrides); the only
// addTearDown calls restore the test view. If the R2 runtime were wired the
// harness itself would run cleanly green with no latent teardown defect.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
Finder _commune(int bfs) => _key('choice:fact_lieu.$bfs');
Finder _search() => _key('field:fact_lieu.search');
Finder _editableUnder(Finder control) =>
    find.descendant(of: control, matching: find.byType(EditableText));

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = _key(key);
  expect(finder, findsOneWidget, reason: 'precondition: $key must exist');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _query(WidgetTester tester, String text) async {
  await tester.enterText(_editableUnder(_search()), text);
  await tester.pump();
}

List<int> _renderedCommuneCodes(WidgetTester tester) => tester
    .widgetList<Widget>(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'choice:fact_lieu.',
            ),
      ),
    )
    .map(
      (widget) => int.parse(
        (widget.key! as ValueKey<String>).value.substring(
          'choice:fact_lieu.'.length,
        ),
      ),
    )
    .toList(growable: false);

// True when the primary focus is on, or nested under, the widget carrying [key].
bool _focusOwnedBy(String key) {
  final target = ValueKey<String>(key);
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var owns = context.widget.key == target;
  context.visitAncestorElements((element) {
    if (element.widget.key == target) {
      owns = true;
      return false;
    }
    return true;
  });
  return owns;
}

bool _searchOwnsFocus() => _focusOwnedBy('field:fact_lieu.search');

// Drive the attested green 3a entry path to the contribution boundary. No
// canton is selected here: the commune-directe fact_lieu replaces the canton
// question, so the honest reach obstacle is the absent fused node itself.
Future<void> _driveToContribution(
  WidgetTester tester, {
  int currentYear = 2026,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp(
      locale: const Locale('fr'),
      currentYear: currentYear,
      textScaler: textScaler,
    ),
  );
  for (final action in _entryActions) {
    await _tapVisible(tester, action);
  }
  expect(
    _key('node:fact_contribution'),
    findsOneWidget,
    reason: 'precondition: the attested R1 contribution boundary must be reachable',
  );
}

// Model the honest green navigation into the fused fact_lieu: advance past the
// contribution boundary and expect the location node. In RED the runtime still
// shows the superseded standalone fact_canton node, so this fails on the named
// reach assertion carrying [R2_XX]; in a future green build the fused node opens
// directly.
Future<void> _reachLieu(
  WidgetTester tester, {
  required String sentinel,
  int currentYear = 2026,
  TextScaler? textScaler,
}) async {
  await _driveToContribution(tester, currentYear: currentYear, textScaler: textScaler);
  await _tapVisible(tester, 'action:fact_contribution.choose_no');
  expect(
    _key('node:fact_lieu'),
    findsOneWidget,
    reason:
        '$sentinel fact_lieu is unreachable: after the contribution boundary the '
        'fused location node is absent (the R2 runtime is unimplemented at this '
        'sealed RED_COMMIT; in the green build both contribution branches reach '
        'the fused fact_lieu and the standalone fact_canton screen is condemned)',
  );
}

void main() {
  // --- Positive control #1: the shared 3a entry path reaches the contribution
  // boundary and the fused fact_lieu node is not yet present at that screen.
  // Holds in RED and in a future GREEN (fact_lieu only opens after advancing).
  // PASSES.
  testWidgets(
    'R2_01 the shared entry path reaches the contribution boundary before the fused location runtime',
    (tester) async {
      await _driveToContribution(tester);
      expect(_key('node:fact_contribution'), findsOneWidget);
      expect(_key('node:fact_lieu'), findsNothing);
    },
  );

  // --- fact_lieu arrival, national search empty states and scope (R2a) ---

  // Positive control #2 for the shared reach: the POSITIVE contribution branch
  // (amount recorded) also reaches the fused fact_lieu node, and origin-aware
  // system-back returns to the amount step (commune-directe: BOTH contribution
  // branches reach fact_lieu). FAILS in RED (fact_lieu absent), PASSES in GREEN.
  testWidgets(
    'R2_16 the positive contribution branch also reaches the fused location runtime and back returns to the amount step',
    (tester) async {
      await _driveToContribution(tester);
      await _tapVisible(tester, 'action:fact_contribution.choose_yes');
      await tester.enterText(
        _key('field:fact_contributed_amount.provider_name'),
        'VIAC',
      );
      await tester.enterText(
        _key('field:fact_contributed_amount.amount'),
        '7000',
      );
      await _tapVisible(tester, 'action:fact_contributed_amount.toggle_all_reviewed');
      await _tapVisible(tester, 'action:fact_contributed_amount.continue');
      expect(
        _key('node:fact_lieu'),
        findsOneWidget,
        reason:
            '[R2_16] the positive contribution branch must reach the fused '
            'fact_lieu node (the R2 runtime is unimplemented at this sealed '
            'RED_COMMIT)',
      );
      // origin-aware system-back returns to the amount step (positive origin).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_key('node:fact_contributed_amount'), findsOneWidget);
    },
  );

  testWidgets(
    'R2_02 arrival focuses the heading not a raised keyboard and the question carries the meaning without a body',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_02]');
      // GREEN: arrival focus is the heading (for the screen reader), the
      // keyboard is NOT auto-raised, and the question stands alone with no
      // explanatory body sentence below it (contract arrival_focus: heading).
      expect(_focusOwnedBy('text:fact_lieu.question'), isTrue);
      expect(_searchOwnsFocus(), isFalse);
      expect(_key('text:fact_lieu.question'), findsOneWidget);
      expect(_key('text:fact_lieu.body'), findsNothing);
      expect(_key('action:fact_lieu.continue'), findsOneWidget);
    },
  );

  testWidgets(
    'R2_03 an empty national query prompts for a commune name and dumps nothing until a prefix is typed',
    (tester) async {
      expect(batch20CommuneScope['BE']![2026]!.length, greaterThan(50));
      await _reachLieu(tester, sentinel: '[R2_03]');
      // GREEN: empty query names the type-to-search prompt and dumps no rows;
      // typing a prefix reveals reviewed national matches.
      expect(_key('status:fact_lieu.empty'), findsOneWidget);
      expect(_renderedCommuneCodes(tester), isEmpty);
      await _query(tester, 'Bern');
      expect(_renderedCommuneCodes(tester), contains(351));
    },
  );

  testWidgets(
    'R2_04 every national result names its derived canton',
    (tester) async {
      // Bern (BFS 351) derives canton BE; Fribourg (BFS 2196) derives canton FR.
      expect(batch20CommuneScope['BE']![2026], contains(351));
      expect(batch20CommuneScope['FR']![2026], contains(2196));
      await _reachLieu(tester, sentinel: '[R2_04]');
      // GREEN: each result names its derived canton. Narrow, deterministic
      // queries (not a broad one that the 50 render cap could exclude): Bern
      // derives BE, Fribourg derives FR — each row carries its canton label.
      await _query(tester, 'Bern');
      expect(_key('canton:fact_lieu.351'), findsOneWidget);
      await _query(tester, 'Fribourg');
      expect(_key('canton:fact_lieu.2196'), findsOneWidget);
    },
  );

  testWidgets(
    'R2_05 results cap at fifty with an overflow status carrying the total',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_05]');
      // GREEN: a broad national query matching more than the 50 render cap shows
      // the overflow status and never renders more than 50 rows.
      await _query(tester, 'e');
      expect(_key('status:fact_lieu.overflow'), findsOneWidget);
      // the overflow status surfaces the total match count (never a silent
      // truncate) and no more than the 50 render cap is built.
      expect(_key('count:fact_lieu.overflow_total'), findsOneWidget);
      expect(_renderedCommuneCodes(tester).length, lessThanOrEqualTo(50));
    },
  );

  testWidgets(
    'R2_12 entry is unset with no default recommended or derived commune and no unknown control',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_12]');
      // GREEN: no preselected commune, no recommendation/inference, and the
      // states are [unset, selected] only — the removed unknown/wheel control
      // must be absent (commune-directe amendment).
      expect(_key('status:fact_lieu.selection_none'), findsOneWidget);
      expect(_key('status:fact_lieu.recommendation'), findsNothing);
      expect(_key('status:fact_lieu.inference'), findsNothing);
      expect(_key('action:fact_lieu.unknown'), findsNothing);
    },
  );

  // --- matching, privacy, NPA and aliases (R2b) ---

  testWidgets(
    'R2_06 bilingual aliases and official variants match the reviewed labels',
    (tester) async {
      expect(batch20CommuneAliases[371], contains('Bienne'));
      await _reachLieu(tester, sentinel: '[R2_06]');
      // GREEN: the bilingual alias resolves to the reviewed commune.
      await _query(tester, 'Bienne');
      expect(_renderedCommuneCodes(tester), contains(371));
    },
  );

  testWidgets(
    'R2_07 the postcode is searchable secondary text but never the committed value',
    (tester) async {
      expect(batch20CommuneNpa[371], '2502');
      expect(batch20CommuneScope['BE']![2026], contains(371));
      await _reachLieu(tester, sentinel: '[R2_07]');
      // GREEN: the NPA matches in search and shows as secondary text; the
      // committed key remains the BFS number, never the postcode.
      await _query(tester, '2502');
      expect(_renderedCommuneCodes(tester), contains(371));
      expect(_key('npa:fact_lieu.371'), findsOneWidget);
    },
  );

  testWidgets(
    'R2_08 the selection summary persists and is visible when the selected commune is not in the current results',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_08]');
      // GREEN: select a commune, then a query that excludes it — the selection
      // summary chip still shows the chosen commune and its derived canton.
      await _query(tester, 'Bienne');
      await _tapVisible(tester, 'choice:fact_lieu.371');
      expect(_key('status:fact_lieu.selection'), findsOneWidget);
      await _query(tester, 'Thun');
      expect(_commune(371), findsNothing);
      expect(_key('status:fact_lieu.selection'), findsOneWidget);
    },
  );

  testWidgets(
    'R2_10 no match prompts a spelling check and reveals a help link that escalates to r3 in the no match state only',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_10]');
      // GREEN: with matches the help link is hidden; a genuinely absent commune
      // yields no rows, the no-match spelling prompt, and the discreet help link
      // (which escalates to the R3 complex-situation path, never commits a fact).
      await _query(tester, 'Bern');
      expect(_key('action:fact_lieu.help'), findsNothing);
      await _query(tester, 'Xyzzyx');
      expect(_renderedCommuneCodes(tester), isEmpty);
      expect(_key('status:fact_lieu.no_match'), findsOneWidget);
      expect(_key('action:fact_lieu.help'), findsOneWidget);
      // activating help surfaces the R3 complex-situation escalation WITHOUT
      // committing a fact/canton and WITHOUT routing out of fact_lieu in R2
      // (contract: escalate ... without_committing, never_routes_in_r2) — no dead end.
      await _tapVisible(tester, 'action:fact_lieu.help');
      expect(_key('status:fact_lieu.r3_help'), findsOneWidget);
      expect(_key('node:fact_lieu'), findsOneWidget);
      expect(_key('status:fact_lieu.selection_none'), findsOneWidget);
      // no fact was committed (not even a hidden one): continue is still guarded.
      await _tapVisible(tester, 'action:fact_lieu.continue');
      expect(_key('status:fact_lieu.error_no_selection'), findsOneWidget);
    },
  );

  // --- selection announcement, glossary, a11y and compact layout (R2c) ---

  testWidgets(
    'R2_09 selecting a commune announces the commune and its derived canton atomically as one node',
    (tester) async {
      // Morat (BFS 2275) derives canton FR — one atomic utterance on selection.
      expect(batch20CommuneAliases[2275], contains('Morat'));
      expect(batch20CommuneScope['FR']![2026], contains(2275));
      await _reachLieu(tester, sentinel: '[R2_09]');
      // GREEN: selecting a row announces the commune AND its derived canton as a
      // single semantics node (never two split live-region updates).
      await _query(tester, 'Morat');
      await _tapVisible(tester, 'choice:fact_lieu.2275');
      // ONE atomic announcement node carries commune + derived canton + selected
      // state; there is no second, split canton live-region node the user could
      // miss (contract accessibility_contract: never_split_into_two_liveregion).
      // The alias "Morat" matches but the OFFICIAL display name is Murten
      // (dataset name rule) and the derived canton FR renders as "Fribourg" (fr,
      // R1 canton catalog).
      expect(_key('announce:fact_lieu.selected'), findsOneWidget);
      expect(_key('announce:fact_lieu.canton'), findsNothing);
      final semantics = tester.ensureSemantics();
      final announced = tester.getSemantics(_key('announce:fact_lieu.selected'));
      // the atomic node is a LIVE REGION (it is spoken on selection) carrying
      // both the official commune name and its derived canton in one utterance.
      expect(announced.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(announced.label, contains(batch20CommuneNames[2275]!['fr']));
      expect(announced.label, contains('Fribourg'));
      semantics.dispose();
      expect(_key('status:fact_lieu.selection'), findsOneWidget);
    },
  );

  testWidgets(
    'R2_11 a tappable glossary anchor opens an aerated definition sheet with a sentence and a metaphor and restores focus',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_11]');
      // GREEN: the communal-tax anchor is a named button (not a bare span); it
      // opens the glossary sheet (heading focus, one plain sentence + optional
      // metaphor), and dismissing it restores focus to the anchor.
      expect(_key('anchor:fact_lieu.impot_communal'), findsOneWidget);
      await _tapVisible(tester, 'anchor:fact_lieu.impot_communal');
      // the sheet opens with a heading and carries one plain sentence + metaphor.
      expect(_key('sheet:fact_lieu.gloss'), findsOneWidget);
      expect(_key('sheet:fact_lieu.gloss.heading'), findsOneWidget);
      expect(_key('sheet:fact_lieu.gloss.metaphor'), findsOneWidget);
      // the sheet takes focus on its heading (focus-trap entry point) and traps
      // focus: traversal cannot escape behind the open sheet (contract: traps
      // focus until dismissed).
      expect(_focusOwnedBy('sheet:fact_lieu.gloss.heading'), isTrue);
      // repeated forward AND backward traversal never escapes the open sheet.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusOwnedBy('sheet:fact_lieu.gloss'), isTrue,
            reason: 'forward traversal $i escaped the trapped sheet');
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusOwnedBy('sheet:fact_lieu.gloss'), isTrue,
            reason: 'backward traversal $i escaped the trapped sheet');
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      // dismissing the sheet restores focus to the anchor, never a dead end
      // (contract: dismiss ... then restores to the anchor).
      await _tapVisible(tester, 'sheet:fact_lieu.gloss.dismiss');
      expect(_key('sheet:fact_lieu.gloss'), findsNothing);
      expect(_key('anchor:fact_lieu.impot_communal'), findsOneWidget);
      expect(_focusOwnedBy('anchor:fact_lieu.impot_communal'), isTrue);
    },
  );

  testWidgets(
    'R2_13 compact 320x700 text scale two keyboard raised keeps continue and a canton naming result reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _reachLieu(
        tester,
        sentinel: '[R2_13]',
        textScaler: const TextScaler.linear(2),
      );
      // GREEN: simulate the RAISED keyboard reducing the viewport (physical px,
      // dpr 1), type a query with a result, and confirm continue stays reachable
      // WITHOUT scrolling — in the pinned footer above the keyboard line (>=48pt,
      // no overflow clip; an overflow would throw during layout) — and at least
      // one result names its derived canton.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(_search());
      await tester.pump();
      await _query(tester, 'Bern');
      final continueFinder = _key('action:fact_lieu.continue');
      expect(continueFinder, findsOneWidget);
      final continueRect = tester.getRect(continueFinder);
      expect(continueRect.height, greaterThanOrEqualTo(48));
      // 700 logical tall, keyboard occupies the bottom 300 -> footer above 400.
      expect(continueRect.bottom, lessThanOrEqualTo(700 - 300));
      // the canton-naming result stays VISIBLE above the keyboard, not merely
      // present in the tree.
      final resultCanton = _key('canton:fact_lieu.351');
      expect(resultCanton, findsOneWidget);
      expect(tester.getRect(resultCanton).top, lessThan(700 - 300));
    },
  );

  testWidgets(
    'R2_14 continue is guarded by a reviewed commune and reselection is idempotent and continue routes to the r3 fact_revenu node at the eclairage integration',
    (tester) async {
      await _reachLieu(tester, sentinel: '[R2_14]');
      // GREEN, superseded by the batch21 éclairage integration: continue with
      // nothing selected surfaces the no-selection guard (route_guard
      // a_reviewed_commune_is_selected); select Bern (BFS 351), reselect it
      // (idempotent no-op), then continue — which now that the éclairage arc is
      // wired into the journey routes forward to the R3 fact_revenu node. The
      // batch20 R2 « never routes in r2 » outbound-edge obligation is superseded
      // BY PIN (registry.deferred_integration); batch20 stays attested at its
      // historical green replay run, this live sibling is re-gated to the wire.
      await _tapVisible(tester, 'action:fact_lieu.continue');
      expect(_key('status:fact_lieu.error_no_selection'), findsOneWidget);
      await _query(tester, 'Bern');
      await _tapVisible(tester, 'choice:fact_lieu.351');
      expect(_key('status:fact_lieu.selection'), findsOneWidget);
      await _tapVisible(tester, 'choice:fact_lieu.351');
      expect(_key('status:fact_lieu.selection'), findsOneWidget);
      await _tapVisible(tester, 'action:fact_lieu.continue');
      expect(_key('node:fact_revenu'), findsOneWidget);
    },
  );

  // --- Positive control #2: the registry keeps R2 the first targeted gate. PASSES.
  test('R2_15 registry keeps R2 before R3 and excludes later evidence', () {
    final registry = File('../../batch20/runtime-gates.yaml').readAsStringSync();
    expect(registry, contains('state: expected_red'));
    expect(registry, contains('next_gate: R3'));
    expect(registry, contains('later_gate_evidence_counts_for_R2: false'));
    expect(
      registry.indexOf('  R2:'),
      lessThan(registry.indexOf('  R3:')),
      reason: '[R2_15] R2 must remain the first targeted runtime gate',
    );
  });
}
