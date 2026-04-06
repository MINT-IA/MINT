# Phase 8: UX Polish - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning
**Mode:** Auto-generated (well-specified phase — success criteria define all requirements)

<domain>
## Phase Boundary

The Aujourd'hui tab animates naturally, ConfidenceScore is visible and actionable, Explorer reflects profile readiness, and navigation transitions feel guided. This is the final polish phase — no new features, only UX refinements to existing screens.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — the success criteria in ROADMAP.md fully specify the requirements:
1. AnimatedSwitcher crossfade on Aujourd'hui signal card dismiss/replace
2. ConfidenceScore visible on Aujourd'hui with single best-improvement action
3. Explorer hubs show visual state reflecting profile completeness (greyed/locked when fields missing)
4. Onboarding journey screens use CustomTransitionPage fade (not Material slide)

Technical decisions (animation durations, exact grey-out styling, transition curves) follow existing MintMotion patterns and DESIGN_SYSTEM.md tokens.

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during research or planning.

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond success criteria — this is a polish phase.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
