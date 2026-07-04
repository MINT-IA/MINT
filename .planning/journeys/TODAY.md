# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-006 | P0 | proof_needed | mint_lucidity_p0_acceptance | blocked | 30 | mint-quality-gate | baselined | baselined / external | .planning/journeys/evidence/mint_dataquest_clean/20260704T130648Z/claude-architecture-audit.txt | Run at least one P0 Patrol journey on an Android emulator with tools/checks/mint_lucidity_gate.sh mobile-p0-patrol emulator-5554, store durable evidence, then rerun Claude external audit. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
