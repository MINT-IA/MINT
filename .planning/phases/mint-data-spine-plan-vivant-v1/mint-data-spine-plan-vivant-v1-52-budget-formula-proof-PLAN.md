# Plan 52 — Budget formula proof

## Problem

The monthly budget screen now rejects implausible captured values, but the
visible "available" number still needs to be auditable at a glance. If the
screen only shows a result, users cannot easily understand whether Mint used
their income, fixed charges, and future allocation correctly.

## Scope

- Add a compact proof row to the budget flow map:
  `net income - charges - future = available`.
- Expose the row through a stable Maestro semantics anchor.
- Extend the budget smoke test so the anchor cannot disappear silently.

## Non-goals

- Change the budget formula.
- Add new data sources.
- Add new localized strings.
- Redesign the full budget screen.

## Steps

1. Add a failing widget assertion for the new `budget_formula_proof` anchor.
2. Render the proof row inside the existing budget flow map.
3. Keep the text derived from existing localized labels and formatted CHF
   values.
4. Run targeted budget tests and static analysis.
5. Re-run the Maestro budget flow on simulator.
