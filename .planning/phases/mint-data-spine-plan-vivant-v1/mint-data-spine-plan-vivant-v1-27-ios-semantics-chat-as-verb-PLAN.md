description: Plan 27 adds iOS Semantics identifiers to chat-as-verb surfaces so Maestro can target the real Aujourd'hui card, action bar, overlay, input, send button, and turn counter.

# Plan 27 — iOS Semantics chat-as-verb anchors

## Goal

Make the F001 chat-as-verb regression runnable end-to-end on iOS Simulator by replacing Dart-Key-only anchors with `Semantics.identifier` anchors where Maestro actually needs `id:` selectors.

## Scope

- `CapDuJourBanner`: expose `card_cap_du_jour`.
- `MintCardActionBar`: expose `mint_card_action_bar`.
- `MintChatOverlay`: expose `mint_chat_overlay`, `chat_input_field`, `chat_send_button`, and `chat_turn_counter`.
- `bug__F001__chat_input_bar_exists.yaml`: route through the canonical Cap du jour card instead of stale `card_mon_3a_2026`.

## Verification

- First add failing widget tests for the Semantics identifiers.
- Make tests pass with minimal widget changes.
- Rebuild the iOS Simulator app and run F001 with Maestro.

