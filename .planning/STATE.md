# GSD State: MINT v2.4 — Fondation

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Un humain externe peut ouvrir MINT, naviguer, uploader, recevoir un premier eclairage, parler au coach — zero crash, zero 404, zero boucle.
**Current focus:** Phase 9 — Les tuyaux (backend infra)

## Current Position

Phase: 9 of 12 (Les tuyaux)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-04-12 — Roadmap created, 28 requirements mapped to 4 phases

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9 — Les tuyaux | 0/TBD | — | — |
| 10 — Les connexions | 0/TBD | — | — |
| 11 — La navigation | 0/TBD | — | — |
| 12 — La preuve | 0/TBD | — | — |

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Sequential execution non-negotiable (parallel agents caused the current damage)
- Backend before frontend (fixing Flutter when backend crashes yields 500s not 404s)
- Device gate is the only real validation (9256 tests green proved nothing)

### From Previous Milestones

- v2.1: Coach tool calling wired on BYOK path, 11 dead services deleted, CI green on dev
- Deep audit (2026-04-12): 32 findings, 11 P0 — root causes: double URL prefix, camelCase mismatch, zero shell, ephemeral ChromaDB

### Blockers/Concerns

- Railway volume mount permissions (UID) need firsthand verification on staging deploy (Phase 9)
- ScopedGoRoute compatibility with StatefulShellRoute untested (Phase 11)
- DELETE /coach/sync-insight/{id} endpoint does not exist yet (Phase 10)

## Session Continuity

Last session: 2026-04-12
Stopped at: Roadmap created, ready to plan Phase 9
Resume file: None

---
*Last activity: 2026-04-12 — Roadmap created*
