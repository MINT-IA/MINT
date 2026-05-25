description: Maestro evidence for the 2026-05-25 chat-as-verb Semantics and neighbor-flow sweep.

# Maestro Runs — 2026-05-25

## Build

- `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true` → PASS.
- Installed `apps/mobile/build/ios/iphonesimulator/Runner.app` on iPhone 17 Pro iOS 26.2.

## Runs

| Flow | Result | Artifact folder |
|---|---:|---|
| `tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml` | PASS | `.planning/_walker/20260525T071425` |
| `tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml` | PASS | `.planning/_walker/20260525T071847` |
| `tools/simulator/flows/regression/bug__S001__cap_du_jour_action_bar_reachable.yaml` | PASS | `.planning/_walker/20260525T072238` |
| `tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml` | PASS | `.planning/_walker/20260525T072415` |
| `tools/simulator/flows/maestro-perfect-set/flow_data_spine_visible_coach_packet.yaml` | PASS | `.planning/_walker/20260525T072505` |
| `tools/simulator/flows/maestro-perfect-set/flow_g2_julien_walkthrough.yaml` | PASS | `.planning/_walker/20260525T072539` |

## Notes

- One earlier S001 attempt failed because the flow tapped `card_cap_du_jour` before asserting the action bar. The current implementation renders the action bar directly below the card, so the flow now asserts it without the tap.
- One earlier combined-flow attempt failed because it still used a stale cold-launch preamble and fallback-only text. It now uses the shared cold-launch fragment plus stable Semantics ids.

