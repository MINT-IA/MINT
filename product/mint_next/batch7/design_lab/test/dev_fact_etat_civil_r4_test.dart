// DEV proof (author-side) for the batch22 R4 fact_etat_civil runtime. NOT a
// sealed governance test. Drives the real MintNextDesignLabApp through the
// batch22Harness and proves the three-card single-select, the no-preselection
// rule, the is_married derivation (the ruling: concubinage never maps to
// married), the determining-date hint, the glossary sheets, and the
// darkened secondary-text token's contrast ratio.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/fact_etat_civil.dart';

Finder _key(String v) => find.byKey(ValueKey<String>(v));

Future<void> _pumpEtatCivil(
  WidgetTester tester, {
  String? civilStatus,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch22Harness(
      locale: const Locale('fr'),
      currentYear: 2026,
      textScaler: textScaler,
      batch22: Batch22Config(
        startNode: Batch22Start.factEtatCivil,
        civilStatus: civilStatus,
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

const _statuses = ['celibataire', 'marie_pacse', 'concubinage'];

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
    const sauge = (0x56, 0x72, 0x5C); // rgb(86,114,92)
    const flaggedMockupPaper = (246, 244, 238); // contract-cited violation bg
    const runtimePaper = (0xFA, 0xF8, 0xF5); // this screen's actual _paper

    double lum((int, int, int) rgb) =>
        _relativeLuminance(rgb.$1, rgb.$2, rgb.$3);
    double contrast((int, int, int) x, (int, int, int) y) {
      final lx = lum(x), ly = lum(y);
      final hi = lx > ly ? lx : ly;
      final lo = lx > ly ? ly : lx;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(contrast(sauge, flaggedMockupPaper), greaterThanOrEqualTo(4.5));
    expect(contrast(sauge, runtimePaper), greaterThanOrEqualTo(4.5));
  });

  test('is_married derives ONLY from marie_pacse (fault_5 ruling)', () {
    expect(r4IsMarriedFromCivilStatus('celibataire'), isFalse);
    expect(r4IsMarriedFromCivilStatus('marie_pacse'), isTrue);
    expect(r4IsMarriedFromCivilStatus('concubinage'), isFalse);
    expect(r4IsMarriedFromCivilStatus(null), isFalse);
  });

  testWidgets(
      'fact_etat_civil is wired and reachable with its header/safe-exit',
      (tester) async {
    await _pumpEtatCivil(tester);
    expect(_key('node:fact_etat_civil'), findsOneWidget);
    expect(_key('action:fact_etat_civil.open_safe_exit'), findsOneWidget);
    expect(_key('text:etat_civil.eyebrow'), findsOneWidget);
    expect(_key('text:etat_civil.question'), findsOneWidget);
    expect(_key('text:etat_civil.determining_hint'), findsOneWidget);
  });

  testWidgets(
      'arrival: heading focused, no raised keyboard, three cards none preselected, determining hint names the tax year',
      (tester) async {
    await _pumpEtatCivil(tester);
    expect(_focusOwnedBy('text:etat_civil.question'), isTrue);
    expect(find.byType(EditableText), findsNothing);
    for (final s in _statuses) {
      expect(_key('choice:etat_civil.$s'), findsOneWidget);
    }
    expect(_key('status:etat_civil.selection_none'), findsOneWidget);
    expect(_key('status:etat_civil.selection'), findsNothing);
    expect(find.textContaining('31 décembre 2026'), findsOneWidget);
    // No personal tax amount/rate on this collection screen.
    expect(find.textContaining('CHF'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('selecting a status commits it, summary shows, no auto-route',
      (tester) async {
    await _pumpEtatCivil(tester);
    await _tap(tester, 'choice:etat_civil.concubinage');
    expect(_key('status:etat_civil.selection'), findsOneWidget);
    expect(_key('status:etat_civil.selection_none'), findsNothing);
    expect(_key('node:fact_etat_civil'), findsOneWidget); // no route
    expect(find.textContaining('En couple, non marié'), findsWidgets);
    expect(_key('text:etat_civil.recompute_hint'), findsOneWidget);
  });

  testWidgets('same-status reselect is idempotent (no churn)', (tester) async {
    await _pumpEtatCivil(tester);
    await _tap(tester, 'choice:etat_civil.marie_pacse');
    expect(_key('status:etat_civil.selection'), findsOneWidget);
    await _tap(tester, 'choice:etat_civil.marie_pacse');
    expect(_key('status:etat_civil.selection'), findsOneWidget);
    expect(find.textContaining('Marié·e ou en partenariat enregistré'),
        findsWidgets);
  });

  testWidgets(
      'continue is guarded: no status stays put with an announced error, a status clears the guard',
      (tester) async {
    await _pumpEtatCivil(tester);
    await _tap(tester, 'action:etat_civil.continue');
    expect(_key('status:etat_civil.error_no_selection'), findsOneWidget);
    expect(_key('node:fact_etat_civil'), findsOneWidget);
    await _tap(tester, 'choice:etat_civil.celibataire');
    await _tap(tester, 'action:etat_civil.continue');
    expect(_key('status:etat_civil.error_no_selection'), findsNothing);
    // never_routes_in_r4 (continue AND back for this node): stays on the
    // node — parallel prep, linear wiring is the promoter's integration wave.
    expect(_key('node:fact_etat_civil'), findsOneWidget);
  });

  testWidgets(
      'concubinage is preselectable via the harness and renders as committed, never mapped to married',
      (tester) async {
    await _pumpEtatCivil(tester, civilStatus: 'concubinage');
    expect(_key('status:etat_civil.selection'), findsOneWidget);
    expect(find.textContaining('En couple, non marié'), findsWidgets);
    expect(r4IsMarriedFromCivilStatus('concubinage'), isFalse);
  });

  group('glossary sheets — splitting (help_link) + concubinage ruling', () {
    testWidgets(
        'help_link opens the splitting sheet (marié·e primary + célibataire secondary), focus-trapped, restores',
        (tester) async {
      await _pumpEtatCivil(tester);
      await _tap(tester, 'action:etat_civil.open_splitting_glossary');
      expect(_key('sheet:etat_civil.gloss.splitting'), findsOneWidget);
      expect(
        _key('sheet:etat_civil.gloss.splitting.heading'),
        findsOneWidget,
      );
      expect(
        _focusOwnedBy('sheet:etat_civil.gloss.splitting.heading'),
        isTrue,
      );
      expect(find.textContaining('imposé·e avec ton ou ta partenaire'),
          findsOneWidget);
      // The célibataire secondary block covers divorce/veuvage in the SAME
      // sheet (mirrors fact_revenu.dart's brut secondary-block pattern).
      expect(find.textContaining('veuvage'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          _focusOwnedBy('sheet:etat_civil.gloss.splitting'),
          isTrue,
          reason: 'traversal $i escaped the trapped sheet',
        );
      }
      await _tap(tester, 'sheet:etat_civil.gloss.splitting.dismiss');
      expect(_key('sheet:etat_civil.gloss.splitting'), findsNothing);
      expect(_focusOwnedBy('action:etat_civil.open_splitting_glossary'), isTrue);
    });

    testWidgets(
        'the concubinage card carries its OWN glossary anchor, distinct from selecting it, and states separate taxation',
        (tester) async {
      await _pumpEtatCivil(tester);
      // Opening the glossary anchor must NOT itself commit a selection.
      await _tap(tester, 'action:etat_civil.open_concubinage_glossary');
      expect(_key('sheet:etat_civil.gloss.concubinage'), findsOneWidget);
      expect(find.textContaining('imposé séparément'), findsOneWidget);
      expect(
        _focusOwnedBy('sheet:etat_civil.gloss.concubinage.heading'),
        isTrue,
      );
      await _tap(tester, 'sheet:etat_civil.gloss.concubinage.dismiss');
      expect(_key('status:etat_civil.selection'), findsNothing,
          reason: 'the glossary anchor must not commit a selection');
      expect(
        _focusOwnedBy('action:etat_civil.open_concubinage_glossary'),
        isTrue,
      );
    });
  });

  testWidgets(
      'a status card is activable by physical keyboard (Space), not only pointer/VoiceOver',
      (tester) async {
    await _pumpEtatCivil(tester);
    expect(_key('status:etat_civil.selection_none'), findsOneWidget);
    final gesture = find.descendant(
      of: _key('choice:etat_civil.marie_pacse'),
      matching: find.byType(GestureDetector),
    );
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_key('status:etat_civil.selection'), findsOneWidget);
    expect(_key('status:etat_civil.selection_none'), findsNothing);
  });

  testWidgets(
      'compact 320x700 text scale two keeps question, determining hint, all three cards, continue, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpEtatCivil(tester, textScaler: const TextScaler.linear(2));
    expect(tester.takeException(), isNull);
    expect(_key('text:etat_civil.question'), findsOneWidget);
    expect(_key('text:etat_civil.determining_hint'), findsOneWidget);
    for (final s in _statuses) {
      expect(_key('choice:etat_civil.$s'), findsOneWidget);
    }
    final continueF = _key('action:etat_civil.continue');
    expect(continueF, findsOneWidget);
    expect(tester.getRect(continueF).height, greaterThanOrEqualTo(48));
  });
}
