---
gsd_state_version: 1.0
milestone: v2.6
milestone_name: Le Coach Qui Marche
status: verifying
stopped_at: Completed 23-01-PLAN.md
last_updated: "2026-04-13T18:23:39.089Z"
last_activity: 2026-04-13
progress:
  total_phases: 14
  completed_phases: 9
  total_plans: 16
  completed_plans: 17
  percent: 100
---

# GSD State: MINT v2.5 — Transformation

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.
**Current focus:** Phase 18 — Living Timeline Full Timeline

## Current Position

Phase: 24
Plan: Not started
Status: Phase complete — ready for verification
Last activity: 2026-04-13

Progress: [##########] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 21 (from v2.4)
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
| Phase 15-coach-intelligence P02 | 4min | 1 tasks | 1 files |
| 15 | 2 | - | - |
| Phase 16-couple-mode-dissymetrique P01 | 4min | 2 tasks | 4 files |
| Phase 16 P02 | 7min | 2 tasks | 7 files |
| 16 | 2 | - | - |
| Phase 17 P01 | 6min | 2 tasks | 15 files |
| 17 | 1 | - | - |
| Phase 18 P01 | 5min | 2 tasks | 19 files |
| 18 | 1 | - | - |
| Phase 21 P01 | 7min | 2 tasks | 4 files |
| 21 | 1 | - | - |
| Phase 22 P01 | 6min | 2 tasks | 17 files |
| 22 | 1 | - | - |
| Phase 23 P01 | 7min | 2 tasks | 4 files |
| 23 | 1 | - | - |

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
- [Phase 15-coach-intelligence]: Used real SQLite in-memory DB (not mocks) for integration tests to prove actual ORM round-trip
- [Phase 16]: Ack-only handlers with zero DB/user_id access — privacy guarantee enforced by source inspection tests
- [Phase 16]: System prompt asks one question at a time in priority order (salary > age > LPP > 3a > canton)
- [Phase 16]: Partner aggregate injected in coach_chat_api_service.chat() — single injection point covers all paths
- [Phase 16]: degradeForPartnerEstimate as static method on ConfidenceScorer — minimal surface, callers opt-in
- [Phase 17]: Auth-aware GoRoute builder using context.watch<AuthProvider>() for reactive routing
- [Phase 17]: Tension card i18n keys stored as string IDs in model, resolved at widget level via S.of(context)
- [Phase 18]: TimelineProvider extends TensionCardProvider (IS-A) so existing tension card consumers work via type hierarchy
- [Phase 20]: Conversation history as structured messages array (not concatenated text) for proper multi-turn Claude API; history only on first agent loop iteration
- [Phase 21]: Dedup by user_id+topic: upsert pattern for save_insight prevents unbounded DB growth
- [Phase 21]: DB insights searched first in retrieve_memories (Pass 0) before memory_block text for priority
- [Phase 22]: MarkdownBody (non-scrollable) for coach messages to avoid nested scroll conflicts
- [Phase 22]: Response length directive (3-5 phrases) placed above FORMAT section in system prompt
- [Phase 23]: Auto-grant document_upload consent on first upload -- user action IS informed consent per nLPD
- [Phase 23]: Vision API as PDF fallback when Docling backend unavailable

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

Last session: 2026-04-13T18:22:58.553Z
Stopped at: Completed 23-01-PLAN.md
Resume file: None

---
*Last activity: 2026-04-12 — Roadmap v2.5 created with 6 phases, 25 requirements mapped*
