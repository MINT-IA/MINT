# Phase 32 — Regression Budget Coach Trust

## Goal

Prove that the new money trust contract holds across backend coach grounding and mobile budget/Mon argent surfaces after the packet boundary work.

## Scope

- Run the backend coach/citation/budget regression set.
- Run the mobile budget/data-spine/coach-packet/Mon argent regression set.
- Fix only contract drift found by those tests.

## Acceptance Criteria

- Backend regression set passes.
- Mobile regression set passes.
- Budget values that replace stale local cache must carry explicit trusted provenance.
- No weakening of the phantom-default guard.
