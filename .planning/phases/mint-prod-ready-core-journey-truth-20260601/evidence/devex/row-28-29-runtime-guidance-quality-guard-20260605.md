# Row 28/29 Runtime Guidance Quality Guard — 2026-06-05

## Why

Runtime and Maestro evidence can prove that a screen opens, a locator is tappable, and a flow reaches the expected route. That is necessary, but not sufficient for MINT production readiness: a green flow can still show guidance that is logically weak, financially misleading, employee-biased, or absurd for the user's situation.

## What Changed

`CJT-OPS-00-CONTEXT-GUARD.md` now defines a required `Runtime Guidance Quality Review` section for runtime closure artifacts.

`tools/checks/cjt_context_guard.py` now enforces that section in the OPS template and in active Row 16/17/20/21/23 runtime reports:

- `mechanical proof`
- `user-visible outcome`
- `guidance quality`
- `non-absurd`
- `inclusive`
- `financial trust`
- `remaining qualitative gaps`

The guard intentionally verifies that the review exists and is structured. It does not pretend to automatically judge whether the prose is true; that remains a product/QA review responsibility backed by screenshots, JUnit, and targeted tests.

## Active Reports Updated

- Row 16 Coach route-to-screen runtime proof now separates fixture-based mechanical proof from remaining live LLM and `ScreenReturn` gaps.
- Row 17 Rente vs Capital runtime visual proof now records inclusive first inputs and the remaining source/disclaimer, i18n, and accessibility gaps.
- Row 20 Coach history resume proof now states that local continuity is proven while cloud sync and live LLM semantic quality are not.
- Row 21 Daily return proof now distinguishes explain/simulate/reassure affordances from unproven action completion and persistence.
- Row 23 visual audit now records role clarity improvements and the remaining Coach/Rapport accessibility/focus proof gap.

## Verification

- `python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q` passed: `8 passed`.
- `python3 tools/checks/cjt_context_guard.py` passed.
- `git diff --check` passed.

## Decision

This closes CJT-039 as a DevEx/Product QA guard. It does not close Row 16, Row 17, Row 21, Row 22, or Row 23 beyond their current scoped evidence. It makes future closure claims harder to inflate because every runtime report must say what the user actually saw and what remains qualitatively unproven.
