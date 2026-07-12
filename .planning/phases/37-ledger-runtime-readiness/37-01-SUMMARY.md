---
phase: 37-ledger-runtime-readiness
plan: "01"
subsystem: backend
tags: [ledger, provenance, confidence, crosswalk, tdd, claude-audit]

requires:
  - phase: 37-00
    provides: Progressive ticket evidence and fail-closed audit manifests
provides:
  - Immutable five-identity mobile-to-backend provenance crosswalk
  - Explicit classification of the three backend-only DataSource members
  - Fail-closed translator and exhaustive drift contract
  - Evidence-backed GREEN transition for G1-SOURCE-01 only
affects: [37-03, provenance, enhanced-confidence, phase-37-scorecard]

tech-stack:
  added: []
  patterns:
    - MappingProxyType for immutable identity translation
    - Live Dart enum parsing for cross-stack drift detection

key-files:
  created:
    - services/backend/app/services/confidence/source_crosswalk.py
    - services/backend/tests/test_source_crosswalk.py
    - .planning/runtime-evidence/phase-37/source-01/audit-manifest.json
  modified:
    - .planning/goals/G1-blocking-gate-tickets.md
    - .planning/runtime-evidence/phase-37/ticket-evidence.json

key-decisions:
  - "SOURCE-01 translates provenance identities only; mobile and backend confidence weights remain intentionally separate."
  - "Every unknown or backend-only token presented as mobile raises explicitly; there is no fallback."
  - "The crosswalk remains a foundation until PROV-01 supplies its live caller; it does not authorize Phase 37 or G2 acceptance."

patterns-established:
  - "Cross-stack enum guard: parse the living mobile enum and require an exact backend mapping."
  - "Progressive acceptance: one ticket transitions GREEN with its own RED/GREEN SHAs and two accepted audit lenses."

requirements-completed: [RDY-SOURCE-01]

duration: 27min
completed: 2026-07-12
---

# Phase 37 Plan 01: Source Crosswalk Summary

**Immutable five-source provenance translation with fail-closed unknown handling, exhaustive cross-stack tests, and evidence-backed SOURCE-01 acceptance**

## Performance

- **Duration:** 27 min
- **Started:** 2026-07-12T15:45:00Z
- **Completed:** 2026-07-12T16:12:26Z
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments

- Added the single backend translation for all five living mobile
  `ProfileDataSource` tokens, backed exclusively by the existing `DataSource`
  enum.
- Classified `document_scan`, `institutional_api`, and `user_estimate` as
  backend-only and rejected them when presented as mobile input.
- Proved a genuine test-first transition: the test-only SHA failed on the
  absent SOURCE-01 business contract, then the production SHA passed the
  identical registry command.
- Kept the slice free of copied weights, competing enums, fallback values,
  logging, API changes, database changes, and Flutter changes.
- Accepted one wrapper-only Opus code audit and one product-domain audit with
  zero P0/P1/critical/high findings, while retaining four complete accepted-P2
  findings in the manifest.

## Task Commits

Each task was committed atomically:

1. **Task 1: Exhaustive source-crosswalk RED contract** — `53dd840c9`
2. **Task 2: Immutable fail-closed crosswalk GREEN** — `ee6912679`
3. **Task 3: SOURCE-01 evidence and audits** — `87ea82f55`

## Files Created/Modified

- `services/backend/tests/test_source_crosswalk.py` — parses the real mobile
  enum, requires the exact five identities, verifies living accuracy sources,
  checks the three backend-only exclusions, and exercises fail-closed inputs.
- `services/backend/app/services/confidence/source_crosswalk.py` — immutable
  mapping, backend-only set, and pure rejecting translator.
- `.planning/runtime-evidence/phase-37/source-01/` — exact RED/GREEN logs,
  complete audit outputs, fail-closed manifest, and verification record.
- `.planning/goals/G1-blocking-gate-tickets.md` — SOURCE-01 alone promoted to
  `green`.
- `.planning/runtime-evidence/phase-37/ticket-evidence.json` — SOURCE-01
  accepted SHAs and artifacts; all other ticket states preserved.

## Decisions Made

- The identity crosswalk does not reconcile confidence weights. Mobile
  `userInput` and backend `user_entry` keep their documented independent
  scoring semantics.
- PROV-01 must become the live consumer before Phase 37 closure. Shipping this
  tested foundation does not claim a complete runtime integration.
- Audit P2 findings remain explicit and accepted in the manifest; only
  unresolved P0/P1/critical/high findings block this slice.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The task-local backend baseline exposed 95 pre-existing global ruff errors.
  No unrelated lint was changed: both touched files are ruff-clean and the
  global count remains exactly 95 after implementation.
- The mandated Flutter analyzer baseline remains exactly 114 pre-existing
  diagnostics. No Flutter file changed, and the pre-change full Flutter suite
  passed all 8,500 tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SOURCE-01 is evidence-backed GREEN and ready for PROV-01 consumption in the
  already planned provenance wave.
- The registry remains 21 `ticket_only`, one `green`, and one `red_proven`.
- G2 remains blocked. The next authorized slice is 37-02; it has not started.

---
*Phase: 37-ledger-runtime-readiness*
*Completed: 2026-07-12*
