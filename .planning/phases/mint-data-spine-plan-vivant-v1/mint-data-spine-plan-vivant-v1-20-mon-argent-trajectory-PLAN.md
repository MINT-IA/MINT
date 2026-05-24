# Plan 20 — Mon Argent trajectory

## Goal
Show the user's A-to-B trajectory in Mon Argent from the existing `TrajectorySummary`.

## Scope
- Reuse Data Spine trajectory fields.
- Add no new calculation path and no ARB key.
- Keep the UI small: progress, target, current free, monthly gap, next step.

## Acceptance
- Mon Argent exposes `trajectoryTitle`, target, current monthly free, monthly gap, and next step.
- The existing Mon Argent widget test locks those visible facts.
- Analyze, targeted tests, Data Spine tests, and design lints stay green.

