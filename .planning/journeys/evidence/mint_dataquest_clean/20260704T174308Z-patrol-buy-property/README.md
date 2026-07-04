# Patrol buy_property iOS proof

## Command

```sh
MINT_PATROL_CLEAN_BUILD=1 bash tools/checks/mint_lucidity_gate.sh mobile-f2-patrol B03E429D-0422-4357-B754-536637D979F9
```

## Runtime

- Device: iPhone 17 Pro simulator
- UDID: `B03E429D-0422-4357-B754-536637D979F9`
- iOS: 26.2
- Patrol report source: `/tmp/mint-mobile-build/ios_results_1783186924839.xcresult`
- Durable summary: `xcresult-summary.json`

## Result

`xcresult-summary.json` reports `result: "Passed"`, `totalTestCount: 1`,
`passedTests: 1`, `failedTests: 0`, and `skippedTests: 0`.

## Product Contract Covered

`f2_datablock_to_mortgage_patrol_test.dart` proves the property-purchase Data
Quest path collects revenue/canton first, then property savings/target value,
without re-asking the already-known salary or canton. It persists only the
canonical keys `q_gross_salary_annual`, `q_canton`, `q_cash_total`, and
`q_target_property_value`, then reuses those facts on `/hypotheque` where
`householdType` remains the next guard ask.
