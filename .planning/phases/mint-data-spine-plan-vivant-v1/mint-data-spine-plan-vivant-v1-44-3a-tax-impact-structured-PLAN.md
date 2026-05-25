# Plan 44 — Structured 3a tax impact

## Problem

The app needs both values: deductible 3a room and estimated tax impact. Returning
only a number makes it too easy for UI or coach copy to confuse the two.

## Scope

- Structured 3a tax-impact result in `financial_core`.
- Compatibility wrapper for `estimate3aTaxSaving`.
- Full-year, first-year pro-rata, and scanned marginal-rate cases.

## Non-goals

- UI rewiring, backend parity, new tax scale model.

## Steps

1. Add failing tests for structured 3a impact.
2. Implement `Pillar3aTaxImpactEstimate` and confidence enum.
3. Let `estimateTaxSaving` accept scanned marginal rates.
4. Verify targeted services and analyzer.

## Acceptance Criteria

- The result exposes ceiling, pro-rated ceiling, deductible contribution,
  marginal rate, estimated tax saving, and confidence.
- Estimated tax saving is below the deductible contribution for normal cases.
- Existing callers of `estimate3aTaxSaving` still pass.
