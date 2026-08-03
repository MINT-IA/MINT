import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/l10n/generated/mint_next_localizations.dart';
import 'package:mint_next_design_lab/multi_provider_amount_draft.dart';
import 'package:mint_next_design_lab/multi_provider_amount_editor.dart';

Future<void> openBatch14AmountBuilder(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch14Harness(
      locale: locale,
      currentYear: 2026,
      textScaler: textScaler,
    ),
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

List<String> providerRowIds(WidgetTester tester) => tester
    .widgetList<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.key is ValueKey<String> &&
            ((widget.key! as ValueKey<String>).value).startsWith(
              'group:provider_row:',
            ),
      ),
    )
    .map(
      (widget) => (widget.key! as ValueKey<String>).value.substring(
        'group:provider_row:'.length,
      ),
    )
    .toList();

Future<void> pumpEditor(
  WidgetTester tester,
  MultiProviderAmountDraft draft, {
  Locale locale = const Locale('fr'),
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: MintNextLocalizations.localizationsDelegates,
    supportedLocales: MintNextLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: MultiProviderAmountEditor(
          taxYear: 2026,
          draft: draft,
          onCommitted: (_) {},
          onCorrectPrevious: () {},
          onUnknown: () {},
          restoreAmountFocus: false,
          restoreUnknownActionFocus: false,
          onRestoreFocusConsumed: () {},
        ),
      ),
    ),
  ),
);

void main() {
  const expectedLocalizedSubtotal = {
    'fr': '1\u202f234,56 CHF',
    'en': '1,234.56 CHF',
    'de': '1.234,56 CHF',
    'it': '1.234,56 CHF',
    'es': '1.234,56 CHF',
    'pt': '1.234,56 CHF',
  };
  for (final language in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
    testWidgets('flagged amount editor renders in $language', (tester) async {
      await openBatch14AmountBuilder(tester, locale: Locale(language));

      expect(providerRowIds(tester), hasLength(1));
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.add_provider'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('@@'), findsNothing);
      final row = providerRowIds(tester).single;
      await tester.enterText(
        find.byKey(ValueKey('field:provider_name:$row')),
        'VIAC',
      );
      await tester.enterText(
        find.byKey(ValueKey('field:amount:$row')),
        '1234,56',
      );
      await tester.pump();
      expect(
        find.textContaining(expectedLocalizedSubtotal[language]!),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'two known providers sum exactly, continue, and restore on Back',
    (tester) async {
      await openBatch14AmountBuilder(tester);

      final providerFields = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.key is ValueKey<String> &&
            ((widget.key! as ValueKey<String>).value).startsWith(
              'field:provider_name:',
            ),
      );
      expect(providerFields, findsOneWidget);
      final firstKey =
          tester.widget<TextFormField>(providerFields).key! as ValueKey<String>;
      final first = firstKey.value.substring('field:provider_name:'.length);
      await tester.enterText(
        find.byKey(ValueKey('field:provider_name:$first')),
        'VIAC',
      );
      await tester.enterText(
        find.byKey(ValueKey('field:amount:$first')),
        '4000',
      );
      await tester.pump();

      final add = find.byKey(
        const ValueKey('action:fact_contributed_amount.add_provider'),
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();

      final ids = providerRowIds(tester);
      expect(ids, hasLength(2));
      final second = ids.last;
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'provider name $second',
      );
      await tester.enterText(
        find.byKey(ValueKey('field:provider_name:$second')),
        'finpension',
      );
      await tester.enterText(
        find.byKey(ValueKey('field:amount:$second')),
        '3000,50',
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('value:fact_contributed_amount.running_subtotal'),
        ),
        findsOne,
      );
      expect(find.textContaining('7\u202f000,50'), findsOne);
      expect(find.textContaining('résultat fiscal'), findsWidgets);

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

      expect(find.byKey(const ValueKey('node:fact_canton')), findsOne);
      await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
      await tester.pumpAndSettle();

      expect(find.text('VIAC'), findsOne);
      expect(find.text('finpension'), findsOne);
      expect(find.text('4000'), findsOne);
      expect(find.text('3000,50'), findsOne);
    },
  );

  testWidgets('empty add is refused and focuses the existing empty row', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final id = providerRowIds(tester).single;
    final add = find.byKey(
      const ValueKey('action:fact_contributed_amount.add_provider'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();

    expect(providerRowIds(tester), [id]);
    expect(find.textContaining('ligne vide'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider name $id');
  });

  testWidgets('empty row removal restores focus without reusing its id', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final first = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$first')),
      'VIAC',
    );
    await tester.enterText(find.byKey(ValueKey('field:amount:$first')), '4000');
    final add = find.byKey(
      const ValueKey('action:fact_contributed_amount.add_provider'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final retired = providerRowIds(tester).last;

    final remove = find.byKey(ValueKey('action:remove_empty:$retired'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(providerRowIds(tester), [first]);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'provider name $first',
    );
    expect(
      find.byKey(const ValueKey('status:batch14.row_removed')),
      findsOneWidget,
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(providerRowIds(tester).last, isNot(retired));
    expect(
      find.byKey(const ValueKey('status:batch14.row_removed')),
      findsNothing,
    );
  });

  testWidgets('exact duplicate blocks confirmation and focuses the later row', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final first = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$first')),
      'VIAC',
    );
    await tester.enterText(find.byKey(ValueKey('field:amount:$first')), '4000');
    final add = find.byKey(
      const ValueKey('action:fact_contributed_amount.add_provider'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final second = providerRowIds(tester).last;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$second')),
      ' viac ',
    );
    await tester.enterText(
      find.byKey(ValueKey('field:amount:$second')),
      '3000',
    );
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();

    expect(find.textContaining('double comptage'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'provider name $second',
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets(
    'three rows, keyboard, error and removal remain reachable at 320x700 text 2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openBatch14AmountBuilder(
        tester,
        textScaler: const TextScaler.linear(2),
      );
      final add = find.byKey(
        const ValueKey('action:fact_contributed_amount.add_provider'),
      );
      for (final entry in [('VIAC', '1000'), ('finpension', '2000')]) {
        final row = providerRowIds(tester).last;
        await tester.enterText(
          find.byKey(ValueKey('field:provider_name:$row')),
          entry.$1,
        );
        await tester.enterText(
          find.byKey(ValueKey('field:amount:$row')),
          entry.$2,
        );
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
      }
      final rows = providerRowIds(tester);
      expect(rows, hasLength(3));
      final thirdProvider = find.byKey(
        ValueKey('field:provider_name:${rows.last}'),
      );
      final continueAction = find.byKey(
        const ValueKey('action:fact_contributed_amount.continue'),
      );
      await tester.ensureVisible(continueAction);
      await tester.tap(continueAction);
      await tester.pump();
      await tester.showKeyboard(thirdProvider);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'provider name ${rows.last}',
      );
      expect(find.text('Indique le nom du prestataire.'), findsOneWidget);
      final remove = find.byKey(ValueKey('action:remove_empty:${rows.last}'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(providerRowIds(tester), hasLength(2));
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'provider name ${rows[1]}',
      );
      for (final control in [
        find.byKey(const ValueKey('content:batch14.classification_guide')),
        find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
        find.byKey(
          const ValueKey('action:fact_contributed_amount.open_safe_exit'),
        ),
      ]) {
        expect(control, findsOneWidget);
        await tester.ensureVisible(control);
        await tester.pump();
        final rect = tester.getRect(control);
        expect(rect.bottom, greaterThan(0));
        expect(rect.top, lessThan(700));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('classification and local-only privacy appear before inputs', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);

    expect(
      find.byKey(const ValueKey('content:batch14.classification_guide')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('content:batch14.privacy')),
      findsOneWidget,
    );
    expect(find.textContaining('transferts'), findsOneWidget);
    expect(find.textContaining('total annuel'), findsOneWidget);
    expect(find.textContaining('plusieurs contrats'), findsOneWidget);
    expect(find.textContaining('rien n’est enregistré ni envoyé'), findsOne);
  });

  testWidgets('unknown help returns focus to the exact unknown action', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final unknown = find.byKey(
      const ValueKey('action:fact_contributed_amount.unknown_amount'),
    );
    await tester.ensureVisible(unknown);
    await tester.tap(unknown);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('action:contributed_amount_unknown_help.back')),
    );
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'unknown amount trigger',
    );
  });

  testWidgets('aggregate overflow has its own error and recovery focus', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final first = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$first')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(ValueKey('field:amount:$first')),
      '999999999999,99',
    );
    final add = find.byKey(
      const ValueKey('action:fact_contributed_amount.add_provider'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final second = providerRowIds(tester).last;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$second')),
      'finpension',
    );
    await tester.enterText(
      find.byKey(ValueKey('field:amount:$second')),
      '0,01',
    );
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('error:batch14.aggregate_overflow')),
      findsOneWidget,
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'aggregate overflow',
    );
  });

  testWidgets('provider capacity is distinct from an unfinished empty row', (
    tester,
  ) async {
    final draft = MultiProviderAmountDraft();
    for (var index = 0; index < 50; index++) {
      final row = draft.rows.last.id;
      draft.updateProviderName(row, 'Provider $index');
      draft.updateAmount(row, '${index + 1}', locale: 'fr');
      if (index < 49) {
        expect(draft.addProvider(), MultiProviderAddResult.added);
      }
    }
    await pumpEditor(tester, draft);
    final add = find.byKey(
      const ValueKey('action:fact_contributed_amount.add_provider'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('error:batch14.provider_capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('error:batch14.empty_before_add')),
      findsNothing,
    );
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'add provider');
  });

  testWidgets('fullwidth duplicate is blocked and focuses the later row', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final first = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$first')),
      'VIAC',
    );
    await tester.enterText(find.byKey(ValueKey('field:amount:$first')), '4000');
    final add = find.byKey(
      const ValueKey('action:fact_contributed_amount.add_provider'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final second = providerRowIds(tester).last;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$second')),
      'ＶＩＡＣ',
    );
    await tester.enterText(
      find.byKey(ValueKey('field:amount:$second')),
      '3000',
    );
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();

    expect(find.textContaining('double comptage'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'provider name $second',
    );
  });

  testWidgets('correcting the previous answer invalidates review and commit', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final row = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$row')),
      'VIAC',
    );
    await tester.enterText(find.byKey(ValueKey('field:amount:$row')), '7258');
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
    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();

    final correct = find.byKey(
      const ValueKey('action:fact_contributed_amount.correct_previous'),
    );
    await tester.ensureVisible(correct);
    await tester.tap(correct);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(
              const ValueKey(
                'action:fact_contributed_amount.toggle_all_reviewed',
              ),
            ),
          )
          .value,
      isFalse,
    );
    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('7258'), findsOneWidget);
  });

  testWidgets('a known subtotal never routes to obsolete partial help', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final row = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$row')),
      'VIAC',
    );
    await tester.enterText(find.byKey(ValueKey('field:amount:$row')), '1000');
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.unknown_amount'),
      ),
      findsNothing,
    );
  });
}
