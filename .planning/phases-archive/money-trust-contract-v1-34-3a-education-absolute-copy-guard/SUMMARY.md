# Phase 34 Summary — 3a Education Absolute Copy Guard

## What Changed

- Added `apps/mobile/test/data/financial_explanations_test.dart`.
- Updated `FinancialExplanations.pillar3aRealReturnExplanation` to describe:
  - potential tax deduction,
  - estimated net cost,
  - estimated equivalent yield,
  - 3a illiquidity and support-dependent returns.
- Updated `Pillar3aComparatorWidget` title and short explanation away from "VIAC is unbeatable".
- Replaced the hard-coded 35% fiscal impact assumption with a simple income-derived estimate based on the widget's `monthlyIncome`.

## Why

MINT should teach the 3a lever without making absolute investment claims. A product comparison can be useful, but the user must understand the assumptions, illiquidity, and estimation boundaries.

## Result

The 3a education flow is still clear and motivating, but now aligned with trust-first fintech language.
