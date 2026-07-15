---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Product Reality — Six Boucles, Un Dossier
status: executing
stopped_at: BND-03 has exact-command semantic RED at production SHA 683e2a1f2 with 1 pass/4 business failures; no product fix has started, 15 hard floors remain, and G2/G3 are not authorized.
last_updated: "2026-07-15T22:44:42Z"
last_activity: 2026-07-15 -- BND-03 advanced from W0 missing-test to collected semantic RED covering stale budget cache, cadence collision, absent live bridge and incorrect budget snapshot delta
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

Last activity: 2026-07-15 -- the exact BND-03 command collects five tests and
returns 1 pass / 4 semantic failures against production SHA `683e2a1f2`: stale
cache 9999/666/888 overrides ledger 1800/400/300 after explicit reload;
BudgetSetup overwrites yearly income cadence and omits monthly housing cadence;
the live BudgetProvider bridge emits no notification/deltas; MintState moves
charges/free by ±783.333 instead of ±650. The fail-closed `budgetGap=null`
predicate passes. This is RED evidence only; no product fix has started.

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
  ingestion flags remain production-off. BND-02A now selects an isolated
  represented-authorization receipt rather than the legacy nominative consent
  chain, and BND-02 names the RetirementDashboard consumer. Controller/contact,
  Anthropic role/DPA and regions, transfer/TIA, retention/ZDR, publishable
  notice/rights channel and the AIPD decision remain activation blockers.
- `G1-BND-02` and `G1-BND-02A` are technical `green` at exact SHA
  `1d022c508`. Their identical commands, cold owner/status-gated consumer,
  explicit caisse quarantine, exact-self 0.02 handling, lifecycle rollback,
  Patrol/Maestro runtime and four wrapper-only audits are accepted. All LPP
  accountability flags remain false. Technical GREEN never authorizes
  activation.

## Active Blockers

- The canonical registry has 31 rows: 16 `green`, 13 `ticket_only`, and two
  `red_proven`. Therefore 15 G1 hard floors remain open.
- `G1-RUNTIME-01` remains `red_proven` at the distinct salary/canton to
  mortgage cold-relaunch consumer; the PROV-03 tax runtime does not close it.
- `G1-BND-03` is `red_proven` at `683e2a1f2`; its exact test now exists and
  fails only on the four intended budget bridge/cadence/cache predicates, so
  W0 missing-test no longer describes this row.
- Eight external production facts remain unproven: controller identity,
  operational privacy contact, Anthropic role/DPA, actual processing regions,
  transfer mechanism/TIA, retention/ZDR, AIPD decision, and the public
  account-free rights channel/runbook/test. They keep LPP activation NO-GO but
  do not undo the default-off technical ticket acceptance.

- Phase 38 and all later phases are dependency-blocked by Phase 37.
- This is expected planned work, not a user-input blocker.

## Historical Context

The previous v2.8 STATE was contradictory and remains immutable at Git commit
`5f8de38ec` with its roadmap, requirements, and phase artifacts. A local
excluded working archive is outside the active GSD scan. No historical summary
counts as a current-SHA PASS without targeted revalidation.

## Session Continuity

Last session: 2026-07-15T22:44:42Z

Stopped at: BND-03 semantic RED evidence is prepared against exact production
SHA `683e2a1f2`; no product implementation, commit or push was performed by the
quality-gate agent. Continue only G1 BND-03 after reviewing the RED slice. Do
not start G2/G3.

Resume files: `.planning/runtime-evidence/phase-37/ticket-evidence.json` and
`.planning/phases/37-ledger-runtime-readiness/37-04-PLAN.md`. Do not infer
progress from plan numbering alone.

## Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|---:|---:|---:|---:|---:|
| 37 | 01 | 27 min | 3 | 12 |
