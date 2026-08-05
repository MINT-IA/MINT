// DEV proof (author-side) for the batch21 R3 eclairage_impot_3a runtime. NOT the
// sealed governance test. Drives the real MintNextDesignLabApp through the
// batch21 harness and proves the five render states, the precision scale, the
// editable hypotheses, the glossary sheets, and the LSFin no-promise contract.
// Every asserted number is grounded on r3-engine-fixtures.yaml.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/eclairage_impot_3a.dart';
import 'package:mint_next_design_lab/r3_eclairage_catalog.g.dart';

Finder _key(String v) => find.byKey(ValueKey<String>(v));

Future<void> _pumpEclairage(
  WidgetTester tester, {
  String? band = 'b70_100',
  bool canContribute = true,
  int? exactIncome,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch21Harness(
      locale: const Locale('fr'),
      currentYear: 2026,
      textScaler: textScaler,
      batch21: Batch21Config(
        startNode: Batch21Start.eclairage,
        band: band,
        canContribute: canContribute,
        exactIncome: exactIncome,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = _key(key);
  expect(f, findsOneWidget, reason: 'precondition: $key must exist');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String _rangeText(WidgetTester t) =>
    t.widget<Text>(_key('text:eclairage.range_value')).data ?? '';

List<String> _allTexts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

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

// LSFin banned terms (fr) — must be absent from every rendered surface.
const _banned = [
  'garanti',
  'optimal',
  'meilleur',
  'sans risque',
  'assuré',
  'parfait',
  'certain',
];

void main() {
  test('R3 copy has full key parity across the six locales (no fallback holes)',
      () {
    final locales = ['fr', 'en', 'de', 'it', 'es', 'pt'];
    for (final l in locales) {
      expect(r3Copy.containsKey(l), isTrue, reason: 'missing locale $l');
    }
    final frKeys = r3Copy['fr']!.keys.toSet();
    for (final l in locales) {
      expect(r3Copy[l]!.keys.toSet(), frKeys,
          reason: 'locale $l key set differs from fr');
    }
  });

  testWidgets('nominal renders in all six locales with a grounded range, no crash',
      (tester) async {
    for (final code in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
      await tester.pumpWidget(
        MintNextDesignLabApp.batch21Harness(
          locale: Locale(code),
          currentYear: 2026,
          batch21: const Batch21Config(
            startNode: Batch21Start.eclairage,
            band: 'b70_100',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'locale $code threw');
      expect(_key('amount:eclairage.range'), findsOneWidget,
          reason: 'locale $code has no range');
      // 1 800 and 2 200 are locale-independent (francs, space-grouped).
      expect(_rangeText(tester).contains('1 800'), isTrue);
      expect(_rangeText(tester).contains('2 200'), isTrue);
    }
  });

  testWidgets('nominal is wired with header/safe-exit and the full result surface',
      (tester) async {
    await _pumpEclairage(tester);
    expect(_key('node:eclairage_impot_3a'), findsOneWidget);
    expect(_key('action:eclairage_impot_3a.open_safe_exit'), findsOneWidget);
    expect(_key('text:eclairage.mechanism'), findsOneWidget);
    expect(_key('amount:eclairage.range'), findsOneWidget);
    expect(_key('text:eclairage.caption'), findsOneWidget);
    expect(_key('group:eclairage.hypotheses'), findsOneWidget);
    for (final id in ['revenu', 'versement', 'situation', 'lieu']) {
      expect(_key('row:eclairage.hyp.$id'), findsOneWidget);
    }
    expect(_key('text:eclairage.assumptions'), findsOneWidget);
    expect(_key('text:eclairage.disclaimer'), findsOneWidget);
    expect(_key('action:eclairage.continue'), findsOneWidget);
    expect(_key('action:eclairage.back'), findsOneWidget);
  });

  testWidgets('nominal amount is the fixture-grounded RANGE, never a single number',
      (tester) async {
    await _pumpEclairage(tester);
    // FR band 70-100k: fixtures saving_low 1831 -> floor100 1800; saving_high
    // 2242 -> floor100 2200. Sealed maquette: « ≈ 1 800 à 2 200 CHF ».
    expect(_rangeText(tester), '1 800 à 2 200 CHF');
    // It is a range (two bounds joined by « à »), not a single promised number.
    expect(_rangeText(tester).contains(' à '), isTrue);
    // The revenu hypothesis carries the committed band; versement the cap 7258.
    expect(find.textContaining('70 000 – 100 000 CHF'), findsWidgets);
    expect(find.textContaining('7 258 CHF'), findsOneWidget);
  });

  testWidgets('LSFin: no banned term, no imperative, no rate headline, not retirement',
      (tester) async {
    await _pumpEclairage(tester);
    final joined = _allTexts(tester).join('\n').toLowerCase();
    for (final term in _banned) {
      expect(joined.contains(term), isFalse, reason: 'banned term present: $term');
    }
    // No abolished imperative (#1061).
    expect(joined.contains('économise'), isFalse);
    expect(joined.contains('economise'), isFalse);
    // Framed on THIS YEAR'S tax, never retirement.
    expect(joined.contains('retraite'), isFalse);
    expect(joined.contains('retirement'), isFalse);
    // Francs, not a rate: no percentage headline anywhere.
    expect(find.textContaining('%'), findsNothing);
    // The estimate-not-advice disclaimer is present and reachable.
    expect(find.textContaining('estimation, pas un conseil fiscal'), findsOneWidget);
  });

  testWidgets('the range is announced atomically as one live-region node',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpEclairage(tester);
    final node = tester.getSemantics(_key('amount:eclairage.range'));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.label, '1 800 à 2 200 CHF');
    handle.dispose();
  });

  testWidgets('pending_missing_income shows no number', (tester) async {
    await _pumpEclairage(tester, band: null);
    expect(_key('status:eclairage.pending'), findsOneWidget);
    expect(_key('amount:eclairage.range'), findsNothing);
    expect(_key('text:eclairage.range_value'), findsNothing);
    // The complete-action CTA (routes to fact_revenu) is present.
    expect(_key('action:eclairage.edit_revenu'), findsOneWidget);
    // No CHF amount anywhere in the pending surface.
    expect(find.textContaining('CHF'), findsNothing);
  });

  testWidgets('non_applicable_source NEVER shows a CHF amount', (tester) async {
    await _pumpEclairage(tester, canContribute: false);
    expect(_key('status:eclairage.na'), findsOneWidget);
    expect(_key('amount:eclairage.range'), findsNothing);
    expect(_key('text:eclairage.range_value'), findsNothing);
    expect(_key('action:eclairage.na_action'), findsOneWidget);
    // The binary gate is false -> a CHF saving would be a false promise.
    expect(find.textContaining('CHF'), findsNothing);
    // na_action opens the ordinaire glossary (never a number).
    await _tap(tester, 'action:eclairage.na_action');
    expect(_key('sheet:eclairage.gloss.ordinaire'), findsOneWidget);
  });

  testWidgets('low_income_floor (lt30) shows an honest note, no number',
      (tester) async {
    await _pumpEclairage(tester, band: 'lt30');
    expect(_key('status:eclairage.low_income_floor'), findsOneWidget);
    expect(_key('amount:eclairage.range'), findsNothing);
    expect(find.textContaining('Sous 30 000 CHF'), findsOneWidget);
  });

  testWidgets('precision_refined: tighter range, STILL a range, provenance upgraded',
      (tester) async {
    // Exact income 85 000 (fixtures precision_refined_point) -> saving 2213,
    // never a point: the refined window is 2 100 à 2 300 CHF (WIDE per P3/P4).
    await _pumpEclairage(tester, exactIncome: 85000);
    expect(_rangeText(tester), '2 100 à 2 300 CHF');
    expect(_rangeText(tester).contains(' à '), isTrue); // still a range
    // Refined caption + exact provenance badge.
    expect(find.textContaining('d’après ton chiffre'), findsOneWidget);
    expect(find.text('exact'), findsOneWidget);
    // The exact figure replaces the bracket in place (same fact, upgraded).
    expect(find.textContaining('85 000 CHF'), findsWidgets);
  });

  testWidgets('refine is pulled by value: sheet tightens the range in place',
      (tester) async {
    await _pumpEclairage(tester); // nominal 1 800 à 2 200
    expect(_rangeText(tester), '1 800 à 2 200 CHF');
    await _tap(tester, 'action:eclairage.refine_revenu');
    expect(_key('sheet:eclairage.refine_revenu'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: _key('sheet:eclairage.refine_revenu.field'),
        matching: find.byType(EditableText),
      ),
      '85000',
    );
    await tester.pump();
    await _tap(tester, 'sheet:eclairage.refine_revenu.save');
    // The range narrows in place, never collapsing to a point.
    expect(_rangeText(tester), '2 100 à 2 300 CHF');
    expect(_rangeText(tester).contains(' à '), isTrue);
  });

  testWidgets(
      'hypothesis rows: revenu/versement/lieu are editable controls, situation is display-only',
      (tester) async {
    await _pumpEclairage(tester);
    // All four hypothesis rows are shown.
    for (final id in ['revenu', 'versement', 'situation', 'lieu']) {
      expect(_key('row:eclairage.hyp.$id'), findsOneWidget);
    }
    // The three editable rows carry a refine/edit control.
    expect(_key('action:eclairage.refine_revenu'), findsOneWidget);
    expect(_key('action:eclairage.edit_versement'), findsOneWidget);
    expect(_key('action:eclairage.edit_lieu'), findsOneWidget);
    // Situation is DISPLAY-ONLY (ANCHOR''' amendment): no inline toggle, no
    // situation sheet — a false « marié » control would overstate the economy.
    // The refine of situation is deferred to the état-civil batch (R4).
    expect(_key('action:eclairage.toggle_situation'), findsNothing);
    expect(_key('sheet:eclairage.situation'), findsNothing);
    // Its stated value is still shown (célibataire by default).
    expect(find.textContaining('élibataire'), findsWidgets);
  });

  testWidgets(
      'ruling: concubinage renders the SAME range as célibataire (no married x0.80)',
      (tester) async {
    // Célibataire (default) grounded range.
    await _pumpEclairage(tester);
    expect(_rangeText(tester), '1 800 à 2 200 CHF');
    // Concubinage is preset via the harness — situation is DISPLAY-ONLY in R3, so
    // there is no inline toggle. It is the SINGLE treatment (is_married=false, no
    // ×0.80), so the grounded range is byte-identical to célibataire.
    await tester.pumpWidget(
      MintNextDesignLabApp.batch21Harness(
        locale: const Locale('fr'),
        currentYear: 2026,
        batch21: const Batch21Config(
          startNode: Batch21Start.eclairage,
          band: 'b70_100',
          situation: EclairageSituation.concubinage,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_rangeText(tester), '1 800 à 2 200 CHF');
    expect(find.textContaining('En couple, non marié'), findsWidgets);
  });

  testWidgets('deduction glossary opens focus-trapped from the mechanism and restores',
      (tester) async {
    await _pumpEclairage(tester);
    await _tap(tester, 'text:eclairage.mechanism');
    expect(_key('sheet:eclairage.gloss.deduction'), findsOneWidget);
    expect(_key('sheet:eclairage.gloss.deduction.heading'), findsOneWidget);
    expect(_key('sheet:eclairage.gloss.deduction.metaphor'), findsOneWidget);
    expect(_focusOwnedBy('sheet:eclairage.gloss.deduction.heading'), isTrue);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusOwnedBy('sheet:eclairage.gloss.deduction'), isTrue,
          reason: 'traversal $i escaped the trapped sheet');
    }
    await _tap(tester, 'sheet:eclairage.gloss.deduction.dismiss');
    expect(_key('sheet:eclairage.gloss.deduction'), findsNothing);
    // Focus restores to the mechanism anchor (holds the gloss_deduction node).
    expect(_focusOwnedBy('text:eclairage.mechanism'), isTrue);
  });

  testWidgets('the eyebrow opens the 3a glossary', (tester) async {
    await _pumpEclairage(tester);
    await _tap(tester, 'text:eclairage.eyebrow');
    expect(_key('sheet:eclairage.gloss.pilier3a'), findsOneWidget);
  });

  testWidgets(
      'compact 320x700 text scale two keeps mechanism, range, >=2 hyps, disclaimer, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpEclairage(tester, textScaler: const TextScaler.linear(2));
    expect(tester.takeException(), isNull);
    expect(_key('text:eclairage.mechanism'), findsOneWidget);
    expect(_key('amount:eclairage.range'), findsOneWidget);
    expect(_key('text:eclairage.disclaimer'), findsOneWidget);
    var rows = 0;
    for (final id in ['revenu', 'versement', 'situation', 'lieu']) {
      if (_key('row:eclairage.hyp.$id').evaluate().isNotEmpty) rows++;
    }
    expect(rows, greaterThanOrEqualTo(2));
  });
}
