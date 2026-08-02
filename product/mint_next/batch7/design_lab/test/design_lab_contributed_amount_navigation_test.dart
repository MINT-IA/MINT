import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

Future<void> openContributedAmountBuilder(
  WidgetTester tester, {
  int currentYear = 2026,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp(locale: const Locale('fr'), currentYear: currentYear),
  );
  for (final action in [
    'action:today_3a_intent.start',
    'action:orientation.continue',
    'action:fact_tax_year.confirm_current_year',
    'action:fact_tax_year.continue',
    'action:fact_lpp_affiliation.choose_yes',
    'action:fact_contribution.choose_yes',
  ]) {
    final finder = find.byKey(ValueKey(action));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'yes opens one empty provider amount builder with no multi-provider controls',
    (tester) async {
      await openContributedAmountBuilder(tester);

      expect(
        find.byKey(const ValueKey('node:fact_contributed_amount')),
        findsOneWidget,
      );
      for (final key in [
        'field:fact_contributed_amount.provider_name',
        'field:fact_contributed_amount.amount',
        'action:fact_contributed_amount.toggle_all_reviewed',
        'action:fact_contributed_amount.toggle_where_to_find',
        'action:fact_contributed_amount.unknown_amount',
        'action:fact_contributed_amount.continue',
        'action:fact_contributed_amount.correct_previous',
        'action:fact_contributed_amount.open_safe_exit',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.missing_amount'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.add_provider'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.remove_provider'),
        ),
        findsNothing,
      );
      expect(find.textContaining('2026'), findsWidgets);

      final provider = tester.widget<TextFormField>(
        find.byKey(
          const ValueKey('field:fact_contributed_amount.provider_name'),
        ),
      );
      final amount = tester.widget<TextFormField>(
        find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      );
      expect(provider.controller!.text, isEmpty);
      expect(amount.controller!.text, isEmpty);
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets('Continue focuses the first invalid control and stays put', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.tap(continueAction);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider name');

    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.tap(continueAction);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ordinary amount');

    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258.50',
    );
    await tester.tap(continueAction);
    await tester.pump();
    expect(find.textContaining('Confirme'), findsOneWidget);
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('provider field rejects sensitive identifiers without routing', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    final provider = find.byKey(
      const ValueKey('field:fact_contributed_amount.provider_name'),
    );
    await tester.enterText(provider, 'CH93 0076 2011 6238 5295 7');
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.pump();

    expect(find.textContaining('sans numéro de compte'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider name');
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('empty amount opens distinct unknown help and Back restores it', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.unknown_amount'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('node:contribution_unknown_help')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('action:contributed_amount_unknown_help.found_amount'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('action:contributed_amount_unknown_help.back')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
  });

  testWidgets('complete positive amount reaches canton and Back restores it', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7’258,50',
    );
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('node:fact_canton')), findsOneWidget);
    expect(find.textContaining('Aucun résultat fiscal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('7’258,50'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(reviewed);
    expect(checkbox.value, isTrue);
  });
}
