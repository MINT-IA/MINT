/// Tests for [CoachProfile.ageOrNull] — Wave B-minimal B6.
///
/// Contract: returns `null` when birthYear/dateOfBirth is missing or out of
/// valid range (future date, impossible old age). Returns a valid `int`
/// otherwise. Consumers (CapEngine, simulators) rely on null to skip
/// age-dependent logic rather than silently compute with `age=0`.
///
/// Refs:
/// - Panel 7 Perfection Gap finding #7
/// - Panel archi review 2026-04-18 (30+ call-sites)
/// - Panel adversaire BUG 4 (CapEngine 10 call-sites)
/// - `.planning/wave-b-home-orchestrateur/PLAN.md` B6-minimal
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  group('CoachProfile.ageOrNull — B6-minimal contract', () {
    final currentYear = DateTime.now().year;

    test('birthYear=0 (default/unset) returns null', () {
      final profile = _buildProfile(birthYear: 0);
      expect(profile.ageOrNull, isNull);
      // Legacy `age` getter still returns 0 for back-compat.
      expect(profile.age, equals(0));
    });

    test('birthYear in the future returns null', () {
      final profile = _buildProfile(birthYear: currentYear + 5);
      expect(profile.ageOrNull, isNull);
      expect(profile.age, equals(0));
    });

    test('birthYear far in the past (before 1900) returns null', () {
      final profile = _buildProfile(birthYear: 1800);
      expect(profile.ageOrNull, isNull);
    });

    test('birthYear valid working-age returns correct age', () {
      final profile = _buildProfile(birthYear: 1977);
      expect(profile.ageOrNull, equals(currentYear - 1977));
      expect(profile.age, equals(currentYear - 1977));
    });

    test('birthYear valid child (loose max bound) returns positive age', () {
      // Newborns or very young users (custodial accounts): age can be 0-9.
      // The helper allows [1900, currentYear+1] — a birthYear of
      // currentYear returns 0 which is a valid age (just born).
      final profile = _buildProfile(birthYear: currentYear);
      expect(profile.ageOrNull, equals(0));
    });

    test('dateOfBirth in the future returns null', () {
      final profile = _buildProfile(
        birthYear: 0,
        dateOfBirth: DateTime(currentYear + 2, 1, 1),
      );
      expect(profile.ageOrNull, isNull);
    });

    test('dateOfBirth impossibly old (>150) returns null', () {
      final profile = _buildProfile(
        birthYear: 0,
        dateOfBirth: DateTime(currentYear - 200, 1, 1),
      );
      expect(profile.ageOrNull, isNull);
    });

    test('dateOfBirth valid returns correct age', () {
      final profile = _buildProfile(
        birthYear: 0,
        dateOfBirth: DateTime(1977, 1, 12),
      );
      final expected = currentYear - 1977 -
          (DateTime.now().isBefore(
                  DateTime(currentYear, 1, 12))
              ? 1
              : 0);
      expect(profile.ageOrNull, equals(expected));
    });

    test('dateOfBirth takes precedence over birthYear', () {
      // When both are set, dateOfBirth wins (more precise).
      final profile = _buildProfile(
        birthYear: 1980,
        dateOfBirth: DateTime(1977, 6, 15),
      );
      // Expected age ~ currentYear - 1977 (roughly).
      final age = profile.ageOrNull;
      expect(age, isNotNull);
      expect(age, closeTo(currentYear - 1977, 1));
    });

    test(
      'legacy contract: age getter preserves 0-sentinel for back-compat',
      () {
        // Readiness gates still read `profile.age == 0` as "missing" per
        // the CHAOS-3 convention. B6-minimal documents this but does not
        // remove it (that is Wave E systemic migration).
        final empty = _buildProfile(birthYear: 0);
        expect(empty.age, equals(0));
        // New callers should prefer ageOrNull == null check.
        expect(empty.ageOrNull, isNull);
      },
    );
  });
}

/// Helper that builds a minimal [CoachProfile] with only the fields
/// required to test age resolution. Fills the required constructor
/// parameters with safe neutral defaults so each test stays readable.
CoachProfile _buildProfile({
  required int birthYear,
  DateTime? dateOfBirth,
}) {
  return CoachProfile(
    birthYear: birthYear,
    dateOfBirth: dateOfBirth,
    canton: 'VS',
    salaireBrutMensuel: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2040),
      label: '',
    ),
  );
}
