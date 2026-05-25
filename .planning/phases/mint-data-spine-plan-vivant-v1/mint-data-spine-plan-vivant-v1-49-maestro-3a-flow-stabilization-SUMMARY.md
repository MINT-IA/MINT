# Summary 49 — Maestro 3a flow stabilization

## Outcome

The 3a Maestro flow now runs autonomously and passed locally on the iPhone 17
Pro simulator.

## Changes

- Updated the documented deep-link scheme to `mintapp:///pilier-3a`.
- Added `launchApp` and `openLink` directly inside the flow.
- Replaced fixed `scroll` commands with `scrollUntilVisible` anchors for:
  `Gain fiscal annuel`, `Stratégie gagnante`, and `Explorer aussi`.

## Verification

- Reproduced initial failure: `ch.mint.app://pilier-3a` returned iOS
  `NSOSStatusErrorDomain -10814`.
- Reproduced second failure: fixed scroll flow failed on `Stratégie gagnante`.
- Passing run: `flow_3a_calculator` passed in 22s through
  `tools/simulator/maestro_with_watchdog.sh`.
