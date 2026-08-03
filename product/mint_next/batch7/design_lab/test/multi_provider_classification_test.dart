import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/multi_provider_amount_draft.dart';

void main() {
  MultiProviderAmountRow fillRow(
    MultiProviderAmountDraft draft,
    MultiProviderAmountRow row,
    String provider,
    String amount,
  ) {
    expect(draft.updateProviderName(row.editToken, provider), isTrue);
    expect(draft.updateAmount(row.editToken, amount, locale: 'fr'), isTrue);
    return row;
  }

  test('unresolved remains provisional but blocks review and commit', () {
    final draft = MultiProviderAmountDraft();
    final row = fillRow(draft, draft.rows.single, 'VIAC', '7258');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), 725800);

    final origin = draft.markAmountUnresolved(row.editToken);

    expect(origin, isNotNull);
    expect(row.classification, MultiProviderAmountClassification.unresolved);
    expect(draft.provisionalSubtotalMinorUnits, 725800);
    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.committedTotalMinorUnits, isNull);
    expect(draft.canConfirmAllProvidersReviewed, isFalse);
    expect(draft.setAllProvidersReviewed(true), isFalse);
    expect(draft.commit(), isNull);
  });

  test('global review is the only transition to confirmed ordinary', () {
    final draft = MultiProviderAmountDraft();
    final first = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = fillRow(draft, draft.rows.last, 'finpension', '2000');

    expect(first.classification, MultiProviderAmountClassification.unreviewed);
    expect(second.classification, MultiProviderAmountClassification.unreviewed);
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(
      draft.rows.map((row) => row.classification),
      everyElement(MultiProviderAmountClassification.confirmedOrdinary),
    );
    expect(draft.commit(), 300000);

    expect(draft.setAllProvidersReviewed(false), isTrue);
    expect(
      draft.rows.map((row) => row.classification),
      everyElement(MultiProviderAmountClassification.unreviewed),
    );
    expect(draft.committedTotalMinorUnits, isNull);
  });

  test('amount edit resets only its row and retires the old help origin', () {
    final draft = MultiProviderAmountDraft();
    final first = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = fillRow(draft, draft.rows.last, 'finpension', '2000');
    expect(draft.setAllProvidersReviewed(true), isTrue);

    final oldOrigin = draft.markAmountUnresolved(first.editToken)!;
    expect(draft.updateAmount(first.editToken, '1500', locale: 'fr'), isTrue);

    expect(first.classification, MultiProviderAmountClassification.unreviewed);
    expect(
      second.classification,
      MultiProviderAmountClassification.confirmedOrdinary,
    );
    expect(
      draft.resolveProviderReportedTotal(oldOrigin.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
    expect(first.amountMinorUnits, 150000);

    final freshOrigin = draft.markAmountUnresolved(first.editToken)!;
    expect(freshOrigin.resolveToken, isNot(same(oldOrigin.resolveToken)));
    expect(
      draft.resolveProviderReportedTotal(freshOrigin.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );
    expect(first.classification, MultiProviderAmountClassification.unreviewed);
    expect(first.amountMinorUnits, 150000);
  });

  test('remove and undo preserve classification but retire help actions', () {
    final draft = MultiProviderAmountDraft();
    final first = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    fillRow(draft, draft.rows.last, 'finpension', '2000');
    final origin = draft.markAmountUnresolved(first.editToken)!;

    expect(
      draft.removeProvider(first.removeToken!),
      MultiProviderRemoveResult.tombstoned,
    );
    expect(first.classification, MultiProviderAmountClassification.unresolved);
    expect(
      draft.resolveProviderReportedTotal(origin.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
    final undo = first.undoToken!;
    expect(draft.undoRemoval(undo), MultiProviderUndoResult.restored);
    expect(first.classification, MultiProviderAmountClassification.unresolved);
  });

  test('finalize and purge erase classification and make actions stale', () {
    final draft = MultiProviderAmountDraft();
    final first = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    fillRow(draft, draft.rows.last, 'finpension', '2000');
    final finalizedOrigin = draft.markAmountUnresolved(first.editToken)!;
    expect(
      draft.removeProvider(first.removeToken!),
      MultiProviderRemoveResult.tombstoned,
    );
    expect(
      draft.finalizeRemoval(first.finalizeToken!),
      MultiProviderFinalizeResult.finalized,
    );
    expect(first.classification, MultiProviderAmountClassification.unreviewed);
    expect(
      draft.resolveProviderReportedTotal(finalizedOrigin.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );

    final remaining = draft.rows.single;
    final purgedOrigin = draft.markAmountUnresolved(remaining.editToken)!;
    draft.purge();
    expect(
      draft.resolveProviderReportedTotal(purgedOrigin.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
    expect(
      draft.rows.single.classification,
      MultiProviderAmountClassification.unreviewed,
    );
  });

  test('name edit and a second doubt retire every earlier resolution', () {
    final draft = MultiProviderAmountDraft();
    final row = fillRow(draft, draft.rows.single, 'VIAC', '7258');
    final beforeNameEdit = draft.markAmountUnresolved(row.editToken)!;

    expect(draft.updateProviderName(row.editToken, 'VIAC Suisse'), isTrue);
    expect(row.classification, MultiProviderAmountClassification.unresolved);
    expect(
      draft.resolveProviderReportedTotal(beforeNameEdit.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );

    final first = draft.markAmountUnresolved(row.editToken)!;
    final second = draft.markAmountUnresolved(row.editToken)!;
    expect(second.resolveToken, isNot(same(first.resolveToken)));
    expect(
      draft.resolveProviderReportedTotal(first.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
    expect(
      draft.resolveProviderReportedTotal(second.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );
    expect(
      draft.resolveProviderReportedTotal(second.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
  });

  test('uncheck retires an unresolved origin without changing the amount', () {
    final draft = MultiProviderAmountDraft();
    final row = fillRow(draft, draft.rows.single, 'VIAC', '7258');
    final origin = draft.markAmountUnresolved(row.editToken)!;

    expect(draft.setAllProvidersReviewed(false), isTrue);
    expect(row.classification, MultiProviderAmountClassification.unreviewed);
    expect(row.amountMinorUnits, 725800);
    expect(
      draft.resolveProviderReportedTotal(origin.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
  });

  test('remove and undo preserve confirmed ordinary classification', () {
    final draft = MultiProviderAmountDraft();
    final first = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    fillRow(draft, draft.rows.last, 'finpension', '2000');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(
      first.classification,
      MultiProviderAmountClassification.confirmedOrdinary,
    );

    expect(
      draft.removeProvider(first.removeToken!),
      MultiProviderRemoveResult.tombstoned,
    );
    expect(
      first.classification,
      MultiProviderAmountClassification.confirmedOrdinary,
    );
    expect(
      draft.undoRemoval(first.undoToken!),
      MultiProviderUndoResult.restored,
    );
    expect(
      first.classification,
      MultiProviderAmountClassification.confirmedOrdinary,
    );
    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.commit(), isNull);
  });
}
