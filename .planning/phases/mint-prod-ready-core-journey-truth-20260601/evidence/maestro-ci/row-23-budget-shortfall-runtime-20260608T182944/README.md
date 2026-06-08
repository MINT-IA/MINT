---
description: Row 23x runtime proof that the independent/no-LPP Budget guard exposes the monthly-capacity shortfall warning.
status: verified-runtime-simulator
date: 2026-06-08
linked_bug: CJT-063
---

# Row 23x - Budget Shortfall Runtime Proof

## Scope

This is a local simulator runtime proof on `iPhone 16e - iOS 26.2`. It proves
that the real `BudgetScreen` renders the independent/no-LPP capacity guard with
the monthly cashflow shortfall warning when the current direct-input budget is
too tight for the legal monthly 3a-room equivalent.

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
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944 \
MAESTRO_HARD_LIMIT=420 \
MAESTRO_STALL_THRESHOLD=90 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_budget_shortfall_runtime.yaml
```

## Result

- Maestro: `1/1 Flow Passed in 21s`
- JUnit: `tests=1`, `failures=0`
- Watchdog: `maestro returned 0`
- Device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`

## Assertions

The flow opens the debug-only route
`/__e2e/budget-direct-inputs?net=4500&housing=3900&lamal=600&render=budget`.
That route persists direct `BudgetInputs` and renders the real `BudgetScreen`
while the app is built with the seeded `independent_no_lpp_income_reality`
profile.

The flow scrolls to `budget_independent_no_lpp_capacity_guard`, copies its
text, and runs `row23_assert_budget_shortfall_guard.js`.

Required fragments include:

- `Marge 3a à vérifier`
- `Marge légale restante`
- `Équivalent mensuel`
- `Budget libre actuel`
- `Marge légale ≠ capacité mensuelle`
- `Budget libre insuffisant pour couvrir cet équivalent mensuel`
- `vérifie la trésorerie avant tout versement`
- independent/no-LPP guidance fragments for AVS status, optional LPP, and
  liquidity.

Rejected fragments include salary-only 3a ceilings, `7’258`, account-opening
wording, provider names, and fixed investment-allocation wording.

## Artifacts

- `result.xml`
- `maestro.log`
- `final-screen.png`
