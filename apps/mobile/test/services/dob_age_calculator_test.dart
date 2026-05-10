// Regression tests for P3-A03: DOB age math must be month/day-aware.
//
// Year-delta only let a 17-year-old register on the day before their 18th
// birthday because `DateTime.now().year - dob.year` returned 18 even when
// the birthday hadn't happened yet. The picker also now caps `firstDate`
// (now.year - 99) and `lastDate` (now - 18 years) so this validator is
// the second line of defence.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/dob_age_calculator.dart';

void main() {
  group('yearsBetween (P3-A03)', () {
    test('exact 18th birthday → 18', () {
      expect(
        yearsBetween(DateTime(2008, 5, 7), DateTime(2026, 5, 7)),
        18,
      );
    });

    test('day before 18th birthday → 17 (rejected)', () {
      // Born 2008-05-08, today 2026-05-07 → year-delta = 18 but actual age = 17.
      // This is the exact case that BUG-P3-A03 documented.
      expect(
        yearsBetween(DateTime(2008, 5, 8), DateTime(2026, 5, 7)),
        17,
      );
    });

    test('born next month → year-delta is positive but age = year - 1', () {
      expect(
        yearsBetween(DateTime(2025, 12, 1), DateTime(2026, 1, 15)),
        0,
      );
    });

    test('one year exactly → 1', () {
      expect(
        yearsBetween(DateTime(2025, 5, 7), DateTime(2026, 5, 7)),
        1,
      );
    });

    test('born today → 0', () {
      final today = DateTime(2026, 5, 7);
      expect(yearsBetween(today, today), 0);
    });

    test('99-year-old exactly → 99', () {
      expect(
        yearsBetween(DateTime(1927, 1, 1), DateTime(2026, 1, 1)),
        99,
      );
    });

    test('day after birthday vs same day → still increments', () {
      // Born 2008-05-07, today 2008-05-08 → 0 (less than 1 year).
      expect(
        yearsBetween(DateTime(2008, 5, 7), DateTime(2008, 5, 8)),
        0,
      );
      // Born 2008-05-07, today 2009-05-07 → 1 (exact birthday).
      expect(
        yearsBetween(DateTime(2008, 5, 7), DateTime(2009, 5, 7)),
        1,
      );
    });
  });
}
