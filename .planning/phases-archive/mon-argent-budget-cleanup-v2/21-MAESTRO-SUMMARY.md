---
phase: mon-argent-budget-cleanup-v2
plan: 21
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: maestro-runtime-proof
---

# Plan 21 - Maestro Mon Argent / Budget Spine Runtime Proof

## Goal

Run the dedicated Mon Argent + Budget DataSpine flow after the trust-chain
fixes, to validate the central user journey beyond widget tests.

## Flow

- `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
- Simulator: iPhone 17 Pro, iOS 26.2
- Bundle: `ch.mint.app`
- Precondition: debug simulator app built with:
  - `CODE_SIGNING_ALLOWED=NO`
  - `--no-codesign`
  - `MINT_E2E_ARCHETYPE=julien_swiss`
  - `MINT_DISABLE_BETA_MODAL=true`

## Result

- `PASS`
- Duration: `42s`
- JUnit: `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T104720Z/result.xml`
- Log: `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T104720Z/maestro.log`
- Screenshots:
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T104720Z/mon-argent-01-data-spine.png`
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T104720Z/mon-argent-02-budget-setup.png`
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T104720Z/mon-argent-03-budget-direct-relaunch.png`
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T104720Z/mon-argent-04-coach-return.png`

## Assertions Covered

- Mon Argent route renders:
  - screen anchor
  - section selector
  - DataSpine summary
  - situation map
  - month group
  - wealth group
  - pension group
  - month, wealth, pension and future sections by deep link
- Budget setup route renders:
  - housing field
  - LAMal field
  - live total
  - save button
  - chat fallback
- Direct Budget relaunch renders:
  - data quality banner
  - calculation detail toggle
  - formula proof
  - expected fixed charges around `3'140`
  - expected available around `2'239`
- Negative guards did not trigger for:
  - `19'272'200`
  - `420'420`
- Coach route renders:
  - chat screen
  - input field
  - lightning menu button
  - send button

## Notes

This complements Plan 20: Plan 20 proves the cross-surface trust chain through
Rapport and Coach; Plan 21 proves the Mon Argent section map and Budget setup
anchors.
