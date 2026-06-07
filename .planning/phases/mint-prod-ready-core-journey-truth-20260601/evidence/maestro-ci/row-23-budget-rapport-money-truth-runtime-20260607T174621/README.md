# Row 23 Budget/Rapport Money Truth Runtime

Date: 2026-06-07
Device: iPhone 16e, iOS 26.2
Flow: `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`

Purpose:
- Runtime proof that the money-trust chain remains coherent after annual-income normalization across Budget/Rapport readers.
- Covers production onboarding writer, Budget setup, app restart, `/budget`, `/mon-argent`, `/rapport`, and `/coach/chat`.
- Checks that absurd captured values, NaN/Infinity, legacy Budget duplication in Rapport, and runtime exceptions are absent.

Build:
```bash
cd apps/mobile
flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Build note:
- First build failed on simulator codesign xattrs: `resource fork, Finder information, or similar detritus not allowed`.
- Fixed by `xattr -cr build/ios`, then the same build passed.

Runtime:
```bash
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=150 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-rapport-money-truth-runtime-20260607T174621 \
bash tools/simulator/maestro_with_watchdog.sh test --format junit --output \
.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-rapport-money-truth-runtime-20260607T174621/result.xml \
tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

Result:
- JUnit: `tests=1`, `failures=0`
- Watchdog exit: `0`
- Runtime duration: `98.0s`

Artifacts:
- `result.xml`
- `maestro.log`
- `money-trust-chain-budget-mon-argent-rapport-coach.png`
- `money-trust-chain-rapport-synthesis.png`
