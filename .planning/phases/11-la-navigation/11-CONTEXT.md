# Phase 11: La navigation - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

User can navigate MINT freely — 3 persistent tabs, ProfileDrawer for settings/profile/logout, working back button, no dead screens, Explorer hubs show real content.

Requirements: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07

</domain>

<decisions>
## Implementation Decisions

### Shell Architecture
- 3 tabs: Aujourd'hui / Coach / Explorer — per NAVIGATION_GRAAL_V10.md
- Material 3 NavigationBar (filled icon, label below) — uses MintColors
- Widget name: `MintShell` wrapping `StatefulShellRoute.indexedStack`
- Aujourd'hui tab reuses existing `MintHomeScreen`
- Only 3 tab root routes go inside shell branches; all 140+ other routes stay top-level with `parentNavigatorKey: _rootNavigatorKey`

### ProfileDrawer & Back Button
- ProfileDrawer triggered by icon button in AppBar (right side, endDrawer)
- safePop replaced with `MintNav.back(context)` with typed fallback map per route category
- Back button hidden entirely on root tab screens (Aujourd'hui, Coach, Explorer)
- `/profile` redirects to `/profile/bilan` instead of `/coach/chat`

### Explorer & Zombie Cleanup
- Each Explorer hub shows list of available screens/tools for that domain
- 7 hub cards in a 2-column grid layout
- 6 zombie screens (achievements, score_reveal, cockpit, annual_refresh, portfolio, ask_mint) deleted with 301 redirects for deep link compat
- Explorer hub routes resolve to real screens instead of redirecting to /coach/chat

### Claude's Discretion
- Tab icons choice (suggest: home/chat/compass or equivalent Material icons)
- MintNav fallback map exact entries (based on route categories in existing codebase)
- Explorer hub card visual design (within MintColors/MintTextStyles system)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ProfileDrawer` widget exists (280 lines, fully built, 0 imports) — just needs mounting
- `MintHomeScreen` exists — reuse as Aujourd'hui tab
- `CoachChatScreen` exists — reuse as Coach tab
- Explorer hub screens may exist (preserved from Phase 2 cleanup)
- MintColors, MintTextStyles, MintSpacing design system

### Established Patterns
- GoRouter with 143 routes in app.dart
- Provider for state management
- MintColors.* for all colors (never hardcode)
- AppLocalizations for all strings

### Integration Points
- app.dart — router restructure (add StatefulShellRoute wrapping 3 branches)
- All 140+ non-shell routes need parentNavigatorKey: _rootNavigatorKey
- safePop (40 call sites) needs migration to MintNav.back()
- ProfileDrawer needs endDrawer mount on shell scaffold

</code_context>

<specifics>
## Specific Ideas

- Navigation spec: `docs/NAVIGATION_GRAAL_V10.md` — definitive reference for shell structure
- Design system: `docs/DESIGN_SYSTEM.md` — tokens, components
- Audit findings: `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` (P0-NAV-1 through P0-NAV-4, P1-NAV-1 through P1-NAV-3)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
