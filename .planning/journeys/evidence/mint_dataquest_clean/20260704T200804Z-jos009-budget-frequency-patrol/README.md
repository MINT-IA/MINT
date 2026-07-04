# JOS-009 Budget Frequency Patrol Proof

Date: `2026-07-04T20:08:04Z`

Branch: `codex/mint-dataquest-transmit-property-clean`

Device: iPhone 17 Pro simulator, iOS 26.2, UDID `B03E429D-0422-4357-B754-536637D979F9`

## Command

```sh
MINT_PATROL_CLEAN_BUILD=1 bash tools/checks/mint_lucidity_gate.sh mobile-budget-housing-frequency-patrol B03E429D-0422-4357-B754-536637D979F9
```

## Runtime

- Patrol report source: `/tmp/mint-mobile-build/ios_results_1783195596501.xcresult`
- Durable summary: `xcresult-summary.json`

## Result

`xcresult-summary.json` reports `result: "Passed"`, `totalTestCount: 1`,
`passedTests: 1`, `failedTests: 0`, and `skippedTests: 0`.

## Product Contract Covered

`budget_housing_frequency_patrol_test.dart` proves that a profile with annual
income (`q_net_income_period_chf=120000`, `q_pay_frequency=yearly`) can enter
monthly housing costs in `/budget/setup`; saving keeps `q_pay_frequency`
income-only, writes `q_housing_cost_frequency=monthly`, writes canonical
housing/LAMal keys, and updates `CoachProfile.depenses`.

The first Patrol run exposed a direct-route crash on save (`GoRouterDelegate`
empty stack after popping `/budget/setup`). The product fix now pops when a
previous page exists and otherwise routes to `/budget`.
