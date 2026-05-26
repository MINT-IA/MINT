# Money Trust Contract v1 — 07 Budget Read Model Convergence Summary

## Changes

- Added `BudgetProvider.hydrateFromProfileState(...)` as the single budget
  startup arbitration rule for Mon Argent and Budget.
- Replaced duplicated hydration branches in `BudgetContainerScreen` and
  `MonArgentScreen` with the provider method.
- Added provider-level tests for null profile, partial profile with cache, and
  complete profile replacing stale cache.
- Added a Budget setup convergence test proving one save updates canonical
  storage, `CoachProfileProvider`, and `BudgetProvider`.

## Product Decision

Mon Argent remains the cockpit, Budget remains the editable monthly proof, and
the provider owns the rule for which budget source is freshest. Financial Report
still needs a follow-up phase because it recomputes budget values from raw
answers instead of consuming the shared read model.

## Follow-up

- Phase 08: migrate `FinancialReportScreenV2` budget section to
  `BudgetInputs + BudgetService`.
- Add Maestro parity assertions for Mon Argent -> Budget -> Report once the
  report is on the same read model.
