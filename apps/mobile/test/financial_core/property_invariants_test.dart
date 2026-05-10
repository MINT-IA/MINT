import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';

// Mobile-only property invariants — CALC-02 Dart fuzz mirror.
// Pure-Dart deterministic loop (1000 iterations, seeded Random) per
// CONTEXT 92.5 D-16 (no Hypothesis-equivalent in Dart ; ship deterministic
// loop instead).
//
// Invariants here cover the canonical Dart calculators that have NO
// Python parity (AvsCalculator.computeMonthlyRente,
// LppCalculator.projectToRetirement). Python parity surface is covered
// in services/backend/tests/test_property_invariants.py.
//
// Plan reference:
//   .planning/phases/92.5-mvp-calc-rigor-foundations/
//     92.5-02-property-suite-PLAN.md (Task 3)

const int _kIterations = 1000;
const int _kSeed = 42;

void main() {
  group('M1 — AvsCalculator.computeMonthlyRente non-negative (LAVS art. 34)', () {
    test('rente >= 0 over 1000 random profiles', () {
      final rng = math.Random(_kSeed);
      for (var i = 0; i < _kIterations; i++) {
        final currentAge = 20 + rng.nextInt(50); // 20..69
        final retirementAge = 63 + rng.nextInt(8); // 63..70
        final salary = rng.nextDouble() * 200000.0; // 0..200k
        final lacunes = rng.nextInt(10); // 0..9
        final rente = AvsCalculator.computeMonthlyRente(
          currentAge: currentAge,
          retirementAge: retirementAge,
          grossAnnualSalary: salary,
          lacunes: lacunes,
        );
        expect(
          rente,
          greaterThanOrEqualTo(0),
          reason: 'iter=$i age=$currentAge ret=$retirementAge salary=$salary '
              'lacunes=$lacunes produced negative rente=$rente',
        );
      }
    });
  });

  group('M2 — AvsCalculator anticipation < 63 returns 0 (LAVS art. 40)', () {
    test('retirementAge in 50..62 always yields rente == 0', () {
      final rng = math.Random(_kSeed + 1);
      for (var i = 0; i < _kIterations; i++) {
        final currentAge = 20 + rng.nextInt(40); // 20..59
        final retirementAge = 50 + rng.nextInt(13); // 50..62 (< 63)
        final salary = rng.nextDouble() * 200000.0;
        final rente = AvsCalculator.computeMonthlyRente(
          currentAge: currentAge,
          retirementAge: retirementAge,
          grossAnnualSalary: salary,
        );
        expect(
          rente,
          0.0,
          reason: 'iter=$i ret=$retirementAge < 63 must yield 0 per LAVS art. 40, '
              'got rente=$rente (avs_calculator.dart:105-107 floor)',
        );
      }
    });
  });

  group('M3 — LppCalculator.projectToRetirement non-negative + monotone (LPP art. 14)', () {
    test('rente >= 0 and monotone in currentBalance over 1000 iterations', () {
      final rng = math.Random(_kSeed + 2);
      for (var i = 0; i < _kIterations; i++) {
        final currentAge = 25 + rng.nextInt(40); // 25..64
        final retirementAge = currentAge + 1 + rng.nextInt(10); // > currentAge
        final salary = 30000.0 + rng.nextDouble() * 170000.0; // 30k..200k
        final balLow = rng.nextDouble() * 200000.0; // 0..200k
        final balHigh = balLow + rng.nextDouble() * 50000.0; // balLow..+50k
        final renteLow = LppCalculator.projectToRetirement(
          currentBalance: balLow,
          currentAge: currentAge,
          retirementAge: retirementAge,
          grossAnnualSalary: salary,
          caisseReturn: 0.015,
          conversionRate: 0.058,
        );
        final renteHigh = LppCalculator.projectToRetirement(
          currentBalance: balHigh,
          currentAge: currentAge,
          retirementAge: retirementAge,
          grossAnnualSalary: salary,
          caisseReturn: 0.015,
          conversionRate: 0.058,
        );
        expect(
          renteLow,
          greaterThanOrEqualTo(0),
          reason: 'iter=$i bal=$balLow produced negative renteLow=$renteLow '
              '(LPP art. 14, lpp_calculator.dart:115 floor)',
        );
        expect(
          renteHigh,
          greaterThanOrEqualTo(renteLow - 0.01),
          reason: 'iter=$i non-monotone: balLow=$balLow renteLow=$renteLow > '
              'balHigh=$balHigh renteHigh=$renteHigh',
        );
      }
    });
  });
}
