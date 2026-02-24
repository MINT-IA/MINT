# FINANCIAL CORE CLEANUP PLAN

Date: 2026-02-24
Status: Executed incrementally with validation

## Priority 1 (CRIT)
- Fix onboarding chiffre choc rule to rely on real `existing_3a` value.
- Align Flutter selector rule with backend (`existing3a <= 0 && taxSaving3a > 1500`).

## Priority 2 (CRIT)
- Route mobile onboarding computation to backend endpoints:
  - `POST /api/v1/onboarding/minimal-profile`
  - `POST /api/v1/onboarding/chiffre-choc`
- Keep deterministic local fallback when API is unavailable.

## Priority 3 (HIGH)
- Route `Rente vs Capital` screen to backend endpoint:
  - `POST /api/v1/arbitrage/rente-vs-capital`
- Keep local `ArbitrageEngine` fallback for offline/error conditions.

## Priority 4 (DOC/ORCHESTRATION)
- Fix ORCHESTRATOR patch detection for `Persona "Anna"`.
- Broaden S30.5 commit detection pattern (`financial-core`, `unify calculations`).
- Align S34-S39 phase mapping in `docs/ONBOARDING_ARBITRAGE_ENGINE.md` with Coach roadmap.
- Materialize S30.5 report artifacts under `docs/reports/`.

## Validation strategy
1. Backend targeted tests (onboarding/chiffre choc).
2. Flutter targeted analyze/tests for changed files.
3. Full-suite checks deferred to dedicated quality hardening sprint due pre-existing global warnings.
