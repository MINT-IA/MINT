# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-006 | P2 | proof_needed | mint_lucidity_p0_acceptance | blocked | 30 | mint-quality-gate | baselined | green / runtime | .planning/journeys/evidence/mint_dataquest_clean/20260704T190006Z-mobile-scenarios-gate/mobile-scenarios.log | Keep iPhone simulator as the active product runtime gate for this Mac mini phase. Handle Android P0 Patrol in a dedicated compatibility branch/CI pass after updating Android Gradle Plugin, Gradle wrapper, compileSdk, and core library desugaring; do not block the current iOS product loop on local Android. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
