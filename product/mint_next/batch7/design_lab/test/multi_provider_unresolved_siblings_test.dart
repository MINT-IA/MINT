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

  List<MultiProviderAmountRow> twoRows(MultiProviderAmountDraft draft) {
    final first = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = fillRow(draft, draft.rows.last, 'finpension', '2000');
    return [first, second];
  }

  test('doubt issues distinct provider refund and all-zero siblings', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);

    final origin = draft.markAmountUnresolved(rows.first.editToken)!;

    expect(origin.resolveToken, isNot(same(origin.refundToken)));
    expect(origin.resolveToken, isNot(same(origin.allZeroToken)));
    expect(origin.refundToken, isNot(same(origin.allZeroToken)));
    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.ready,
    );
  });

  test('provider total resolution consumes every sibling atomically', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final origin = draft.markAmountUnresolved(rows.first.editToken)!;

    expect(
      draft.resolveProviderReportedTotal(origin.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );

    expect(
      draft.refundFullyProvider(origin.refundToken),
      MultiProviderUnresolvedRefundResult.stale,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.stale,
    );
    expect(draft.rows.length, 2);
  });

  test(
    'eligible refund tombstones exact origin and preserves every other row',
    () {
      final draft = MultiProviderAmountDraft();
      final rows = twoRows(draft);
      expect(draft.setAllProvidersReviewed(true), isTrue);
      final secondName = rows.last.providerName;
      final secondAmount = rows.last.amountMinorUnits;
      final secondClassification = rows.last.classification;
      final origin = draft.markAmountUnresolved(rows.first.editToken)!;

      expect(
        draft.refundFullyProvider(origin.refundToken),
        MultiProviderUnresolvedRefundResult.tombstoned,
      );

      expect(rows.first.lifecycle, MultiProviderRowLifecycle.tombstone);
      expect(rows.first.undoToken, isNotNull);
      expect(rows.last.lifecycle, MultiProviderRowLifecycle.active);
      expect(rows.last.providerName, secondName);
      expect(rows.last.amountMinorUnits, secondAmount);
      expect(rows.last.classification, secondClassification);
      expect(draft.provisionalSubtotalMinorUnits, secondAmount);
      expect(
        draft.resolveProviderReportedTotal(origin.resolveToken),
        MultiProviderUnresolvedActionResult.stale,
      );
      expect(
        draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
        MultiProviderAllZeroCorrectionResult.stale,
      );
      expect(
        draft.refundFullyProvider(origin.refundToken),
        MultiProviderUnresolvedRefundResult.stale,
      );
      expect(
        draft.undoRemoval(rows.first.undoToken!),
        MultiProviderUndoResult.restored,
      );
      expect(
        rows.first.classification,
        MultiProviderAmountClassification.unresolved,
      );
      expect(
        draft.resolveProviderReportedTotal(origin.resolveToken),
        MultiProviderUnresolvedActionResult.stale,
      );
      expect(
        draft.refundFullyProvider(origin.refundToken),
        MultiProviderUnresolvedRefundResult.stale,
      );
      expect(
        draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
        MultiProviderAllZeroCorrectionResult.stale,
      );
    },
  );

  test('simultaneous origins never cross-target or consume the other row', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final firstOrigin = draft.markAmountUnresolved(rows.first.editToken)!;
    final secondOrigin = draft.markAmountUnresolved(rows.last.editToken)!;

    expect(
      draft.refundFullyProvider(secondOrigin.refundToken),
      MultiProviderUnresolvedRefundResult.tombstoned,
    );
    expect(rows.last.lifecycle, MultiProviderRowLifecycle.tombstone);
    expect(rows.first.lifecycle, MultiProviderRowLifecycle.active);
    expect(
      rows.first.classification,
      MultiProviderAmountClassification.unresolved,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(firstOrigin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.ready,
    );
    expect(
      draft.resolveProviderReportedTotal(firstOrigin.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );
    expect(rows.first.amountMinorUnits, 100000);
    expect(rows.last.amountMinorUnits, isNull);
  });

  test('provider-total on one origin leaves the other refund valid', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final firstOrigin = draft.markAmountUnresolved(rows.first.editToken)!;
    final secondOrigin = draft.markAmountUnresolved(rows.last.editToken)!;

    expect(
      draft.resolveProviderReportedTotal(firstOrigin.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );
    expect(rows.first.lifecycle, MultiProviderRowLifecycle.active);
    expect(
      rows.first.classification,
      MultiProviderAmountClassification.unreviewed,
    );
    expect(
      rows.last.classification,
      MultiProviderAmountClassification.unresolved,
    );
    expect(
      draft.refundFullyProvider(secondOrigin.refundToken),
      MultiProviderUnresolvedRefundResult.tombstoned,
    );
    expect(rows.first.amountMinorUnits, 100000);
    expect(rows.last.lifecycle, MultiProviderRowLifecycle.tombstone);
  });

  test('ineligible refund is a no-op and consumes nothing', () {
    final draft = MultiProviderAmountDraft();
    final row = fillRow(draft, draft.rows.single, 'VIAC', '1000');
    final origin = draft.markAmountUnresolved(row.editToken)!;

    expect(
      draft.refundFullyProvider(origin.refundToken),
      MultiProviderUnresolvedRefundResult.ineligible,
    );
    expect(row.lifecycle, MultiProviderRowLifecycle.active);
    expect(row.classification, MultiProviderAmountClassification.unresolved);
    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.ready,
    );
    expect(
      draft.resolveProviderReportedTotal(origin.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );
  });

  test('all-zero correction entry preserves origin siblings and amount', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final origin = draft.markAmountUnresolved(rows.first.editToken)!;

    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.ready,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.ready,
    );
    expect(
      rows.first.classification,
      MultiProviderAmountClassification.unresolved,
    );
    expect(rows.first.amountMinorUnits, 100000);
    expect(draft.provisionalSubtotalMinorUnits, 300000);
    expect(
      draft.resolveProviderReportedTotal(origin.resolveToken),
      MultiProviderUnresolvedActionResult.resolvedToUnreviewed,
    );
  });

  test('external removal invalidates siblings and undo never revives them', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final origin = draft.markAmountUnresolved(rows.first.editToken)!;

    expect(
      draft.removeProvider(rows.first.removeToken!),
      MultiProviderRemoveResult.tombstoned,
    );
    expect(
      draft.undoRemoval(rows.first.undoToken!),
      MultiProviderUndoResult.restored,
    );

    expect(
      draft.refundFullyProvider(origin.refundToken),
      MultiProviderUnresolvedRefundResult.stale,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.stale,
    );
  });

  test(
    'new doubt creates fresh siblings and every old sibling stays stale',
    () {
      final draft = MultiProviderAmountDraft();
      final rows = twoRows(draft);
      final old = draft.markAmountUnresolved(rows.first.editToken)!;
      final fresh = draft.markAmountUnresolved(rows.first.editToken)!;

      expect(fresh.resolveToken, isNot(same(old.resolveToken)));
      expect(fresh.refundToken, isNot(same(old.refundToken)));
      expect(fresh.allZeroToken, isNot(same(old.allZeroToken)));
      expect(
        draft.refundFullyProvider(old.refundToken),
        MultiProviderUnresolvedRefundResult.stale,
      );
      expect(
        draft.beginAllProvidersZeroCorrection(old.allZeroToken),
        MultiProviderAllZeroCorrectionResult.stale,
      );
      expect(
        draft.beginAllProvidersZeroCorrection(fresh.allZeroToken),
        MultiProviderAllZeroCorrectionResult.ready,
      );
    },
  );

  test('provider and amount edits retire every sibling before mutation', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final beforeName = draft.markAmountUnresolved(rows.first.editToken)!;

    expect(
      draft.updateProviderName(rows.first.editToken, 'VIAC Suisse'),
      isTrue,
    );
    expect(
      draft.refundFullyProvider(beforeName.refundToken),
      MultiProviderUnresolvedRefundResult.stale,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(beforeName.allZeroToken),
      MultiProviderAllZeroCorrectionResult.stale,
    );

    final beforeAmount = draft.markAmountUnresolved(rows.first.editToken)!;
    expect(
      draft.updateAmount(rows.first.editToken, '1500', locale: 'fr'),
      isTrue,
    );
    expect(
      draft.refundFullyProvider(beforeAmount.refundToken),
      MultiProviderUnresolvedRefundResult.stale,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(beforeAmount.allZeroToken),
      MultiProviderAllZeroCorrectionResult.stale,
    );
    expect(rows.first.amountMinorUnits, 150000);
    expect(rows.last.amountMinorUnits, 200000);
  });

  test('purge makes every sibling permanently stale', () {
    final draft = MultiProviderAmountDraft();
    final rows = twoRows(draft);
    final origin = draft.markAmountUnresolved(rows.first.editToken)!;

    draft.purge();

    expect(
      draft.resolveProviderReportedTotal(origin.resolveToken),
      MultiProviderUnresolvedActionResult.stale,
    );
    expect(
      draft.refundFullyProvider(origin.refundToken),
      MultiProviderUnresolvedRefundResult.stale,
    );
    expect(
      draft.beginAllProvidersZeroCorrection(origin.allZeroToken),
      MultiProviderAllZeroCorrectionResult.stale,
    );
  });
}
