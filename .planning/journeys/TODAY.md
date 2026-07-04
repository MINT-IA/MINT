# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-007 | P0 | proof_needed | mint_lucidity_p0_acceptance | blocked | 30 | mint-lead | baselined | baselined / external | .planning/journeys/evidence/mint_dataquest_clean/20260704T130648Z/claude-architecture-audit.txt | Create a real MINT_EVIDENCE_DIR with SCORECARD.md, claude-phase audit marker, quality-gate score, and roster co-signatures; then run the phase acceptance artifact gate. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
