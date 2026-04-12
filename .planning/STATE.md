---
gsd_state_version: 1.0
milestone: v2.5
milestone_name: Transformation
status: executing
stopped_at: Completed 15-01-PLAN.md
last_updated: "2026-04-12T18:09:47.764Z"
last_activity: 2026-04-12
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 9
  completed_plans: 8
  percent: 89
---

# GSD State: MINT v2.5 — Transformation

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.
**Current focus:** Phase 15 — Coach Intelligence

## Current Position

Phase: 15 (Coach Intelligence) — EXECUTING
Plan: 2 of 2
Status: Ready to execute
Last activity: 2026-04-12

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 12 (from v2.4)
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
| Phase 14-commitment-devices P02 | 11min | 2 tasks | 19 files |
| Phase 14-commitment-devices P03 | 6min | 2 tasks | 17 files |
| 14 | 3 | - | - |
| Phase 15-coach-intelligence P01 | 10min | 2 tasks | 7 files |

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
- [Phase 14-commitment-devices]: Notification scheduling pulled into Task 1 to avoid compile error in widget_renderer
- [Phase 14-commitment-devices]: Dual rate limiting for fresh-start: server-side primary, client SharedPreferences as UX backup
- [Phase 14-commitment-devices]: Fresh-start notification IDs in 6000+ range, job anniversary uses July 1 midpoint
- [Phase 15]: Immediate DB persistence for provenance/earmark tools (not ack-only) — data needed in next conversation
- [Phase 15]: user_id and db threaded through _run_agent_loop to _execute_internal_tool for DB write access

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

Last session: 2026-04-12T18:09:47.761Z
Stopped at: Completed 15-01-PLAN.md
Resume file: None

---
*Last activity: 2026-04-12 — Roadmap v2.5 created with 6 phases, 25 requirements mapped*
