---
phase: mint-data-spine-plan-vivant-v1
plan: 05
type: ui-maestro
wave: 5
depends_on:
  - mint-data-spine-plan-vivant-v1-04-ui-maestro-proof-PLAN.md
files_modified:
  - apps/mobile/lib/screens/coach/**
  - tools/simulator/flows/maestro-perfect-set/
autonomous: false
requirements:
  - REQ-DSP-05
must_haves:
  truths:
    - "Plan 05 must prove a visible user-facing behavior, not just payload wiring."
    - "The visible explanation must be grounded in `coach_context_packet` facts and missing fields."
    - "Maestro proof must cover persistence/relaunch/chat explanation on the iPhone simulator."
---

# Plan 05 — Visible Packet-Backed Maestro Proof

## Objective

Add one small visible coach surface that demonstrates the live data spine:
the coach should explain at least one known packet fact and one missing field or
next question, then Maestro must prove the flow after app relaunch.

## Tasks

### Task 1 — Choose the narrow visible surface

Pick the least invasive existing coach screen/card seam. Do not introduce a new
route unless reuse is impossible.

### Task 2 — TDD the visible packet behavior

Add a widget/service test proving the visible copy or action model is derived
from `coach_context_packet`, not raw wizard maps or hardcoded fixtures.

### Task 3 — Implement the UI seam

Render one packet-backed explanation or card state. Keep legacy chat behavior
compatible.

### Task 4 — Maestro proof

Add a flow under `tools/simulator/flows/maestro-perfect-set/` that:

- enters or restores enough profile/budget data to produce a packet;
- relaunches the app;
- opens the coach path;
- asserts the visible explanation uses the expected known fact and missing field.

### Task 5 — Close-out

Run focused Flutter tests, simulator proof, and update the phase summary.

## Non-Goals

- No navigation rewrite.
- No broad budget UI redesign.
- No new financial calculation.
