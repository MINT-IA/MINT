# Plan 49 — Maestro 3a flow stabilization

## Problem

`flow_3a_calculator.yaml` was stale in two ways:

- It documented `ch.mint.app://pilier-3a`, which iOS does not open for this
  app. The working scheme is `mintapp:///pilier-3a`.
- It relied on fixed `scroll` steps, so the flow could overshoot or inherit a
  previous scroll position and fail despite the target labels being present.

## Scope

- Make the flow self-launch and self-deep-link to the 3a simulator.
- Replace fixed scroll steps with anchored `scrollUntilVisible` checks.
- Re-run the flow through the watchdog harness.

## Non-goals

- Change the 3a screen product copy.
- Change calculator logic.
- Add a new rate-change interaction flow.

## Steps

1. Reproduce the failure with the current flow.
2. Update the deep-link scheme and launch sequence.
3. Replace fixed scrolls with anchored scrolls.
4. Re-run the flow and record the verdict.
