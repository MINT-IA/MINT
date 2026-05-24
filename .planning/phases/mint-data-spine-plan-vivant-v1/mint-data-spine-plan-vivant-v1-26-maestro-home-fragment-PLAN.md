description: Plan 26 updates the shared Maestro cold-launch fragment so regression flows can reliably reach the home shell after the current onboarding storyboard.

# Plan 26 — Maestro Home Fragment

## Goal

Stabilize `_fragment_cold_launch_to_aujourdhui.yaml` after the onboarding
storyboard changed from direct anonymous home routing to intermediate screens.

## Scope

- Handle the current `Ouvrir`, intent, FATCA, age/canton, and transition
  screens when they appear.
- Deep-link to `/home` after local mode has been activated, because this
  fragment is a setup primitive for regression flows rather than an onboarding
  acceptance flow.
- Verify with the F001 regression flow until the fragment reaches
  `Aujourd'hui`.

## Verification

- `MAESTRO_STALL_THRESHOLD=60 MAESTRO_HARD_LIMIT=300 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml`
- Result: fragment completed and reached `Aujourd'hui`; the outer flow then
  failed at the documented `card_mon_3a_2026` precondition.
