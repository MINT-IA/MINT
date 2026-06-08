---
description: Row 23v runtime proof that the independent/no-LPP Budget capacity guard is visible in the canonical Maestro flow.
status: verified-runtime-simulator
date: 2026-06-08
linked_bug: CJT-063
---

# Row 23v - Budget Capacity Guard Runtime Proof

## Scope

This is a simulator runtime proof for `independent_no_lpp_income_reality` on
`iPhone 16e - iOS 26.2`. It proves that `/rapport` and `/budget` render in the
canonical Row 23 flow and that `/budget` exposes
`budget_independent_no_lpp_capacity_guard`.

It does not prove physical-device VoiceOver/focus traversal, live backend/LLM
scoring, or production/staging behavior.

## Build

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

## Runtime Command

```bash
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941 \
MAESTRO_HARD_LIMIT=420 \
MAESTRO_STALL_THRESHOLD=90 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

## Result

- Maestro: `1/1 Flow Passed in 30s`
- JUnit: `tests=1`, `failures=0`
- Watchdog: `maestro returned 0`
- Device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`

## Assertions

The flow scrolls to `budget_independent_no_lpp_capacity_guard`, copies its
text, and runs `row23_assert_budget_capacity_guard.js`.

Required fragments include AVS-independent status, taxable income, income
volatility, risk cover, optional LPP, 3a, and liquidity.

Rejected fragments include salary-only 3a ceiling, `7’258`, account-opening
wording, provider names, and fixed investment allocation.

## Artifacts

- `result.xml`
- `maestro.log`
- `watchdog-summary.txt`
- `row23-independent-no-lpp-budget.png`
- `row23-independent-no-lpp-rapport.png`
