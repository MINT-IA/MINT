---
description: Row 23 iPhone 16e runtime rerun and AX capture attempt for independent/no-LPP Budget and Rapport surfaces.
linked_rows: [23, 26]
---

# Row 23 - Budget/Rapport Runtime AX Attempt

## Scope

Runtime follow-up for `independent_no_lpp_income_reality` after the local
semantics traversal contract. This checks the real iPhone 16e flow and records
why it still does not close VoiceOver/AX traversal.

## Runtime Proof

Build/install:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

Flow:

```bash
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-rapport-ax-runtime-20260606T213645 \
bash tools/simulator/maestro_with_watchdog.sh test --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-rapport-ax-runtime-20260606T213645/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

Result: iPhone 16e iOS 26.2, `tests=1`, `failures=0`, watchdog returned `0`.
Screenshots show `/rapport` and `/budget` render the independent/no-LPP persona
without salary-only or LPP-affiliated fallback assumptions.

Evidence folder:

`evidence/maestro-ci/row-23-budget-rapport-ax-runtime-20260606T213645/`

## AX Capture Attempt

Attempted captures:

- `idb ui describe-all --json` on `/budget`
- `idb ui describe-all --json` on `/rapport`
- `idb ui describe-all --json --nested` after foreground relaunch
- XcodeBuild MCP `snapshot_ui`

Result: `idb` consistently returned one empty `0x0` node, and MCP
`snapshot_ui` failed to get the accessibility hierarchy while a screenshot
confirmed Budget was visibly rendered.

This therefore records a runtime AX tooling gap. It is not a positive
VoiceOver traversal proof.

## Decision

Row 23 remains `PARTIAL`. The runtime content/screenshot path is green on
iPhone 16e, but full VoiceOver/AX traversal still needs a reliable capture
method or manual VoiceOver sweep.
