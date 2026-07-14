# Independent mint-quality-gate verdict

## Verdict

**PASS — G1 Expat AVS runtime slice**

| Severity | Count |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |

## Gate scorecard

| Gate | Result | Independent evidence |
|---|---|---|
| Exact SHA | GREEN | before = after = `e8c0263acb6ddad9b5acafd889193c4caf4909f3` |
| Clean tree | GREEN | both status artifacts are empty |
| Full MINT Doctor | GREEN | every repo and host line is `PASS` |
| Patrol tooling guard | GREEN | checked-in config/tests/CLI wired |
| Patrol runtime | GREEN | exit 0; independent `.xcresult`: 1/1 passed, 0 failed, 0 skipped |
| Normal iOS build | GREEN | exit 0; normal `Runner.app` built and installed after Patrol |
| Maestro runtime | GREEN | exit 0; watchdog returned 0; every required command completed |
| Runtime screenshot | GREEN | valid 1206 × 2622 PNG; both official CTAs visible |
| RED retention | GREEN | Patrol finder, Maestro composite text, and non-actionable wrapper failures preserved |
| Fix correspondence | GREEN | `810741211` fixes Patrol attachment/finders; `e8c0263ac` fixes semantic action/state and final flow |
| Artifact integrity | GREEN | `SHA256SUMS` covers every file except itself |

## Non-vacuity assessment

The green result is not a launch-only or selector-only facade:

- Patrol manipulates the real nullable picker to value `4`, verifies the real
  `FilledButton` callback before selection, and compares persisted answers
  before, during, and after navigation.
- Maestro first taps the disabled control and proves no result exists, then
  explicitly confirms a picker value, proves the control becomes enabled, and
  proves the unknown-gap result appears.
- Both runners independently prove the guide chain reaches the CI CTA and the
  future-calculation CTA.
- Both runners assert the financial hard floor: no personal CHF amount is
  produced by the declared years-abroad scenario.
- The three retained red artifacts fail at precisely the contracts changed by
  the two green commits; they are not synthetic always-failing placeholders.
- The `.xcresult` summary was independently extracted from the preserved
  Apple result bundle during this audit.

The single Maestro warning is an optional system `Cancel` selector that was
absent. It is explicitly optional and occurs before all required product
assertions; it is not a P2.

## Scope

This verdict closes the **Expat AVS slice only**. It is not a verdict that all
G1 tickets are complete, and it is not a global `RUNTIME-01` closure if that
ticket's acceptance criteria name additional flows.
