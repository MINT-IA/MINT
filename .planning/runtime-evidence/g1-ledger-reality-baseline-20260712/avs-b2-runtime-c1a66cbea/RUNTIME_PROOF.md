# G1 AVS B2 exact runtime proof

Date: 2026-07-13
Commit under test: `c1a66cbea519646f6b5f722f745e7e3b76117b1f`
Device: iPhone 17 Pro simulator, iOS 26.2, arm64
Data: synthetic only; no personal document, AVS identifier, or production write.

## Exact-tree boundary

`git status --porcelain -- apps/mobile` was empty before the simulator build and
again after removal of Patrol's generated `test_bundle.dart`. The normal iOS
Runner binary SHA-256 is recorded in `metadata.txt`.

## Tooling and build

- Full `python3 tools/checks/mint_os_doctor.py`: PASS for repo contracts and
  host Patrol, Maestro, Mermaid, Claude and Beads CLIs.
- `flutter build ios --simulator --debug`: PASS.

## Maestro

`retirement_missing_avs.yaml` ran through the checked-in watchdog with a
300-second hard limit and 90-second stall threshold. Result: PASS, exit 0.

The synthetic flow writes salary/canton/birth-year/LPP facts, opens the
retirement dashboard, and proves:

- `retirement_missing_avs_state` visible;
- `retirement_capital_amount` visible;
- `retirement_avs_document_cta` visible;
- `retirement_complete_income` absent;
- `retirement_replacement_rate` absent.

The visual artifact was captured by `takeScreenshot` inside the passing flow,
not after Maestro exited: `maestro/final-screen.png`.

## Patrol

The native Patrol contract ran with `MINT_PATROL_CLI=true` on the same simulator.
Result: 1 passed, 0 failed, 0 skipped. `xcresulttool` independently reports
`result=Passed`, `totalTestCount=1`, `passedTests=1`, `failedTests=0`.

## Boundary

This proves the B2 missing-official-AVS fail-closed screen on the exact commit.
It does not close the remaining G1 Swiss-law, parser/source-date, partner-consent,
or fallback-inventory blockers. G2/G3 remain forbidden.
