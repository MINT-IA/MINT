---
phase: 24-coach-widgets-suggestions
plan: 01
subsystem: ui
tags: [flutter, coach, suggestion-chips, tool-calls, ux]

requires:
  - phase: 14-commitment-devices
    provides: widget_renderer tool call infrastructure
provides:
  - Contextual suggestion chips derived from LLM tool calls
  - No hardcoded fallback chips
affects: [coach-chat, widget-rendering]

tech-stack:
  added: []
  patterns: [route-chip-extraction from tool calls]

key-files:
  created: []
  modified:
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart

key-decisions:
  - "Remove hardcoded defaults entirely rather than replace with different defaults"
  - "Extract route_to_screen context_message as chip text with 60-char cap"
  - "Enrich both SLM and BYOK paths identically for consistent behavior"

patterns-established:
  - "_extractRouteChips: derive UI suggestions from LLM tool call payloads"

requirements-completed: [WID-01, WID-02, WID-04, UX-04]

duration: 3min
completed: 2026-04-13
---

# Phase 24: Coach Widgets & Suggestions Summary

**Removed hardcoded static suggestion chips, replaced with contextual chips derived from conversation topic regex and LLM route_to_screen tool calls**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-13T18:25:55Z
- **Completed:** 2026-04-13T18:28:41Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments
- Eliminated hardcoded [fitness, retirement] fallback chips that appeared after every response regardless of context
- Added _extractRouteChips() to derive contextual chips from route_to_screen tool call payloads
- Enriched both SLM and BYOK response paths with route-derived chip suggestions
- Chips now appear only when conversation matches a topic regex OR LLM provides route_to_screen tool calls

## Task Commits

Each task was committed atomically:

1. **Tasks 1+2: Remove hardcoded chips + derive from tool calls** - `d1c1b6ae` (fix)

## Files Created/Modified
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` - Removed hardcoded defaults from _inferSuggestedActions, added _extractRouteChips helper, enriched both response paths

## Decisions Made
- Removed hardcoded defaults entirely rather than replacing with different defaults -- the coach should be silent when it has nothing contextual to suggest
- Used context_message from route_to_screen tool calls as chip text, capped at 60 chars for readability
- Applied identical enrichment logic to both SLM and BYOK paths for consistent behavior

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Verification

- WID-01 (inline widgets): widget_renderer.dart already handles show_fact_card correctly -- verified by code inspection, no changes needed
- WID-02 (route_to_screen): widget_renderer.dart already handles route_to_screen correctly -- verified by code inspection, no changes needed
- WID-04 (route navigation): RouteSuggestionCard uses context.push(route, extra: prefill) correctly -- verified by code inspection
- UX-04 (contextual chips): hardcoded defaults removed, chips now contextual only

## Next Phase Readiness
- Coach suggestion system is now contextual
- Widget rendering and route navigation were already working correctly

---
*Phase: 24-coach-widgets-suggestions*
*Completed: 2026-04-13*
