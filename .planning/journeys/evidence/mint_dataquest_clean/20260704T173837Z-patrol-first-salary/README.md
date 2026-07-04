# Patrol first_salary_tax iOS proof

## Command

```sh
MINT_PATROL_CLEAN_BUILD=1 bash tools/checks/mint_lucidity_gate.sh mobile-first-salary-patrol B03E429D-0422-4357-B754-536637D979F9
```

## Runtime

- Device: iPhone 17 Pro simulator
- UDID: `B03E429D-0422-4357-B754-536637D979F9`
- iOS: 26.2
- Patrol report source: `/tmp/mint-mobile-build/ios_results_1783186551539.xcresult`
- Durable summary: `xcresult-summary.json`

## Result

`xcresult-summary.json` reports `result: "Passed"`, `totalTestCount: 1`,
`passedTests: 1`, `failedTests: 0`, and `skippedTests: 0`.

## Product Contract Covered

`first_salary_tax_datablock_to_3a_patrol_test.dart` proves the first-salary
Data Quest path writes only the canonical salary/canton/birth-year/LPP answers,
does not duplicate net/monthly salary keys, then reuses those facts on
`/pilier-3a` with `pillar3aAnnual` as the next useful ask and the 2026 3a LPP
ceiling displayed as `CHF 7'258`.
