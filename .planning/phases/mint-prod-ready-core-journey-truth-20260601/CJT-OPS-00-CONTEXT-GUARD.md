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
| CJT-018 | Onboarding AX / Maestro locators | Fragile selectors weaken every later live journey proof. |

## Next Execution Bias

Execute CJT-018 first unless a release/access constraint explicitly moves
CJT-015 or CJT-013 ahead of it. Stable Maestro automation makes the later
account, OCR, Coach-widget, action-loop, and design/navigation waves cheaper to
interpret.

## Verification Commands

```bash
python3 tools/checks/cjt_context_guard.py
python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q
git diff --check
```

## Drift Rules

- Do not run `$gsd-next` blindly while `.planning/STATE.md` and
  `.planning/ROADMAP.md` disagree with the CJT matrix.
- Do not mark a Journey Truth Matrix row as live-proven without a fresh runtime
  or backend proof artifact.
- Do not close CJT-013 from staging-only evidence.
- Do not close CJT-018 while affected flows still require coordinate fallbacks
  for the known onboarding CTA path.
- When new evidence changes a row, update the matrix, bug tracker, and Engram
  in the same work wave.
