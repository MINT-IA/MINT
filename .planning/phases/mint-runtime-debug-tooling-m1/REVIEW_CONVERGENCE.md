# Mint Runtime Debug Tooling M1 — Review Convergence

Date: 2026-06-22

## Initial Review Loop

The first draft was not accepted. Reviewers found execution blockers:

- Patrol bootstrap was not fail-closed when `patrol_cli` was missing.
- The network recorder could be implemented at `ApiService` only, missing direct
  `MintHttpClient.shared` callers.
- Existing debug HTTP body logs could leak request/response bodies into runtime
  evidence.
- Fresh/reset/relaunch proof did not explicitly cover account lifecycle residue
  classes such as `keep_local`, `restart_clean`, `local_data_migrated_*`, and
  sync-off account behavior.
- Release workflow scanning rejected only `ENABLE_ADMIN=1` and
  `ENABLE_DEBUG_TOOLS=1`, missing the accepted `true` spellings.

## Fixes Applied

- `01-patrol-bootstrap-contract-PLAN.md` now requires `command -v patrol` and
  `dart pub global list | grep -q "patrol_cli"` to pass after setup; missing CLI
  is a NO-GO prerequisite, not a passing setup.
- `02-runtime-fresh-reset-relaunch-PLAN.md`, `CONTEXT.md`, and
  `VERIFICATION.md` now require central `MintHttpClient.shared` recording and
  suppression/redaction of body logs during the Patrol gate.
- `02-runtime-fresh-reset-relaunch-PLAN.md` now includes a synthetic account
  handoff leg for the simulator-proven lifecycle classes.
- `03-ci-release-closeout-PLAN.md`, `CONTEXT.md`, and `VERIFICATION.md` now
  require release scans to reject `ENABLE_ADMIN=(1|true)` and
  `ENABLE_DEBUG_TOOLS=(1|true)` through direct, env-wrapped, and
  dart-define-from-file inputs.

## Final Verdicts

| Reviewer | Score | Verdict | High Blockers |
| --- | ---: | --- | --- |
| Claude Max | 9.5/10 | GO | None |
| QA expert | 8.5/10 | GO | None |
| Flutter expert | 9/10 | GO | None |
| Security auditor | 9/10 | GO | None |
| GSD plan checker | 9/10 | GO | None |

## Mechanical Proof

All plan files passed `gsd-sdk query verify.plan-structure` with no errors or
warnings after the final patch.
