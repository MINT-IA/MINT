/// Tests for residence-permit normalization in [CoachProfile.archetype]
/// and [CoachProfile.isCrossBorder].
///
/// Audit finding 2026-05-08 — wizard option values are
/// `permit_g` / `permit_b` / `permit_c` / `swiss` but the archetype
/// getter compared against `'G'` / `'C'` / `'B'` / `'Swiss'`. Result :
/// every cross-border / expat / Swiss-permit user silently fell through
/// to the default archetype.
///
/// Refs:
/// - Perimeter STUB
///   `.planning/decisions/2026-05-09-perimeter-archetype-input-normalization/STUB.md`
/// - Audit synthesis 2026-05-09 (PR #533) P0 #3 line item
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  group('normalizeResidencePermit — wizard form ↔ canonical', () {
    test('permit_g → G', () {
      expect(normalizeResidencePermit('permit_g'), equals('G'));
    });

    test('permit_b → B', () {
      expect(normalizeResidencePermit('permit_b'), equals('B'));
    });

    test('permit_c → C', () {
      expect(normalizeResidencePermit('permit_c'), equals('C'));
    });

    test('permit_l → L', () {
      expect(normalizeResidencePermit('permit_l'), equals('L'));
    });

    test('swiss → Swiss', () {
      expect(normalizeResidencePermit('swiss'), equals('Swiss'));
    });

    test('canonical G stays G (idempotent)', () {
      expect(normalizeResidencePermit('G'), equals('G'));
    });

    test('lowercase canonical g → G (uppercase)', () {
      expect(normalizeResidencePermit('g'), equals('G'));
    });

    test('null → null', () {
      expect(normalizeResidencePermit(null), isNull);
    });

    test('empty string → null', () {
      expect(normalizeResidencePermit(''), isNull);
      expect(normalizeResidencePermit('   '), isNull);
    });

    test('mixed-case wizard form matches case-insensitively', () {
      expect(normalizeResidencePermit('Permit_G'), equals('G'));
      expect(normalizeResidencePermit('PERMIT_B'), equals('B'));
    });

    test('idempotent: normalize(normalize(x)) == normalize(x)', () {
      const samples = ['permit_g', 'G', 'swiss', 'Swiss', 'B'];
      for (final s in samples) {
        final once = normalizeResidencePermit(s);
        final twice = normalizeResidencePermit(once);
        expect(twice, equals(once), reason: 'failed idempotency on $s');
      }
    });
  });

  group('CoachProfile.isCrossBorder accepts both forms', () {
    test('isCrossBorder true when residencePermit = "permit_g" (wizard form)', () {
      final profile = _buildProfile(residencePermit: 'permit_g');
      expect(profile.isCrossBorder, isTrue);
    });

    test('isCrossBorder true when residencePermit = "G" (canonical)', () {
      final profile = _buildProfile(residencePermit: 'G');
      expect(profile.isCrossBorder, isTrue);
    });

    test('isCrossBorder false when residencePermit = "permit_b"', () {
      final profile = _buildProfile(residencePermit: 'permit_b');
      expect(profile.isCrossBorder, isFalse);
    });

    test('isCrossBorder false when residencePermit = null', () {
      final profile = _buildProfile(residencePermit: null);
      expect(profile.isCrossBorder, isFalse);
    });
  });

  group('CoachProfile.archetype detects crossBorder on wizard form', () {
    test('permit_g → FinancialArchetype.crossBorder', () {
      final profile = _buildProfile(
        residencePermit: 'permit_g',
        nationality: 'FR', // French frontalier
      );
      expect(profile.archetype, equals(FinancialArchetype.crossBorder));
    });

    test('canonical G → FinancialArchetype.crossBorder', () {
      final profile = _buildProfile(
        residencePermit: 'G',
        nationality: 'FR',
      );
      expect(profile.archetype, equals(FinancialArchetype.crossBorder));
    });

    test(
      'PRE-FIX REGRESSION GUARD: permit_g must NEVER fall through to '
      'expatNonEu / expatEu (the bug we are fixing)',
      () {
        final profile = _buildProfile(
          residencePermit: 'permit_g',
          nationality: 'FR',
          arrivalAge: 35,
        );
        expect(profile.archetype, isNot(equals(FinancialArchetype.expatEu)));
        expect(profile.archetype, isNot(equals(FinancialArchetype.expatNonEu)));
        expect(profile.archetype, isNot(equals(FinancialArchetype.swissNative)));
      },
    );
  });

  group('Wizard map exhaustiveness', () {
    test('all 4 wizard option values map to a canonical permit code', () {
      // Mirrors data/wizard_questions_v2.dart:54-61 option values.
      const wizardValues = ['swiss', 'permit_c', 'permit_b', 'permit_g'];
      for (final v in wizardValues) {
        final canonical = normalizeResidencePermit(v);
        expect(
          canonical,
          isNotNull,
          reason: 'wizard value "$v" should map to a canonical permit code',
        );
        expect(
          canonical!.isNotEmpty,
          isTrue,
          reason: 'wizard value "$v" mapped to empty string',
        );
      }
    });
  });
}

CoachProfile _buildProfile({
  String? residencePermit,
  String? nationality,
  int? arrivalAge,
}) {
  return CoachProfile(
    birthYear: 1990,
    canton: 'GE',
    salaireBrutMensuel: 6000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2040),
      label: '',
    ),
    residencePermit: residencePermit,
    nationality: nationality,
    arrivalAge: arrivalAge,
  );
}
