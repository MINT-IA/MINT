# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-005 | P0 | regressed | onboarding_first_value | partial | 24 | mint-mobile | red | red / runtime / 2026-06-28T03:19:17Z / c4ad4531 | .planning/journeys/evidence/runtime_replay/20260628T031810Z/onboarding_first_value/result.xml | Fix the Mint2 LPP/rente-capital first-value path so selecting the live axis reaches /rente-vs-capital before account creation, then rerun the iPhone 13 mini Mint2 quality gate. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.
When the current top issue closes, move `runtime_replay.sets` `top` to the next actionable issue in the same PR; if that issue requires auth, the replay workflow must route through the authenticated job.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
