// R4 (batch22) STATE-OWNERSHIP dev test (non-sealed) — locks the fermeture-loop
// state preservation the roast (P1-1) found destroyed.
//
// The bug: re-entering scenarios_versement from the éclairage payoff is a LOOP
// TURN, not a fresh journey, but `_enterScenariosFromEclairage` forced
// contributedChf to 0, erased the own-amount ("versement"), reset referenceKept,
// and hardcoded the commune to the fixture (Fribourg) — so one loop turn
// silently destroyed the user's financial state and displayed Fribourg after the
// user had chosen Bern.
//
// This test drives the WIRED linear journey through ONE full loop turn
//   éclairage -> scenarios -> etat_civil -> éclairage -> scenarios
// and asserts the versement (own amount), the kept reference, and the picked
// commune are ALL preserved on the second turn — and that the éclairage shows
// the commune the user actually picked (Bern), never the fixture (Fribourg).
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

// Walk the wired 3a arc to the éclairage payoff, PICKING Bern (commune 351) in
// fact_lieu so the éclairage lieu row must reflect the user's actual choice.
Future<void> _reachEclairagePickingBern(WidgetTester tester) async {
  await tester.pumpWidget(
    const MintNextDesignLabApp(locale: Locale('fr'), currentYear: 2026),
  );
  await _tapVisible(tester, 'action:today_3a_intent.start');
  await _tapVisible(tester, 'action:orientation.continue');
  await _tapVisible(tester, 'action:fact_lpp_affiliation.choose_yes');
  await _tapVisible(tester, 'action:fact_contribution.choose_no');
  await tester.enterText(_editableUnder(_key('field:fact_lieu.search')), 'Bern');
  await tester.pump();
  await _tapVisible(tester, 'choice:fact_lieu.351');
  await _tapVisible(tester, 'action:fact_lieu.continue');
  await _tapVisible(tester, 'choice:fact_revenu.b70_100');
  await _tapVisible(tester, 'action:fact_revenu.continue');
  expect(_key('node:eclairage_impot_3a'), findsOneWidget);
}

void main() {
  testWidgets(
    'R4 loop preserves the versement, the kept reference and the picked commune '
    'across one fermeture turn (never a silent reset, never the fixture commune)',
    (tester) async {
      await _reachEclairagePickingBern(tester);

      // TURN 1 éclairage — the payoff hypothesis shows the commune the user
      // picked (Bern), NEVER the graved fixture (Fribourg) presented as theirs.
      expect(find.textContaining('Bern'), findsWidgets,
          reason: 'the éclairage lieu row must show the picked commune');
      expect(find.textContaining('Fribourg'), findsNothing,
          reason: 'the fixture commune must not be shown as the user\'s choice');

      // Enter scenarios (turn 1).
      await _tapVisible(tester, 'action:eclairage.continue');
      expect(_key('node:scenarios_versement'), findsOneWidget);

      // Enter a personal versement of 4 000 via the own-amount sheet.
      await _tapVisible(tester, 'action:scenarios.own_amount');
      await tester.enterText(
        _editableUnder(_key('sheet:scenarios.own_amount.field')),
        '4000',
      );
      await tester.pump();
      await _tapVisible(tester, 'sheet:scenarios.own_amount.save');
      // The own-amount result row is present (the key renders only when an
      // amount is committed).
      expect(_key('amount:scenarios.own_amount_result'), findsOneWidget);
      expect(find.textContaining('4 000'), findsWidgets);

      // Keep the estimate (persists in place, announced chip).
      await _tapVisible(tester, 'action:scenarios.keep_local_reference');
      expect(_key('status:scenarios.reference_kept'), findsOneWidget);

      // LOOP: scenarios -> etat_civil -> (select) -> continue -> éclairage.
      await _tapVisible(tester, 'action:scenarios.continue');
      expect(_key('node:fact_etat_civil'), findsOneWidget);
      await _tapVisible(tester, 'choice:etat_civil.celibataire');
      await _tapVisible(tester, 'action:etat_civil.continue');

      // TURN 2 éclairage — the picked commune SURVIVED the loop (still Bern,
      // never reverted to the fixture Fribourg).
      expect(_key('node:eclairage_impot_3a'), findsOneWidget);
      expect(find.textContaining('Bern'), findsWidgets,
          reason: 'commune must survive the loop turn');
      expect(find.textContaining('Fribourg'), findsNothing);

      // Enter scenarios again (turn 2).
      await _tapVisible(tester, 'action:eclairage.continue');
      expect(_key('node:scenarios_versement'), findsOneWidget);

      // The versement (own amount) SURVIVED — the row is still present with its
      // value, not silently dropped to a fresh no-amount state.
      expect(_key('amount:scenarios.own_amount_result'), findsOneWidget,
          reason: 'the versement must survive the loop turn (roast P1-1ii)');
      expect(find.textContaining('4 000'), findsWidgets);

      // The kept reference SURVIVED — the announced chip is still shown, not
      // reset to false.
      expect(_key('status:scenarios.reference_kept'), findsOneWidget,
          reason: 'the kept reference must survive the loop turn (roast P1-1ii)');

      // The commune SURVIVED (scenarios is NOT pending on a missing commune) —
      // it renders the choose line, not the pending state.
      expect(_key('text:scenarios.choose_line'), findsOneWidget);
      expect(_key('status:scenarios.pending'), findsNothing);
    },
  );
}
