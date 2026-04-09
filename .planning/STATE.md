---
gsd_state_version: 1.0
milestone: v2.3
milestone_name: Simplification Radicale
status: Defining requirements
stopped_at: PROJECT.md updated, awaiting REQUIREMENTS.md + ROADMAP.md
last_updated: "2026-04-09T00:00:00.000Z"
last_activity: 2026-04-09 — v2.3 Simplification Radicale started after device walkthrough revealed 4 P0
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-09)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Current focus:** v2.3 Simplification Radicale — chat-as-shell inversion, defining requirements

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-04-09 — Milestone v2.3 started

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

1. **Auth leak** — `register_screen.dart:431,445` go to `/profile/consent`; `app.dart:167-173` `protectedPrefixes` is operation-based not scope-based, `/profile/*` `/home` `/explore/*` unprotected
2. **Infinite loop** — `coach_chat_screen.dart:1317` short-circuits to `CoachEmptyState` before payload consumed; `coach_empty_state.dart:63` routes back to `/onboarding/intent`
3. **Centre de contrôle catastrophe** — `/profile/consent` registered as destination at `app.dart:653-656` instead of contextual summon; 8 toggles + raw nLPD references
4. **Créer ton compte horrible** — 25+ elements, banned jargon, 4 consents, source of Bug 1

### 2 founding principles (apply to every phase)

1. **3-second no-finance-human test** — replaces all UI ship gates
2. **Chat EST l'app (chat-as-shell inversion)** — every destination screen is suspect; should it be a drawer or deleted?

### Carryover technical debt

- 12 orphan GoRouter routes (v2.1)
- ~65 NEEDS-VERIFY try/except blocks
- ACCESS-01 a11y partner emails never sent (deferred v2.4)
- Krippendorff α validation (15 testers) infra ready but never run (deferred v2.4)

### Pending Todos

- Write `.planning/REQUIREMENTS.md`
- Spawn gsd-roadmapper for v2.3 phases (reset numbering at 1)

### Blockers/Concerns

- None at milestone level. Roadmap can be created immediately from the 2 audits.

## Session Continuity

Last session: 2026-04-09
Stopped at: PROJECT.md updated for v2.3, STATE.md reset
Resume file: None — next step is REQUIREMENTS.md generation
