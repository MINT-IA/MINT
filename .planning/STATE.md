---
gsd_state_version: 1.0
milestone: v2.5
milestone_name: Transformation
status: executing
stopped_at: Completed 14-01-PLAN.md
last_updated: "2026-04-12T17:22:45.221Z"
last_activity: 2026-04-12
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 7
  completed_plans: 5
  percent: 71
---

# GSD State: MINT v2.5 — Transformation

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.
**Current focus:** Phase 14 — Commitment Devices

## Current Position

Phase: 14 (Commitment Devices) — EXECUTING
Plan: 2 of 3
Status: Ready to execute
Last activity: 2026-04-12

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 9 (from v2.4)
- Average duration: ~6 min/plan
- Total execution time: ~0.5 hours

**By Phase (v2.4):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9 — Les tuyaux | 2 | 6min | 3min |
| 10 — Les connexions | 1 | 6min | 6min |
| 11 — La navigation | 2 | 16min | 8min |
| Phase 13 P01 | 9min | 1 tasks | 5 files |
| Phase 13 P02 | 9min | 2 tasks | 18 files |
| Phase 13 P03 | 8min | 1 tasks | 4 files |
| Phase 13 P04 | 2min | 2 tasks | 3 files |
| 13 | 4 | - | - |
| Phase 14 P01 | 7min | 2 tasks | 6 files |

## Accumulated Context

### Decisions

- Sequential execution non-negotiable (parallel agents caused v2.4 damage)
- Device gate is the only real validation (9256 tests green proved nothing)
- Premium/monetisation deferred to v2.6 (zero external users yet)
- Anonymous intent screen already built (quick-260412-kue) — ANON-02 partially done
- Facade-without-wiring is the #1 risk — every phase must be E2E testable
- [Phase 13]: Discovery prompt written from scratch (not derived from auth prompt) to prevent info disclosure
- [Phase 13]: Separate _NoRagOrchestrator in anonymous_chat.py — full isolation from authenticated path
- [Phase 13]: Anonymous chat route outside ShellRoute for clean pre-auth UX
- [Phase 13]: Auth gate as conversational bottom sheet (coach avatar + message, not system interrupt)
- [Phase 13]: Atomic SharedPreferences migration: write new keys, verify, then delete old keys
- [Phase 13]: Eager persistence after each coach response instead of fixing callback chain — more robust against navigation changes
- [Phase 14]: Ack-only tool handlers for record_commitment and save_pre_mortem (persistence deferred to Plan 02 dedicated endpoint)
- [Phase 14]: show_commitment_card as Flutter-bound tool (not internal) for editable commitment card rendering
- [Phase 14]: DB-sourced memory block always includes commitment data for natural LLM reference

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.1: Coach tool calling wired on BYOK path, 11 dead services deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns

- Phase 12 (La preuve) still not started — v2.4 not formally validated on device yet
- Anonymous endpoint needs "mode decouverte" system prompt (reduced tools, no profile questions)
- Session migration on auth (conversation claim) is highest-risk technical challenge

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260412-kue | Implement first anonymous intent screen with felt-state pills | 2026-04-12 | 3acab9c4 | [260412-kue](./quick/260412-kue-implement-first-anonymous-intent-screen-/) |
| 260412-n09 | Fix: landing stays, animation added, pills move to coach chat | 2026-04-12 | 4dba643d | [260412-n09](./quick/260412-n09-fix-anonymous-screen-landing-stays-anima/) |

## Session Continuity

Last session: 2026-04-12T17:22:45.219Z
Stopped at: Completed 14-01-PLAN.md
Resume file: None

---
*Last activity: 2026-04-12 — Roadmap v2.5 created with 6 phases, 25 requirements mapped*
