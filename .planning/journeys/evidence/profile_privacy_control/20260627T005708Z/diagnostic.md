# Profile Privacy Control Runtime Proof

- Verified at: `2026-06-27T00:57:37Z`
- Verified commit: `104c92d125f6c2a0dcfcad9fb61a1d62aed11db1`
- Device: `iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9`
- Flow: `tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml`
- Result: `1/1 Flow Passed in 29s`

Command:

```sh
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true

MINT_WALKER_ARTIFACTS=.planning/journeys/evidence/profile_privacy_control/20260627T005708Z \
  MAESTRO_HARD_LIMIT=300 \
  MAESTRO_STALL_THRESHOLD=90 \
  bash tools/simulator/maestro_with_watchdog.sh test \
    --format junit \
    --output .planning/journeys/evidence/profile_privacy_control/20260627T005708Z/result.xml \
    tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml
```

The flow enters anonymous local mode through the existing JOS-001 privacy-center
route pattern, opens `/profile/privacy-control`, and asserts that profile data
is present and not the empty state.
