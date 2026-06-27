# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-005 | P0 | regressed | onboarding_first_value | partial | 24 | mint-mobile | red | red / runtime / 2026-06-27T17:55:32Z / cc58ad2a | .planning/journeys/evidence/onboarding_first_value/20260627T175336Z/maestro-red.txt | Fix the Mint2 LPP/rente-capital first-value path so selecting the live axis reaches /rente-vs-capital before account creation, then rerun the iPhone 13 mini Mint2 quality gate. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
