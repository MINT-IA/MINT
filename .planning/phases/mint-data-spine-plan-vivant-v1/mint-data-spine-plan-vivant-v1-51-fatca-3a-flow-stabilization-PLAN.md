# Plan 51 — FATCA 3a flow stabilization

## Problem

After Plan 49, `flow_fatca_3a_gate.yaml` still used the stale
`ch.mint.app://pilier-3a` deep-link scheme. Its first assertion also depended
on a landing-page phrase before routing to the actual screen, which made the
flow fail before it tested the FATCA gate.

## Scope

- Reproduce the current flow failure with an `expat_us_seed` simulator build.
- Replace the pre-route landing assertion with a stable launch wait.
- Switch the deep-link to `mintapp:///pilier-3a`.
- Keep the FATCA panel and negative simulator-input assertions.

## Non-goals

- Change FATCA business logic.
- Change 3a eligibility rules.
- Change app routing code.

## Steps

1. Build/install the simulator app with `MINT_E2E_ARCHETYPE=expat_us`.
2. Run the existing FATCA Maestro flow and capture the failure.
3. Update the flow launch and deep-link mechanics.
4. Re-run the flow through the watchdog harness.
