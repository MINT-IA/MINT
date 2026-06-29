# Journey OS Today

Generated from Journey OS records and issues. Do not edit directly.

## Top Queue Item

| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |
|---|---|---|---|---|---:|---|---|---|---|---|
No red, missing, or baselined Journey OS issue is currently queued.

## Operating Rule

Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.
When the current top issue closes, move `runtime_replay.sets` `top` to the next actionable issue in the same PR; if that issue requires auth, the replay workflow must route through the authenticated job.

## Proof Discipline

A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.
