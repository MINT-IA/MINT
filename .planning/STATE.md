---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Product Reality — Six Boucles, Un Dossier
status: executing
stopped_at: Phase 37 cross-plan execution; 13/31 GREEN and 18 hard floors remain; G2/G3 are not authorized.
last_updated: "2026-07-14T17:30:00Z"
last_activity: 2026-07-14 -- PROV-03 code and exact-SHA runtime proved GREEN; acceptance evidence reconciliation in progress
progress:
  total_phases: 14
  completed_phases: 0
  total_plans: 8
  completed_plans: 2
  percent: 25
---

# GSD State: MINT v3.0 — Product Reality

## Project Reference

See `.planning/PROJECT.md` and
`.planning/goals/v3-product-reality-migration-manifest-2026-07-12.md`.

**Core value:** A user understands a real Swiss financial decision with their
own sourced data and leaves with clear questions plus a specialist-ready dossier.

**Current focus:** Phase 37 — ledger-runtime-readiness

## Current Position

Phase: 37 (ledger-runtime-readiness) — EXECUTING

Plan: cross-plan G1 execution under 37-02 through 37-07

Status: Executing Phase 37

Last activity: 2026-07-14 -- PROV-03 typed-tax persistence proved through
real process death at exact SHA `ac74672db`; code and product-domain audits
passed without P0/P1. Production activation remains disabled.

## Build Order

`37 -> 38 -> 39 -> 40 -> 41 -> 42 -> 43 -> 44 -> 45 -> 46 -> 47 -> 48 -> 49 -> 50`

- 37: 31 G1 blockers, runtime proof, audits, G2 decision.
- 38: Mint OS runway, flags, guards, old P0 convergence.
- 39: G2 DataQuest + CaseRegistry.
- 40-45: six G3 loops in product-plan order.
- 46: G4 dossier/PDF.
- 47: G5 runtime/drift.
- 48: G6 beta cohesion.
- 49: Chat Vivant convergence.
- 50: final release gate.

## Hard Floors

- Mint OS Doctor and checked-in wrappers are mandatory per phase.
- G2 allowed is NO until Phase 37 is accepted at >=9.0 with 31/31 GREEN.
- G3 allowed is NO until Phase 39 is accepted.
- Every UI P0 slice ships same-slice Maestro and Patrol evidence.
- Financial paths require Claude code and product-domain audits; architecture
  audit is required for core boundaries and closures.

- No phase is complete below 9.0; final program is complete only at >=9.5 and
  zero open P0/P1.

## Active Decisions

- v2.8 is archived as incomplete; completed CTX/OBS/MAP work is revalidated,
  not replayed.

- The July 2026 product plan is authoritative for G2-G6.
- Phase numbering continues at 37.
- Chat Vivant follows G6 and must reuse the one ledger/Case/dossier spine.
- `G1-SOURCE-01` is the first evidence-backed GREEN ticket; its live caller
  remains the already planned PROV-01 provenance slice.
- Source translation maps identities only. Mobile and backend confidence
  weights remain separate documented scoring contracts.
- The checked-in registry expanded from the original 23 rows to 31 as eight
  additional Swiss correctness, provenance and runtime hard floors were made
  explicit. The live registry and its checked-in guard are authoritative.
- `G1-PROV-03` is code-GREEN at `5a772865b` and runtime-GREEN at
  `ac74672db`; its tax ingestion flags remain production-off.

## Active Blockers

- The canonical registry has 31 rows: 13 `green`, 17 `ticket_only`, and one
  `red_proven`. Therefore 18 G1 hard floors remain open.
- `G1-RUNTIME-01` remains `red_proven` at the distinct salary/canton to
  mortgage cold-relaunch consumer; the PROV-03 tax runtime does not close it.

- Phase 38 and all later phases are dependency-blocked by Phase 37.
- This is expected planned work, not a user-input blocker.

## Historical Context

The previous v2.8 STATE was contradictory and remains immutable at Git commit
`5f8de38ec` with its roadmap, requirements, and phase artifacts. A local
excluded working archive is outside the active GSD scan. No historical summary
counts as a current-SHA PASS without targeted revalidation.

## Session Continuity

Last session: 2026-07-14T17:30:00Z

Stopped at: PROV-03 evidence reconciliation after exact-SHA runtime and external
audits; select the next dependency-valid ticket from the 18 remaining G1 rows.

Resume files: `.planning/runtime-evidence/phase-37/ticket-evidence.json` and
`.planning/phases/37-ledger-runtime-readiness/37-02-PLAN.md` through
`37-07-PLAN.md`. Do not infer progress from plan numbering alone.

## Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|---:|---:|---:|---:|---:|
| 37 | 01 | 27 min | 3 | 12 |
