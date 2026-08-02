import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

Future<void> openContributionQuestion(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  TextScaler? textScaler,
  int? currentYear,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp(
      locale: locale,
      textScaler: textScaler,
      currentYear: currentYear,
    ),
  );
  for (final action in [
    'action:today_3a_intent.start',
    'action:orientation.continue',
    'action:fact_tax_year.confirm_current_year',
    'action:fact_tax_year.continue',
    'action:fact_lpp_affiliation.choose_yes',
  ]) {
    final finder = find.byKey(ValueKey(action));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const ValueKey('node:fact_contribution')), findsOneWidget);
}

Tristate selectedState(WidgetTester tester, String action) => tester
    .getSemantics(find.byKey(ValueKey(action)))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

void main() {
  testWidgets('asks the exact beginner contribution question without default', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);

    expect(
      find.text('En 2026, l’un de tes 3a a-t-il reçu un nouveau versement ?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Compte seulement l’argent neuf reçu'),
      findsOneWidget,
    );
    expect(find.textContaining('un transfert, un rendement'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('group:fact_contribution.choices')),
          )
          .label,
      contains('2026'),
    );
    for (final id in ['choose_yes', 'choose_no', 'choose_unknown']) {
      final action = 'action:fact_contribution.$id';
      expect(find.byKey(ValueKey(action)), findsOneWidget);
      expect(selectedState(tester, action), isNot(Tristate.isTrue));
      expect(
        tester.getSize(find.byKey(ValueKey(action))).height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('yes routes to amount boundary and back restores yes', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.textContaining('aucun montant n’est connu'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.back')),
    );
    await tester.pumpAndSettle();
    expect(
      selectedState(tester, 'action:fact_contribution.choose_yes'),
      Tristate.isTrue,
    );
  });

  testWidgets('no routes to canton boundary and back restores no', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_no')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_canton')), findsOneWidget);
    expect(find.textContaining('Aucun résultat fiscal'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();
    expect(
      selectedState(tester, 'action:fact_contribution.choose_no'),
      Tristate.isTrue,
    );
  });

  testWidgets('unknown provides verification help and education-only route', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_unknown')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contribution_unknown_help')),
      findsOneWidget,
    );
    expect(find.textContaining('sans additionner toi-même'), findsOneWidget);
    expect(
      find.textContaining('N’additionne jamais un transfert'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey(
          'action:contribution_unknown_help.continue_education_only',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:education_explanation')),
      findsOneWidget,
    );
    expect(find.textContaining('aucun montant personnel'), findsOneWidget);
    expect(find.textContaining('Tu économiseras'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.back')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contribution_unknown_help')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('action:contribution_unknown_help.back')),
    );
    await tester.pumpAndSettle();
    expect(
      selectedState(tester, 'action:fact_contribution.choose_unknown'),
      Tristate.isTrue,
    );
  });

  testWidgets('edge help stays on the question and classifies every movement', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);
    final disclosure = find.byKey(
      const ValueKey('action:fact_contribution.toggle_edge_help'),
    );
    expect(
      tester
          .getSemantics(disclosure)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(find.textContaining('rendements ou les intérêts'), findsNothing);
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:fact_contribution')),
      findsOneWidget,
    );
    for (final fragment in [
      'transfert entre deux 3a',
      'rachat pour une année passée',
      'remboursement partiel',
      'rendements ou les intérêts',
      'remboursement de frais',
    ]) {
      expect(find.textContaining(fragment), findsWidgets);
    }
  });

  testWidgets(
    'safe exit resume preserves contribution state and leave purges it',
    (tester) async {
      await openContributionQuestion(tester, currentYear: 2026);
      final disclosure = find.byKey(
        const ValueKey('action:fact_contribution.toggle_edge_help'),
      );
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('action:fact_contribution.choose_unknown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('action:contribution_unknown_help.open_safe_exit'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('node:contribution_unknown_help')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('action:contribution_unknown_help.back')),
      );
      await tester.pumpAndSettle();
      expect(
        selectedState(tester, 'action:fact_contribution.choose_unknown'),
        Tristate.isTrue,
      );
      expect(find.textContaining('rendements ou les intérêts'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('action:fact_contribution.open_safe_exit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('overlay-action:safe_exit.leave_without_saving'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('action:dismissed.restart')));
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
    },
  );

  testWidgets('safe exit has exact label, initial focus and focus return', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);
    final trigger = find.byKey(
      const ValueKey('action:fact_contribution.open_safe_exit'),
    );
    expect(tester.getSemantics(trigger).label, 'Quitter ce parcours');

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final heading = tester.widget<Focus>(
      find.byKey(const ValueKey('heading:safe_exit')),
    );
    expect(heading.focusNode?.hasFocus, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    final action = tester.widget<MintDesignLabAction>(trigger);
    expect(action.focusNode?.hasFocus, isTrue);
  });

  testWidgets('year rollover clears year-scoped contribution state', (
    tester,
  ) async {
    await openContributionQuestion(tester, currentYear: 2026);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const MintNextDesignLabApp(locale: Locale('fr'), currentYear: 2027),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:today_3a_intent')), findsOneWidget);
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('all contribution routes remain usable at 320x700 text scale 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openContributionQuestion(
      tester,
      locale: const Locale('de'),
      textScaler: TextScaler.linear(2),
      currentYear: 2026,
    );
    for (final action in [
      'action:fact_contribution.toggle_edge_help',
      'action:fact_contribution.choose_unknown',
      'action:contribution_unknown_help.continue_education_only',
      'action:education_explanation.back',
      'action:contribution_unknown_help.back',
      'action:fact_contribution.choose_no',
      'action:fact_canton.back',
      'action:fact_contribution.choose_yes',
      'action:fact_contributed_amount.back',
    ]) {
      final finder = find.byKey(ValueKey(action));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
