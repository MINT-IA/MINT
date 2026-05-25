description: Plan 27 completed iOS Semantics anchors for chat-as-verb and made the F001 Maestro flow pass end-to-end through Cap du jour.

# Summary 27 — iOS Semantics chat-as-verb anchors

## Completed

- Added `Semantics.identifier` for `card_cap_du_jour`, `mint_card_action_bar`, `mint_chat_overlay`, `chat_input_field`, `chat_send_button`, and `chat_turn_counter`.
- Added widget assertions that fail if those iOS-facing anchors disappear.
- Updated `bug__F001__chat_input_bar_exists.yaml` to use the real Aujourd'hui path: cold launch → Cap du jour → action bar → `Explique-moi` → overlay → input/send.

## Verification

- `flutter test test/widgets/aujourdhui/cap_du_jour_banner_test.dart test/widgets/mint_chat_overlay_test.dart test/widgets/confidence_score_card_actionbar_test.dart` → PASS.
- `flutter analyze lib/widgets/aujourdhui/cap_du_jour_banner.dart lib/widgets/mint_card_action_bar.dart lib/widgets/mint_chat_overlay.dart test/widgets/aujourdhui/cap_du_jour_banner_test.dart test/widgets/mint_chat_overlay_test.dart` → PASS.
- `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true` → PASS.
- `MAESTRO_STALL_THRESHOLD=60 MAESTRO_HARD_LIMIT=300 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml` → PASS.

## Result

F001 now reaches the overlay on iOS and verifies the input field, send button, turn counter, and `0 / 3` → `1 / 3` counter path.

