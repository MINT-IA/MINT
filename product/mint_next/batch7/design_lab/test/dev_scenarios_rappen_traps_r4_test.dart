// R4 (batch22) REAL-JOURNEY trap dev test (non-sealed) — reproduces, on the wired
// app (never the harness, so the parser + fact_lieu are exercised), the exact
// three Codex v3 P1 traps the fixes must close:
//
//   V4-1 (P1-1): the éclairage lieu-row fixture disclosure is by EXACT LOCALITY.
//     The fixture is the CHEF-LIEU Fribourg (BFS 2196). Bulle (BFS 2125) is canton
//     FR but NOT the chef-lieu, so it must show the INTRA-cantonal disclosure
//     (different text from the inter-cantonal one). Bern (canton BE) shows the
//     inter-cantonal one; Fribourg (the chef-lieu) shows NONE.
//
//   V4-2 (P1-2): accepted centimes are carried rappen-native, never truncated.
//     4 000.99 CHF contributed (400 099 rappen) is an UNGROUNDED amount: the
//     margin floors to reste 3 257 (never 3 258) and NO grounded fixture scenario
//     rows appear. 4 000.00 exact (400 000 rappen) still fires the sealed fixture:
//     reste 3 258 + the grounded incremental rows.
//
//   V4-3 (P1-3): the amount EXACTLY at the cap is « plafond atteint », not « au-
//     dessus ». 7 258.00 (== cap) -> plafond_atteint (no excess line); 7 258.01
//     (strictly over) -> the overcontribution state.
//
// These are the deterministic success criteria from the fix brief.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/r3_eclairage_catalog.g.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Finder _editableUnder(Finder control) =>
    find.descendant(of: control, matching: find.byType(EditableText));

Finder _regions() =>
    find.byKey(const ValueKey<String>('region:scenarios.scenario'));

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = _key(key);
  expect(finder, findsOneWidget, reason: 'precondition: $key must exist');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// Walk the wired 3a arc to the éclairage payoff. [amount] is the RAW string typed
// into the contribution amount field (so centimes like "4000.99" reach the
// parser verbatim); null takes the "no contribution" branch. [search]/[communeId]
// pick a commune in fact_lieu so the éclairage reflects the real locality.
Future<void> _reachEclairage(
  WidgetTester tester, {
  required String search,
  required int communeId,
  String? amount,
}) async {
  await tester.pumpWidget(
    const MintNextDesignLabApp(locale: Locale('fr'), currentYear: 2026),
  );
  await _tapVisible(tester, 'action:today_3a_intent.start');
  await _tapVisible(tester, 'action:orientation.continue');
  await _tapVisible(tester, 'action:fact_lpp_affiliation.choose_yes');
  if (amount == null) {
    await _tapVisible(tester, 'action:fact_contribution.choose_no');
  } else {
    await _tapVisible(tester, 'action:fact_contribution.choose_yes');
    expect(_key('node:fact_contributed_amount'), findsOneWidget);
    await tester.enterText(
      _editableUnder(_key('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      _editableUnder(_key('field:fact_contributed_amount.amount')),
      amount,
    );
    await tester.pump();
    // First continue surfaces the reviewed gate (stays); toggle then continue.
    await _tapVisible(tester, 'action:fact_contributed_amount.continue');
    await _tapVisible(
        tester, 'action:fact_contributed_amount.toggle_all_reviewed');
    await _tapVisible(tester, 'action:fact_contributed_amount.continue');
    expect(_key('node:fact_lieu'), findsOneWidget);
  }
  await tester.enterText(_editableUnder(_key('field:fact_lieu.search')), search);
  await tester.pump();
  await _tapVisible(tester, 'choice:fact_lieu.$communeId');
  await _tapVisible(tester, 'action:fact_lieu.continue');
  await _tapVisible(tester, 'choice:fact_revenu.b70_100');
  await _tapVisible(tester, 'action:fact_revenu.continue');
  expect(_key('node:eclairage_impot_3a'), findsOneWidget);
}

Future<void> _reachScenarios(
  WidgetTester tester, {
  required String search,
  required int communeId,
  String? amount,
}) async {
  await _reachEclairage(
    tester,
    search: search,
    communeId: communeId,
    amount: amount,
  );
  await _tapVisible(tester, 'action:eclairage.continue');
  expect(_key('node:scenarios_versement'), findsOneWidget);
}

String? _lieuCaveatText(WidgetTester tester) {
  final finder = _key('text:eclairage.lieu_caveat');
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

void main() {
  final fr = r3CopyFor('fr');
  final intraText = fr['eclairage_lieu_intra_canton_disclosure']!;
  final interText = fr['eclairage_lieu_fixture_disclosure']!;

  group('V4-1 lieu-row disclosure by EXACT locality', () {
    testWidgets(
        'Bulle (BFS 2125, canton FR, NOT the chef-lieu) shows the INTRA-cantonal disclosure',
        (tester) async {
      await _reachEclairage(tester, search: 'Bulle', communeId: 2125);
      expect(find.textContaining('Bulle'), findsWidgets,
          reason: 'the lieu row must keep the real picked commune');
      final caveat = _lieuCaveatText(tester);
      expect(caveat, isNotNull,
          reason: 'a FR non-chef-lieu commune must disclose the chef-lieu basis');
      expect(caveat, intraText,
          reason: 'Bulle must show the INTRA-cantonal disclosure text');
      expect(caveat, isNot(interText),
          reason: 'Bulle must NOT reuse the inter-cantonal disclosure text');
    });

    testWidgets(
        'Bern (canton BE) shows the INTER-cantonal disclosure, distinct from intra',
        (tester) async {
      await _reachEclairage(tester, search: 'Bern', communeId: 351);
      final caveat = _lieuCaveatText(tester);
      expect(caveat, interText,
          reason: 'another canton must show the inter-cantonal disclosure');
      expect(caveat, isNot(intraText));
    });

    testWidgets(
        'Fribourg (BFS 2196, the chef-lieu) shows NO disclosure — the number is theirs',
        (tester) async {
      await _reachEclairage(tester, search: 'Fribourg', communeId: 2196);
      expect(find.textContaining('Fribourg'), findsWidgets);
      expect(_key('text:eclairage.lieu_caveat'), findsNothing,
          reason: 'the chef-lieu pick must NOT show any fixture disclosure');
    });
  });

  group('V4-2 rappen end-to-end (conservative floor, exact-fixture trigger)', () {
    testWidgets(
        '4 000.99 CHF contributed floors the margin to reste 3 257 (never 3 258) and shows NO grounded scenario row',
        (tester) async {
      await _reachScenarios(
        tester,
        search: 'Fribourg',
        communeId: 2196,
        amount: '4000.99',
      );
      expect(find.textContaining('3 257'), findsWidgets,
          reason: 'floor((725800 - 400099)/100) = 3257, never 3258');
      expect(find.textContaining('3 258'), findsNothing,
          reason: 'the truncated-centime rounding to 3 258 is the fixed bug');
      // Ungrounded amount: the sealed +1 000 / +3 258 fixture must NOT fire.
      expect(_regions(), findsNothing,
          reason: '4 000.99 is not the grounded 4 000.00 fixture point');
    });

    testWidgets(
        '4 000.00 CHF exact still fires the grounded fixture: reste 3 258 + the incremental rows',
        (tester) async {
      await _reachScenarios(
        tester,
        search: 'Fribourg',
        communeId: 2196,
        amount: '4000',
      );
      expect(find.textContaining('3 258'), findsWidgets,
          reason: 'the exact 4 000.00 fixture point still resolves to reste 3 258');
      expect(find.textContaining('3 257'), findsNothing);
      // The grounded incremental spectrum (+1 000 / +3 258) reappears.
      expect(_regions(), findsNWidgets(2),
          reason: 'the exact fixture point keeps its two grounded scenarios');
      expect(find.textContaining('+1 000 CHF'), findsOneWidget);
      expect(find.textContaining('+3 258 CHF'), findsOneWidget);
    });
  });

  group('V4-3 exact-cap is plafond_atteint, strictly over is the over state', () {
    testWidgets(
        '7 258.00 CHF (== cap) is plafond_atteint — no excess, no "au-dessus"',
        (tester) async {
      await _reachScenarios(
        tester,
        search: 'Fribourg',
        communeId: 2196,
        amount: '7258',
      );
      expect(_key('status:scenarios.plafond_atteint'), findsOneWidget);
      expect(_key('status:scenarios.over'), findsNothing);
      expect(find.textContaining('au-dessus'), findsNothing,
          reason: 'exactly at the cap is not "above" the cap');
      // No contribute-more scenario at the reached ceiling (fault_E).
      expect(_regions(), findsNothing);
    });

    testWidgets(
        '7 258.01 CHF (strictly over the cap) is the overcontribution state',
        (tester) async {
      await _reachScenarios(
        tester,
        search: 'Fribourg',
        communeId: 2196,
        amount: '7258.01',
      );
      expect(_key('status:scenarios.over'), findsOneWidget);
      expect(_key('status:scenarios.plafond_atteint'), findsNothing);
      expect(find.textContaining('au-dessus'), findsWidgets,
          reason: 'strictly over the cap keeps the "above the ceiling" state');
    });
  });
}
