// ────────────────────────────────────────────────────────────
//  BUDGET SNAPSHOT — Model Tests
// ────────────────────────────────────────────────────────────
//
//  Tests for BudgetSnapshot, PresentBudget, RetirementBudget,
//  BudgetGap, and BudgetCapImpact.
//
//  Invariants verified:
//  - monthlyFree = monthlyNet - monthlyCharges - monthlySavings
//  - isDeficit flag
//  - chargesRatio calculation and clamping
//  - Zero income edge cases
//  - Negative free amounts
//  - BudgetGap: isSignificant, isSurplus
//  - BudgetStage transitions reflected in hasFullGap
//  - BudgetSnapshot.monthlyFree delegates to present
// ────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';

void main() {
  // ── PresentBudget ─────────────────────────────────────────────

  group('PresentBudget — monthlyFree invariant', () {
    test('monthlyFree equals net minus charges minus savings', () {
      const budget = PresentBudget(
        monthlyNet: 8000,
        monthlyCharges: 3500,
        monthlySavings: 600,
        monthlyFree: 3900, // 8000 - 3500 - 600
      );
      expect(
        budget.monthlyFree,
        closeTo(budget.monthlyNet - budget.monthlyCharges - budget.monthlySavings, 0.01),
      );
    });

    test('isDeficit is false when monthlyFree is positive', () {
      const budget = PresentBudget(
        monthlyNet: 6000,
        monthlyCharges: 3000,
        monthlySavings: 500,
        monthlyFree: 2500,
      );
      expect(budget.isDeficit, isFalse);
    });

    test('isDeficit is true when monthlyFree is negative', () {
      const budget = PresentBudget(
        monthlyNet: 4000,
        monthlyCharges: 3800,
        monthlySavings: 600,
        monthlyFree: -400, // 4000 - 3800 - 600
      );
      expect(budget.isDeficit, isTrue);
    });

    test('isDeficit is false when monthlyFree is exactly zero', () {
      const budget = PresentBudget(
        monthlyNet: 4400,
        monthlyCharges: 3800,
        monthlySavings: 600,
        monthlyFree: 0,
      );
      expect(budget.isDeficit, isFalse);
    });
  });

  group('PresentBudget — chargesRatio', () {
    test('chargesRatio is charges / net * 100', () {
      const budget = PresentBudget(
        monthlyNet: 8000,
        monthlyCharges: 4000,
        monthlySavings: 0,
        monthlyFree: 4000,
      );
      expect(budget.chargesRatio, closeTo(50.0, 0.01));
    });

    test('chargesRatio is 0 when monthlyNet is 0 (no division by zero)', () {
      const budget = PresentBudget(
        monthlyNet: 0,
        monthlyCharges: 500,
        monthlySavings: 0,
        monthlyFree: -500,
      );
      expect(budget.chargesRatio, equals(0.0));
    });

    test('chargesRatio is clamped to max 200 when charges exceed 2x net', () {
      const budget = PresentBudget(
        monthlyNet: 1000,
        monthlyCharges: 5000,
        monthlySavings: 0,
        monthlyFree: -4000,
      );
      expect(budget.chargesRatio, equals(200.0));
    });

    test('chargesRatio is 100 when charges equal net', () {
      const budget = PresentBudget(
        monthlyNet: 5000,
        monthlyCharges: 5000,
        monthlySavings: 0,
        monthlyFree: 0,
      );
      expect(budget.chargesRatio, closeTo(100.0, 0.01));
    });
  });

  // ── BudgetGap ─────────────────────────────────────────────────

  group('BudgetGap — isSignificant', () {
    test('isSignificant is true when gap > 20% of presentNet', () {
      const gap = BudgetGap(monthlyGap: 2000, replacementRate: 60);
      expect(gap.isSignificant(8000), isTrue); // 2000 / 8000 = 25% > 20%
    });

    test('isSignificant is false when gap <= 20% of presentNet', () {
      const gap = BudgetGap(monthlyGap: 1000, replacementRate: 80);
      expect(gap.isSignificant(8000), isFalse); // 1000 / 8000 = 12.5% < 20%
    });

    test('isSignificant is false when presentNet is 0', () {
      const gap = BudgetGap(monthlyGap: 500, replacementRate: 0);
      expect(gap.isSignificant(0), isFalse);
    });

    test('isSignificant is false when gap is exactly 20% of presentNet', () {
      const gap = BudgetGap(monthlyGap: 1600, replacementRate: 72);
      // 1600 / 8000 = 0.20 — not strictly greater than
      expect(gap.isSignificant(8000), isFalse);
    });
  });

  group('BudgetGap — isSurplus', () {
    test('isSurplus is true when monthlyGap is negative', () {
      const gap = BudgetGap(monthlyGap: -500, replacementRate: 110);
      expect(gap.isSurplus, isTrue);
    });

    test('isSurplus is false when monthlyGap is positive', () {
      const gap = BudgetGap(monthlyGap: 1500, replacementRate: 70);
      expect(gap.isSurplus, isFalse);
    });

    test('isSurplus is false when monthlyGap is zero', () {
      const gap = BudgetGap(monthlyGap: 0, replacementRate: 100);
      expect(gap.isSurplus, isFalse);
    });
  });

  // ── BudgetSnapshot ────────────────────────────────────────────

  group('BudgetSnapshot — monthlyFree delegation', () {
    test('monthlyFree on snapshot delegates to present.monthlyFree', () {
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 7000,
          monthlyCharges: 3000,
          monthlySavings: 500,
          monthlyFree: 3500,
        ),
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 55,
      );
      expect(snapshot.monthlyFree, equals(3500));
    });
  });

  group('BudgetSnapshot — hasFullGap', () {
    test('hasFullGap is true when stage is fullGapVisible and gap is present', () {
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 7000,
          monthlyCharges: 3000,
          monthlySavings: 500,
          monthlyFree: 3500,
        ),
        retirement: RetirementBudget(
          monthlyIncome: 4500,
          monthlyTax: 200,
          monthlyNet: 4300,
        ),
        gap: BudgetGap(monthlyGap: 2700, replacementRate: 61),
        capImpacts: [],
        stage: BudgetStage.fullGapVisible,
        confidenceScore: 75,
      );
      expect(snapshot.hasFullGap, isTrue);
    });

    test('hasFullGap is false when stage is presentOnly (no retirement data)', () {
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 5000,
          monthlyCharges: 2500,
          monthlySavings: 300,
          monthlyFree: 2200,
        ),
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 30,
      );
      expect(snapshot.hasFullGap, isFalse);
    });

    test('hasFullGap is false when stage is emergingRetirement', () {
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 6000,
          monthlyCharges: 2800,
          monthlySavings: 400,
          monthlyFree: 2800,
        ),
        retirement: RetirementBudget(
          monthlyIncome: 3500,
          monthlyTax: 150,
          monthlyNet: 3350,
        ),
        gap: BudgetGap(monthlyGap: 1650, replacementRate: 55),
        capImpacts: [],
        stage: BudgetStage.emergingRetirement,
        confidenceScore: 38,
      );
      expect(snapshot.hasFullGap, isFalse);
    });

    test('hasFullGap is false when stage is fullGapVisible but gap is null', () {
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 8000,
          monthlyCharges: 3500,
          monthlySavings: 600,
          monthlyFree: 3900,
        ),
        capImpacts: [],
        stage: BudgetStage.fullGapVisible,
        confidenceScore: 80,
        // gap intentionally omitted — null
      );
      expect(snapshot.hasFullGap, isFalse);
    });
  });

  // ── Zero income edge case ─────────────────────────────────────

  group('Zero income edge cases', () {
    test('PresentBudget with zero net income constructs without error', () {
      const budget = PresentBudget(
        monthlyNet: 0,
        monthlyCharges: 0,
        monthlySavings: 0,
        monthlyFree: 0,
      );
      expect(budget.monthlyFree, equals(0));
      expect(budget.isDeficit, isFalse);
      expect(budget.chargesRatio, equals(0.0));
    });

    test('RetirementBudget with zero income constructs without error', () {
      const ret = RetirementBudget(
        monthlyIncome: 0,
        monthlyTax: 0,
        monthlyNet: 0,
      );
      expect(ret.monthlyNet, equals(0));
    });
  });

  // ── BudgetCapImpact ───────────────────────────────────────────

  group('BudgetCapImpact', () {
    test('stores capId and monthlyDelta correctly', () {
      const impact = BudgetCapImpact(capId: 'rachat_lpp', monthlyDelta: 320.0);
      expect(impact.capId, equals('rachat_lpp'));
      expect(impact.monthlyDelta, closeTo(320.0, 0.01));
    });

    test('negative monthlyDelta (gap widens) is stored as-is', () {
      const impact = BudgetCapImpact(capId: 'test_cap', monthlyDelta: -50.0);
      expect(impact.monthlyDelta, isNegative);
    });
  });

  // ── BudgetStage enum ──────────────────────────────────────────

  group('BudgetStage enum values', () {
    test('all three stages are distinct', () {
      expect(BudgetStage.presentOnly, isNot(equals(BudgetStage.emergingRetirement)));
      expect(BudgetStage.emergingRetirement, isNot(equals(BudgetStage.fullGapVisible)));
      expect(BudgetStage.presentOnly, isNot(equals(BudgetStage.fullGapVisible)));
    });
  });
}
