description: Plan 28 updates neighboring Maestro flows to reuse the hardened cold-launch fragment and stable Semantics identifiers.

# Plan 28 — Maestro neighbor flows

## Goal

After F001 passes, keep the adjacent regression flows aligned with the same current entry path and stable iOS anchors.

## Scope

- `bug__F001_S001_combined__chat_via_cap_du_jour.yaml`: use the shared cold-launch fragment and `card_cap_du_jour` / `mint_card_action_bar` anchors.
- `bug__S001__cap_du_jour_action_bar_reachable.yaml`: stop tapping the card as a reveal action because the action bar is now rendered directly below the card.
- Run the navigation/data/chat smoke flows that matter for this surface.

## Verification

- Run S001, F001+S001 combined, drawer navigation, Data Spine coach packet, and G2 Julien walkthrough on the installed simulator app.

