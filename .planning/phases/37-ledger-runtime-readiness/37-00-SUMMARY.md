---
phase: 37-ledger-runtime-readiness
plan: "00"
subsystem: testing
tags: [ledger, evidence, maestro, patrol, claude-audit, mint-os]

requires:
  - phase: g1-baseline
    provides: 23 blocking tickets and the immutable G2 hard floor
provides:
  - Evidence-backed ticket_only, red_proven, and green transition contract
  - Machine-readable index for all 23 G1 tickets
  - Same-device Maestro and two-process Patrol persistence harness
  - Accepted Wave 0 code and product-domain audit manifest
affects: [37-01, phase-37-scorecard, g2-decision, runtime-evidence]

tech-stack:
  added: []
  patterns:
    - Exact-command JSON evidence with committed SHA and synthetic-data boundary
    - Distinct Patrol write/read processes around explicit simctl process death

key-files:
  created:
    - .planning/runtime-evidence/phase-37/ticket-evidence.json
    - apps/mobile/.maestro/r4_persistence.yaml
    - tools/simulator/patrol_persistence_process_death.sh
    - .planning/runtime-evidence/phase-37/00-gate/audit-manifest.json
  modified:
    - tools/checks/tests/test_g1_p0_ledger_dead_keys.py
    - .planning/goals/G1-blocking-gate-tickets.md

key-decisions:
  - "Ticket status is evidence-backed and registry/index disagreement fails closed."
  - "G1-RUNTIME-01 is red_proven at the cold-relaunch consumer predicate; no Wave 0 product repair was attempted."
  - "G2 remains NO with 22 ticket_only tickets and one red_proven ticket."

patterns-established:
  - "Progressive gate: one registry row and its JSON evidence record transition together."
  - "Runtime persistence: Maestro covers the cold user journey while Patrol isolates write and read into separate native processes."

requirements-completed: []

duration: 50min
completed: 2026-07-12
---

# Phase 37 Plan 00: Ledger Runtime Readiness Summary

> **Historical snapshot:** this summary truthfully records the 23-ticket Wave 0
> seed on 2026-07-12. The live registry was later expanded to **31 rows**. The
> current counts, plan coverage and G2 hard floor come only from
> `G1-blocking-gate-tickets.md`, `ticket-evidence.json` and Plans 37-01..07; the
> historical 23/22 figures below must never be used as current acceptance.

**Fail-closed evidence transitions for 23 G1 tickets, plus a same-UDID persistence harness that captured an honest cold-relaunch RED without weakening the product assertion**

## Performance

- **Duration:** 50 min
- **Started:** 2026-07-12T14:48:39Z
- **Completed:** 2026-07-12T15:38:25Z
- **Tasks:** 3
- **Files modified:** 27

## Accomplishments

- Replaced the all-pending assumption with strict `ticket_only -> red_proven ->
  green` evidence contracts, including named negative fixtures for every
  fail-closed condition.
- Seeded an exact 23-ticket machine-readable index while preserving every
  canonical matrix, reader, uniqueness, and required-gate assertion.
- Added a real-control Maestro journey and distinct Patrol write/read native
  processes with explicit same-device launch, process death, SHA, command, exit,
  and UTC metadata.
- Captured `G1-RUNTIME-01` as semantic `red_proven`: the normal cold-relaunch
  journey reaches the mortgage consumer but shows the stable default
  `CHF 120'000 / VD` instead of the synthetic `CHF 96'000 / GE`. The isolated
  Patrol write/death/read contract passes, narrowing the future repair to cold
  hydration/recompute behavior.
- Accepted one Opus/high wrapper-only code audit and one product-domain audit,
  both PASS with zero P0/P1/critical/high findings.

## Task Commits

Each task was committed atomically:

1. **Task 1: Progressive evidence and audit contracts** — `1a0500d38`,
   `13a764719`, `4463ed670`
2. **Task 2: Fail-closed 23-ticket evidence index** — `37173b2df`, `e4dbb65e1`
3. **Task 3: Same-device runtime baseline and external audits** —
   `96e1762dd`, `562fb701b`, `111a89282`, `65ddce9c1`, `57d371e56`,
   `d4fcf7b21`

## Files Created/Modified

- `tools/checks/tests/test_g1_p0_ledger_dead_keys.py` — progressive ticket and
  audit-manifest validators with non-vacuous negative cases.
- `.planning/runtime-evidence/phase-37/ticket-evidence.json` — exact evidence
  state for all 23 blockers.
- `apps/mobile/.maestro/r4_persistence.yaml` — synthetic write, stop, cold
  relaunch, and downstream mortgage assertion.
- `apps/mobile/integration_test/g1_p0_persistence_*_patrol_test.dart` — distinct
  real-control writer and setup-free consumer reader.
- `apps/mobile/test/patrol/g1_p0_persistence_*_runtime_test.dart` — checked-in
  Patrol-directory entrypoints for the canonical integration contracts.
- `tools/simulator/patrol_persistence_process_death.sh` — fail-closed native
  write/launch/terminate/read orchestrator and metadata archive.
- `.planning/runtime-evidence/phase-37/runtime-01/red.json` — exact-command
  semantic RED for the accepted runtime baseline SHA.
- `.planning/runtime-evidence/phase-37/00-gate/audit-manifest.json` — accepted
  code and product-domain audit runs with complete findings/counts.

## Decisions Made

- A product ticket cannot advance from prose: exact registry command, committed
  artifact, existing SHA, matching business assertion, and synthetic-data flag
  are mandatory.
- The Patrol GREEN is retained as diagnostic narrowing evidence, but it does not
  override the canonical composite command's Maestro RED or turn the runtime
  ticket GREEN.
- Wave 0 does not repair ledger product behavior. The runtime failure is handed
  to the later named implementation slice with G2 still hard-blocked.

## Deviations from Plan

### Auto-fixed Issues

**1. Patrol CLI generated an invalid Dart alias from `MINT.nosync`**
- **Found during:** Task 3
- **Issue:** Patrol's generated bundle used the absolute checkout path as an
  import alias; the dot in `MINT.nosync` caused an iOS compile failure.
- **Fix:** Added thin, checked-in runners under the configured `test/patrol/`
  directory while keeping the actual write/read contracts distinct under
  `integration_test/`.
- **Verification:** Orchestrator contract tests pass and both native Patrol
  processes compiled and ran on the named simulator.
- **Committed in:** `65ddce9c1`

**2. Patrol exits with the application already stopped**
- **Found during:** Task 3
- **Issue:** Direct `simctl terminate` returned “nothing to terminate,” so the
  required explicit process-death proof could not be archived successfully.
- **Fix:** The orchestrator now launches the preserved install, then terminates
  that exact bundle and fails closed at either native step.
- **Verification:** Metadata records successful write, launch, terminate, and
  read stages; six orchestrator tests cover stage ordering and failure stops.
- **Committed in:** `57d371e56`

---

**Total deviations:** 2 auto-fixed blocking harness issues.
**Impact on plan:** Both fixes were limited to the versioned runtime harness;
no financial or ledger product behavior changed.

## Issues Encountered

- Maestro and Patrol disagree only across startup timing: the isolated Patrol
  reader waits for application hydration and passes, while an immediate
  cold-relaunch deep link reaches the real consumer with defaults. This was
  retained as the required semantic baseline RED, not hidden as a harness gap.

## User Setup Required

None - the checked-in Mint OS Doctor discovered all required local tools and the
named iOS simulator was already available.

## Next Phase Readiness

- Wave 0 is complete and all later ticket slices can transition independently
  using the evidence contract.
- `G1-RUNTIME-01` remains `red_proven`; 22 other tickets remain `ticket_only`.
- G2/G3 remain blocked. The next authorized plan is `37-01`; no G2/G3 work has
  started.

---
*Phase: 37-ledger-runtime-readiness*
*Completed: 2026-07-12*
