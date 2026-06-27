# Money Truth Spine Runtime Proof

- Verified at: `2026-06-27T00:38:40Z`
- Verified commit: `5d8b970cb04f346b8a00c63bf120aa35fa0c4616`
- Device: `iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9`
- Flow: `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
- Result: `1/1 Flow Passed in 1m 2s`

Command:

```sh
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_PROOF_ANCHORS=true

MINT_WALKER_ARTIFACTS=.planning/journeys/evidence/money_truth_spine/20260627T003738Z \
  MAESTRO_HARD_LIMIT=600 \
  MAESTRO_STALL_THRESHOLD=150 \
  bash tools/simulator/maestro_with_watchdog.sh test \
    --debug-output .planning/journeys/evidence/money_truth_spine/20260627T003738Z/debug \
    --format junit \
    --output .planning/journeys/evidence/money_truth_spine/20260627T003738Z/result.xml \
    tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

This rerun proves the downstream Money Truth chain after PR #745 and PR #746:
Budget, Mon Argent, Rapport, and Coach all completed with the E2E proof anchors
enabled. The prior red diagnostic from `20260626T213202Z` is preserved as
baselined historical evidence.
