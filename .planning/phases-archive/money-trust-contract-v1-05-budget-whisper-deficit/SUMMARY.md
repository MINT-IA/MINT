# Money Trust Contract v1 — 05 Budget Whisper Deficit Summary

This phase fixes a deterministic Mon Argent guidance bug: the coach whisper
could not detect a deficit because it checked a non-negative allocation value.

## What Changed

- Added a regression test for a deficit month.
- Changed `CoachWhisperService` to derive signed monthly free cashflow from
  budget inputs.

## Why

`BudgetPlan.available` is intentionally clamped to zero because it represents
money available to allocate. A deficit warning must instead use the signed
cashflow equation: income minus fixed charges minus planned future allocation.

## Next Phase

The next larger phase remains read-model convergence: make Mon Argent, Budget,
coach packet, and report surfaces consume one canonical present-budget view.
