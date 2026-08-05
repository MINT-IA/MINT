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
  const expectedLocalizedUndo = {
    'fr': 'Annuler le retrait de la ligne 1',
    'en': 'Undo removal of row 1',
    'de': 'Entfernen von Zeile 1 rückgängig machen',
    'it': 'Annulla la rimozione della riga 1',
    'es': 'Deshacer la retirada de la fila 1',
    'pt': 'Anular a remoção da linha 1',
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

    testWidgets('tombstone actions are explicit in $language', (tester) async {
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single;
      draft.updateProviderName(first.editToken, 'VIAC');
      draft.updateAmount(first.editToken, '1000', locale: language);
      draft.addProvider();
      final second = draft.rows.last;
      draft.updateProviderName(second.editToken, 'finpension');
      draft.updateAmount(second.editToken, '2000', locale: language);
      draft.removeProvider(first.removeToken!);
      await pumpEditor(tester, draft, locale: Locale(language));

      expect(find.text(expectedLocalizedUndo[language]!), findsOneWidget);
      expect(find.textContaining('@@'), findsNothing);
      expect(
        find.byKey(ValueKey('action:finalize_removal:${first.id}')),
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

      expect(find.byKey(const ValueKey('node:fact_lieu')), findsOne);
      await tester.binding.handlePopRoute();
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
    expect(find.byKey(const ValueKey('node:fact_lieu')), findsNothing);
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
      final row = draft.rows.last;
      draft.updateProviderName(row.editToken, 'Provider $index');
      draft.updateAmount(row.editToken, '${index + 1}', locale: 'fr');
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
    await tester.binding.handlePopRoute();
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

  testWidgets('contentful removal is private, inline and exactly undoable', (
    tester,
  ) async {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'PRIVATE PROVIDER');
    draft.updateAmount(first.editToken, '4000', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '3000', locale: 'fr');
    await pumpEditor(tester, draft);

    final remove = find.byKey(ValueKey('action:remove_provider:${first.id}'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();

    expect(
      find.byKey(ValueKey('group:provider_tombstone:${first.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('field:provider_name:${first.id}')),
      findsNothing,
    );
    expect(find.text('PRIVATE PROVIDER'), findsNothing);
    expect(find.textContaining('3\u202f000,00 CHF'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('status:batch14.row_removed')),
          )
          .properties
          .label,
      contains('3\u202f000,00 CHF'),
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'provider name ${second.id}',
    );

    final undo = find.byKey(ValueKey('action:undo_removal:${first.id}'));
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pump();
    expect(
      find.byKey(ValueKey('field:provider_name:${first.id}')),
      findsOneWidget,
    );
    expect(find.text('PRIVATE PROVIDER'), findsOneWidget);
    expect(find.textContaining('7\u202f000,00 CHF'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('status:batch14.row_removed')),
          )
          .properties
          .label,
      contains('7\u202f000,00 CHF'),
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'restored provider heading ${first.id}',
    );
  });

  testWidgets(
    'tombstone blocks continue and finalize frees the rendered slot',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single;
      draft.updateProviderName(first.editToken, 'VIAC');
      draft.updateAmount(first.editToken, '4000', locale: 'fr');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final second = draft.rows.last;
      draft.updateProviderName(second.editToken, 'finpension');
      draft.updateAmount(second.editToken, '3000', locale: 'fr');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final third = draft.rows.last;
      draft.updateProviderName(third.editToken, 'frankly');
      draft.updateAmount(third.editToken, '2000', locale: 'fr');
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates:
                MintNextLocalizations.localizationsDelegates,
            supportedLocales: MintNextLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                key: const ValueKey('scroll:batch15_compact'),
                child: MultiProviderAmountEditor(
                  taxYear: 2026,
                  draft: draft,
                  onCommitted: (_) => fail('must remain blocked'),
                  onCorrectPrevious: () {},
                  onUnknown: () {},
                  restoreAmountFocus: false,
                  restoreUnknownActionFocus: false,
                  onRestoreFocusConsumed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final remove = find.byKey(ValueKey('action:remove_provider:${first.id}'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pump();
      final undo = find.byKey(ValueKey('action:undo_removal:${first.id}'));
      final finalize = find.byKey(
        ValueKey('action:finalize_removal:${first.id}'),
      );
      expect(tester.getSize(undo).height, 48);
      expect(tester.getSize(finalize).height, 48);
      await tester.ensureVisible(undo);
      await tester.pumpAndSettle();
      expect(tester.getRect(undo).bottom, lessThanOrEqualTo(420));
      expect(undo.hitTestable(), findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      await tester.showKeyboard(
        find.byKey(ValueKey('field:amount:${first.id}')),
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'amount ${first.id}',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      final removeAgain = find.byKey(
        ValueKey('action:remove_provider:${first.id}'),
      );
      await tester.ensureVisible(removeAgain);
      await tester.tap(removeAgain);
      await tester.pump();
      final continueAction = find.byKey(
        const ValueKey('action:fact_contributed_amount.continue'),
      );
      final compactScrollable = find
          .descendant(
            of: find.byKey(const ValueKey('scroll:batch15_compact')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        continueAction,
        300,
        scrollable: compactScrollable,
      );
      expect(tester.getRect(continueAction).bottom, lessThanOrEqualTo(420));
      expect(continueAction.hitTestable(), findsOneWidget);
      await tester.tap(continueAction);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'undo removal ${first.id}',
      );

      final finalizeAgain = find.byKey(
        ValueKey('action:finalize_removal:${first.id}'),
      );
      await tester.ensureVisible(finalizeAgain);
      await tester.pumpAndSettle();
      expect(tester.getRect(finalizeAgain).bottom, lessThanOrEqualTo(420));
      expect(finalizeAgain.hitTestable(), findsOneWidget);
      await tester.tap(finalizeAgain);
      await tester.pump();
      expect(
        find.byKey(ValueKey('group:provider_tombstone:${first.id}')),
        findsNothing,
      );
      expect(draft.rows, hasLength(2));
      expect(draft.rows.map((row) => row.id), [second.id, third.id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale remove callback cannot remove a restored generation', (
    tester,
  ) async {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '1000', locale: 'fr');
    draft.addProvider();
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '2000', locale: 'fr');
    await pumpEditor(tester, draft);

    final removeFinder = find.byKey(
      ValueKey('action:remove_provider:${first.id}'),
    );
    final staleCallback = tester.widget<TextButton>(removeFinder).onPressed!;
    final staleEdit = tester
        .widget<TextFormField>(
          find.byKey(ValueKey('field:provider_name:${first.id}')),
        )
        .onChanged!;
    staleCallback();
    await tester.pump();
    final undo = find.byKey(ValueKey('action:undo_removal:${first.id}'));
    final staleUndo = tester.widget<OutlinedButton>(undo).onPressed!;
    final staleFinalize = tester
        .widget<TextButton>(
          find.byKey(ValueKey('action:finalize_removal:${first.id}')),
        )
        .onPressed!;
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pump();
    expect(first.lifecycle, MultiProviderRowLifecycle.active);

    staleCallback();
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pump();
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    expect(tester.widget<CheckboxListTile>(reviewed).subtitle, isNotNull);
    // The old edit closure must not clear errors or status when its token is stale.
    staleEdit('MUTATED');
    staleUndo();
    staleFinalize();
    await tester.pump();
    expect(first.lifecycle, MultiProviderRowLifecycle.active);
    expect(first.providerName, 'VIAC');
    expect(tester.widget<CheckboxListTile>(reviewed).subtitle, isNotNull);
    expect(
      find.byKey(ValueKey('field:provider_name:${first.id}')),
      findsOneWidget,
    );
  });

  testWidgets('empty removal skips a neighbouring tombstone for focus', (
    tester,
  ) async {
    final draft = MultiProviderAmountDraft();
    for (var index = 0; index < 3; index++) {
      final row = draft.rows.last;
      if (index < 2) {
        draft.updateProviderName(row.editToken, 'Provider $index');
        draft.updateAmount(row.editToken, '${index + 1}000', locale: 'fr');
      }
      if (index < 2) draft.addProvider();
    }
    final first = draft.rows[0];
    final second = draft.rows[1];
    final empty = draft.rows[2];
    draft.removeProvider(second.removeToken!);
    await pumpEditor(tester, draft);

    final removeEmpty = find.byKey(ValueKey('action:remove_empty:${empty.id}'));
    await tester.ensureVisible(removeEmpty);
    await tester.tap(removeEmpty);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'provider name ${first.id}',
    );
  });

  testWidgets(
    'finalize skips preceding tombstones and focuses next rendered active row',
    (tester) async {
      final draft = MultiProviderAmountDraft();
      for (var index = 0; index < 5; index++) {
        final row = draft.rows.last;
        draft.updateProviderName(row.editToken, 'Provider $index');
        draft.updateAmount(row.editToken, '${index + 1}000', locale: 'fr');
        if (index < 4) draft.addProvider();
      }
      final second = draft.rows[1];
      final third = draft.rows[2];
      final fourth = draft.rows[3];
      draft.removeProvider(second.removeToken!);
      draft.removeProvider(third.removeToken!);
      await pumpEditor(tester, draft);

      final finalizeThird = find.byKey(
        ValueKey('action:finalize_removal:${third.id}'),
      );
      await tester.ensureVisible(finalizeThird);
      await tester.tap(finalizeThird);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'provider name ${fourth.id}',
      );
    },
  );

  testWidgets('two tombstones have distinct actions and remain independent', (
    tester,
  ) async {
    final draft = MultiProviderAmountDraft();
    for (var index = 0; index < 3; index++) {
      final row = draft.rows.last;
      draft.updateProviderName(row.editToken, 'Provider $index');
      draft.updateAmount(row.editToken, '${index + 1}000', locale: 'fr');
      if (index < 2) expect(draft.addProvider(), MultiProviderAddResult.added);
    }
    final first = draft.rows[0];
    final second = draft.rows[1];
    final third = draft.rows[2];
    await pumpEditor(tester, draft);
    for (final row in [first, second]) {
      final remove = find.byKey(ValueKey('action:remove_provider:${row.id}'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pump();
    }

    expect(find.text('Annuler le retrait de la ligne 1'), findsOneWidget);
    expect(find.text('Annuler le retrait de la ligne 2'), findsOneWidget);
    expect(
      find.text('Effacer définitivement la ligne 1 de cette saisie'),
      findsOneWidget,
    );
    expect(
      find.text('Effacer définitivement la ligne 2 de cette saisie'),
      findsOneWidget,
    );
    expect(draft.provisionalSubtotalMinorUnits, 300000);

    final undoFirst = find.byKey(ValueKey('action:undo_removal:${first.id}'));
    await tester.ensureVisible(undoFirst);
    await tester.tap(undoFirst);
    await tester.pump();
    final finalizeSecond = find.byKey(
      ValueKey('action:finalize_removal:${second.id}'),
    );
    await tester.ensureVisible(finalizeSecond);
    await tester.tap(finalizeSecond);
    await tester.pump();
    expect(first.lifecycle, MultiProviderRowLifecycle.active);
    expect(draft.rows.map((row) => row.id), [first.id, third.id]);
    expect(draft.provisionalSubtotalMinorUnits, 400000);
  });

  testWidgets('active field errors precede the first tombstone error', (
    tester,
  ) async {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '1000', locale: 'fr');
    draft.addProvider();
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '2000', locale: 'fr');
    draft.addProvider();
    final third = draft.rows.last;
    draft.removeProvider(first.removeToken!);
    await pumpEditor(tester, draft);
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'provider name ${third.id}',
    );
    expect(find.byKey(ValueKey('error:tombstone:${first.id}')), findsNothing);

    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:${third.id}')),
      'frankly',
    );
    await tester.enterText(
      find.byKey(ValueKey('field:amount:${third.id}')),
      '3000',
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'undo removal ${first.id}',
    );
    expect(find.byKey(ValueKey('error:tombstone:${first.id}')), findsOneWidget);
  });

  testWidgets('tombstone survives safe-exit resume and reversible correction', (
    tester,
  ) async {
    await openBatch14AmountBuilder(tester);
    final first = providerRowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$first')),
      'VIAC',
    );
    await tester.enterText(find.byKey(ValueKey('field:amount:$first')), '1000');
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
      '2000',
    );
    final remove = find.byKey(ValueKey('action:remove_provider:$first'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();

    final safeExit = find.byKey(
      const ValueKey('action:fact_contributed_amount.open_safe_exit'),
    );
    await tester.ensureVisible(safeExit);
    await tester.tap(safeExit);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('group:provider_tombstone:$first')),
      findsOneWidget,
    );

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
      find.byKey(ValueKey('group:provider_tombstone:$first')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('field:provider_name:$second')), findsOneWidget);
  });

  testWidgets(
    'tombstone survives help Back and terminal leave removes its UI',
    (tester) async {
      await openBatch14AmountBuilder(tester);
      final first = providerRowIds(tester).single;
      await tester.enterText(
        find.byKey(ValueKey('field:provider_name:$first')),
        'VIAC',
      );
      await tester.enterText(
        find.byKey(ValueKey('field:amount:$first')),
        '1000',
      );
      final add = find.byKey(
        const ValueKey('action:fact_contributed_amount.add_provider'),
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final remove = find.byKey(ValueKey('action:remove_provider:$first'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pump();
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
        find.byKey(
          const ValueKey('action:contributed_amount_unknown_help.back'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('group:provider_tombstone:$first')),
        findsOneWidget,
      );

      final safeExit = find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      );
      await tester.ensureVisible(safeExit);
      await tester.tap(safeExit);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('overlay-action:safe_exit.leave_without_saving'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('group:provider_tombstone:$first')),
        findsNothing,
      );
      expect(find.text('VIAC'), findsNothing);
    },
  );
}
