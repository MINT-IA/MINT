# Phase 37 — Verification

## Commands

```sh
git diff --check
```

Result: pass.

```sh
bash tools/simulator/maestro_env.sh --version
```

Result: Maestro `2.5.1`.

```sh
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result: pass, `✓ Built build/ios/iphonesimulator/Runner.app`.

```sh
timeout 30s xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
```

Result: pass.

```sh
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

Result: pass, Maestro returned `0`.

## Artifact

`.planning/_walker/20260526T161549/maestro.log`
