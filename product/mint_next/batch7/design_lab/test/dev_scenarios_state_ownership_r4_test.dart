// R4 (batch22) STATE-OWNERSHIP dev test (non-sealed) — locks the fermeture-loop
// state preservation the roast (P1-1) found destroyed AND the two V3 corrections
// Codex demanded (v2 review):
//
//   V3-1 (P1-1): the éclairage hero range is ALWAYS the Fribourg fixture figure
//   (offline-lab). Showing the user's picked canton (Bern) on that number is a
//   displayable lie UNLESS co-located with a disclosure. So: Bern picked ->
//   éclairage lieu row shows the real commune label AND a fixture-canton
//   disclosure; a Fribourg pick (canton == fixture) shows NO disclosure.
//
//   V3-2 (P1-2): the already-contributed amount entered on the real journey must
//   reach the scenarios margin. LPP yes -> already contributed 4 000 -> scenarios
//   must show the reduced margin (reste 3 258 = plafond 7 258 − versé 4 000),
//   never the full 7 258.
//
//   And the ORIGINAL P1-1ii: the fermeture-loop financial state (kept reference,
//   picked commune, contributed amount) survives one loop turn (scenarios ->
//   etat_civil -> éclairage -> scenarios) rather than being silently reset.
//
// It reaches the runtime through the REAL app (not the harness) because the point
// is the parent-owned state that survives widget destruction; the harness would
// bypass fact_lieu (where the commune is picked) and the loop wiring.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

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

// Walk the wired 3a arc to the éclairage payoff, declaring an already-contributed
// amount (LPP yes -> contribution yes -> [amount]) and PICKING a commune by id in
// fact_lieu so the éclairage reflects the user's real choice.
Future<void> _reachEclairage(
  WidgetTester tester, {
  required String search,
  required int communeId,
  int? alreadyContributedChf,
}) async {
  await tester.pumpWidget(
    const MintNextDesignLabApp(locale: Locale('fr'), currentYear: 2026),
  );
  await _tapVisible(tester, 'action:today_3a_intent.start');
  await _tapVisible(tester, 'action:orientation.continue');
  await _tapVisible(tester, 'action:fact_lpp_affiliation.choose_yes');
  if (alreadyContributedChf == null) {
    await _tapVisible(tester, 'action:fact_contribution.choose_no');
  } else {
    // Declare an already-contributed amount on the REAL journey (single
    // provider): provider name + amount + reviewed toggle + continue. This is
    // the path Codex P1-2 showed dropped the value before V3-2.
    await _tapVisible(tester, 'action:fact_contribution.choose_yes');
    expect(_key('node:fact_contributed_amount'), findsOneWidget);
    await tester.enterText(
      _editableUnder(_key('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      _editableUnder(_key('field:fact_contributed_amount.amount')),
      '$alreadyContributedChf',
    );
    await tester.pump();
    // First continue surfaces the confirm/reviewed gate (stays on the node);
    // toggle "all providers reviewed", then continue routes to fact_lieu.
    await _tapVisible(tester, 'action:fact_contributed_amount.continue');
    await _tapVisible(tester, 'action:fact_contributed_amount.toggle_all_reviewed');
    await _tapVisible(tester, 'action:fact_contributed_amount.continue');
    expect(_key('node:fact_lieu'), findsOneWidget);
  }
  await tester.enterText(
    _editableUnder(_key('field:fact_lieu.search')),
    search,
  );
  await tester.pump();
  await _tapVisible(tester, 'choice:fact_lieu.$communeId');
  await _tapVisible(tester, 'action:fact_lieu.continue');
  await _tapVisible(tester, 'choice:fact_revenu.b70_100');
  await _tapVisible(tester, 'action:fact_revenu.continue');
  expect(_key('node:eclairage_impot_3a'), findsOneWidget);
}

void main() {
  testWidgets(
    'R4 loop: Bern + already-contributed 4 000 shows the fixture-canton '
    'disclosure and the reduced margin (reste 3 258), both surviving one turn',
    (tester) async {
      // Bern (commune 351, canton BE ≠ the FR fixture) + already contributed
      // 4 000 CHF on the real journey.
      await _reachEclairage(
        tester,
        search: 'Bern',
        communeId: 351,
        alreadyContributedChf: 4000,
      );

      // TURN 1 éclairage — the lieu row shows the picked commune (Bern) AND the
      // co-located fixture-canton disclosure (V3-1): the hero number is the FR
      // fixture, so the picked-canton label is honestly flagged.
      expect(find.textContaining('Bern'), findsWidgets,
          reason: 'the éclairage lieu row must show the picked commune');
      expect(_key('text:eclairage.lieu_caveat'), findsOneWidget,
          reason: 'canton ≠ FR must show the fixture-canton disclosure (V3-1)');

      // Enter scenarios (turn 1) — the already-contributed 4 000 reached the
      // margin (V3-2): reduced room reste 3 258, never the full plafond 7 258.
      await _tapVisible(tester, 'action:eclairage.continue');
      expect(_key('node:scenarios_versement'), findsOneWidget);
      expect(find.textContaining('3 258'), findsWidgets,
          reason: 'contributed 4 000 must reduce the margin to 3 258 (V3-2)');
      expect(find.textContaining('7 258'), findsNothing,
          reason: 'the full plafond must NOT be shown once 4 000 is contributed');

      // Keep the estimate (persists in place, announced chip).
      await _tapVisible(tester, 'action:scenarios.keep_local_reference');
      expect(_key('status:scenarios.reference_kept'), findsOneWidget);

      // LOOP: scenarios -> etat_civil -> (select) -> continue -> éclairage.
      await _tapVisible(tester, 'action:scenarios.continue');
      expect(_key('node:fact_etat_civil'), findsOneWidget);
      await _tapVisible(tester, 'choice:etat_civil.celibataire');
      await _tapVisible(tester, 'action:etat_civil.continue');

      // TURN 2 éclairage — the picked commune AND its disclosure SURVIVED the
      // loop (still Bern, still disclosed — never reverted to the fixture).
      expect(_key('node:eclairage_impot_3a'), findsOneWidget);
      expect(find.textContaining('Bern'), findsWidgets,
          reason: 'commune must survive the loop turn');
      expect(_key('text:eclairage.lieu_caveat'), findsOneWidget,
          reason: 'the disclosure must survive the loop turn');

      // Enter scenarios again (turn 2).
      await _tapVisible(tester, 'action:eclairage.continue');
      expect(_key('node:scenarios_versement'), findsOneWidget);

      // The contributed amount SURVIVED — the reduced margin (reste 3 258) is
      // still shown, not silently reset to the full plafond (roast P1-1ii + V3-2).
      expect(find.textContaining('3 258'), findsWidgets,
          reason: 'the contributed amount must survive the loop turn');
      expect(find.textContaining('7 258'), findsNothing);

      // The kept reference SURVIVED — the announced chip is still shown.
      expect(_key('status:scenarios.reference_kept'), findsOneWidget,
          reason: 'the kept reference must survive the loop turn (roast P1-1ii)');

      // The commune SURVIVED (scenarios is NOT pending) — it renders content,
      // not the pending state.
      expect(_key('status:scenarios.pending'), findsNothing);
    },
  );

  testWidgets(
    'R4 éclairage: a Fribourg pick (canton == the FR fixture) shows NO '
    'fixture-canton disclosure — the number IS theirs',
    (tester) async {
      // Fribourg (commune 2196, canton FR == the fixture): the hero number is
      // computed for their canton, so no disclosure is shown (V3-1).
      await _reachEclairage(tester, search: 'Fribourg', communeId: 2196);
      expect(find.textContaining('Fribourg'), findsWidgets,
          reason: 'the éclairage lieu row must show the picked commune');
      expect(_key('text:eclairage.lieu_caveat'), findsNothing,
          reason: 'canton == FR must NOT show the fixture-canton disclosure');
    },
  );
}
