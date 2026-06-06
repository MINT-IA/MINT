# Row 26 iPhone 16e S005 Regression Proof

Date: 2026-06-06
Rows: 26 primary, Row 6 supporting regression signal
Related bug: CJT-059

## Purpose

After fixing the simulator build CodeSign path and moving runtime defaults away
from `iPhone 17 Pro`, this run proves that the existing supported landing
anonymous-CTA to Home regression still passes on the less premium `iPhone 16e`
simulator.

## Command

```bash
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-26-iphone16e-s005-regression-20260606T152734 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-26-iphone16e-s005-regression-20260606T152734/result.xml \
  tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

## Result

```text
[Passed] bug__S005__landing_anonymous_cta_to_home (27s)
1/1 Flow Passed in 27s
[watchdog] EXIT — maestro returned 0
```

JUnit:

```text
device="iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B"
tests="1"
failures="0"
time="27.0"
```

Artifacts:

- `result.xml`
- `maestro.log`
- `watchdog-terminal.txt`

## Scope Limit

This is a targeted Row 26 regression proof for a less premium simulator class.
It does not replace broader regression sweeps, TestFlight/signed-device proof,
or product-quality flow scoring.
