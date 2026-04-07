# Phase 5: Interface Contextuelle - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

The Aujourd'hui tab shows a living, ranked set of cards that reflect what matters most to the user right now. Max 5 cards, session-deterministic ranking, biography-aware coach opener, deep links to simulators.

Requirements: CTX-01, CTX-02, CTX-03, CTX-04, CTX-05, CTX-06

</domain>

<decisions>
## Implementation Decisions

### Card System
- Max 5 cards: hero stat + narrative, anticipation signal (from Phase 4), progress/milestone, action opportunity, expandable "See more" overflow — per CTX-01
- Card ranking: priority_score = timeliness × user_relevance × confidence — computed at app launch (session-deterministic, not on scroll) — per CTX-02
- Completed action demotes its triggering card in priority ranking — per CTX-05
- Each card deep-links to relevant simulator or tool via GoRouter — per CTX-04

### Coach Opener
- Biography-aware opener: uses AnonymizedBiographySummary from Phase 3 — per CTX-03
- LSFin compliant: passes ComplianceGuard, ends with user-initiated action suggestion (never imperatives) — per CTX-03
- Opener refreshes once per session (same as card ranking)

### Shell & Navigation
- 3-tab shell (Aujourd'hui, Coach, Explorer) + ProfileDrawer remain unchanged — per CTX-06
- No tab removal, no navigation changes

### Claude's Discretion
- Card visual design (MintSurface variants, icons, colors per card type)
- Hero stat selection logic (which metric to highlight)
- Progress/milestone card content
- Action opportunity detection heuristics
- "See more" expandable section interaction

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `screens/main_tabs/mint_home_screen.dart` — Aujourd'hui tab (target for card integration)
- `services/anticipation/` — Phase 4 anticipation cards already on Aujourd'hui
- `services/biography/anonymized_biography_service.dart` — Phase 3 anonymized summary
- `providers/anticipation_provider.dart` — Phase 4 provider with ranking
- `services/anticipation/anticipation_ranking.dart` — Phase 4 priority_score ranking
- `widgets/home/anticipation_signal_card.dart` — Phase 4 card widget pattern

### Integration Points
- MintHomeScreen: card list rendering area (Phase 4 cards already integrated)
- AnticipationRanking: extend or compose with new card types
- BiographyProvider: data for coach opener
- ComplianceGuard: validate coach opener text
- GoRouter: deep link destinations for each card type

</code_context>

<specifics>
## Specific Ideas

- Phase 4 already put anticipation cards on Aujourd'hui with ranking — Phase 5 EXTENDS this to a unified card system with 5 card types
- Hero stat: the "chiffre vivant" concept — a single number that captures the user's financial state
- Progress cards: milestones from onboarding (Phase 1), document scans (Phase 2), biography growth (Phase 3)
- Action cards: actionable next steps (scan a document, complete profile, review a projection)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
