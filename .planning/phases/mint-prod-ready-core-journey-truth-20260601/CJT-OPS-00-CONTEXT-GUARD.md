---
description: CJT-OPS-00 anti-drift dashboard connecting STATE, ROADMAP, Journey Truth Matrix, Bug Tracker, and the mechanical context guard.
---

# CJT-OPS-00 — Context Guard

Date: 2026-06-03

This dashboard prevents agents from resuming old GSD state while the active
production-readiness work lives in the Core Journey Truth phase.

## Active Sources

| Layer | File / command | Role |
|---|---|---|
| Capability truth | `JOURNEY-TRUTH-MATRIX.md` | One row per user capability, with proof status. |
| Bug truth | `BUG-TRACKER.md` | CJT bug rows, owner, status, evidence. |
| Wiki router | `.planning/STATE.md` | Current operating phase and next bias. |
| Roadmap router | `.planning/ROADMAP.md` | Milestone entry and canonical links. |
| Mechanical guard | `python3 tools/checks/cjt_context_guard.py` | Fails if the routing files drift away from CJT. |
| Memory | Engram project `mint` | Decisions and discoveries that survive compaction. |

## Current Open Gates

| Gate | Meaning | Why it matters |
|---|---|---|
| CJT-013 | Backend production Phase 02 cutover | Staging proof is not production proof. |
| CJT-015 | TestFlight / Universal Links | Beta access cannot be inferred from simulator proof. |

Recently closed: CJT-018 onboarding AX / Maestro locators. The 2026-06-04
current AX frame audit proved valid lower frames for the active T6/T7/T8 ids.

## Next Execution Bias

Execute CJT-015 first when signed/TestFlight access is available. Otherwise use
the matrix to choose between CJT-013 and the next human-journey proof wave.

## Verification Commands

```bash
python3 tools/checks/cjt_context_guard.py
python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q
git diff --check
```

## Session Handoff Checklist

Every CJT handoff or resumed session must explicitly state:

- `MEMORY.md` read or Engram context restored.
- `CLAUDE.md` read.
- `AGENTS.md` read.
- `JOURNEY-TRUTH-MATRIX.md` read.
- `BUG-TRACKER.md` read.
- `open gates named`: at minimum `CJT-013` and `CJT-015`.
- `newest commit audited` against the active matrix before new work starts.

## No-New-Debt Commit Review

Every CJT commit review should include:

- `introduced`: new debt created by this lot, or `none`.
- `revealed`: old debt surfaced by this lot, or `none`.
- `accepted`: debt intentionally left open, with owner.
- `removed`: debt eliminated by this lot.
- `owner`: person/team or subsystem owning each non-removed item.
- `next proof`: command, runtime flow, or external gate needed next.

## Drift Rules

- Do not run `$gsd-next` blindly while `.planning/STATE.md` and
  `.planning/ROADMAP.md` disagree with the CJT matrix.
- Do not mark a Journey Truth Matrix row as live-proven without a fresh runtime
  or backend proof artifact.
- Do not close CJT-013 from staging-only evidence.
- Do not reopen CJT-018 without fresh runtime evidence showing the affected
  flows require coordinate fallbacks again.
- When new evidence changes a row, update the matrix, bug tracker, and Engram
  in the same work wave.
