# Plan 48 — Profile budget plausibility

## Problem

The budget screen path was guarded, but `CoachProfile` still had two raw
expense consumers:

- `isInDebtCrisis` could treat an implausible monthly capture as a real
  emergency-fund shortfall.
- `toBudgetInputs()` returned raw rent instead of the guarded budget derivation.

## Scope

- Add regression tests for both raw-consumer paths.
- Expose the budget plausibility guard as a shared `BudgetInputs` helper.
- Make `CoachProfile.toBudgetInputs()` delegate to
  `BudgetInputs.fromCoachProfile`.
- Apply the same plausible monthly expense basis inside `isInDebtCrisis`.

## Non-goals

- Change debt ratio thresholds.
- Redesign SafeMode copy or UI.
- Change budget setup capture limits.

## Steps

1. Add failing tests for `isInDebtCrisis` and `toBudgetInputs()`.
2. Share the monthly plausibility helper from `BudgetInputs`.
3. Reuse the guarded values in `CoachProfile`.
4. Run model and budget tests plus targeted analyzer.
