# CJT-024 Post-Fix Regression Wave — 2026-06-04

## Scope

Post-fix runtime proof after `84a33b736` and `74cb97d36`.

## Commands

```bash
python3 tools/checks/maestro_locator_audit.py
MAESTRO_HARD_LIMIT=600 MAESTRO_STALL_THRESHOLD=90 tools/simulator/maestro_sweep.sh --tier regression
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-024-money-trust-rerun-20260604T084601 MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=75 bash tools/simulator/maestro_with_watchdog.sh test --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-024-money-trust-rerun-20260604T084601/debug --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-024-money-trust-rerun-20260604T084601/result.xml tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/storytelling/cjt-010-rapport-fallback-rerun-20260604T084810 MAESTRO_HARD_LIMIT=180 MAESTRO_STALL_THRESHOLD=60 bash tools/simulator/maestro_with_watchdog.sh test --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/storytelling/cjt-010-rapport-fallback-rerun-20260604T084810/debug --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/storytelling/cjt-010-rapport-fallback-rerun-20260604T084810/result.xml tools/simulator/flows/maestro-perfect-set/flow_rapport_budget_read_model_spine.yaml
```

## Results

- Static locator audit: `35` flows scanned, `1` skipped, `366` locators, all resolved.
- Regression sweep: `.planning/_walker/sweep-20260604T084055/sweep-summary.md`, `6/6` green, `0` red, `0` stalled, `0` hard-limit.
- Money Trust rerun: `flow_money_trust_chain_budget_mon_argent_rapport_coach`, iPhone 17 Pro iOS 26.2, `tests=1`, `failures=0`, `time=99.0`.
- Rapport fallback rerun: `flow_rapport_budget_read_model_spine`, iPhone 17 Pro iOS 26.2, `tests=1`, `failures=0`, `time=38.0`.

## Evidence

- `.planning/_walker/sweep-20260604T084055/`
- `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-024-money-trust-rerun-20260604T084601/`
- `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/storytelling/cjt-010-rapport-fallback-rerun-20260604T084810/`

## Interpretation

CJT-024 remains verified after a fresh full Money Trust rerun. The direct
Rapport/Bilan fallback path remains a synthesis/read-model proof and did not
reopen the old duplicate-dashboard failure. The regression sweep keeps S005,
Coach overlay, Cap du jour action bar, cold launch, and combined chat entry
green on the current build.

This does not close CJT-015 signed Universal Link/TestFlight proof, and it does
not by itself close CJT-018 root AX stale-frame analysis.
