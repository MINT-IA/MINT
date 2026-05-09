/// Tests for [FinancialArchetypeBackendName.backendName] extension.
///
/// Audit fix 2026-05-09 (perimeter STUB at
/// `.planning/decisions/2026-05-09-perimeter-fatca-calculator-gate/STUB.md`):
/// Replaces the per-screen ad-hoc conversion (camelCase → snake_case) which
/// was buggy in `rachat_echelonne_screen.dart:191`
/// (`name.replaceAll('_', '_')` was a no-op).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  group('FinancialArchetype.backendName — exhaustive snake_case map', () {
    test('all 8 archetypes return non-empty snake_case strings', () {
      for (final a in FinancialArchetype.values) {
        final name = a.backendName;
        expect(name, isNotEmpty, reason: 'archetype $a → empty backend name');
        expect(
          name,
          isNot(contains(' ')),
          reason: 'archetype $a → contains whitespace',
        );
        // snake_case: only lowercase ASCII letters + underscores.
        expect(
          RegExp(r'^[a-z_]+$').hasMatch(name),
          isTrue,
          reason: 'archetype $a → "$name" not snake_case',
        );
      }
    });

    test('explicit mapping matches backend doctrine_checks expectations', () {
      // Matches the keys in
      // services/backend/app/services/coach/doctrine_checks.py
      // _ARCHETYPE_CUES dict (swiss_native / expat_eu / expat_us / etc.).
      expect(FinancialArchetype.swissNative.backendName, equals('swiss_native'));
      expect(FinancialArchetype.expatEu.backendName, equals('expat_eu'));
      expect(FinancialArchetype.expatNonEu.backendName, equals('expat_non_eu'));
      expect(FinancialArchetype.expatUs.backendName, equals('expat_us'));
      expect(
        FinancialArchetype.independentWithLpp.backendName,
        equals('independent_with_lpp'),
      );
      expect(
        FinancialArchetype.independentNoLpp.backendName,
        equals('independent_no_lpp'),
      );
      expect(FinancialArchetype.crossBorder.backendName, equals('cross_border'));
      expect(
        FinancialArchetype.returningSwiss.backendName,
        equals('returning_swiss'),
      );
    });

    test(
      'PRE-FIX REGRESSION GUARD: enum.name.toLowerCase() does NOT match',
      () {
        // The pre-fix code at rachat_echelonne_screen.dart:191 did
        // `profile.archetype.name.replaceAll('_', '_').toLowerCase()` which
        // produced 'swissnative' / 'crossborder' (no underscore). The
        // backend expects 'swiss_native' / 'cross_border'. The bug went
        // unnoticed because doctrine_checks fell back to the default
        // archetype on every mismatch.
        for (final a in FinancialArchetype.values) {
          final buggy = a.name.toLowerCase();
          final canonical = a.backendName;
          if (canonical.contains('_')) {
            expect(
              buggy,
              isNot(equals(canonical)),
              reason:
                  'Pre-fix path .name.toLowerCase() should differ from '
                  'canonical backendName for $a',
            );
          }
        }
      },
    );
  });
}
