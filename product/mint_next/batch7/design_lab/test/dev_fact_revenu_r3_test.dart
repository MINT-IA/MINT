// DEV proof (author-side) for the batch21 R3 fact_revenu runtime. NOT the sealed
// governance test (that is the lead's design_lab_batch21_* file). These widget
// tests drive the real MintNextDesignLabApp through the batch21 harness and prove
// the fact_revenu behaviours + ValueKey conventions the sealed governance test
// aligns with.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

Finder _key(String v) => find.byKey(ValueKey<String>(v));

Future<void> _pumpFactRevenu(
  WidgetTester tester, {
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch21Harness(
      locale: const Locale('fr'),
      currentYear: 2026,
      textScaler: textScaler,
      batch21: const Batch21Config(startNode: Batch21Start.factRevenu),
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

const _bands = ['lt30', 'b30_50', 'b50_70', 'b70_100', 'b100_150', 'gt150'];

void main() {
  testWidgets('R3 fact_revenu is wired and reachable with its header/safe-exit',
      (tester) async {
    await _pumpFactRevenu(tester);
    expect(_key('node:fact_revenu'), findsOneWidget);
    expect(_key('action:fact_revenu.open_safe_exit'), findsOneWidget);
    expect(_key('text:fact_revenu.eyebrow'), findsOneWidget);
    expect(_key('text:fact_revenu.question'), findsOneWidget);
  });

  testWidgets(
      'arrival: heading focused, no raised keyboard, no wheel, question alone, six bands none preselected',
      (tester) async {
    await _pumpFactRevenu(tester);
    // Heading takes arrival focus for the screen reader; no keyboard is raised
    // (there is no text field / editable at all).
    expect(_focusOwnedBy('text:fact_revenu.question'), isTrue);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(Slider), findsNothing); // no wheel / continuum control
    // Six tappable band cards, stable low->high, none preselected.
    for (final b in _bands) {
      expect(_key('choice:fact_revenu.$b'), findsOneWidget);
    }
    expect(_key('status:fact_revenu.selection_none'), findsOneWidget);
    expect(_key('status:fact_revenu.selection'), findsNothing);
    // The question carries the imposable anchor + a help link.
    expect(_key('anchor:fact_revenu.imposable'), findsOneWidget);
    expect(_key('action:fact_revenu.help_link'), findsOneWidget);
    // No tax amount / rate / saving on this screen.
    expect(find.textContaining('CHF'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('selecting a band commits it, summary shows, no auto-route',
      (tester) async {
    await _pumpFactRevenu(tester);
    await _tap(tester, 'choice:fact_revenu.b70_100');
    // Committed: selection summary is visible, none-state gone, still on
    // fact_revenu (choose_band commits WITHOUT routing).
    expect(_key('status:fact_revenu.selection'), findsOneWidget);
    expect(_key('status:fact_revenu.selection_none'), findsNothing);
    expect(_key('node:fact_revenu'), findsOneWidget);
    // The committed key is the band enum, surfaced as the reviewed band label.
    expect(find.textContaining('70 000 – 100 000 CHF'), findsOneWidget);
  });

  testWidgets(
      'continue is guarded: no band stays on fact_revenu, a band routes to eclairage (integration)',
      (tester) async {
    await _pumpFactRevenu(tester);
    // Nothing selected -> the no-selection guard is announced, no route.
    await _tap(tester, 'action:fact_revenu.continue');
    expect(_key('status:fact_revenu.error_no_selection'), findsOneWidget);
    expect(_key('node:fact_revenu'), findsOneWidget);
    expect(_key('node:eclairage_impot_3a'), findsNothing);
    // Select then continue -> the guard clears and, now that the éclairage arc
    // is wired into the journey (batch21 integration, superseding the R3
    // never-routes obligation), continue routes forward to the payoff node.
    await _tap(tester, 'choice:fact_revenu.b50_70');
    await _tap(tester, 'action:fact_revenu.continue');
    expect(_key('node:eclairage_impot_3a'), findsOneWidget);
    expect(_key('node:fact_revenu'), findsNothing);
  });

  testWidgets('same-band reselect is idempotent (no churn)', (tester) async {
    await _pumpFactRevenu(tester);
    await _tap(tester, 'choice:fact_revenu.b100_150');
    expect(_key('status:fact_revenu.selection'), findsOneWidget);
    await _tap(tester, 'choice:fact_revenu.b100_150');
    expect(_key('status:fact_revenu.selection'), findsOneWidget);
    expect(find.textContaining('100 000 – 150 000 CHF'), findsOneWidget);
  });

  testWidgets(
      'glossary anchor opens a focus-trapped sheet and restores focus to the anchor',
      (tester) async {
    await _pumpFactRevenu(tester);
    await _tap(tester, 'anchor:fact_revenu.imposable');
    expect(_key('sheet:fact_revenu.gloss'), findsOneWidget);
    expect(_key('sheet:fact_revenu.gloss.heading'), findsOneWidget);
    expect(_focusOwnedBy('sheet:fact_revenu.gloss.heading'), isTrue);
    // Forward + backward traversal never escapes the open sheet.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusOwnedBy('sheet:fact_revenu.gloss'), isTrue,
          reason: 'forward traversal $i escaped the trapped sheet');
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusOwnedBy('sheet:fact_revenu.gloss'), isTrue,
          reason: 'backward traversal $i escaped the trapped sheet');
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    // Dismiss restores focus to the anchor (never a dead end).
    await _tap(tester, 'sheet:fact_revenu.gloss.dismiss');
    expect(_key('sheet:fact_revenu.gloss'), findsNothing);
    expect(_focusOwnedBy('anchor:fact_revenu.imposable'), isTrue);
  });

  testWidgets('the help link opens the same imposable glossary sheet',
      (tester) async {
    await _pumpFactRevenu(tester);
    await _tap(tester, 'action:fact_revenu.help_link');
    expect(_key('sheet:fact_revenu.gloss'), findsOneWidget);
  });

  testWidgets(
      'a band card is activable by physical keyboard (Space), not only pointer/VoiceOver',
      (tester) async {
    await _pumpFactRevenu(tester);
    expect(_key('status:fact_revenu.selection_none'), findsOneWidget);
    // Reach the control's focus node (the FocusableActionDetector inside the
    // card) and focus it WITHOUT a pointer tap, then press Space.
    final gesture = find.descendant(
      of: _key('choice:fact_revenu.b70_100'),
      matching: find.byType(GestureDetector),
    );
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    // Space activated the band (ActivateIntent -> commit), no tap involved.
    expect(_key('status:fact_revenu.selection'), findsOneWidget);
    expect(_key('status:fact_revenu.selection_none'), findsNothing);
  });

  testWidgets(
      'compact 320x700 text scale two keeps question, continue and >=2 bands, no overflow clip',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpFactRevenu(tester, textScaler: const TextScaler.linear(2));
    // No RenderFlex overflow would have thrown during pump. The question and the
    // pinned continue stay present; at least two band cards are built.
    expect(_key('text:fact_revenu.question'), findsOneWidget);
    final continueF = _key('action:fact_revenu.continue');
    expect(continueF, findsOneWidget);
    expect(tester.getRect(continueF).height, greaterThanOrEqualTo(48));
    var built = 0;
    for (final b in _bands) {
      if (_key('choice:fact_revenu.$b').evaluate().isNotEmpty) built++;
    }
    expect(built, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });
}
