// DEV proof (author-side, NON-sealed) for the married-only co-located situation
// caveat on the batch21 R3 eclairage_impot_3a payoff. Closes the mint-experience
// P1 (VAGUE GROUPÉE, lead arbitration 2026-08-06): when the user is
// marié·e/pacsé·e the éclairage hero range is STILL the single-person fixture
// figure (no fabricated married ×0.80 — the couple-income recompute is a backend
// L2 sensitivity, NEVER#3). The caveat says so, co-located with the situation
// hypothesis row; célibataire and concubinage (both is_married=false) own the
// number and get NO caveat.
//
// This LOCKS the co-located caveat + the byte-identical hero range across
// célibataire/marié. It is NOT a sealed governance test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/eclairage_impot_3a.dart';
import 'package:mint_next_design_lab/r3_eclairage_catalog.g.dart';

Finder _key(String v) => find.byKey(ValueKey<String>(v));

const _caveatKey = 'text:eclairage.situation_caveat';
const _situationRowKey = 'row:eclairage.hyp.situation';
const _rangeValueKey = 'text:eclairage.range_value';

Future<void> _pump(WidgetTester tester, EclairageSituation situation) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch21Harness(
      locale: const Locale('fr'),
      currentYear: 2026,
      batch21: Batch21Config(
        startNode: Batch21Start.eclairage,
        band: 'b70_100', // grounded nominal band (fixtures 1 800 à 2 200 CHF)
        situation: situation,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _rangeText(WidgetTester t) =>
    t.widget<Text>(_key(_rangeValueKey)).data ?? '';

// LSFin banned terms (fr) — must be absent from the caveat.
const _bannedFr = [
  'garanti',
  'optimal',
  'meilleur',
  'sans risque',
  'assuré',
  'parfait',
  'certain',
];

void main() {
  testWidgets(
      'marié shows the co-located situation caveat (folded into the row, refine kept)',
      (tester) async {
    await _pump(tester, EclairageSituation.marie);
    // The caveat renders exactly once...
    expect(_key(_caveatKey), findsOneWidget);
    // ...co-located INSIDE the situation hypothesis row (announced with it).
    expect(
      find.descendant(of: _key(_situationRowKey), matching: _key(_caveatKey)),
      findsOneWidget,
      reason: 'the caveat must live inside the situation row, not float free',
    );
    // It is the exact sealed FR copy (no promised number, no promised delay).
    expect(
      tester.widget<Text>(_key(_caveatKey)).data,
      r3CopyFor('fr')['eclairage_situation_caveat_marie'],
    );
    // The « Préciser mon état civil » refine affordance is KEPT (not demoted).
    expect(_key('action:eclairage.refine_situation'), findsOneWidget);
    // The situation stays display-only: no inline toggle appears.
    expect(_key('action:eclairage.toggle_situation'), findsNothing);
  });

  testWidgets('célibataire never shows the married caveat (is_married=false owns the number)',
      (tester) async {
    await _pump(tester, EclairageSituation.celibataire);
    expect(_key(_caveatKey), findsNothing);
  });

  testWidgets('concubinage never shows the married caveat (is_married=false, no ×0.80)',
      (tester) async {
    await _pump(tester, EclairageSituation.concubinage);
    expect(_key(_caveatKey), findsNothing);
  });

  testWidgets(
      'the hero range is byte-identical between célibataire and marié (no fabricated married economy, NEVER#3)',
      (tester) async {
    await _pump(tester, EclairageSituation.celibataire);
    final single = _rangeText(tester);
    await _pump(tester, EclairageSituation.marie);
    final married = _rangeText(tester);
    expect(married, single,
        reason: 'a married ×0.80 would silently fabricate a saving the user '
            'does not own; the number must stay the single-person fixture');
    // ...and it is the grounded nominal fixture range, not a point.
    expect(single, '1 800 à 2 200 CHF');
  });

  test('the married caveat exists in all six locales and is LSFin-clean (fr)', () {
    for (final l in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
      final v = r3CopyFor(l)['eclairage_situation_caveat_marie'];
      expect(v, isNotNull, reason: 'locale $l is missing the caveat key');
      expect(v!.trim().isNotEmpty, isTrue, reason: 'locale $l caveat is empty');
    }
    final fr = r3CopyFor('fr')['eclairage_situation_caveat_marie']!.toLowerCase();
    for (final term in _bannedFr) {
      expect(fr.contains(term), isFalse, reason: 'banned term present: $term');
    }
  });
}
