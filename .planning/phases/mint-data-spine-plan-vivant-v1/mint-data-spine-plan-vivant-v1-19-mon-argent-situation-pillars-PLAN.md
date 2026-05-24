# Plan 19 — Mon Argent situation + piliers

## Goal
Expose the central financial situation and Swiss 3-pillar facts inside Mon Argent from the existing `DataSpineSnapshot`.

## Scope
- Reuse the current Mint State/Data Spine source.
- Add no new model, route, or ARB key.
- Keep the change small and covered by the existing Mon Argent widget test.

## Acceptance
- Mon Argent shows situation facts: gross annual income, liquid savings, debt.
- Mon Argent shows AVS, LPP, and 3a values with known/partial/missing state.
- Local widget/service tests and design lints stay green.

