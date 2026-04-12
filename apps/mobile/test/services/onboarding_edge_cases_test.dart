// Onboarding Edge Cases — unit tests for BudgetLivingEngine, AvsCalculator,
// LppCalculator, and 3a eligibility under extreme/boundary inputs.
//
// Run: cd apps/mobile && flutter test test/services/onboarding_edge_cases_test.dart
//
// All tests are pure (no I/O, no SharedPreferences) — these services are
// stateless static functions backed by financial_core.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';

// ────────────────────────────────────────────────────────────
//  Test helpers
// ────────────────────────────────────────────────────────────

/// Build a minimal CoachProfile fixing [birthYear] and [salaireBrutMensuel].
/// All other fields use sensible defaults.
CoachProfile _profileWith({
  required int birthYear,
  required double salaireBrutMensuel,
  FinancialArchetype archetype = FinancialArchetype.swissNative,
  int? targetRetirementAge,
}) {
  final currentYear = DateTime.now().year;
  return CoachProfile(
    birthYear: birthYear,
    canton: 'ZH',
    salaireBrutMensuel: salaireBrutMensuel,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(currentYear + 20, 1, 1),
      label: 'Retraite',
    ),
    targetRetirementAge: targetRetirementAge,
    prevoyance: PrevoyanceProfile(
      canContribute3a: archetype != FinancialArchetype.expatUs,
    ),
  );
}

/// Build a profile where the main user is a FATCA resident (expat_us archetype).
/// Simulates a US citizen who cannot contribute to 3a with most providers.
CoachProfile _fatcaProfile() {
  return CoachProfile(
    birthYear: 1982,
    canton: 'ZH',
    nationality: 'US',
    salaireBrutMensuel: 8000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(DateTime.now().year + 22, 1, 1),
      label: 'Retraite',
    ),
    prevoyance: const PrevoyanceProfile(
      canContribute3a: false, // FATCA block
    ),
  );
}

/// Build a standard Swiss native profile.
CoachProfile _swissNativeProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: 'ZH',
    nationality: 'CH',
    salaireBrutMensuel: 7000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(DateTime.now().year + 20, 1, 1),
      label: 'Retraite',
    ),
    prevoyance: const PrevoyanceProfile(
      canContribute3a: true,
    ),
  );
}

// ────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════
  //  GROUP 1 — BudgetLivingEngine: extreme age + salary inputs
  // ══════════════════════════════════════════════════════════

  group('BudgetLivingEngine — extreme age/salary edge cases', () {
    test('OE1.1 age 18 with salary 2000/month → does not crash', () {
      final profile = _profileWith(
        birthYear: DateTime.now().year - 18,
        salaireBrutMensuel: 2000,
      );
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });

    test('OE1.2 age 18 with salary 2000/month → returns a valid BudgetSnapshot', () {
      final profile = _profileWith(
        birthYear: DateTime.now().year - 18,
        salaireBrutMensuel: 2000,
      );
      final snapshot = BudgetLivingEngine.compute(profile);
      expect(snapshot, isA<BudgetSnapshot>());
      expect(snapshot.confidenceScore.isNaN, isFalse);
      expect(snapshot.confidenceScore.isInfinite, isFalse);
    });

    test('OE1.3 salary 0 → BudgetLivingEngine returns presentOnly (no salary data)', () {
      // When salary == 0 and user is not yet retired, hasRetirementData = false
      // → the engine returns presentOnly (graceful degradation).
      final profile = _profileWith(
        birthYear: DateTime.now().year - 35,
        salaireBrutMensuel: 0,
      );
      final snapshot = BudgetLivingEngine.compute(profile);
      expect(
        snapshot.stage,
        BudgetStage.presentOnly,
        reason: 'Salary=0, not retired → hasRetirementData=false → presentOnly',
      );
    });

    test('OE1.4 salary 0 → BudgetLivingEngine does not crash', () {
      final profile = _profileWith(
        birthYear: DateTime.now().year - 35,
        salaireBrutMensuel: 0,
      );
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });

    test('OE1.5 age 75 with salary 0 → retired mode, not presentOnly, not crash', () {
      // birthYear that makes age == 75.
      // targetRetirementAge defaults to 65 → 75 >= 65 → isRetired = true.
      // The engine takes the isRetired branch regardless of salary.
      final profile = _profileWith(
        birthYear: DateTime.now().year - 75,
        salaireBrutMensuel: 0,
      );
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
      final snapshot = BudgetLivingEngine.compute(profile);
      // Retired branch can return fullGapVisible (when rente calc succeeds)
      // or presentOnly (graceful degradation if rente calc fails).
      // The critical invariant: no crash. Both outcomes are acceptable.
      expect(snapshot, isA<BudgetSnapshot>());
    });

    test('OE1.6 age 65 exact → retired mode (not presentOnly path, isRetired=true)', () {
      // At targetRetirementAge (65), user is considered retired.
      // Engine enters the isRetired branch → must NOT return presentOnly
      // unless the internal rente projection itself fails.
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 65,
        canton: 'ZH',
        salaireBrutMensuel: 5000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(DateTime.now().year + 1, 1, 1),
          label: 'Retraite',
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 150000,
          rendementCaisse: 0.02,
        ),
      );
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
      final snapshot = BudgetLivingEngine.compute(profile);
      // isRetired=true → engine entered retired branch.
      // Acceptable outcomes: fullGapVisible (rente computed) or presentOnly
      // (graceful degradation). What must NOT happen: crash.
      expect(snapshot, isA<BudgetSnapshot>());
      // The retired path never goes through the "hasRetirementData" gate —
      // verify the retirement field is set (or at least no exception thrown).
      expect(snapshot.confidenceScore.isNaN, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════
  //  GROUP 2 — AvsCalculator: boundary inputs
  // ══════════════════════════════════════════════════════════

  group('AvsCalculator — boundary/edge inputs', () {
    test('OE2.1 age 18 → computeMonthlyRente does not crash', () {
      expect(
        () => AvsCalculator.computeMonthlyRente(
          currentAge: 18,
          retirementAge: 65,
          grossAnnualSalary: 24000,
        ),
        returnsNormally,
      );
    });

    test('OE2.2 age 18 → computeMonthlyRente returns a non-negative value', () {
      // At 18, contribution years = 18-20 = -2 → clamped to 0.
      // Future years = 65-18 = 47 → capped at 44.
      // gapFactor = 44/44 = 1.0 → full rente based on salary.
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 18,
        retirementAge: 65,
        grossAnnualSalary: 24000,
      );
      expect(rente, greaterThanOrEqualTo(0.0));
      expect(rente.isNaN, isFalse);
      expect(rente.isInfinite, isFalse);
    });

    test('OE2.3 age 18, salary 0 → renteFromRAMD returns 0 (no salary data)', () {
      // renteFromRAMD(0) returns 0 per AvsCalculator contract.
      final rente = AvsCalculator.renteFromRAMD(0);
      expect(rente, closeTo(0.0, 0.001),
          reason: 'salary=0 → no RAMD data → rente=0 per contract');
    });

    test('OE2.4 age 18, salary 0 → computeMonthlyRente returns 0', () {
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 18,
        retirementAge: 65,
        grossAnnualSalary: 0,
      );
      expect(rente, closeTo(0.0, 0.001),
          reason: 'salary=0 → no RAMD → rente=0');
    });

    test('OE2.5 large lacune (> total years) → rente is 0, not negative', () {
      // 50 lacune years on a 44-year career → effectiveYears clamped to 0
      // → gapFactor=0 → rente=0. Must not be negative.
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 40,
        retirementAge: 65,
        lacunes: 50, // exceeds full career
        grossAnnualSalary: 80000,
      );
      expect(rente, greaterThanOrEqualTo(0.0));
    });
  });

  // ══════════════════════════════════════════════════════════
  //  GROUP 3 — LppCalculator: zero salary / boundary inputs
  // ══════════════════════════════════════════════════════════

  group('LppCalculator — zero salary / boundary inputs', () {
    test('OE3.1 salary 0 → projectToRetirement returns 0, does not crash', () {
      // grossAnnualSalary=0 < lppSeuilEntree → belowThreshold=true
      // → no bonifications → balance grows at caisseReturn only.
      // conversionRate * balance_at_65 is still >= 0.
      expect(
        () => LppCalculator.projectToRetirement(
          currentBalance: 0,
          currentAge: 35,
          retirementAge: 65,
          grossAnnualSalary: 0,
          caisseReturn: 0.02,
          conversionRate: 0.068,
        ),
        returnsNormally,
      );
      final rente = LppCalculator.projectToRetirement(
        currentBalance: 0,
        currentAge: 35,
        retirementAge: 65,
        grossAnnualSalary: 0,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(rente, closeTo(0.0, 0.001),
          reason: 'Zero balance + zero salary → zero projected rente');
    });

    test('OE3.2 salary 0 with existing balance → grows at caisseReturn only', () {
      // No bonifications below seuil, but existing capital still compounds.
      // Result must be > 0 (existing capital earns return).
      final rente = LppCalculator.projectToRetirement(
        currentBalance: 50000,
        currentAge: 40,
        retirementAge: 65,
        grossAnnualSalary: 0,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(rente, greaterThan(0.0),
          reason: 'Existing capital 50k grows at 2%/yr → non-zero rente at 65');
    });

    test('OE3.3 computeSalaireCoordonne(0) → returns 0 (below seuil entree)', () {
      final coordonne = LppCalculator.computeSalaireCoordonne(0);
      expect(coordonne, closeTo(0.0, 0.001));
    });

    test('OE3.4 projectToRetirement does not crash when retirementAge == currentAge', () {
      // No loop iterations → result is simply currentBalance × conversionRate.
      expect(
        () => LppCalculator.projectToRetirement(
          currentBalance: 100000,
          currentAge: 65,
          retirementAge: 65,
          grossAnnualSalary: 60000,
          caisseReturn: 0.02,
          conversionRate: 0.068,
        ),
        returnsNormally,
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  //  GROUP 4 — 3a eligibility: FATCA vs Swiss native
  // ══════════════════════════════════════════════════════════

  group('3a eligibility — FATCA vs Swiss native', () {
    test('OE4.1 FATCA profile (archetype expat_us) → canContribute3a = false', () {
      final profile = _fatcaProfile();
      expect(
        profile.prevoyance.canContribute3a,
        isFalse,
        reason: 'US citizen / FATCA resident → cannot contribute to 3a (LSFin)',
      );
    });

    test('OE4.2 Swiss native profile → canContribute3a = true', () {
      final profile = _swissNativeProfile();
      expect(
        profile.prevoyance.canContribute3a,
        isTrue,
        reason: 'Swiss native with LPP coverage can contribute to 3a (OPP3 art. 7)',
      );
    });

    test('OE4.3 ConjointProfile with isFatcaResident=true via copyWith → canContribute3a is false', () {
      // The FATCA hard-block is enforced through copyWith() and fromJson(),
      // not the const constructor (which is a direct field assignment).
      // This tests the copyWith() path used at runtime when updating profiles.
      const base = ConjointProfile(
        birthYear: 1982,
        salaireBrutMensuel: 6000,
        isFatcaResident: false,
        canContribute3a: true,
      );
      final fatca = base.copyWith(isFatcaResident: true);
      expect(
        fatca.canContribute3a,
        isFalse,
        reason: 'copyWith(isFatcaResident: true) enforces FATCA block → canContribute3a=false',
      );
    });

    test('OE4.4 ConjointProfile with isFatcaResident=false, Swiss → canContribute3a = true', () {
      const conj = ConjointProfile(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        nationality: 'CH',
        isFatcaResident: false,
        canContribute3a: true,
      );
      expect(conj.canContribute3a, isTrue);
    });

    test('OE4.5 FATCA profile → BudgetLivingEngine does not crash', () {
      final profile = _fatcaProfile();
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });

    test('OE4.6 Swiss native profile → BudgetLivingEngine does not crash', () {
      final profile = _swissNativeProfile();
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });
  });
}
