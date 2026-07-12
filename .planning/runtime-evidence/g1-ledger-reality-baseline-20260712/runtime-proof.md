# G1 Runtime Proof

Date: 2026-07-12
Commit under test: `0d0950181`
Device: iPhone 17 Pro simulator, iOS 26.2, arm64
Data: synthetic only; no user document, identifier, or production write.

## Toolchain

- `python3 tools/checks/mint_os_doctor.py`: PASS, including host Patrol,
  Maestro, Mermaid, Claude CLI, and repo contracts.
- `python3 tools/checks/patrol_tooling_guard.py`: PASS.
- Local debug simulator build with staging API base and an empty Sentry DSN:
  PASS.

## Maestro

Both flows ran through `tools/simulator/maestro_with_watchdog.sh` with a
300-second hard limit and 90-second stall limit.

| flow | result | semantic proof | artifacts |
|---|---|---|---|
| `apps/mobile/.maestro/r1_scan_review.yaml` | PASS | Cold `/scan/review` resolves the missing session safely, exposes `scan_review_recovery_cta`, then reaches `document_scan_capture_cta`. | `maestro-r1/maestro.log`, `maestro-r1/final-screen.png` |
| `apps/mobile/.maestro/r2_scan_impact.yaml` | PASS | Cold `/scan/impact` exposes `scan_impact_recovery_cta`, then returns to `home_route`; no domain payload is required. | `maestro-r2/maestro.log`, `maestro-r2/final-screen.png` |

The watchdog returned exit code 0 for both flows; neither stalled.

## Patrol

Command:

```bash
$HOME/.pub-cache/bin/patrol test \
  -t test/patrol/lamal_franchise_runtime_test.dart \
  -d "iPhone 17 Pro" \
  --dart-define=MINT_PATROL_CLI=true \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=SENTRY_DSN= \
  --no-uninstall
```

Result: **1 passed, 0 failed, 0 skipped**. The synthetic flow opened the LAMal
screen by deep link, observed the missing-ledger state, entered CHF 2,200
housing, CHF 390 premium, CHF 2,500 franchise, and CHF 120 medical-cost
fixtures, saved them, returned to the origin, and observed the premium,
franchise, medical fact, and result section.

`xcrun xcresulttool get test-results summary` independently reports
`result=Passed`, `totalTestCount=1`, `passedTests=1`, `failedTests=0` for the
iPhone 17 Pro simulator.

Artifacts:

- `patrol-lamal/ios_results.xcresult`

## Boundary

This proves the G1 route-recovery behavior and one real
missing-fact → collection → ledger read → result loop. It does not prove all
six future P0 loops, restart persistence for every canonical key, or G2
readiness; those remain exact blocking tickets and `G2 allowed? NO`.
