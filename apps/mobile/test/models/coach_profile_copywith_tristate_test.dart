/// Regression guard for the [CoachProfile.copyWith] sentinel pattern that
/// preserves explicit-null writes on tri-state nullable fields.
///
/// Codex C2 HIGH (REVIEWS.md 2026-05-22 §C2): the standard Dart `??`
/// null-coalescing pattern (`usTaxPerson: usTaxPerson ?? this.usTaxPerson`)
/// BLOCKS explicit null assignment. A caller writing
/// `profile.copyWith(usTaxPerson: null)` to RESET the FATCA signal would
/// get the previous value preserved instead — silently breaking the R4
/// tri-state contract (null = "not asked yet", false = "explicit
/// non-US declaration"). Fix: Object sentinel pattern applied to ALL
/// nullable fields where null is a meaningful semantic value.
///
/// A `??`-pattern copyWith fails the explicit-null tests below. The
/// sentinel-pattern copyWith introduced in Wave 02 Plan 01 (Step 1.9)
/// passes all five.
///
/// Refs:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-02-01-PLAN.md Step 1.9
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-REVIEWS.md §C2 (Codex HIGH)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

CoachProfile _profile({String? nationality, bool? usTaxPerson}) {
  return CoachProfile(
    birthYear: 1980,
    canton: 'ZH',
    salaireBrutMensuel: 6000,
    nationality: nationality,
    usTaxPerson: usTaxPerson,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

void main() {
  group('CoachProfile.copyWith — sentinel pattern (Codex C2 HIGH fix)', () {
    test('copyWith_explicit_null_clears_us_tax_person', () {
      final base = _profile(usTaxPerson: true);
      final cleared = base.copyWith(usTaxPerson: null);
      expect(cleared.usTaxPerson, isNull,
          reason:
              'Explicit null on usTaxPerson MUST overwrite (R4 tri-state)');
    });

    test('copyWith_explicit_null_clears_nationality', () {
      final base = _profile(nationality: 'CH');
      final cleared = base.copyWith(nationality: null);
      expect(cleared.nationality, isNull,
          reason: 'Explicit null on nationality MUST overwrite');
    });

    test('copyWith_omitted_arg_preserves_us_tax_person', () {
      final base = _profile(usTaxPerson: true);
      final copy = base.copyWith();
      expect(copy.usTaxPerson, isTrue,
          reason: 'Sentinel default keeps the previous value when omitted');
    });

    test('copyWith_omitted_arg_preserves_nationality', () {
      final base = _profile(nationality: 'CH');
      final copy = base.copyWith();
      expect(copy.nationality, equals('CH'));
    });

    test('copyWith_explicit_set_overwrites_us_tax_person', () {
      final base = _profile();
      final updated = base.copyWith(usTaxPerson: false);
      expect(updated.usTaxPerson, isFalse,
          reason: 'Explicit false on usTaxPerson MUST land as false, not null');
    });
  });
}
