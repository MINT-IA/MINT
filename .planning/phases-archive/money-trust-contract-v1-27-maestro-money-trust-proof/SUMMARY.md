# Phase 27 — Summary

## Changed

- Rebuilt the iOS simulator app with `MINT_E2E_ARCHETYPE=julien_swiss` and `MINT_DISABLE_BETA_MODAL=true`.
- Installed the fresh simulator build.
- Ran the canonical money trust Maestro flow with the project watchdog.
- Copied the Maestro log to `evidence/maestro-20260526T133151.log`.
- Copied the final Coach screenshot to
  `evidence/money-trust-chain-budget-mon-argent-rapport-coach.png`.

## Result

The flow passed end-to-end with Maestro exit `0`.

The visible chain is coherent:

- Budget setup wrote `2200` housing and `420` LAMal.
- Budget showed `3'140` charges and `2'239` free monthly margin.
- Mon Argent showed the budget summary and budget flow bar.
- Rapport showed `2'200` and `420`.
- Coach chat opened with input field and send button.

The flow also asserted that the known absurd values and runtime error markers were absent.
