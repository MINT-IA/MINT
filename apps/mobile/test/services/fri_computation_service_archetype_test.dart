/// Tests for R2 + Gemini C4 — `FriComputationService.detectArchetype`
/// returns 'unknown' for null-signal AND empty-string-signal inputs,
/// and preserves existing archetype semantics for positive signals.
///
/// Sub-phase 01.5 Wave 02 Plan 01 Task 3 (R2 + Gemini C4 fix 2026-05-22).
///
/// Gemini C4: null and empty string must be handled IDENTICALLY as
/// "no signal". The pre-fix detector branched on `nat == ''` separately
/// from null checks elsewhere, which created subtle drift between the
/// typed getter (coach_profile.dart) and this string-slug detector.
/// The fixed detector uses `?.isEmpty ?? true` so absent + empty both
/// count as "absent".
///
/// Refs:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-02-01-PLAN.md Task 3 Step 3.3.
/// - REVIEWS.md §R2 + §C4.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';

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
  group(
      'FriComputationService.detectArchetype — null-signal absence (R2 + R4)',
      () {
    test('returns_unknown_when_signals_null', () {
      final p = _profile();
      expect(FriComputationService.detectArchetype(p), equals('unknown'));
    });

    test('returns_unknown_when_signals_empty_strings_gemini_c4_parity', () {
      // Gemini C4: empty strings must be treated IDENTICALLY as null
      // (no signal). Pre-fix, the detector mixed lowercase-then-compare-to-''
      // semantics that could diverge from the typed getter contract.
      final p = _profile(
        nationality: '',
        residencePermit: '',
      );
      expect(FriComputationService.detectArchetype(p), equals('unknown'));
    });
  });

  group(
      'FriComputationService.detectArchetype — positive signals preserved',
      () {
    test('returns_swiss_native_for_ch', () {
      final p = _profile(nationality: 'CH');
      expect(FriComputationService.detectArchetype(p), equals('swiss_native'));
    });

    test('returns_expat_us_for_us', () {
      final p = _profile(nationality: 'US');
      expect(FriComputationService.detectArchetype(p), equals('expat_us'));
    });

    test('returns_expat_us_for_us_tax_person_true_with_other_nationality', () {
      // R4 FATCA short-circuit: usTaxPerson true wins over nationality
      // (mirrors the typed getter from Task 1).
      final p = _profile(nationality: 'FR', usTaxPerson: true);
      expect(FriComputationService.detectArchetype(p), equals('expat_us'));
    });

    test('returns_cross_border_for_permit_g', () {
      final p = _profile(residencePermit: 'G');
      expect(FriComputationService.detectArchetype(p), equals('cross_border'));
    });
  });
}
