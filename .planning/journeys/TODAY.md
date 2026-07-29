# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
| JOS-006 | P1 | proof_needed | coach_advice_turn | partial | 27 | mint-quality-gate | green | green / unit / 2026-07-29T05:32:10Z / 1ae9af4f | .planning/journeys/evidence/coach_advice_turn/20260729T053210Z/etalon-fiscal-campagne.md | Après la fusion des 5 vagues de la campagne étalon fiscal (#1063-#1100, plan de fusion #1100), rejouer bash tools/simulator/journey_os_runtime_replay.sh --set top pour re-prouver en runtime que le tour de conseil coach cite les chiffres post-étalon (ESTV v2) avec provenance et sans langage de certitude. |

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.
When the current top issue closes, move `runtime_replay.sets` `top` to the next actionable issue in the same PR; if that issue requires auth, the replay workflow must route through the authenticated job.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
