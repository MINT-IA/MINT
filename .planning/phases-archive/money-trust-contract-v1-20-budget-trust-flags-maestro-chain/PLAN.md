# Phase 20 — Budget Trust Flags + Maestro Chain

## Goal
Close the budget trust-chain gap and prove the runtime budget spine across
Budget, Mon Argent, Rapport, and Coach.

## Problem
Phase 19 prevented phantom profile defaults from becoming budget inputs, but
the data-quality flags were still too coarse:

- absent LAMal and confirmed LAMal could both appear as `isHealthEstimated:
  false`;
- `userProvidedFields` and `dataSources` were not treated consistently;
- other fixed charges could be inflated by subtracting partially gated totals;
- Mon Argent needed a stable Maestro anchor for the monthly section.

## Scope
- Add explicit missing flags for housing and LAMal in `BudgetInputs`.
- Preserve `ProfileDataSource.estimated` as estimated instead of dropping it.
- Sum other fixed charges only from sourced/trusted sub-posts.
- Surface missing LAMal as a missing quality tag in the Budget UI.
- Add a Maestro flow for Budget setup → Budget → Mon Argent → Rapport → Coach.

## Acceptance Criteria
- Missing, estimated, and provided budget facts remain distinguishable.
- Legacy budgets without housing meta are treated as missing housing.
- Budget provider/storage round-trip preserves data-quality flags.
- Maestro P0 chain passes and rejects absurd values (`19'272'200`,
  `420'420`, `NaN`, `Infinity`) across the main surfaces.
