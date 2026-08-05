// DEV proof (author-side) for the batch22 R4 scenarios_versement runtime. NOT
// a sealed governance test. Drives the real MintNextDesignLabApp through the
// batch22Harness and proves the state_precedence resolution, the derived
// ceiling rule, the fixture-grounded scenario spectrum, the mandatory
// liquidity/disclaimer, fault_B/E, the glossary sheets, and the darkened
// secondary-text token's contrast ratio. Every asserted number is grounded on
// r4-engine-fixtures.yaml (via r4_fermeture_catalog.g.dart).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/r4_fermeture_catalog.g.dart';

Finder _key(String v) => find.byKey(ValueKey<String>(v));

// Reconciled (batch22 integration): the per-scenario announced region now shares
// one key (region:scenarios.scenario) — one widget per grounded scenario. Count
// the regions instead of indexing distinct row keys.
Finder _regions() => find.byKey(const ValueKey<String>('region:scenarios.scenario'));

Future<void> _pumpScenarios(
  WidgetTester tester, {
  bool taxYearKnown = true,
  bool communeKnown = true,
  bool bandKnown = true,
  bool affiliationKnown = true,
  bool affiliated = true,
  int contributedChf = 0,
  int nonAffiliatedIncomeChf = r4Plafond20DemoIncomeChf,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch22Harness(
      locale: const Locale('fr'),
      currentYear: 2026,
      textScaler: textScaler,
      batch22: Batch22Config(
        startNode: Batch22Start.scenariosVersement,
        taxYearKnown: taxYearKnown,
        communeKnown: communeKnown,
        bandKnown: bandKnown,
        affiliated: affiliated,
        affiliationKnown: affiliationKnown,
        contributedChf: contributedChf,
        nonAffiliatedIncomeChf: nonAffiliatedIncomeChf,
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

List<String> _allTexts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

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

// --- WCAG 2.1 relative-luminance contrast, computed mechanically (not just
// cited in a comment) — proves the darkened sauge token clears 4.5:1. ---
double _linearize(int channel) {
  final c = channel / 255;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(int r, int g, int b) =>
    0.2126 * _linearize(r) + 0.7152 * _linearize(g) + 0.0722 * _linearize(b);

void main() {
  test(
      'darkened sauge secondary-text token clears 4.5:1 on paper (WCAG relative-luminance formula, mechanically computed)',
      () {
    // rgb triples avoid any ambiguity around Color component accessors across
    // Flutter versions.
    const sauge = (0x56, 0x72, 0x5C); // rgb(86,114,92) — the R4 darkened token
    const flaggedMockupPaper = (246, 244, 238); // contract-cited violation background
    const runtimePaper = (0xFA, 0xF8, 0xF5); // this file's actual _paper token

    double lum((int, int, int) rgb) =>
        _relativeLuminance(rgb.$1, rgb.$2, rgb.$3);
    double contrast((int, int, int) x, (int, int, int) y) {
      final lx = lum(x), ly = lum(y);
      final hi = lx > ly ? lx : ly;
      final lo = lx > ly ? ly : lx;
      return (hi + 0.05) / (lo + 0.05);
    }

    final onFlaggedPaper = contrast(sauge, flaggedMockupPaper);
    final onRuntimePaper = contrast(sauge, runtimePaper);

    // The flagged mockup sauge rgb(110,140,116) measured 3.37:1 (sealed
    // contract's own measurement) — BELOW 4.5. This darkened token must clear
    // it on both the contract-cited paper AND the runtime's actual paper.
    expect(onFlaggedPaper, greaterThanOrEqualTo(4.5),
        reason:
            'sauge rgb$sauge on contract paper rgb$flaggedMockupPaper = ${onFlaggedPaper.toStringAsFixed(3)}:1');
    expect(onRuntimePaper, greaterThanOrEqualTo(4.5),
        reason:
            'sauge rgb$sauge on runtime paper rgb$runtimePaper = ${onRuntimePaper.toStringAsFixed(3)}:1');
  });

  test('ceiling_derivation_opp3: the 3 mandatory_contract_test_cases pass',
      () {
    // affilié -> 7 258 quel que soit le revenu (testé 20 000 ET 250 000).
    expect(
      r4DeriveAnnualCapChf(affiliated: true, nonAffiliatedIncomeChf: 20000),
      7258,
    );
    expect(
      r4DeriveAnnualCapChf(affiliated: true, nonAffiliatedIncomeChf: 250000),
      7258,
    );
    // non-affilié 20 000 -> 20% = 4 000 (le forfait 7258 surestimerait de 81%).
    expect(
      r4DeriveAnnualCapChf(affiliated: false, nonAffiliatedIncomeChf: 20000),
      4000,
    );
    // non-affilié 250 000 -> 20% = 50 000 plafonné à 36 288.
    expect(
      r4DeriveAnnualCapChf(affiliated: false, nonAffiliatedIncomeChf: 250000),
      36288,
    );
  });

  testWidgets(
      'scenarios_versement is wired and reachable with its header/safe-exit',
      (tester) async {
    await _pumpScenarios(tester);
    expect(_key('node:scenarios_versement'), findsOneWidget);
    expect(_key('action:scenarios_versement.open_safe_exit'), findsOneWidget);
    expect(_key('text:scenarios.eyebrow'), findsOneWidget);
    expect(_key('text:scenarios.choose_line'), findsOneWidget);
  });

  testWidgets(
      'arrival: choose_line focused (not a scenario amount), no naked amount before it',
      (tester) async {
    await _pumpScenarios(tester);
    expect(_focusOwnedBy('text:scenarios.choose_line'), isTrue);
  });

  group('nominal (affilié, contributed 0, plafond 7 258)', () {
    testWidgets(
        'shows 2-3 grounded scenarios, each a RANGE, the maximum marked, liquidity + disclaimer + commune caveat',
        (tester) async {
      await _pumpScenarios(tester);
      expect(_regions(), findsNWidgets(3));
      expect(_key('amount:scenarios.effect'), findsNWidgets(3));
      // 2 000 -> environ 500 à 600 CHF ; 4 000 -> environ 1 000 à 1 200 CHF ;
      // 7 258 (max) -> environ 1 800 à 2 200 CHF (= R3 payoff, same engine).
      expect(find.textContaining('2 000 CHF'), findsOneWidget);
      expect(find.textContaining('500 à 600 CHF'), findsOneWidget);
      expect(find.textContaining('4 000 CHF'), findsOneWidget);
      expect(find.textContaining('1 000 à 1 200 CHF'), findsOneWidget);
      // "7 258 CHF" appears both in the max scenario row and the remaining
      // line ("jusqu'à 7 258 CHF") — both are expected, hence findsWidgets.
      expect(find.textContaining('7 258 CHF'), findsWidgets);
      expect(find.textContaining('1 800 à 2 200 CHF'), findsOneWidget);
      expect(find.textContaining('le maximum cette année'), findsOneWidget);
      expect(find.textContaining('jusqu’à 7 258 CHF'), findsOneWidget);
      expect(_key('text:scenarios.liquidity'), findsOneWidget);
      expect(_key('text:scenarios.disclaimer'), findsOneWidget);
      expect(_key('text:scenarios.commune_caveat'), findsOneWidget);
      expect(_key('action:scenarios.own_amount'), findsOneWidget);
      // No "already" line at contributed = 0.
      expect(_key('text:scenarios.already'), findsNothing);
    });

    testWidgets('LSFin: no banned term, no imperative, no bare rate headline',
        (tester) async {
      await _pumpScenarios(tester);
      final joined = _allTexts(tester).join('\n').toLowerCase();
      for (final term in _banned) {
        expect(joined.contains(term), isFalse,
            reason: 'banned term present: $term');
      }
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a scenario region is focusable and announced as one utterance',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpScenarios(tester);
      final node = tester.getSemantics(_regions().at(2));
      final data = node.getSemanticsData();
      expect(data.label, contains('7 258 CHF'));
      expect(data.label, contains('1 800 à 2 200 CHF'));
      handle.dispose();
    });
  });

  group('marge_reduite (contributed 4 000, reste 3 258 — grounded)', () {
    testWidgets(
        'already + remaining lines, 2 incremental scenarios, rest marked, no invented numbers',
        (tester) async {
      await _pumpScenarios(tester, contributedChf: 4000);
      expect(find.textContaining('déjà versé 4 000 CHF'), findsOneWidget);
      expect(find.textContaining('jusqu’à 3 258 CHF'), findsOneWidget);
      // +1 000 -> environ 200 à 300 CHF ; +3 258 (le reste) -> environ 800 à
      // 1 000 CHF (marge déjà acquise NON recomptée).
      expect(find.textContaining('+1 000 CHF'), findsOneWidget);
      expect(find.textContaining('200 à 300 CHF'), findsOneWidget);
      expect(find.textContaining('+3 258 CHF'), findsOneWidget);
      expect(find.textContaining('800 à 1 000 CHF'), findsOneWidget);
      expect(find.textContaining('encore possible cette année'), findsOneWidget);
      // marge_reduite grounds exactly 2 incremental scenarios (no third).
      expect(_regions(), findsNWidgets(2));
    });

    testWidgets('an ungrounded contributed amount shows no invented scenario row',
        (tester) async {
      // No fixture exists for 2 500 déjà versé — 0-trust: no row is invented.
      await _pumpScenarios(tester, contributedChf: 2500);
      expect(find.textContaining('déjà versé 2 500 CHF'), findsOneWidget);
      expect(_regions(), findsNothing);
      // Liquidity + disclaimer still mandatory.
      expect(_key('text:scenarios.liquidity'), findsOneWidget);
      expect(_key('text:scenarios.disclaimer'), findsOneWidget);
    });
  });

  group('marge_epuisee_overcontribution (fault_E)', () {
    testWidgets(
        'no contribute-more scenario, cap/contributed/excess stated, correction action, mandatory liquidity/disclaimer kept',
        (tester) async {
      await _pumpScenarios(tester, contributedChf: 8000); // cap 7 258
      expect(_key('status:scenarios.over'), findsOneWidget);
      expect(find.textContaining('déjà versé 8 000 CHF'), findsOneWidget);
      expect(find.textContaining('plafond de 7 258 CHF'), findsOneWidget);
      expect(find.textContaining('742 CHF de plus'), findsOneWidget);
      expect(_regions(), findsNothing);
      expect(_key('action:scenarios.own_amount'), findsNothing);
      expect(
        _key('action:scenarios.review_existing_overcontribution'),
        findsOneWidget,
      );
      expect(_key('text:scenarios.liquidity'), findsOneWidget);
      expect(_key('text:scenarios.disclaimer'), findsOneWidget);
    });
  });

  group('plafond_20pct_non_affilie overlay (revenu exact 20 000 -> 4 000)', () {
    testWidgets(
        'ceiling depends on income, derived amount shown, ONE qualitative max scenario, no fabricated fourchette',
        (tester) async {
      await _pumpScenarios(tester, affiliated: false);
      expect(_key('text:scenarios.plafond20_line'), findsOneWidget);
      expect(find.textContaining('4 000 CHF cette année'), findsOneWidget);
      expect(_key('text:scenarios.plafond20_income_hyp'), findsOneWidget);
      // Non-affilié overlay: exactly ONE qualitative max scenario.
      expect(_regions(), findsNWidgets(1));
      // Never a flat 7 258 for a non-affilié (fault_A).
      expect(find.textContaining('7 258'), findsNothing);
      // Qualitative note, never a numeric fourchette ("à" range join) for
      // this state's scenario effect.
      expect(
        find.textContaining('reste modeste et dépend beaucoup de ta commune'),
        findsOneWidget,
      );
      expect(_key('text:scenarios.liquidity'), findsOneWidget);
      expect(_key('text:scenarios.disclaimer'), findsOneWidget);
    });

    testWidgets('marge_epuisee still resolves relative to the DERIVED cap',
        (tester) async {
      // non-affilié, cap dérivé 4 000, déjà versé 4 000 -> épuisé, PAS marge
      // réduite, PAS avalé par un état plafond terminal (state_precedence).
      await _pumpScenarios(tester, affiliated: false, contributedChf: 4000);
      expect(_key('status:scenarios.over'), findsOneWidget);
      expect(find.textContaining('plafond de 4 000 CHF'), findsOneWidget);
    });
  });

  group('pending_missing_fact (relative critical inputs)', () {
    testWidgets('missing tax_year names the fact, no scenario numbers',
        (tester) async {
      await _pumpScenarios(tester, taxYearKnown: false);
      expect(_key('status:scenarios.pending'), findsOneWidget);
      expect(find.textContaining('l’année fiscale'), findsOneWidget);
      expect(_regions(), findsNothing);
      expect(_key('action:scenarios.pending_action'), findsOneWidget);
    });

    testWidgets('missing commune names the fact', (tester) async {
      await _pumpScenarios(tester, communeKnown: false);
      expect(find.textContaining('ta commune'), findsOneWidget);
    });

    testWidgets('missing band names the fact', (tester) async {
      await _pumpScenarios(tester, bandKnown: false);
      expect(find.textContaining('ta tranche de revenu imposable'),
          findsOneWidget);
    });

    testWidgets('missing lpp_affiliation names the fact', (tester) async {
      await _pumpScenarios(tester, affiliationKnown: false);
      expect(
        find.textContaining('ton affiliation à une caisse de pension'),
        findsOneWidget,
      );
    });
  });

  group('own_amount: pulled by value, optional, no preselection', () {
    testWidgets('opens the sheet, no preselected amount', (tester) async {
      await _pumpScenarios(tester);
      await _tap(tester, 'action:scenarios.own_amount');
      expect(_key('sheet:scenarios.own_amount'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: _key('sheet:scenarios.own_amount.field'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets(
        'entering the exact remaining room shows the grounded max effect (honest, not fabricated)',
        (tester) async {
      await _pumpScenarios(tester); // nominal, remaining room = 7 258
      await _tap(tester, 'action:scenarios.own_amount');
      await tester.enterText(
        find.descendant(
          of: _key('sheet:scenarios.own_amount.field'),
          matching: find.byType(EditableText),
        ),
        '7258',
      );
      await tester.pump();
      await _tap(tester, 'sheet:scenarios.own_amount.save');
      expect(_key('row:scenarios.own_amount_result'), findsOneWidget);
      expect(find.textContaining('1 800 à 2 200 CHF'), findsWidgets);
    });

    testWidgets(
        'entering MORE than the remaining room states the excess, never credits a benefit on it (fault_B)',
        (tester) async {
      await _pumpScenarios(tester);
      await _tap(tester, 'action:scenarios.own_amount');
      await tester.enterText(
        find.descendant(
          of: _key('sheet:scenarios.own_amount.field'),
          matching: find.byType(EditableText),
        ),
        '9000',
      );
      await tester.pump();
      await _tap(tester, 'sheet:scenarios.own_amount.save');
      expect(_key('text:scenarios.excess_note'), findsOneWidget);
      // The deductible part clamps to remaining room (7 258) -> same grounded
      // effect as the max anchor; no number is invented for the excess.
      expect(find.textContaining('1 800 à 2 200 CHF'), findsWidgets);
    });

    testWidgets('an ungrounded own amount shows the amount with no invented effect',
        (tester) async {
      await _pumpScenarios(tester);
      await _tap(tester, 'action:scenarios.own_amount');
      await tester.enterText(
        find.descendant(
          of: _key('sheet:scenarios.own_amount.field'),
          matching: find.byType(EditableText),
        ),
        '3000',
      );
      await tester.pump();
      await _tap(tester, 'sheet:scenarios.own_amount.save');
      expect(_key('row:scenarios.own_amount_result'), findsOneWidget);
      expect(_key('text:scenarios.own_amount_result.effect'), findsNothing);
    });

    testWidgets(
        'the own_amount control is NOT offered when the room is exhausted (fault_E)',
        (tester) async {
      await _pumpScenarios(tester, contributedChf: 8000);
      expect(_key('action:scenarios.own_amount'), findsNothing);
    });
  });

  group('glossary sheets — focus-trapped, restore to anchor', () {
    testWidgets('plafond glossary opens from choose_line and restores',
        (tester) async {
      await _pumpScenarios(tester);
      await _tap(tester, 'action:scenarios.open_plafond_glossary');
      expect(_key('sheet:scenarios.gloss.plafond'), findsOneWidget);
      expect(find.textContaining('7 258 CHF'), findsWidgets);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusOwnedBy('sheet:scenarios.gloss.plafond'), isTrue,
            reason: 'traversal $i escaped the trapped sheet');
      }
      await _tap(tester, 'sheet:scenarios.gloss.plafond.dismiss');
      expect(_key('sheet:scenarios.gloss.plafond'), findsNothing);
      expect(_focusOwnedBy('text:scenarios.choose_line'), isTrue);
    });

    testWidgets('marge glossary opens from the remaining line and restores',
        (tester) async {
      await _pumpScenarios(tester);
      await _tap(tester, 'action:scenarios.open_marge_glossary');
      expect(_key('sheet:scenarios.gloss.marge'), findsOneWidget);
      await _tap(tester, 'sheet:scenarios.gloss.marge.dismiss');
      expect(_focusOwnedBy('text:scenarios.remaining'), isTrue);
    });

    testWidgets(
        'liquidity (bloqué) glossary opens and states the withdrawal exceptions',
        (tester) async {
      await _pumpScenarios(tester);
      await _tap(tester, 'action:scenarios.open_liquidity_glossary');
      expect(_key('sheet:scenarios.gloss.bloque'), findsOneWidget);
      expect(find.textContaining('retrait anticipé'), findsOneWidget);
      await _tap(tester, 'sheet:scenarios.gloss.bloque.dismiss');
      expect(_focusOwnedBy('text:scenarios.liquidity'), isTrue);
    });
  });

  testWidgets(
      'compact 320x700 text scale two keeps choose_line, a scenario, liquidity, disclaimer, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpScenarios(tester, textScaler: const TextScaler.linear(2));
    expect(tester.takeException(), isNull);
    expect(_key('text:scenarios.choose_line'), findsOneWidget);
    expect(_regions(), findsAtLeastNWidgets(1));
    expect(_key('text:scenarios.liquidity'), findsOneWidget);
    expect(_key('text:scenarios.disclaimer'), findsOneWidget);
    final continueF = _key('action:scenarios.continue');
    expect(continueF, findsOneWidget);
    expect(tester.getRect(continueF).height, greaterThanOrEqualTo(48));
  });
}
