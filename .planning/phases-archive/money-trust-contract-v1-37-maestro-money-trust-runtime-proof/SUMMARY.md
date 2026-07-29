# Phase 37 — Summary

## Result

The iOS simulator runtime proof passed end to end.

## What ran

Build:

```sh
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Install:

```sh
xattr -cr apps/mobile/build/ios/iphonesimulator/Runner.app
timeout 30s xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
```

Maestro:

```sh
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

## Evidence

- Simulator: iPhone 17 Pro, iOS 26.2, `B03E429D-0422-4357-B754-536637D979F9`.
- Maestro artifact: `.planning/_walker/20260526T161549/maestro.log`.
- Screenshot: `.planning/phases/money-trust-contract-v1-37-maestro-money-trust-runtime-proof/money-trust-chain-budget-mon-argent-rapport-coach.png`.
- Maestro exit: `0`.
- Rerun after Phase 38 cleanup: `.planning/_walker/20260526T163138/maestro.log`.
- Rerun screenshot: `.planning/phases/money-trust-contract-v1-37-maestro-money-trust-runtime-proof/money-trust-chain-budget-mon-argent-rapport-coach-rerun-20260526T163138.png`.

## Runtime assertions passed

- Budget setup deep link opens and fields are visible.
- Housing `2200` and LAMal `420` are entered and saved.
- App restarts without losing the budget values.
- Budget screen shows `3'140` charges and `2'239` available.
- Mon Argent exposes `mon_argent_budget_summary` and `mon_argent_budget_flow_bar`.
- Rapport shows `Ton Budget`, `2'200`, and `420`.
- Coach chat opens with input and send controls.
- No visible absurd captured values: `19'272'200`, `420'420`, `19M`, `420k`.
- No visible invalid numeric values: `NaN`, `Infinity`.
- No visible Flutter runtime failure text on Rapport.

## Note

The first build attempt without the Tahoe workaround failed on Xcode code
signing. The documented MINT path, `CODE_SIGNING_ALLOWED=NO` plus
`--no-codesign`, produced a valid simulator build.
