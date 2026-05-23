description: Plan 11 validates the FATCA hard-gate navigation path on the iOS simulator before deeper data-spine work.

# Plan 11 — Maestro Hard-Gate Navigation

Goal: run `flow_hardgate_expat_us.yaml` end-to-end on the iOS simulator, then fix only reproducible navigation/testability defects found by the flow.

Scope:
- Use the existing G1 hard-gate flow and staging API target.
- Keep fixes surgical: selectors, route reachability, waitlist form state, or onboarding bridge only.
- Do not mix in budget/data-spine model refactors.

Verification:
- Local Flutter test for any changed runtime path.
- `maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_hardgate_expat_us.yaml`.
- ARB parity and LSFin scans if copy changes.
- CI + design lints after push.

Decision rule:
- If G1 passes, next phase is G2 Julien walkthrough.
- If G1 fails, fix the first deterministic blocker and rerun G1 before moving on.
