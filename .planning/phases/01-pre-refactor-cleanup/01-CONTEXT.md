# Phase 1: Pre-Refactor Cleanup - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate duplicate service copies, orphan routes, and dead screens so the codebase is safe to build on. No new features — strictly removing dead weight and resolving ambiguity in the existing code.

</domain>

<decisions>
## Implementation Decisions

### Duplicate Service Resolution
- **D-01:** For each of the 3 duplicate pairs, trace imports across the codebase to determine which copy is actually used — the copy with more importers is canonical
- **D-02:** Delete the non-canonical copy entirely (no re-export shim, no backward-compat wrapper)
- **D-03:** Update all imports to point to the surviving canonical file
- **D-04:** The 3 pairs: `coach_narrative_service.dart` (root vs coach/), `community_challenge_service.dart` (gamification/ vs coach/), `goal_tracker_service.dart` (memory/ vs coach/)

### Route Triage
- **D-05:** Classify each of 67 canonical routes as: **live** (has screen + reachable), **redirected** (old path forwarding to new — keep redirect), or **archived** (no screen, no redirect, not referenced — remove route entry)
- **D-06:** Wire Spec V2 archived routes (`/ask-mint`, `/tools`, `/coach/cockpit`, `/coach/checkin`, `/coach/refresh`) already have redirects to `/home?tab=N` — keep these redirects, remove the old screen files if they still exist
- **D-07:** A route is "dead" only when no screen file exists AND no redirect is configured AND it is not referenced in any navigation code

### Dead Screen Removal
- **D-08:** Remove screen files with zero routes pointing to them (truly unreachable)
- **D-09:** Deprecated screens with active redirects (e.g., `ask_mint_screen.dart`) — remove the screen file, keep the redirect pointing to the replacement
- **D-10:** `theme_detail_screen.dart` with broken imports to removed `mint_ui_kit.dart` — remove
- **D-11:** After all removals, `flutter analyze` must report 0 errors

### Claude's Discretion
- Order of operations (which duplicate pair to resolve first)
- Exact git commit granularity (one commit per pair vs one commit for all duplicates)
- Whether to add a brief comment at redirect sites explaining the redirect purpose

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Navigation & Routes
- `docs/NAVIGATION_GRAAL_V10.md` — Detailed target IA with all 67 canonical routes, Wire Spec V2 archived routes, redirect rules
- `apps/mobile/lib/app.dart` — GoRouter route table (source of truth for what routes exist in code)

### Codebase Analysis
- `.planning/codebase/CONCERNS.md` — Lists the 3 duplicate service pairs, deprecated screens, and legacy term references
- `.planning/codebase/STRUCTURE.md` — Directory layout and screen organization

### Architecture
- `decisions/ADR-20260223-unified-financial-engine.md` — Financial core as single source of truth (relevant for understanding why duplicates are harmful)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- GoRouter route table in `app.dart` — single file to audit for all route definitions
- Wire Spec V2 redirect rules already implemented for 5 archived routes

### Established Patterns
- Import organization: `package:mint_mobile/` prefix for all project imports — makes tracing imports mechanical
- Provider pattern: all providers in `lib/providers/` — need to check provider references to duplicate services

### Integration Points
- `lib/services/coach/` subdirectory is the main area where duplicates live — coach_narrative, community_challenge, goal_tracker
- `lib/services/` root also has copies — import tracing will determine which location wins
- Route table in `app.dart` connects to all screens — the single file to audit for orphan routes

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard mechanical cleanup approach.

</specifics>

<deferred>
## Deferred Ideas

- **Legacy "chiffre choc" rename** (51 files) — Internal term only, not user-facing. Dedicated rename sprint, not a cleanup prerequisite. Does not block Phase 2+ wiring work.
- **i18n hardcoded French strings** (~120 strings in 24 service files) — Separate concern, tracked in project memory as D4 priority.

</deferred>

---

*Phase: 01-pre-refactor-cleanup*
*Context gathered: 2026-04-05*
