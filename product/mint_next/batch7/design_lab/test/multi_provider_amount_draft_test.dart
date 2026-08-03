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
    final first = draft.rows.single.id;
    draft.updateProviderName(first, 'VIAC');
    draft.updateAmount(first, '4000', locale: 'fr');

    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last.id;
    expect(second, 'provider-row-2');
    draft.updateProviderName(second, 'finpension');
    draft.updateAmount(second, '3000,50', locale: 'fr');

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
      final first = draft.rows.single.id;
      draft.updateProviderName(first, ' VIAC ');
      draft.updateAmount(first, '4000', locale: 'de');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final second = draft.rows.last.id;
      draft.updateProviderName(second, 'viac');
      draft.updateAmount(second, '3000', locale: 'de');

      expect(draft.duplicateRowIds, {first, second});
      expect(draft.canConfirmAllProvidersReviewed, isFalse);
      expect(draft.setAllProvidersReviewed(true), isFalse);
      expect(draft.commit(), isNull);
    },
  );

  test('every edit clears confirmation and committed total', () {
    final draft = MultiProviderAmountDraft();
    final row = draft.rows.single.id;
    draft.updateProviderName(row, 'VIAC');
    draft.updateAmount(row, '7258', locale: 'fr');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), 725800);

    draft.updateAmount(row, '7000', locale: 'fr');

    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.committedTotalMinorUnits, isNull);
    expect(draft.provisionalSubtotalMinorUnits, 700000);
  });

  test(
    'only an empty unbound row can be removed in the first hidden slice',
    () {
      final draft = MultiProviderAmountDraft();
      final first = draft.rows.single.id;
      draft.updateProviderName(first, 'VIAC');
      draft.updateAmount(first, '4000', locale: 'fr');
      expect(draft.addProvider(), MultiProviderAddResult.added);
      final second = draft.rows.last.id;

      expect(draft.removeEmptyProvider(second), isTrue);
      expect(draft.rows.map((row) => row.id), [first]);
      expect(draft.removeEmptyProvider(first), isFalse);
    },
  );

  test('checked aggregate overflow never becomes a subtotal or commit', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single.id;
    draft.updateProviderName(first, 'VIAC');
    draft.updateAmount(first, '999999999999,99', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last.id;
    draft.updateProviderName(second, 'finpension');
    draft.updateAmount(second, '0,01', locale: 'fr');

    expect(draft.aggregateOverflow, isTrue);
    expect(draft.provisionalSubtotalMinorUnits, isNull);
    expect(draft.canConfirmAllProvidersReviewed, isFalse);
    expect(draft.commit(), isNull);
  });

  test('purge erases every value and never reuses a row id', () {
    final draft = MultiProviderAmountDraft();
    final retired = draft.rows.single.id;
    draft.updateProviderName(retired, 'VIAC');
    draft.updateAmount(retired, '7258', locale: 'fr');
    expect(draft.setAllProvidersReviewed(true), isTrue);
    expect(draft.commit(), isNotNull);

    draft.purge();

    expect(draft.rows, hasLength(1));
    expect(draft.rows.single.id, isNot(retired));
    expect(draft.rows.single.providerName, isEmpty);
    expect(draft.rows.single.rawAmount, isEmpty);
    expect(draft.provisionalSubtotalMinorUnits, isNull);
    expect(draft.allProvidersReviewed, isFalse);
    expect(draft.committedTotalMinorUnits, isNull);
  });

  test('Unicode-equivalent labels cannot bypass duplicate detection', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single.id;
    draft.updateProviderName(first, 'VIAC');
    draft.updateAmount(first, '4000', locale: 'fr');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last.id;
    draft.updateProviderName(second, 'ＶＩＡＣ');
    draft.updateAmount(second, '3000', locale: 'fr');

    expect(draft.duplicateRowIds, {first, second});
    expect(draft.canConfirmAllProvidersReviewed, isFalse);
  });

  test('Unicode whitespace and casefold-equivalent labels are duplicates', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single.id;
    draft.updateProviderName(first, 'Straße Vorsorge');
    draft.updateAmount(first, '4000', locale: 'de');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last.id;
    draft.updateProviderName(second, 'STRASSE\u00a0VORSORGE');
    draft.updateAmount(second, '3000', locale: 'de');

    expect(draft.duplicateRowIds, {first, second});
  });

  test('full Unicode casefold treats dotted-I forms as duplicates', () {
    final draft = MultiProviderAmountDraft();
    final first = draft.rows.single.id;
    draft.updateProviderName(first, 'İ Pension');
    draft.updateAmount(first, '4000', locale: 'de');
    expect(draft.addProvider(), MultiProviderAddResult.added);
    final second = draft.rows.last.id;
    draft.updateProviderName(second, 'i\u0307 pension');
    draft.updateAmount(second, '3000', locale: 'de');

    expect(draft.duplicateRowIds, {first, second});
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
      final row = draft.rows.single.id;
      draft.updateProviderName(row, unsafe);
      draft.updateAmount(row, '1000', locale: 'fr');

      expect(draft.rows.single.hasSafeProviderName, isFalse, reason: unsafe);
      expect(draft.canConfirmAllProvidersReviewed, isFalse);
    }
  });

  test('add result distinguishes an empty row from provider capacity', () {
    final draft = MultiProviderAmountDraft();
    expect(draft.addProvider(), MultiProviderAddResult.existingEmpty);
    for (var index = 0; index < 50; index++) {
      final row = draft.rows.last.id;
      draft.updateProviderName(row, 'Provider $index');
      draft.updateAmount(row, '${index + 1}', locale: 'fr');
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
      final row = draft.rows.single.id;
      draft.updateProviderName(row, 'VIAC');
      draft.updateAmount(row, '7258', locale: 'fr');
      expect(draft.setAllProvidersReviewed(true), isTrue);
      expect(draft.commit(), 725800);

      draft.invalidateConfirmation();

      expect(draft.allProvidersReviewed, isFalse);
      expect(draft.committedTotalMinorUnits, isNull);
    },
  );
}
