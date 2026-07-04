# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-004 | P0 | proof_needed | coach_advice_turn | partial | 27 | mint-quality-gate | baselined | baselined / runtime / 2026-06-27T17:28:41Z / 4cb5c173 | .planning/journeys/evidence/coach_advice_turn/20260627T172841Z/maestro.txt | Rerun the JOS-004 Coach advice Maestro proof with JUnit output or a captured flow-level [Passed]/Flow Passed marker before marking the issue verified. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
