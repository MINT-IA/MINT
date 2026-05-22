/// Phase 01.5 W02-T07 Task 2 — R4 cached profile preservation guard.
///
/// Per Codex C2 / C4 (REVIEWS.md 2026-05-22) and the tri-state contract
/// shipped in plan 02-01 :
///   * `usTaxPerson` and `nationality` are tri-state nullable fields.
///   * `null` means « signal not yet collected » — distinct from `false`
///     and distinct from `true`.
///   * A legacy JSON payload (pre-01.5) that lacks these keys must
///     deserialize to `null` for both fields, NEVER coerce to `false` or
///     a default Swiss nationality.
///
/// Why this is the « R4 silent killer » : if `fromJson` silently coerced
/// the missing `usTaxPerson` key to `false`, the next archetype evaluation
/// would mis-classify a real expat_us user as swiss_native and bypass the
/// FATCA hard gate.
///
/// These 5 model-layer tests complement Task 1's `integration_legacy_user_
/// grandfather` integration test : Task 1 verifies the migration FLAGS the
/// ambiguous profile ; Task 2 verifies the model itself preserves the
/// ambiguity (no coercion at the deserialization boundary).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  group('CoachProfile.fromJson — legacy tri-state preservation (R4)', () {
    test(
        'legacy_json_no_us_tax_person_no_nationality_preserves_null: empty '
        'JSON deserializes with usTaxPerson=null AND nationality=null '
        '(NOT false, NOT "CH")', () {
      final profile = CoachProfile.fromJson(<String, dynamic>{});
      expect(profile.usTaxPerson, isNull,
          reason: 'absent key MUST preserve null (R4 silent-coercion guard)');
      expect(profile.nationality, isNull,
          reason: 'absent key MUST preserve null (R4 silent-coercion guard)');
    });

    test(
        'legacy_json_no_us_tax_person_with_nationality_preserves_null_for_us_tax: '
        'CoachProfile.fromJson({"nationality": "CH"}) → usTaxPerson stays null '
        '(absence on one tri-state field MUST NOT contaminate the other)', () {
      final profile =
          CoachProfile.fromJson(<String, dynamic>{'nationality': 'CH'});
      expect(profile.nationality, 'CH',
          reason: 'present nationality must round-trip');
      expect(profile.usTaxPerson, isNull,
          reason:
              'usTaxPerson absent → null (not coerced from nationality signal)');
    });

    test(
        'legacy_json_explicit_null_us_tax_person_preserves_null: explicit '
        '{"usTaxPerson": null} must NOT coerce to false (the R4 silent killer)',
        () {
      final profile =
          CoachProfile.fromJson(<String, dynamic>{'usTaxPerson': null});
      expect(profile.usTaxPerson, isNull,
          reason: 'explicit null MUST round-trip as null, not false');
    });

    test(
        'legacy_json_us_tax_person_true_round_trips: a positive FATCA signal '
        'in JSON survives fromJson → toJson', () {
      final profile =
          CoachProfile.fromJson(<String, dynamic>{'usTaxPerson': true});
      expect(profile.usTaxPerson, isTrue);
      final round = profile.toJson();
      expect(round['usTaxPerson'], isTrue,
          reason: 'toJson must emit usTaxPerson=true verbatim');
    });

    test(
        'legacy_json_us_tax_person_false_round_trips: explicit false survives '
        'roundtrip as false (NOT null, NOT true) — confirms the tri-state '
        'distinguishes the three values cleanly', () {
      final profile =
          CoachProfile.fromJson(<String, dynamic>{'usTaxPerson': false});
      expect(profile.usTaxPerson, isFalse,
          reason: 'explicit false must NOT be coerced to null or true');
      final round = profile.toJson();
      expect(round['usTaxPerson'], isFalse,
          reason: 'toJson must emit usTaxPerson=false verbatim');
    });
  });
}
