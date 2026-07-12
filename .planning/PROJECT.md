# MINT — Product Reality

## What This Is

MINT is a Swiss financial lucidity system built with Flutter and FastAPI. It
maintains a living ledger of user facts, opens decision-focused cases, asks only
for missing or stale information, compares scenarios without advice language,
and produces a specialist-ready dossier.

The active product spine is:

`ledger variable -> DataQuest ask -> Case/scenario -> screen state -> dossier/PDF -> runtime proof`

## Core Value

**A user understands a real Swiss financial decision with their own sourced
data, sees what is known, estimated, stale, or missing, and leaves with clear
questions and a dossier they can use with the right specialist.**

## Current Milestone: v3.0 Product Reality — Six Boucles, Un Dossier

**Goal:** Close the 23 G1 runtime-readiness blockers, converge the unfinished
v2.8 operating work into Mint OS, then deliver G2, six complete G3 loops, G4
dossier/PDF, G5 runtime/drift proof, G6 beta cohesion, and the preserved Chat
Vivant plan without accepting any phase below its evidence floor.

**Target outcomes:**

- 23/23 G1 blockers implemented with real RED -> GREEN evidence before G2.
- One versioned Mint OS operating contract; no ad-hoc tool substitutions.
- DataQuest and CaseRegistry collect exactly the missing or stale delta.
- Six P0 loops work from entry point to dossier: work, housing, retirement,
  disability, succession, and frontalier.
- Every financial result exposes known/missing/estimated/stale state,
  provenance, freshness, confidence, and recovery.
- Every P0 slice has unit/widget/integration proof plus Maestro and Patrol on a
  real iPhone simulator path in the same slice.
- Every phase has external Claude audits through the checked-in wrapper and a
  scorecard of at least 9.0/10; final program score is at least 9.5/10.

## Requirements

### Validated foundations

- G1 Ledger Reality Baseline closed at commit `5f8de38ec`, score 9.2/10.
- Route registry parity is live: 149 path literals, 148 registry keys, and 141
  comparable routes after documented exemptions on 2026-07-12.
- Mermaid, Maestro, Patrol, Claude audit wrapper, route reconciliation, and MINT
  agent workflow are visible to `mint_os_doctor.py --repo-only`.
- v2.8 CTX-01..05, OBS-01..07, and MAP-01..05 have historical implementation
  summaries; they remain subject to targeted current-SHA revalidation.

### Active

See `.planning/REQUIREMENTS.md`. The binding order is:

1. Phase 37 closes all 23 G1 blockers.
2. Phase 38 closes the operating runway and unfinished v2.8 prerequisites.
3. Phase 39 delivers G2.
4. Phases 40-45 deliver the six G3 loops.
5. Phases 46-48 deliver G4-G6.
6. Phase 49 converges Chat Vivant onto the proven product spine.
7. Phase 50 is the final route-wide release gate.

### Out of scope

- Production account/login expansion beyond persisted local/demo facts required
  by the P0 loops.
- Advisor marketplace or institutional API integrations.
- A broad new catalog of Swiss topics outside the six P0 loops.
- Unsupported legal/tax precision, advice, rankings, or guarantees.
- Beads initialization except through a dedicated reviewable PR.
- New unversioned MCP or local wrappers that duplicate Mint OS gates.

## Operating Constraints

### Mint OS zero-drift hard floor

Every phase starts with the repo-only Doctor and every runtime phase runs the
full Doctor. A tool claim counts only when the Doctor and the checked-in wrapper
see it.

- External Claude: `tools/checks/claude_external_audit.sh`; no direct CLI audit
  invocation.
- Maestro: checked-in environment/watchdog wrappers.
- Patrol: `$HOME/.pub-cache/bin/patrol` plus
  `tools/checks/patrol_tooling_guard.py`.
- Mermaid: `tools/checks/mermaid_render_guard.py`.
- Routes: `./tools/mint-routes reconcile`.
- Interaction and persistence: checked-in registry, coverage, ledger, and
  no-bypass gates.
- Git hooks: lefthook, with no silent bypass.

Any wrapper disappearance, contract drift, wrong-SHA runtime evidence, or
unverified substitution stops the phase and becomes a separate infrastructure
repair.

### Product and quality floors

- G2 remains `NO` until all 23 G1 tickets are GREEN, runtime proof exists, both
  financial audit lenses pass, and the Phase 37 scorecard is >=9.0.
- G3 remains `NO` until G2 is fully accepted.
- Swiss meaning is specified before financial implementation.
- Durable user facts live in `CoachProfileProvider`; `MintStateProvider` is a
  derived read model; scenario levers remain case/session assumptions.
- No façade without wiring, no route without a renderer/recovery path, no
  scenario without tests, no screen-local durable financial fact.
- New product paths have a default-off feature flag and a proved kill switch.
- Commits are atomic and pushed regularly; unrelated user changes are preserved.

## Context

The previous active GSD milestone, v2.8 L'Oracle & La Boucle, was internally
inconsistent: four of nine phases had summaries, Phase 32 remained AMBER, while
STATE reported 100%. Its exact plan and phase artifacts remain immutable at Git
commit `5f8de38ec`; its unresolved intentions are mapped in
`.planning/goals/v3-product-reality-migration-manifest-2026-07-12.md`.

The old v2.8 rules "zero new feature" and "Patrol out of scope" are superseded
by `AGENTS.md`, `CLAUDE.md`, and the 2026-07-12 product plan. Completed v2.8
work is not replayed; it is revalidated where the current milestone consumes
it. Unfinished work is absorbed only when it protects the product spine.

## Key Decisions

| Decision | Rationale | Status |
|---|---|---|
| Start v3.0 at Phase 37 | Preserve historical numbering and avoid collisions. | accepted |
| Archive v2.8 as incomplete | Its remaining work is real, but its state cannot truthfully be marked complete. | accepted |
| Make the July G2-G6 plan authoritative | It defines the current product outcome and hard floors. | accepted |
| Treat Mint OS as a hard floor | Prevent tool drift, fake unavailability, and ad-hoc evidence. | accepted |
| Close 23 blockers before G2 | Ticket-only contracts are not runtime readiness. | accepted |
| Revalidate rather than replay v2.8 CTX/OBS/MAP | Historical summaries are evidence pointers, not current-SHA proof. | accepted |
| Preserve Chat Vivant after G6 | It must converge onto the product spine, not create duplicate state/screens. | accepted |

## Evolution

This document evolves at phase transitions and milestone boundaries.

After each phase, validated requirements move out of Active with evidence
references; invalidated assumptions move to Out of Scope with a reason; new
requirements require an explicit phase mapping and cannot silently expand a
current slice.

---
*Last updated: 2026-07-12 for milestone v3.0 Product Reality*
