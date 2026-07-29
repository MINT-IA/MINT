---
phase: mon-argent-budget-cleanup-v2
plan: 26
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: maestro-runtime-proof
---

# Plan 26 - Maestro Mon Argent / Budget Post-Gate Proof

## Goal

Re-run the central Mon Argent + Budget runtime flow after the arbitrage canton
gates and neutral-copy fixes, to verify that the core money journey still works
on the iPhone simulator.

## Build

- Simulator: iPhone 17 Pro, iOS 26.2
- Bundle: `ch.mint.app`
- Build command:
  `CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
- Install:
  `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`

## Flow

- `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
- Output root:
  `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/`

## Result

- `PASS`
- Duration: `42s`
- JUnit:
  `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/result.xml`
- Debug log:
  `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/debug/.maestro/tests/2026-05-27_142437/maestro.log`
- Screenshots:
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/mon-argent-01-data-spine.png`
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/mon-argent-02-budget-setup.png`
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/mon-argent-03-budget-direct-relaunch.png`
  - `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T122350Z/mon-argent-04-coach-return.png`

## Assertions Covered

- Mon Argent route renders:
  - screen anchor
  - section selector
  - DataSpine summary
  - situation map
  - month, wealth, pension and future sections
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

The Flutter build rewrote generated l10n files with line-ending churn. Those
generated changes were restored before committing this proof because they were
not source changes.
