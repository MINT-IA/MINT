/// Tests for [CoachProfile.archetype] tri-state detection and the new
/// [FinancialArchetype.unknown] enum value (Sub-phase 01.5 Wave 02 Plan 01).
///
/// Closes the silent-fallback bug at `coach_profile.dart:1875` where a
/// profile with `nationality == null` was bucketed as `swissNative`.
/// Also asserts the FATCA short-circuit (`usTaxPerson == true` → expatUs
/// regardless of nationality) and the propagation of `usTaxPerson`
/// through `==` / `hashCode` / `fromJson` / `toJson` / `defaults()`.
///
/// Refs:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-02-01-PLAN.md
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-MAPPER-archetype-detection.md §3.1
/// - REVIEWS.md §R1 (enum exhaustiveness) + §R4 (tri-state) + §code-reviewer-verdict
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

CoachProfile _profile({
  String? nationality,
  String? residencePermit,
  String? employmentStatus,
  int? arrivalAge,
  bool? usTaxPerson,
}) {
  return CoachProfile(
    birthYear: 1980,
    canton: 'ZH',
    salaireBrutMensuel: 6000,
    nationality: nationality,
    residencePermit: residencePermit,
    employmentStatus: employmentStatus ?? 'salarie',
    arrivalAge: arrivalAge,
    usTaxPerson: usTaxPerson,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

void main() {
  group('FinancialArchetype.unknown — enum + extension exhaustiveness', () {
    test('FinancialArchetype.unknown exists in the enum values list', () {
      expect(FinancialArchetype.values, contains(FinancialArchetype.unknown));
    });

    test('FinancialArchetype.unknown.backendName returns "unknown"', () {
      expect(FinancialArchetype.unknown.backendName, equals('unknown'));
    });
  });

  group('CoachProfile.archetype — tri-state detection (R1 + R4)', () {
    test('archetype_returns_unknown_when_all_signals_null', () {
      // CoachProfile.defaults() has all five archetype signals null.
      final profile = CoachProfile.defaults();
      expect(profile.archetype, FinancialArchetype.unknown);
    });

    test('archetype_returns_expatUs_when_usTaxPerson_true_with_nationality_ch',
        () {
      final profile = _profile(nationality: 'CH', usTaxPerson: true);
      expect(profile.archetype, FinancialArchetype.expatUs);
    });

    test(
        'archetype_returns_expatUs_when_usTaxPerson_true_with_nationality_null',
        () {
      final profile = _profile(usTaxPerson: true);
      expect(profile.archetype, FinancialArchetype.expatUs);
    });

    test('archetype_returns_swissNative_when_nationality_ch_and_arrived_early',
        () {
      final profile = _profile(nationality: 'CH', arrivalAge: 5);
      expect(profile.archetype, FinancialArchetype.swissNative);
    });

    test('archetype_does_not_assume_ch_when_nationality_null', () {
      // Pre-fix: nationality==null was bucketed swissNative via
      // `isSwiss = nationality == null || nationality == 'CH'`. Now
      // null nationality + arrivalAge present (so not all-signals-null)
      // must NOT silently fall through to swissNative.
      final profile = _profile(arrivalAge: 15);
      expect(profile.archetype, isNot(FinancialArchetype.swissNative));
    });

    test('archetype_returns_crossBorder_for_permit_g', () {
      final profile = _profile(residencePermit: 'G');
      expect(profile.archetype, FinancialArchetype.crossBorder);
    });

    test('archetype_returns_expatUs_for_nationality_us', () {
      final profile = _profile(nationality: 'US');
      expect(profile.archetype, FinancialArchetype.expatUs);
    });
  });

  group('CoachProfile usTaxPerson — propagation (R4)', () {
    test('constructor_accepts_us_tax_person_null', () {
      final profile = _profile();
      expect(profile.usTaxPerson, isNull);
    });

    test('fromJson_preserves_us_tax_person_true', () {
      final base = _profile(usTaxPerson: true);
      final json = base.toJson();
      final parsed = CoachProfile.fromJson(json);
      expect(parsed.usTaxPerson, isTrue);
    });

    test('fromJson_preserves_us_tax_person_null_when_key_absent', () {
      final base = _profile();
      final json = base.toJson();
      // Strip the key entirely to simulate a legacy payload.
      json.remove('usTaxPerson');
      final parsed = CoachProfile.fromJson(json);
      // R4 tri-state: absent key must NOT coerce to false.
      expect(parsed.usTaxPerson, isNull);
    });

    test('toJson_emits_us_tax_person', () {
      final profile = _profile(usTaxPerson: true);
      expect(profile.toJson()['usTaxPerson'], isTrue);
    });

    test('equality_distinguishes_us_tax_person', () {
      final a = _profile();
      final b = _profile(usTaxPerson: true);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });
  });
}
