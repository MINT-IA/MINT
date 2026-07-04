# Patrol transmit_property iOS proof

## Command

```sh
MINT_PATROL_CLEAN_BUILD=1 bash tools/checks/mint_lucidity_gate.sh mobile-transmit-property-patrol B03E429D-0422-4357-B754-536637D979F9
```

## Runtime

- Device: iPhone 17 Pro simulator
- UDID: `B03E429D-0422-4357-B754-536637D979F9`
- iOS: 26.2
- Patrol report source: `/tmp/mint-mobile-build/ios_results_1783187387510.xcresult`
- Durable summary: `xcresult-summary.json`

## Result

`xcresult-summary.json` reports `result: "Passed"`, `totalTestCount: 2`,
`passedTests: 2`, `failedTests: 0`, and `skippedTests: 0`.

## Product Contract Covered

`transmit_property_patrol_test.dart` proves the transmission flow first collects
the owned property value before modelling, advances the Data Quest next ask from
`propertyMarketValue` to `targetRetirementAge`, and then reuses a complete
Raiffeisen-style fact set to surface retirement-affordability and family
equalization statuses.

The test also locks the runtime semantics row separately from the visible
status rows so duplicate display/runtime text cannot create ambiguous UI proof.
