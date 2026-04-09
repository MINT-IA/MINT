---
gsd_state_version: 1.0
milestone: v2.3
milestone_name: Simplification Radicale
status: Roadmap created — Phase 1 not started
stopped_at: ROADMAP.md + REQUIREMENTS.md traceability written, awaiting /gsd-plan-phase 1
last_updated: "2026-04-09T00:00:00.000Z"
last_activity: 2026-04-09 — gsd-roadmapper created 6 phases, 33/33 requirements mapped
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-09)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Current focus:** v2.3 Simplification Radicale — Phase 1 (Architectural foundation) ready to plan

## Current Position

Phase: 1 — Architectural foundation (not started)
Plan: —
Status: Roadmap created, awaiting `/gsd-plan-phase 1`
Last activity: 2026-04-09 — Roadmap written: 6 phases, 33/33 requirements mapped

## Phase Map (v2.3)

1. Architectural foundation — NAV-01, NAV-02, GATE-01..05, DEVICE-01
2. Deletion spree — KILL-01..07, BUG-01, BUG-02
3. Chat-as-shell rebuild — CHAT-01..05
4. Residual bugs & i18n hygiene — BUG-03, BUG-04, NAV-03..06
5. Sober visual polish — POLISH-01..04
6. End-to-end device walkthrough & ship gate — DEVICE-02

## Accumulated Context

### v2.2 outcome (carryover)

- 15 phases shipped, 175+ commits, 9326 Flutter tests + 5246 backend tests, 18/18 automated ship gates green, audit grade A-
- TestFlight build 2026-04-08 — Julien device walkthrough 2026-04-09 found 4 P0 bugs in 4 minutes
- Lesson: tests green ≠ app functional. Gate 0 (creator-device walkthrough) becomes mandatory non-skippable per phase from v2.3 forward.

### v2.3 inputs (read before any phase)

- `.planning/v2.3-handoff/HANDOFF.md` — full context + 2 founding principles
- `.planning/v2.3-handoff/screenshots/WALKTHROUGH_NOTES.md` — device diagnosis
- `docs/NAVIGATION_MAP_v2.2_REALITY.md` — file:line root-causes for 4 P0
- `docs/AESTHETIC_AUDIT_v2.2_BRUTAL.md` — 7/10 screens to delete as destinations

### 4 P0 bugs (from device walkthrough)

1. **Auth leak** — dissolves via Phase 1 (scope-based guard) + Phase 2 deletion
2. **Infinite loop** — fixed in Phase 2 at `coach_chat_screen.dart:1317` (BUG-01)
3. **Centre de contrôle catastrophe** — dissolves via Phase 2 KILL-03
4. **Créer ton compte horrible** — dissolves via Phase 2 KILL-05

### 2 founding principles (apply to every phase)

1. **3-second no-finance-human test** — replaces all UI ship gates
2. **Chat EST l'app (chat-as-shell inversion)** — every destination screen is suspect

### Gate 0 reminder

DEVICE-01 is a recurring Gate 0 on every phase (1-5). No PR merges without creator-device annotated screenshots showing the flow works on a real iPhone.

### Carryover technical debt

- 12 orphan GoRouter routes (v2.1) — absorbed by Phase 2 deletion spree
- ~65 NEEDS-VERIFY try/except blocks — out of scope for v2.3
- ACCESS-01 a11y partner emails never sent (deferred v2.4)
- Krippendorff α validation infra ready but never run (deferred v2.4)

### Pending Todos

- Run `/gsd-plan-phase 1` to decompose Phase 1 into plans

### Blockers/Concerns

- None. Phase 1 can begin immediately.

## Session Continuity

Last session: 2026-04-09
Stopped at: Roadmap created, 33/33 requirements mapped, Phase 1 ready to plan
Resume file: None — next step is `/gsd-plan-phase 1`
