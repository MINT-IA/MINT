# Phase 27 — Verification

## Commands

```bash
cd apps/mobile && flutter build ios --simulator --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result: pass. Built `build/ios/iphonesimulator/Runner.app`.

```bash
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
```

Result: pass.

```bash
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=60 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

Result: pass, Maestro exit `0`.

## Evidence

- `.planning/_walker/20260526T133151/maestro.log`
- `.planning/phases/money-trust-contract-v1-27-maestro-money-trust-proof/evidence/maestro-20260526T133151.log`
- `.planning/phases/money-trust-contract-v1-27-maestro-money-trust-proof/evidence/money-trust-chain-budget-mon-argent-rapport-coach.png`

## Residual Risk

This is a deterministic simulator flow. It does not yet prove live LLM quality, broader archetype coverage, or full production-readiness of the Mon Argent information architecture.
