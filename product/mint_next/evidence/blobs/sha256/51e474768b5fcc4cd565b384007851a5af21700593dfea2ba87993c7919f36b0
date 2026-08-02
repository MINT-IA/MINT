import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

Future<void> openLppQuestion(WidgetTester tester) async {
  await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('fr')));
  await tester.tap(find.byKey(const ValueKey('action:today_3a_intent.start')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('action:fact_tax_year.confirm_current_year')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('action:fact_tax_year.continue')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('node:fact_lpp_affiliation')),
    findsOneWidget,
  );
}

void main() {
  testWidgets('LPP paths remain reachable at 320px and text scale 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MintNextDesignLabApp(
        locale: Locale('de'),
        textScaler: TextScaler.linear(2),
      ),
    );
    for (final key in [
      'action:today_3a_intent.start',
      'action:orientation.continue',
      'action:fact_tax_year.confirm_current_year',
      'action:fact_tax_year.continue',
    ]) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    final unknown = find.byKey(
      const ValueKey('action:fact_lpp_affiliation.choose_unknown'),
    );
    await tester.ensureVisible(unknown);
    await tester.tap(unknown);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:lpp_unknown_help')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final back = find.byKey(const ValueKey('action:lpp_unknown_help.back'));
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();

    for (final route in [
      (
        choice: 'action:fact_lpp_affiliation.choose_no',
        node: 'node:without_lpp_boundary',
        back: 'action:without_lpp_boundary.back',
      ),
      (
        choice: 'action:fact_lpp_affiliation.choose_yes',
        node: 'node:fact_contribution',
        back: 'action:fact_contribution.back',
      ),
    ]) {
      final choice = find.byKey(ValueKey(route.choice));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(route.node)), findsOneWidget);
      final routeBack = find.byKey(ValueKey(route.back));
      await tester.ensureVisible(routeBack);
      await tester.tap(routeBack);
      await tester.pumpAndSettle();
    }

    final exit = find.byKey(
      const ValueKey('action:fact_lpp_affiliation.open_safe_exit'),
    );
    await tester.tap(exit);
    await tester.pumpAndSettle();
    final disabled = tester.getSemantics(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.keep_local_reference'),
      ),
    );
    expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    final leave = find.byKey(
      const ValueKey('overlay-action:safe_exit.leave_without_saving'),
    );
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tax year continues to the exact tri-state LPP question', (
    tester,
  ) async {
    await openLppQuestion(tester);
    expect(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_yes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_no')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_unknown')),
      findsOneWidget,
    );
    expect(
      find.text('As-tu actuellement une caisse de pension ?'),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('group:fact_lpp_affiliation.choices')),
          )
          .label,
      'As-tu actuellement une caisse de pension ?',
    );
    for (final id in ['choose_yes', 'choose_no', 'choose_unknown']) {
      expect(
        tester
            .getSize(find.byKey(ValueKey('action:fact_lpp_affiliation.$id')))
            .height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('unknown routes to honest help and back preserves selection', (
    tester,
  ) async {
    await openLppQuestion(tester);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_unknown')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:lpp_unknown_help')), findsOneWidget);
    final disabled = tester.getSemantics(
      find.byKey(
        const ValueKey('action:lpp_unknown_help.keep_checklist_local'),
      ),
    );
    expect(
      disabled.getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    await tester.tap(
      find.byKey(const ValueKey('action:lpp_unknown_help.back')),
    );
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_unknown')),
    );
    expect(
      semantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('no routes to honest boundary and back preserves selection', (
    tester,
  ) async {
    await openLppQuestion(tester);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_no')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:without_lpp_boundary')),
      findsOneWidget,
    );
    expect(
      find.textContaining('ne signifie pas que tu n’as pas droit au 3a'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('action:without_lpp_boundary.back')),
    );
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_no')),
    );
    expect(
      semantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets(
    'yes reaches the declared next node and returns with yes visible',
    (tester) async {
      await openLppQuestion(tester);
      await tester.tap(
        find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_yes')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('node:fact_contribution')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('action:fact_contribution.back')),
      );
      await tester.pumpAndSettle();
      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_yes')),
      );
      expect(
        semantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
    },
  );

  testWidgets('safe exit resume preserves facts and leave purges them', (
    tester,
  ) async {
    await openLppQuestion(tester);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_lpp_affiliation.choose_unknown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:lpp_unknown_help.open_safe_exit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:lpp_unknown_help.back')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(
            find.byKey(
              const ValueKey(
                'action:fact_lpp_affiliation.choose_unknown',
              ),
            ),
          )
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_lpp_affiliation.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('action:dismissed.restart')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:orientation.continue')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('action:fact_tax_year.continue')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_tax_year.confirm_current_year'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_tax_year.continue')),
    );
    await tester.pumpAndSettle();
    for (final id in ['choose_yes', 'choose_no', 'choose_unknown']) {
      expect(
        tester
            .getSemantics(
              find.byKey(ValueKey('action:fact_lpp_affiliation.$id')),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        isNot(Tristate.isTrue),
      );
    }
  });
}
