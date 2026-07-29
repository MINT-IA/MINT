---
phase: mon-argent-budget-cleanup-v2
plan: 20
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: maestro-runtime-proof
---

# Plan 20 - Maestro Money Trust Chain Runtime Proof

## Goal

Run the runtime flow that matches the highest-risk user complaint in this
phase: Budget, Mon Argent, Rapport and Coach must stay coherent and must not
show absurd money values such as `19'272'200`, `420'420`, `NaN` or `Infinity`.

## Flow

- `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
- Simulator: iPhone 17 Pro, iOS 26.2
- Bundle: `ch.mint.app`
- Build command:
  - `CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
- Install:
  - `xcrun simctl uninstall booted ch.mint.app`
  - `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`
- Runner:
  - `MINT_WALKER_ARTIFACTS=.planning/walker/maestro-flows/money-trust-chain/20260527T104419Z MAESTRO_STALL_THRESHOLD=120 MAESTRO_HARD_LIMIT=420 bash tools/simulator/maestro_with_watchdog.sh test ... --format junit`

## Result

- `PASS`
- Duration: `54s`
- JUnit: `.planning/walker/maestro-flows/money-trust-chain/20260527T104419Z/result.xml`
- Log: `.planning/walker/maestro-flows/money-trust-chain/20260527T104419Z/maestro.log`
- Screenshot: `.planning/walker/maestro-flows/money-trust-chain/20260527T104419Z/money-trust-chain-budget-mon-argent-rapport-coach.png`

## Assertions Covered

- Budget setup accepts and persists:
  - housing: `2'200`
  - LAMal: `420`
- Direct `/budget` relaunch restores the calculation proof.
- Budget detail shows expected values:
  - fixed charges around `3'140`
  - available around `2'239`
- Mon Argent renders the budget summary and flow bar.
- Rapport renders the budget values.
- Coach route and input anchors remain reachable.
- Negative guards did not trigger for:
  - `19'272'200`
  - `420'420`
  - `19M`
  - `420k`
  - `NaN`
  - `Infinity`
  - Flutter visible exception strings on Rapport.

## Notes

The first standard Flutter simulator build failed on `CodeSign`. The known
simulator workaround succeeded: `CODE_SIGNING_ALLOWED=NO` plus `--no-codesign`.
This should remain the default for local Maestro simulator proof on this Mac.
