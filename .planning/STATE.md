---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: verifying
stopped_at: Completed 11-02-PLAN.md
last_updated: "2026-04-12T10:34:06.488Z"
last_activity: 2026-04-12
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 5
  completed_plans: 5
  percent: 100
---

# GSD State: MINT v2.4 — Fondation

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Un humain externe peut ouvrir MINT, naviguer, uploader, recevoir un premier eclairage, parler au coach — zero crash, zero 404, zero boucle.
**Current focus:** Phase 11 — La navigation

## Current Position

Phase: 11 (La navigation) — EXECUTING
Plan: 2 of 2
Status: Phase complete — ready for verification
Last activity: 2026-04-12

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 3
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9 — Les tuyaux | 0/TBD | — | — |
| 10 — Les connexions | 0/TBD | — | — |
| 11 — La navigation | 0/TBD | — | — |
| 12 — La preuve | 0/TBD | — | — |
| Phase 09-les-tuyaux P01 | 4min | 2 tasks | 6 files |
| Phase 09-les-tuyaux P02 | 2min | 1 tasks | 2 files |
| 09 | 2 | - | - |
| Phase 10-les-connexions P01 | 6min | 3 tasks | 5 files |
| 10 | 1 | - | - |
| Phase 11-la-navigation P01 | 11min | 2 tasks | 6 files |
| Phase 11-la-navigation P02 | 5min | 2 tasks | 5 files |

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Sequential execution non-negotiable (parallel agents caused the current damage)
- Backend before frontend (fixing Flutter when backend crashes yields 500s not 404s)
- Device gate is the only real validation (9256 tests green proved nothing)
- [Phase 09-les-tuyaux]: Repo-root Docker build context to include education/inserts without symlinks
- [Phase 09-les-tuyaux]: 55s total + 25s per-iteration timeout on agent loop, graceful French message on timeout
- [Phase 10-les-connexions]: No camelCase fallback in fromJson — backend is source of truth, single key enforces contract
- [Phase 10-les-connexions]: Staging URL as fallback after production URL, not replacement
- [Phase 11-la-navigation]: ScopedGoRoute works inside StatefulShellBranch for auth scope preservation
- [Phase 11-la-navigation]: LandingScreen reused for Aujourd'hui tab (MintHomeScreen does not exist)
- [Phase 11-la-navigation]: MintNav.back() uses /home fallback (not /coach/chat) to prevent infinite loop
- [Phase 11-la-navigation]: safePop kept as shim delegating to MintNav.back() — 44 call sites unchanged

### From Previous Milestones

- v2.1: Coach tool calling wired on BYOK path, 11 dead services deleted, CI green on dev
- Deep audit (2026-04-12): 32 findings, 11 P0 — root causes: double URL prefix, camelCase mismatch, zero shell, ephemeral ChromaDB

### Blockers/Concerns

- Railway volume mount permissions (UID) need firsthand verification on staging deploy (Phase 9)
- ScopedGoRoute compatibility with StatefulShellRoute untested (Phase 11)
- DELETE /coach/sync-insight/{id} endpoint does not exist yet (Phase 10)

## Session Continuity

Last session: 2026-04-12T10:34:06.486Z
Stopped at: Completed 11-02-PLAN.md
Resume file: None

---
*Last activity: 2026-04-12 — Roadmap created*
