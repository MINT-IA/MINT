# FINANCIAL CORE AUDIT

Date: 2026-02-24
Scope: Sprint S30.5 prerequisite audit for Coach Vivant (S31+)

## Baseline
- Backend tests: 2424 passed, 80 skipped
- Backend lint: ruff reports remaining hygiene issues (unused imports, ambiguous names)
- Flutter analyze: warnings/info debt remains in repository

## Findings (S30.5)
1. Duplicate financial logic still existed in onboarding services instead of strict `financial_core` usage.
2. Backend/Flutter divergence risk on minimal onboarding assumptions (expenses/net approximations).
3. Chiffre choc selection rule for 3a had an edge-case bug (`existing_3a == 0` not enforced with the actual value).
4. Orchestration traceability artifacts were missing from `docs/reports/`.

## Canonical direction
- Backend remains source of truth for financial outputs.
- Flutter consumes backend outputs for onboarding/arbitrage where endpoints exist.
- Local calculations are fallback only when API is unreachable.

## Evidence snapshot
- Core unification commits observed in history:
  - `656e620` refactor(financial-core): eliminate duplicate calculators
  - `42195a9` refactor(financial-core): unify calculations
- Coach rollout commits S31-S40 observed from `ef25060` to `dd896ef` + follow-up `b01cbc3`.

## Risks still open
- Repository-wide lint debt (not blocker for calculation correctness but affects quality gates).
- Some legacy Flutter flows still use local computation paths and should be progressively migrated to backend endpoints.
