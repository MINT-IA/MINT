import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/multi_provider_amount_draft.dart';

void main() {
  test('starts with one stable empty row and refuses a second empty row', () {
    final draft = MultiProviderAmountDraft();

    expect(draft.rows, hasLength(1));
    expect(draft.rows.single.id, 'provider-row-1');
    expect(draft.addProvider(), MultiProviderAddResult.existingEmpty);
    expect(draft.rows, hasLength(1));
  });

  test('adds exact provider rows and computes a provisional CHF subtotal', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '4000', locale: 'fr');

    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    expect(second.id, 'provider-row-2');
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '3000,50', locale: 'fr');

    expect(draft.provisionalSubtotalMinorUnits, 700050);
    expect(draft.aggregateOverflow, isFalse);
    expect(draft.canConfirmAllProvidersReviewed, isTrue);
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), 700050);
  });

  test(
    'exact duplicate blocks confirmation without claiming provider identity',
    () {
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single;
      draft.updateProviderName(first.editToken, ' VIAC ');
      draft.updateAmount(first.editToken, '4000', locale: 'de');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final second = draft.rows.last;
      draft.updateProviderName(second.editToken, 'viac');
      draft.updateAmount(second.editToken, '3000', locale: 'de');

      expect(draft.duplicateRowIds, {first.id, second.id});
      expect(draft.canConfirmAllProvidersReviewed, isFalse);
      expect(draft.setAllProvidersReviewed(true), isFalse);
      expect(draft.commit(), isNull);
    },
  );

  test('every edit clears confirmation and committed total', () {
    final draft = MultiProviderAmountDraft();
    final row = draft.rows.single;
    draft.updateProviderName(row.editToken, 'VIAC');
    draft.updateAmount(row.editToken, '7258', locale: 'fr');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), 725800);

    draft.updateAmount(row.editToken, '7000', locale: 'fr');

    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.committedTotalMinorUnits, isNull);
    expect(draft.provisionalSubtotalMinorUnits, 700000);
  });

  test(
    'only an empty unbound row can be removed in the first hidden slice',
    () {
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single;
      draft.updateProviderName(first.editToken, 'VIAC');
      draft.updateAmount(first.editToken, '4000', locale: 'fr');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final second = draft.rows.last;

      expect(
        draft.removeProvider(second.removeToken!),
        MultiProviderRemoveResult.removedEmpty,
      );
      expect(draft.rows.map((row) => row.id), [first.id]);
      expect(
        draft.removeProvider(first.removeToken!),
        MultiProviderRemoveResult.minimumActive,
      );
    },
  );

  test('checked aggregate overflow never becomes a subtotal or commit', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '999999999999,99', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '0,01', locale: 'fr');

    expect(draft.aggregateOverflow, isTrue);
    expect(draft.provisionalSubtotalMinorUnits, isNull);
    expect(draft.canConfirmAllProvidersReviewed, isFalse);
    expect(draft.commit(), isNull);
  });

  test('purge erases every value and never reuses a row id', () {
    final draft = MultiProviderAmountDraft();
    final retired = draft.rows.single;
    draft.updateProviderName(retired.editToken, 'VIAC');
    draft.updateAmount(retired.editToken, '7258', locale: 'fr');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), isNotNull);

    draft.purge();

    expect(draft.rows, hasLength(1));
    expect(draft.rows.single.id, isNot(retired.id));
    expect(draft.rows.single.providerName, isEmpty);
    expect(draft.rows.single.rawAmount, isEmpty);
    expect(draft.provisionalSubtotalMinorUnits, isNull);
    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.committedTotalMinorUnits, isNull);
  });

  test('Unicode-equivalent labels cannot bypass duplicate detection', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '4000', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'ＶＩＡＣ');
    draft.updateAmount(second.editToken, '3000', locale: 'fr');

    expect(draft.duplicateRowIds, {first.id, second.id});
    expect(draft.canConfirmAllProvidersReviewed, isFalse);
  });

  test('Unicode whitespace and casefold-equivalent labels are duplicates', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'Straße Vorsorge');
    draft.updateAmount(first.editToken, '4000', locale: 'de');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'STRASSE\u00a0VORSORGE');
    draft.updateAmount(second.editToken, '3000', locale: 'de');

    expect(draft.duplicateRowIds, {first.id, second.id});
  });

  test('full Unicode casefold treats dotted-I forms as duplicates', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'İ Pension');
    draft.updateAmount(first.editToken, '4000', locale: 'de');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'i\u0307 pension');
    draft.updateAmount(second.editToken, '3000', locale: 'de');

    expect(draft.duplicateRowIds, {first.id, second.id});
    expect(draft.canConfirmAllProvidersReviewed, isFalse);
  });

  test('invisible, bidi and control characters make a provider unsafe', () {
    for (final unsafe in [
      'VI\u200bAC',
      'VI\u202eAC',
      'VI\u0007AC',
      'VI\u00adAC',
      'VI\u061cAC',
      'VI\u180eAC',
      'VIAC\ufe0f',
      'VIAC\u034f',
      'VIAC\u{e0100}',
    ]) {
      final draft = MultiProviderAmountDraft();
      final row = draft.rows.single;
      draft.updateProviderName(row.editToken, unsafe);
      draft.updateAmount(row.editToken, '1000', locale: 'fr');

      expect(draft.rows.single.hasSafeProviderName, isFalse, reason: unsafe);
      expect(draft.canConfirmAllProvidersReviewed, isFalse);
    }
  });

  test('add result distinguishes an empty row from provider capacity', () {
    final draft = MultiProviderAmountDraft();
    expect(draft.addProvider(), MultiProviderAddResult.existingEmpty);
    for (var index = 0; index < 50; index++) {
      final row = draft.rows.last;
      draft.updateProviderName(row.editToken, 'Provider $index');
      draft.updateAmount(row.editToken, '${index + 1}', locale: 'fr');
      if (index < 49) {
        expect(draft.addProvider(), MultiProviderAddResult.added);
      }
    }

    expect(draft.rows, hasLength(50));
    expect(draft.addProvider(), MultiProviderAddResult.capacityReached);
  });

  test(
    'confirmation state is read-only and explicit invalidation clears it',
    () {
      final draft = MultiProviderAmountDraft();
      final row = draft.rows.single;
      draft.updateProviderName(row.editToken, 'VIAC');
      draft.updateAmount(row.editToken, '7258', locale: 'fr');
      expect(draft.setAllProvidersReviewed(true), isTrue);
      expect(draft.commit(), 725800);

      draft.invalidateConfirmation();

      expect(draft.allProvidersReviewed, isFalse);
      expect(draft.committedTotalMinorUnits, isNull);
    },
  );

  test('contentful removal becomes an inline tombstone and undo is exact', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '4000', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '3000', locale: 'fr');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), 700000);

    final removeToken = first.removeToken!;
    expect(
      draft.removeProvider(removeToken),
      MultiProviderRemoveResult.tombstoned,
    );
    expect(draft.rows.first.lifecycle, MultiProviderRowLifecycle.tombstone);
    expect(draft.provisionalSubtotalMinorUnits, 300000);
    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.committedTotalMinorUnits, isNull);
    final undoToken = draft.rows.first.undoToken!;
    final staleFinalize = draft.rows.first.finalizeToken!;

    expect(draft.undoRemoval(undoToken), MultiProviderUndoResult.restored);
    expect(draft.rows.first.id, first.id);
    expect(draft.rows.first.providerName, 'VIAC');
    expect(draft.rows.first.rawAmount, '4000');
    expect(draft.provisionalSubtotalMinorUnits, 700000);
    expect(draft.allProvidersReviewed, isFalse);
    expect(
      draft.finalizeRemoval(staleFinalize),
      MultiProviderFinalizeResult.stale,
    );
    expect(draft.removeProvider(removeToken), MultiProviderRemoveResult.stale);
  });

  test('finalize retires row and sibling tokens without reusing its id', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single;
    draft.updateProviderName(first.editToken, 'VIAC');
    draft.updateAmount(first.editToken, '4000', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last;
    draft.updateProviderName(second.editToken, 'finpension');
    draft.updateAmount(second.editToken, '3000', locale: 'fr');
    expect(
      draft.removeProvider(first.removeToken!),
      MultiProviderRemoveResult.tombstoned,
    );
    final retiredId = first.id;
    final undo = first.undoToken!;
    final finalize = first.finalizeToken!;

    expect(
      draft.finalizeRemoval(finalize),
      MultiProviderFinalizeResult.finalized,
    );
    expect(draft.rows.map((row) => row.id), isNot(contains(retiredId)));
    expect(draft.undoRemoval(undo), MultiProviderUndoResult.stale);
    expect(draft.provisionalSubtotalMinorUnits, 300000);
    expect(draft.addProvider(), MultiProviderAddResult.added);
    expect(draft.rows.last.id, isNot(retiredId));
  });

  test(
    'stale edit token cannot mutate tombstoned, restored or purged data',
    () {
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single;
      final staleEdit = first.editToken;
      draft.updateProviderName(staleEdit, 'VIAC');
      draft.updateAmount(staleEdit, '4000', locale: 'fr');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final second = draft.rows.last;
      draft.updateProviderName(second.editToken, 'finpension');
      draft.updateAmount(second.editToken, '3000', locale: 'fr');
      expect(
        draft.removeProvider(first.removeToken!),
        MultiProviderRemoveResult.tombstoned,
      );

      expect(draft.updateProviderName(staleEdit, 'MUTATED'), isFalse);
      expect(
        draft.undoRemoval(first.undoToken!),
        MultiProviderUndoResult.restored,
      );
      expect(draft.updateProviderName(staleEdit, 'MUTATED'), isFalse);
      expect(draft.rows.first.providerName, 'VIAC');
      final currentEdit = draft.rows.first.editToken;
      draft.purge();
      expect(draft.updateProviderName(currentEdit, 'MUTATED'), isFalse);
      expect(draft.rows.single.providerName, isEmpty);
    },
  );

  test(
    'multiple tombstones remain independent and expose no retired values',
    () {
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single;
      draft.updateProviderName(first.editToken, 'SECRET A');
      draft.updateAmount(first.editToken, '1000', locale: 'fr');
      draft.addProvider();
      final second = draft.rows.last;
      draft.updateProviderName(second.editToken, 'SECRET B');
      draft.updateAmount(second.editToken, '2000', locale: 'fr');
      draft.addProvider();
      final third = draft.rows.last;
      draft.updateProviderName(third.editToken, 'VISIBLE');
      draft.updateAmount(third.editToken, '3000', locale: 'fr');

      expect(
        draft.removeProvider(first.removeToken!),
        MultiProviderRemoveResult.tombstoned,
      );
      expect(
        draft.removeProvider(second.removeToken!),
        MultiProviderRemoveResult.tombstoned,
      );
      final firstUndo = first.undoToken!;
      final secondFinalize = second.finalizeToken!;
      expect(first.providerName, isEmpty);
      expect(first.rawAmount, isEmpty);
      expect(second.providerName, isEmpty);
      expect(draft.provisionalSubtotalMinorUnits, 300000);

      expect(draft.undoRemoval(firstUndo), MultiProviderUndoResult.restored);
      expect(first.providerName, 'SECRET A');
      expect(second.lifecycle, MultiProviderRowLifecycle.tombstone);
      expect(
        draft.finalizeRemoval(secondFinalize),
        MultiProviderFinalizeResult.finalized,
      );
      expect(draft.rows.map((row) => row.id), [first.id, third.id]);
    },
  );

  test(
    'tombstones occupy capacity until finalize and purge retires every token',
    () {
      final draft = MultiProviderAmountDraft();
      for (var index = 0; index < 50; index++) {
        final row = draft.rows.last;
        draft.updateProviderName(row.editToken, 'Provider $index');
        draft.updateAmount(row.editToken, '${index + 1}', locale: 'fr');
        if (index < 49) {
          expect(draft.addProvider(), MultiProviderAddResult.added);
        }
      }
      final first = draft.rows.first;
      final staleEdit = first.editToken;
      final staleRemove = first.removeToken!;
      expect(
        draft.removeProvider(staleRemove),
        MultiProviderRemoveResult.tombstoned,
      );
      final staleUndo = first.undoToken!;
      final staleFinalize = first.finalizeToken!;
      expect(draft.addProvider(), MultiProviderAddResult.capacityReached);
      expect(
        draft.finalizeRemoval(staleFinalize),
        MultiProviderFinalizeResult.finalized,
      );
      expect(draft.addProvider(), MultiProviderAddResult.added);

      final currentRemove = draft.rows.last.removeToken!;
      draft.purge();
      expect(draft.updateProviderName(staleEdit, 'MUTATED'), isFalse);
      expect(
        draft.removeProvider(staleRemove),
        MultiProviderRemoveResult.stale,
      );
      expect(draft.undoRemoval(staleUndo), MultiProviderUndoResult.stale);
      expect(
        draft.finalizeRemoval(staleFinalize),
        MultiProviderFinalizeResult.stale,
      );
      expect(
        draft.removeProvider(currentRemove),
        MultiProviderRemoveResult.stale,
      );
    },
  );
}
