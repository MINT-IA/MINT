---
description: Row 28/30 proof for CJT session handoff and no-new-debt guardrails.
status: verified
date: 2026-06-04
---

# Row 28/30 — Context And Debt Guard

## Finding

The CJT workflow had a mechanical context guard, but it only checked the active
phase, matrix, bug tracker, known external gates, and the `mint-ai.ch` domain.
It did not mechanically require the two habits that prevent session drift:

- a handoff checklist naming the sources restored/read and the open external
  gates;
- a no-new-debt commit review naming debt introduced, revealed, accepted,
  removed, owner, and next proof.

## Change

- `tools/checks/cjt_context_guard.py` now reads
  `CJT-OPS-00-CONTEXT-GUARD.md`.
- The guard fails if `Session Handoff Checklist` is missing or incomplete.
- The guard fails if `No-New-Debt Commit Review` is missing or incomplete.
- `CJT-OPS-00-CONTEXT-GUARD.md` now carries both checklists.

## Proof

- Red proof: `python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q`
  failed before the guard change because missing checklist sections still
  returned `OK cjt_context_guard`.
- Green proof: same command passed (`6 passed`).
- Runtime guard: `python3 tools/checks/cjt_context_guard.py` passed on the
  real repo after the OPS doc update.

## Scope

This improves Row 28 and Row 30 but does not close the broader quality system.
The next useful hardening is applying this template to every future CJT handoff
and commit-review evidence file, then making stale or missing evidence reviews
fail loudly.
