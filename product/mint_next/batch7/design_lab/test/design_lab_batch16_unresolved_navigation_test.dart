import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';
import 'package:mint_next_design_lab/l10n/generated/mint_next_localizations.dart';

import 'batch16_semantic_fixture.g.dart';

final batch16OutboundEvents = <String>[];
const batch16AmountBuilderEntryActions = [
  'action:today_3a_intent.start',
  'action:orientation.continue',
  'action:fact_tax_year.confirm_current_year',
  'action:fact_tax_year.continue',
  'action:fact_lpp_affiliation.choose_yes',
  'action:fact_contribution.choose_yes',
];

void recordBatch16Outbound(String channel, Object? payload) {
  batch16OutboundEvents.add('$channel:$payload');
}

Future<void> openBatch16AmountBuilder(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  TextScaler? textScaler,
  DateTime Function()? now,
  ValueChanged<Object?>? onPersistenceWrite,
  ValueChanged<Object?>? onNetworkRequest,
  ValueChanged<Object?>? onAnalyticsEvent,
  ValueChanged<Object?>? onCrashBreadcrumb,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp.batch16Harness(
      locale: locale,
      currentYear: 2026,
      textScaler: textScaler,
      now: now,
      onPersistenceWrite:
          onPersistenceWrite ??
          (value) => recordBatch16Outbound('persistence', value),
      onNetworkRequest:
          onNetworkRequest ??
          (value) => recordBatch16Outbound('network', value),
      onAnalyticsEvent:
          onAnalyticsEvent ??
          (value) => recordBatch16Outbound('analytics', value),
      onCrashBreadcrumb:
          onCrashBreadcrumb ??
          (value) => recordBatch16Outbound('breadcrumb', value),
    ),
  );
  for (final action in batch16AmountBuilderEntryActions) {
    final finder = find.byKey(ValueKey(action));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

Future<void> restartBatch16AmountBuilder(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('action:dismissed.restart')));
  await tester.pumpAndSettle();
  for (final action in batch16AmountBuilderEntryActions) {
    final finder = find.byKey(ValueKey(action));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

List<String> batch16RowIds(WidgetTester tester) => tester
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

Future<List<String>> enterTwoProviders(WidgetTester tester) async {
  var rows = batch16RowIds(tester);
  final first = rows.single;
  await tester.enterText(
    find.byKey(ValueKey('field:provider_name:$first')),
    'Prestataire A',
  );
  await tester.enterText(find.byKey(ValueKey('field:amount:$first')), '1000');
  await tester.tap(
    find.byKey(const ValueKey('action:fact_contributed_amount.add_provider')),
  );
  await tester.pumpAndSettle();
  rows = batch16RowIds(tester);
  final second = rows.last;
  await tester.enterText(
    find.byKey(ValueKey('field:provider_name:$second')),
    'Prestataire B',
  );
  await tester.enterText(find.byKey(ValueKey('field:amount:$second')), '2000');
  await tester.pump();
  return rows;
}

Future<List<String>> enterThreeProviders(WidgetTester tester) async {
  await enterTwoProviders(tester);
  await tester.tap(
    find.byKey(const ValueKey('action:fact_contributed_amount.add_provider')),
  );
  await tester.pumpAndSettle();
  final rows = batch16RowIds(tester);
  expect(rows, hasLength(3));
  await tester.enterText(
    find.byKey(ValueKey('field:provider_name:${rows.last}')),
    'Prestataire C',
  );
  await tester.enterText(
    find.byKey(ValueKey('field:amount:${rows.last}')),
    '3000',
  );
  await tester.pump();
  return rows;
}

void expectSingleEmptyDraft(WidgetTester tester) {
  final rows = batch16RowIds(tester);
  expect(rows, hasLength(1));
  expect(
    tester
        .widget<TextFormField>(
          find.byKey(ValueKey('field:provider_name:${rows.single}')),
        )
        .controller!
        .text,
    isEmpty,
  );
  expect(
    tester
        .widget<TextFormField>(
          find.byKey(ValueKey('field:amount:${rows.single}')),
        )
        .controller!
        .text,
    isEmpty,
  );
}

Future<void> openUnresolvedHelp(WidgetTester tester, String rowId) async {
  final action = find.byKey(ValueKey('action:amount_doubt:$rowId'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('node:unresolved_amount_help')),
    findsOneWidget,
  );
}

void expectExactFocus(String label) {
  expect(FocusManager.instance.primaryFocus?.debugLabel, label);
}

void main() {
  setUp(batch16OutboundEvents.clear);
  tearDown(() => expect(batch16OutboundEvents, isEmpty));
  testWidgets('exact_row_doubt_help_back_and_system_back', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;

    await openUnresolvedHelp(tester, origin);
    expectExactFocus('unresolved help heading');
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unresolved:$origin')), findsOne);
    expectExactFocus('amount doubt $origin');

    await openUnresolvedHelp(tester, origin);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unresolved:$origin')), findsOne);
    expectExactFocus('amount doubt $origin');
  });

  testWidgets('three_rows_exact_origin_never_falls_back_to_first', (
    tester,
  ) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterThreeProviders(tester);
    final origin = rows[1];
    await openUnresolvedHelp(tester, origin);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.provider_total')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unreviewed:$origin')), findsOne);
    expect(
      find.byKey(ValueKey('status:amount_unreviewed:${rows.first}')),
      findsOne,
    );
    expect(
      find.byKey(ValueKey('status:amount_unreviewed:${rows.last}')),
      findsOne,
    );
    expectExactFocus('amount $origin');
    expect([
      for (final row in rows)
        tester
            .widget<TextFormField>(find.byKey(ValueKey('field:amount:$row')))
            .controller!
            .text,
    ], equals(['1000', '2000', '3000']));
  });

  testWidgets('unresolved_blocks_review_commit_continue_and_canton', (
    tester,
  ) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();

    expect(find.textContaining('3\u202f000'), findsWidgets);
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.pump();
    expect(find.byKey(ValueKey('error:amount_unresolved:$origin')), findsOne);
    final errorSemantics = tester
        .getSemantics(find.byKey(ValueKey('error:amount_unresolved:$origin')))
        .getSemanticsData();
    expect(errorSemantics.flagsCollection.isLiveRegion, isTrue);
    final doubtSemantics = tester
        .getSemantics(find.byKey(ValueKey('action:amount_doubt:$origin')))
        .getSemanticsData();
    expect(doubtSemantics.hint, contains(errorSemantics.label));
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
    expectExactFocus('amount doubt $origin');
  });

  testWidgets('all_confirmed_reversible_edits_and_safe_exit', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
      ),
    );
    await tester.pumpAndSettle();
    for (final row in rows) {
      expect(
        find.byKey(ValueKey('status:amount_confirmed_ordinary:$row')),
        findsOne,
      );
    }

    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    for (final row in rows) {
      expect(
        find.byKey(ValueKey('status:amount_confirmed_ordinary:$row')),
        findsOne,
      );
    }
    expectExactFocus('all confirmed editor safe exit');

    await tester.enterText(
      find.byKey(ValueKey('field:amount:${rows.last}')),
      '2100',
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey('status:amount_confirmed_ordinary:${rows.first}')),
      findsOne,
    );
    expect(
      find.byKey(ValueKey('status:amount_unreviewed:${rows.last}')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('all_confirmed_safe_exit_system_back_leave_and_canton_back', (
    tester,
  ) async {
    Future<List<String>> enterConfirmed() async {
      await openBatch16AmountBuilder(tester);
      final rows = await enterThreeProviders(tester);
      await tester.tap(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
        ),
      );
      await tester.pumpAndSettle();
      return rows;
    }

    var rows = await enterConfirmed();
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    for (final row in rows) {
      expect(
        find.byKey(ValueKey('status:amount_confirmed_ordinary:$row')),
        findsOne,
      );
    }
    expectExactFocus('all confirmed editor safe exit');

    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_canton')), findsOne);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(batch16RowIds(tester), equals(rows));
    for (final row in rows) {
      expect(
        find.byKey(ValueKey('status:amount_confirmed_ordinary:$row')),
        findsOne,
      );
    }
    expectExactFocus('all confirmed editor continue');

    rows = await enterConfirmed();
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOne);
    await restartBatch16AmountBuilder(tester);
    expectSingleEmptyDraft(tester);
  });

  testWidgets('mixed_editor_safe_exit_resume_system_back_and_leave', (
    tester,
  ) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterThreeProviders(tester);
    await openUnresolvedHelp(tester, rows[1]);
    final staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('status:amount_unresolved:${rows[1]}')),
      findsOne,
    );
    expectExactFocus('mixed editor safe exit');

    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('status:amount_unresolved:${rows[1]}')),
      findsOne,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOne);
    await restartBatch16AmountBuilder(tester);
    staleProviderTotal();
    await tester.pumpAndSettle();
    expectSingleEmptyDraft(tester);
  });

  testWidgets('all_confirmed_full_reversible_matrix', (tester) async {
    Future<List<String>> enterConfirmed() async {
      await openBatch16AmountBuilder(tester);
      final rows = await enterTwoProviders(tester);
      await tester.tap(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
        ),
      );
      await tester.pumpAndSettle();
      return rows;
    }

    var rows = await enterConfirmed();
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:${rows.last}')),
      'Prestataire B corrigé',
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey('status:amount_unreviewed:${rows.last}')),
      findsOne,
    );

    rows = await enterConfirmed();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.add_provider')),
    );
    await tester.pumpAndSettle();
    final added = batch16RowIds(tester).last;
    expect(find.byKey(ValueKey('status:amount_unreviewed:$added')), findsOne);

    rows = await enterConfirmed();
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
      ),
    );
    await tester.pump();
    for (final row in rows) {
      expect(find.byKey(ValueKey('status:amount_unreviewed:$row')), findsOne);
    }

    rows = await enterConfirmed();
    await tester.tap(
      find.byKey(ValueKey('action:remove_provider:${rows.last}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('group:provider_tombstone:${rows.last}')),
      findsOne,
    );
    expect(
      find.byKey(ValueKey('status:amount_confirmed_ordinary:${rows.first}')),
      findsOne,
    );

    rows = await enterConfirmed();
    await openUnresolvedHelp(tester, rows.last);
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('status:amount_unresolved:${rows.last}')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);

    rows = await enterConfirmed();
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.correct_previous'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_contribution')), findsOne);
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();
    for (final row in rows) {
      expect(find.byKey(ValueKey('status:amount_unreviewed:$row')), findsOne);
    }
  });

  testWidgets('provider_total_exact_return_and_sibling_consumption', (
    tester,
  ) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    final staleRefund = tester
        .widget<MintDesignLabAction>(
          find.byKey(
            const ValueKey('action:unresolved_help.provider_refunded'),
          ),
        )
        .onPressed!;
    final staleAllZero = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.all_zero')),
        )
        .onPressed!;
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.provider_total')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('status:amount_unresolved:$origin')),
      findsNothing,
    );
    expect(find.byKey(ValueKey('status:amount_unreviewed:$origin')), findsOne);
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
    expect(
      tester
          .widget<TextFormField>(find.byKey(ValueKey('field:amount:$origin')))
          .controller!
          .text,
      '2000',
    );
    expectExactFocus('amount $origin');
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
    staleRefund();
    staleAllZero();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('field:amount:$origin')), findsOne);
    expect(
      find.byKey(ValueKey('group:provider_tombstone:$origin')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('eligible_refund_exact_tombstone_and_replay', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    final refund = find.byKey(
      const ValueKey('action:unresolved_help.provider_refunded'),
    );
    final staleRefund = tester.widget<MintDesignLabAction>(refund).onPressed!;
    await tester.tap(refund);
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('group:provider_tombstone:$origin')), findsOne);
    expect(find.byKey(ValueKey('field:amount:${rows.first}')), findsOne);
    expect(batch16RowIds(tester), equals([rows.first]));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(ValueKey('field:amount:${rows.first}')),
          )
          .controller!
          .text,
      '1000',
    );
    expect(
      find.byKey(ValueKey('status:amount_unreviewed:${rows.first}')),
      findsOne,
    );
    expect(find.textContaining('1\u202f000'), findsWidgets);
    final subtotalSemantics = tester
        .getSemantics(
          find.byKey(
            const ValueKey('value:fact_contributed_amount.running_subtotal'),
          ),
        )
        .getSemanticsData();
    expect(subtotalSemantics.flagsCollection.isLiveRegion, isTrue);
    expect(subtotalSemantics.label, contains('1\u202f000'));
    expectExactFocus('undo removal $origin');
    expect(find.byKey(ValueKey('action:undo_removal:$origin')), findsOne);
    staleRefund();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('group:provider_tombstone:$origin')), findsOne);
    await tester.tap(find.byKey(ValueKey('action:undo_removal:$origin')));
    await tester.pumpAndSettle();
    expect(batch16RowIds(tester), equals(rows));
    expect(find.byKey(ValueKey('status:amount_unresolved:$origin')), findsOne);
    staleRefund();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('field:provider_name:$origin')), findsOne);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(ValueKey('field:provider_name:${rows.first}')),
          )
          .controller!
          .text,
      'Prestataire A',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(ValueKey('field:amount:${rows.first}')),
          )
          .controller!
          .text,
      '1000',
    );
    expect(
      find.byKey(ValueKey('status:amount_unreviewed:${rows.first}')),
      findsOne,
    );
  });

  testWidgets('ineligible_refund_hidden_without_consumption', (tester) async {
    await openBatch16AmountBuilder(tester);
    final origin = batch16RowIds(tester).single;
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$origin')),
      'Prestataire A',
    );
    await tester.enterText(
      find.byKey(ValueKey('field:amount:$origin')),
      '1000',
    );
    await openUnresolvedHelp(tester, origin);
    expect(
      find.byKey(const ValueKey('action:unresolved_help.provider_refunded')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('action:unresolved_help.provider_total')),
      findsOne,
    );
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.provider_total')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('field:amount:$origin')), findsOne);
  });

  testWidgets('all_zero_explicit_entry_back_and_system_back', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.all_zero')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contribution_status_correction')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('status:contribution_current_yes')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('status:contribution_correction_unselected')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expectExactFocus('unresolved all zero action');
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.all_zero')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:contribution_correction.back')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expectExactFocus('unresolved all zero action');
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(ValueKey('field:amount:$origin')))
          .controller!
          .text,
      '2000',
    );
    expect(find.byKey(ValueKey('status:amount_unresolved:$origin')), findsOne);
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
  });

  testWidgets('all_zero_yes_preserves_origin_no_unknown_purge', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.all_zero')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:contribution_correction.choose_yes')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unresolved:$origin')), findsOne);
    expectExactFocus('amount doubt $origin');

    await openUnresolvedHelp(tester, origin);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.all_zero')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('action:contribution_correction.choose_unknown'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('node:contribution_unknown_help')),
      findsOne,
    );

    await openBatch16AmountBuilder(tester);
    final noRows = await enterTwoProviders(tester);
    await openUnresolvedHelp(tester, noRows.last);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.all_zero')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:contribution_correction.choose_no')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_canton')), findsOne);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.key is ValueKey<String> &&
            ((widget.key! as ValueKey<String>).value).startsWith(
              'field:amount:',
            ),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  testWidgets('correction_safe_exit_exact_restore_and_leave', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    final staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.all_zero')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('action:contribution_status_correction.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contribution_status_correction')),
      findsOne,
    );
    expectExactFocus('correction safe exit trigger');

    await tester.tap(
      find.byKey(
        const ValueKey('action:contribution_status_correction.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contribution_status_correction')),
      findsOne,
    );
    expectExactFocus('correction safe exit trigger');

    await tester.tap(
      find.byKey(
        const ValueKey('action:contribution_status_correction.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOne);
  });

  testWidgets('education_back_safe_exit_and_terminal_purge', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.education')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:education_explanation')), findsOne);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expectExactFocus('unresolved education action');

    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.education')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.back')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expectExactFocus('unresolved education action');

    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.education')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.open_safe_exit')),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:education_explanation')), findsOne);
    expectExactFocus('education safe exit trigger');

    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.open_safe_exit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:education_explanation')), findsOne);
    expectExactFocus('education safe exit trigger');
    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.open_safe_exit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOne);
  });

  testWidgets('help_safe_exit_resume_back_leave_and_stale_callbacks', (
    tester,
  ) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    final staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(
      find.byKey(
        const ValueKey('action:unresolved_amount_help.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expectExactFocus('unresolved safe exit trigger');

    await tester.tap(
      find.byKey(
        const ValueKey('action:unresolved_amount_help.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expectExactFocus('unresolved safe exit trigger');

    await tester.tap(
      find.byKey(
        const ValueKey('action:unresolved_amount_help.open_safe_exit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOne);
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:dismissed')), findsOne);
  });

  testWidgets('terminal_choices_and_leaves_purge_data_and_callbacks', (
    tester,
  ) async {
    Future<VoidCallback> enterCorrectionAndCapture() async {
      await openBatch16AmountBuilder(tester);
      final rows = await enterTwoProviders(tester);
      await openUnresolvedHelp(tester, rows.last);
      final callback = tester
          .widget<MintDesignLabAction>(
            find.byKey(const ValueKey('action:unresolved_help.provider_total')),
          )
          .onPressed!;
      await tester.tap(
        find.byKey(const ValueKey('action:unresolved_help.all_zero')),
      );
      await tester.pumpAndSettle();
      return callback;
    }

    var terminalCallback = await enterCorrectionAndCapture();
    await tester.tap(
      find.byKey(const ValueKey('action:contribution_correction.choose_no')),
    );
    await tester.pumpAndSettle();
    terminalCallback();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();
    expectSingleEmptyDraft(tester);

    terminalCallback = await enterCorrectionAndCapture();
    await tester.tap(
      find.byKey(
        const ValueKey('action:contribution_correction.choose_unknown'),
      ),
    );
    await tester.pumpAndSettle();
    terminalCallback();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:contribution_unknown_help.back')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();
    expectSingleEmptyDraft(tester);

    await openBatch16AmountBuilder(tester);
    final rows = await enterThreeProviders(tester);
    await openUnresolvedHelp(tester, rows.last);
    terminalCallback = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.education')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.open_safe_exit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    terminalCallback();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:dismissed.restart')));
    await tester.pumpAndSettle();
    for (final action in [
      'action:today_3a_intent.start',
      'action:orientation.continue',
      'action:fact_tax_year.confirm_current_year',
      'action:fact_tax_year.continue',
      'action:fact_lpp_affiliation.choose_yes',
      'action:fact_contribution.choose_yes',
    ]) {
      await tester.tap(find.byKey(ValueKey(action)));
      await tester.pumpAndSettle();
    }
    expectSingleEmptyDraft(tester);
  });

  testWidgets('year_ttl_and_app_lifecycle_purge_callbacks', (tester) async {
    var now = DateTime(2026, 8, 3, 12);
    await openBatch16AmountBuilder(tester, now: () => now);
    var rows = await enterTwoProviders(tester);
    await openUnresolvedHelp(tester, rows.last);
    var staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.pumpWidget(
      MintNextDesignLabApp.batch16Harness(
        locale: const Locale('fr'),
        currentYear: 2027,
        now: () => now,
      ),
    );
    await tester.pumpAndSettle();
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_tax_year')), findsOne);

    await openBatch16AmountBuilder(tester, now: () => now);
    rows = await enterTwoProviders(tester);
    await openUnresolvedHelp(tester, rows.last);
    staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    now = now.add(const Duration(minutes: 31));
    await tester.pump(const Duration(minutes: 31));
    await tester.pumpAndSettle();
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_tax_year')), findsOne);

    await openBatch16AmountBuilder(tester, now: () => now);
    rows = await enterTwoProviders(tester);
    await openUnresolvedHelp(tester, rows.last);
    staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pumpAndSettle();
    staleProviderTotal();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MintNextDesignLabApp.batch16Harness(
        locale: const Locale('fr'),
        currentYear: 2026,
        now: () => now,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_tax_year')), findsOne);
  });

  testWidgets('stale_callbacks_never_retarget_after_every_invalidation', (
    tester,
  ) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final origin = rows.last;
    await openUnresolvedHelp(tester, origin);
    var staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('field:amount:$origin')),
      '2100',
    );
    await tester.pump();
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('status:amount_unresolved:$origin')),
      findsNothing,
    );
    expect(find.byKey(ValueKey('field:amount:${rows.first}')), findsOne);
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);

    await openUnresolvedHelp(tester, origin);
    staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('field:provider_name:$origin')),
      'Prestataire B corrigé',
    );
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('status:amount_unresolved:$origin')),
      findsNothing,
    );

    await openUnresolvedHelp(tester, origin);
    staleProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('action:remove_provider:$origin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('action:undo_removal:$origin')));
    await tester.pumpAndSettle();
    staleProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unresolved:$origin')), findsOne);

    await openUnresolvedHelp(tester, origin);
    final retiredByNewDoubt = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('action:amount_doubt:$origin')));
    await tester.pumpAndSettle();
    retiredByNewDoubt();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    final retiredByFinalize = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('action:remove_provider:$origin')));
    await tester.pumpAndSettle();
    final staleUndo = tester
        .widget<MintDesignLabAction>(
          find.byKey(ValueKey('action:undo_removal:$origin')),
        )
        .onPressed!;
    await tester.tap(find.byKey(ValueKey('action:finalize_removal:$origin')));
    await tester.pumpAndSettle();
    expectExactFocus('provider name ${rows.first}');
    staleUndo();
    retiredByFinalize();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('field:amount:$origin')), findsNothing);
  });

  testWidgets('wrong_row_and_repeated_actions_never_retarget', (tester) async {
    await openBatch16AmountBuilder(tester);
    final rows = await enterTwoProviders(tester);
    final first = rows.first;
    final second = rows.last;
    await openUnresolvedHelp(tester, second);
    final secondProviderTotal = tester
        .widget<MintDesignLabAction>(
          find.byKey(const ValueKey('action:unresolved_help.provider_total')),
        )
        .onPressed!;
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    await openUnresolvedHelp(tester, first);
    secondProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:unresolved_amount_help')), findsOne);
    expect(find.byKey(ValueKey('status:amount_unresolved:$first')), findsOne);
    secondProviderTotal();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unresolved:$first')), findsOne);
    await tester.tap(find.byKey(const ValueKey('action:unresolved_help.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('status:amount_unreviewed:$second')), findsOne);
    expect(
      tester
          .widget<TextFormField>(find.byKey(ValueKey('field:amount:$first')))
          .controller!
          .text,
      '1000',
    );
  });

  testWidgets('compact_keyboard_layout_targets_and_order', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openBatch16AmountBuilder(
      tester,
      textScaler: const TextScaler.linear(2),
    );
    final rows = await enterThreeProviders(tester);
    await openUnresolvedHelp(tester, rows.last);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('heading:unresolved_amount_help')),
          )
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpAndSettle();

    final orderedKeys = [
      'action:unresolved_help.provider_total',
      'action:unresolved_help.provider_refunded',
      'action:unresolved_help.all_zero',
      'action:unresolved_help.education',
      'action:unresolved_help.back',
      'action:unresolved_amount_help.open_safe_exit',
    ];
    final orderedFocusLabels = [
      'unresolved provider total action',
      'unresolved provider refunded action',
      'unresolved all zero action',
      'unresolved education action',
      'unresolved back action',
      'unresolved safe exit trigger',
    ];
    for (final expectedFocus in orderedFocusLabels) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expectExactFocus(expectedFocus);
    }
    for (var index = 0; index < orderedKeys.length; index++) {
      final key = orderedKeys[index];
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pump();
      final rect = tester.getRect(finder);
      expect(rect.width, greaterThanOrEqualTo(48), reason: key);
      expect(rect.height, greaterThanOrEqualTo(48), reason: key);
      expect(tester.hitTestOnBinding(rect.center), isNotEmpty, reason: key);
      final semanticsFinder = find.descendant(
        of: finder,
        matching: find.byType(Semantics),
      );
      final semanticsWidget = semanticsFinder.evaluate().isNotEmpty
          ? tester.widget<Semantics>(semanticsFinder.first)
          : tester.widget<Semantics>(
              find.ancestor(of: finder, matching: find.byType(Semantics)).first,
            );
      expect(
        semanticsWidget.properties.sortKey,
        OrdinalSortKey(index.toDouble()),
        reason: key,
      );
    }
  });

  testWidgets('semantic_names_states_modal_trap_and_reduced_motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openBatch16AmountBuilder(tester);
    final rows = await enterThreeProviders(tester);
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final status = tester
          .getSemantics(find.byKey(ValueKey('status:amount_unreviewed:$row')))
          .label;
      expect(status.trim(), isNotEmpty, reason: 'state must not rely on color');
      final doubt = tester
          .getSemantics(find.byKey(ValueKey('action:amount_doubt:$row')))
          .label;
      expect(doubt, contains('${index + 1}'));
      expect(doubt, contains('2026'));
      expect(doubt, isNot(contains('Prestataire')));
    }
    await openUnresolvedHelp(tester, rows[1]);
    final actionKeys = [
      'action:unresolved_help.provider_total',
      'action:unresolved_help.provider_refunded',
      'action:unresolved_help.all_zero',
      'action:unresolved_help.education',
      'action:unresolved_help.back',
      'action:unresolved_amount_help.open_safe_exit',
    ];
    final labels = <String>[];
    for (final key in actionKeys) {
      final finder = find.byKey(ValueKey(key));
      final label = tester.getSemantics(finder).label;
      final visibleText = tester
          .widgetList<Text>(
            find.descendant(of: finder, matching: find.byType(Text)),
          )
          .map((widget) => widget.data ?? '')
          .where((value) => value.isNotEmpty)
          .join(' ');
      expect(label, visibleText, reason: key);
      expect(
        label.toLowerCase(),
        contains('ligne 2'),
        reason: '$key selected row context',
      );
      expect(label, contains('2026'), reason: '$key selected year context');
      expect(label, isNot(contains('Prestataire B')), reason: key);
      labels.add(label);
    }
    expect(labels.toSet(), hasLength(labels.length));

    await tester.tap(
      find.byKey(
        const ValueKey('action:unresolved_amount_help.open_safe_exit'),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expectExactFocus('safe exit heading');
    final modal = tester.widget<Semantics>(
      find.byKey(const ValueKey('overlay:safe_exit')),
    );
    expect(modal.properties.scopesRoute, isTrue);
    expect(modal.properties.namesRoute, isTrue);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        anyOf('safe exit resume', 'safe exit leave without saving'),
      );
    }
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('local_ephemeral_privacy_probe_records_no_outputs', (
    tester,
  ) async {
    final outputs = <String>[];
    void record(String channel, Object? payload) =>
        outputs.add('$channel:$payload');
    await openBatch16AmountBuilder(
      tester,
      onPersistenceWrite: (value) => record('persistence', value),
      onNetworkRequest: (value) => record('network', value),
      onAnalyticsEvent: (value) => record('analytics', value),
      onCrashBreadcrumb: (value) => record('breadcrumb', value),
    );
    final rows = await enterThreeProviders(tester);
    for (final row in rows) {
      for (final field in ['provider_name', 'amount']) {
        final input = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey('field:$field:$row')),
            matching: find.byType(EditableText),
          ),
        );
        expect(input.enableIMEPersonalizedLearning, isFalse);
        expect(input.enableSuggestions, isFalse);
        expect(input.autocorrect, isFalse);
      }
    }
    await openUnresolvedHelp(tester, rows[1]);
    await tester.tap(
      find.byKey(const ValueKey('action:unresolved_help.provider_total')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('field:amount:${rows.first}')),
      '1100',
    );
    await tester.pump();
    expect(outputs, isEmpty);
  });

  for (final language in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
    testWidgets('six_locale_private_semantic_intents_$language', (
      tester,
    ) async {
      await openBatch16AmountBuilder(tester, locale: Locale(language));
      final rows = await enterTwoProviders(tester);
      final origin = rows.last;
      final doubt = find.byKey(ValueKey('action:amount_doubt:$origin'));
      final semantics = tester.getSemantics(doubt);
      expect(semantics.label, contains('2'));
      expect(semantics.label, contains('2026'));
      expect(semantics.label, isNot(contains('Prestataire B')));
      await openUnresolvedHelp(tester, origin);
      final helpTree = tester
          .getSemantics(
            find.byKey(const ValueKey('node:unresolved_amount_help')),
          )
          .toStringDeep()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      expect(helpTree, isNot(contains('prestatairea')));
      expect(helpTree, isNot(contains('prestataireb')));
      final safeExitLabel = tester
          .getSemantics(
            find.byKey(
              const ValueKey('action:unresolved_amount_help.open_safe_exit'),
            ),
          )
          .label
          .toLowerCase();
      expect(safeExitLabel, isNot(contains('prestataire')));
      final context = tester.element(
        find.byKey(const ValueKey('node:unresolved_amount_help')),
      );
      final l10n = MintNextLocalizations.of(context);
      final swissIntents = <String>[
        l10n.batch16AnnualOrdinaryTotalMeaning,
        l10n.batch16ActuallyCreditedMeaning(2026),
        l10n.batch16ExcludedMovementsMeaning,
        l10n.batch16ProviderConfirmedNetMeaning,
        l10n.batch16InsuranceCertificateMeaning,
        l10n.batch16RefundVsAllZeroMeaning,
        l10n.batch16MintNotVerifiedMeaning,
        l10n.batch16NoTaxAdviceMeaning,
      ];
      expect(swissIntents, hasLength(8));
      expect(swissIntents.toSet(), hasLength(8));
      expect(
        swissIntents,
        equals(
          batch16SemanticFixture[language]!.values
              .map((value) => value.replaceAll('{taxYear}', '2026'))
              .toList(),
        ),
      );
      for (final intent in swissIntents) {
        expect(intent.trim(), isNotEmpty);
        expect(intent, isNot(contains('@@')));
        expect(intent, isNot(contains('Prestataire A')));
        expect(intent, isNot(contains('Prestataire B')));
        expect(find.text(intent), findsOneWidget);
        expect(
          helpTree,
          contains(intent.toLowerCase().replaceAll(RegExp(r'\s+'), '')),
        );
      }
      for (final key in [
        'action:unresolved_help.provider_total',
        'action:unresolved_help.provider_refunded',
        'action:unresolved_help.all_zero',
        'action:unresolved_help.education',
        'action:unresolved_help.back',
      ]) {
        final label = tester.getSemantics(find.byKey(ValueKey(key))).label;
        expect(label, isNot(contains('Prestataire A')), reason: key);
        expect(label, isNot(contains('Prestataire B')), reason: key);
      }
      expect(
        tester
            .getSemantics(
              find.byKey(
                const ValueKey('action:unresolved_help.provider_refunded'),
              ),
            )
            .label,
        isNot(
          tester
              .getSemantics(
                find.byKey(const ValueKey('action:unresolved_help.all_zero')),
              )
              .label,
        ),
      );
      expect(find.textContaining('@@'), findsNothing);
    });
  }
}
