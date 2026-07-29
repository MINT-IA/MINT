---
phase: mon-argent-budget-cleanup-v2
plan: 27
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: maestro-runtime-proof
---

# Plan 27 - Maestro Money Trust Chain Post-Gate Proof

## Goal

Re-run the full money trust-chain flow after the arbitrage canton gates and
neutral-copy fixes: Budget setup, direct Budget relaunch, Mon Argent, Rapport
and Coach.

## Flow

- `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
- Simulator: iPhone 17 Pro, iOS 26.2
- Bundle: `ch.mint.app`
- Precondition: debug simulator app built with:
  - `CODE_SIGNING_ALLOWED=NO`
  - `--no-codesign`
  - `MINT_E2E_ARCHETYPE=julien_swiss`
  - `MINT_DISABLE_BETA_MODAL=true`

## Result

- `PASS`
- Duration: `54s`
- JUnit:
  `.planning/walker/maestro-flows/money-trust-chain/20260527T123000Z/result.xml`
- Debug log:
  `.planning/walker/maestro-flows/money-trust-chain/20260527T123000Z/debug/.maestro/tests/2026-05-27_143018/maestro.log`
- Screenshot:
  `.planning/walker/maestro-flows/money-trust-chain/20260527T123000Z/money-trust-chain-budget-mon-argent-rapport-coach.png`

## Assertions Covered

- Budget setup accepts fixed-charge inputs:
  - housing: `2'200`
  - LAMal: `420`
- Direct Budget relaunch restores the saved read model.
- Budget formula proof renders expected values:
  - fixed charges around `3'140`
  - available around `2'239`
- Mon Argent month section renders:
  - `mon_argent_budget_summary`
  - `mon_argent_budget_flow_bar`
- Rapport renders `Ton Plan Mint`, `Ton Budget`, and the edited budget values.
- Coach chat remains reachable with input/send anchors.
- Negative guards did not trigger across Budget, Mon Argent, Rapport and Coach:
  - `19'272'200`
  - `420'420`
  - `19M`
  - `420k`
  - `NaN`
  - `Infinity`
  - `A RenderFlex overflowed`
  - `Exception caught`
  - `NoSuchMethodError`

## Notes

This complements Plan 26. Plan 26 validates the Mon Argent section spine and
Budget setup surfaces; Plan 27 validates cross-surface number trust after a
runtime restart and across Rapport and Coach.
