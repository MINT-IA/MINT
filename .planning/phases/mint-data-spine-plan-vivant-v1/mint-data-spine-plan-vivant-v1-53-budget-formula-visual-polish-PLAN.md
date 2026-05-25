# Plan 53 — Budget formula visual polish

## Problem

Plan 52 made the budget formula auditable, but the first visual screenshot
showed the proof row as a framed element inside an existing card. That made the
screen feel heavier than necessary and created a nested-card pattern.

## Scope

- Keep the `budget_formula_proof` anchor and semantics label.
- Replace the framed proof chip with a native equation stack inside the flow
  map.
- Keep the formula readable on narrow mobile widths.
- Update the widget test where the new equation stack duplicates an existing
  label.

## Non-goals

- Change the budget formula.
- Change persisted budget inputs.
- Change Maestro route mechanics.

## Steps

1. Inspect the simulator screenshot after Plan 52.
2. Replace the framed proof chip with a compact row stack.
3. Re-run targeted budget tests and analysis.
4. Rebuild the simulator app and inspect the revised screenshot.
