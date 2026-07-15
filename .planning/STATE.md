---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Product Reality — Six Boucles, Un Dossier
status: executing
stopped_at: Phase 37 plans reconciled to all 31 registry rows; next is the BND-02A legal pre-gate then the integrated BND-02/BND-02A caller slice; 17 hard floors remain and G2/G3 are not authorized.
last_updated: "2026-07-15T13:26:05Z"
last_activity: 2026-07-15 -- exact plan/validation coverage guard added; historical 23-row plans reconciled to the 31-row registry without reopening GREEN tickets
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

Plan: 37-04 — partner accountability and real downstream bridge

Status: Executing Phase 37

Last activity: 2026-07-15 -- the executable Phase 37 plans and validation map
now cover every one of the 31 live registry rows exactly once. The next slice
starts with the BND-02A named legal/privacy decision and semantic RED, then
builds the real BND-02 caller/downstream/caisse proof before closing BND-02A on
that caller. Production activation remains disabled and G1 remains NO-GO.

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
- The same gate now rejects any Phase 37 plan set that omits or duplicates a
  live ticket, and rejects validation commands/statuses that drift from the
  registry/evidence index. Plan 37-07 cannot start before exactly 30/31 GREEN
  with only `G1-RUNTIME-01` open.
- `G1-PROV-03` is code-GREEN at `5a772865b` and runtime-GREEN at
  `ac74672db`; its tax ingestion flags remain production-off.
- `G1-PROV-02` is ticket- and runtime-GREEN at `30728b8a0671`; both LPP
  ingestion flags remain production-off. A named downstream consumer and the
  named legal/privacy accountability decision and outcome remain
  activation/later-G1 blockers.

## Active Blockers

- The canonical registry has 31 rows: 14 `green`, 16 `ticket_only`, and one
  `red_proven`. Therefore 17 G1 hard floors remain open.
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

Last session: 2026-07-15T13:26:05Z

Stopped at: Phase 37 plan coverage is reconciled. Start the BND-02A legal
pre-gate and integrated BND-02/BND-02A slice; LPP activation stays NO.

Resume files: `.planning/runtime-evidence/phase-37/ticket-evidence.json` and
`.planning/phases/37-ledger-runtime-readiness/37-04-PLAN.md`. Do not infer
progress from plan numbering alone.

## Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|---:|---:|---:|---:|---:|
| 37 | 01 | 27 min | 3 | 12 |
