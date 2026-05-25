description: Plan 28 completed neighboring Maestro flow updates and ran the broader smoke set around chat-as-verb, Data Spine, G2, and drawer navigation.

# Summary 28 — Maestro neighbor flows

## Completed

- Updated `bug__F001_S001_combined__chat_via_cap_du_jour.yaml` to reuse the hardened cold-launch fragment.
- Updated the combined flow to assert `card_cap_du_jour` and `mint_card_action_bar` instead of fallback-only text.
- Updated `bug__S001__cap_du_jour_action_bar_reachable.yaml` to assert the always-rendered action bar without tapping the card first.

## Maestro Runs

- `bug__F001__chat_input_bar_exists.yaml` → PASS.
- `bug__F001_S001_combined__chat_via_cap_du_jour.yaml` → PASS.
- `bug__S001__cap_du_jour_action_bar_reachable.yaml` → PASS.
- `flow_drawer_navigation_smoke.yaml` → PASS.
- `flow_data_spine_visible_coach_packet.yaml` → PASS.
- `flow_g2_julien_walkthrough.yaml` → PASS.

## Evidence

- Console artifact folders:
  - `.planning/_walker/20260525T071425`
  - `.planning/_walker/20260525T071847`
  - `.planning/_walker/20260525T072238`
  - `.planning/_walker/20260525T072415`
  - `.planning/_walker/20260525T072505`
  - `.planning/_walker/20260525T072539`
- Screenshot evidence folder: `.planning/_walker/maestro-evidence-20260525T0725/`

