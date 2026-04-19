---
phase: 18-living-timeline-full-timeline
plan: 01
subsystem: ui
tags: [flutter, timeline, sliver, provider, i18n]

requires:
  - phase: 17-living-timeline-3-tensions
    provides: TensionCardProvider, TensionCardWidget, CleoLoopIndicator, AujourdhuiScreen with 3 tension cards

provides:
  - TimelineNode model with 5 NodeType variants and TimelineMonth grouping
  - TimelineProvider extending TensionCardProvider with node aggregation and lazy pagination
  - TimelineNodeWidget with type-specific icons and earned/pulsing/ghosted visual states
  - MonthHeaderWidget with collapsible month grouping
  - AujourdhuiScreen rebuilt with CustomScrollView (tension header + timeline slivers)
  - 9 i18n keys in 6 ARB files

affects: [aujourdhui, timeline, coach, explorer]

tech-stack:
  added: []
  patterns: [sliver-based-scrollview, provider-inheritance, month-grouping-with-collapse]

key-files:
  created:
    - apps/mobile/lib/models/timeline_node.dart
    - apps/mobile/lib/providers/timeline_provider.dart
    - apps/mobile/lib/widgets/timeline/timeline_node_widget.dart
    - apps/mobile/lib/widgets/timeline/month_header_widget.dart
  modified:
    - apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb

key-decisions:
  - "TimelineProvider extends TensionCardProvider — IS-A relationship, not composition, so existing tension card consumers work via type hierarchy"
  - "Month labels hardcoded in French (Janvier, Fevrier...) since the app is French-first and month formatting matches existing patterns"
  - "No animation on individual timeline nodes — only header tension cards pulse (per CONTEXT.md)"

patterns-established:
  - "Provider inheritance: TimelineProvider extends TensionCardProvider, overrides refresh() calling super first"
  - "Sliver-based home screen: CustomScrollView with SliverToBoxAdapter for fixed content + SliverList.builder for lazy lists"
  - "Month collapse state: local Set<String> in screen state, current month expanded by default"

requirements-completed: [TIME-03, TIME-04, TIME-05]

duration: 5min
completed: 2026-04-13
---

# Phase 18 Plan 01: Full Living Timeline Summary

**5-node-type timeline on Aujourd'hui tab with month grouping, lazy pagination, and earned/pulsing/ghosted visual states via CustomScrollView slivers**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-13T05:33:36Z
- **Completed:** 2026-04-13T05:39:31Z
- **Tasks:** 2
- **Files modified:** 19

## Accomplishments
- TimelineNode model with 5 NodeType variants (document, conversation, commitment, couple, projection) and TimelineMonth grouping
- TimelineProvider extends TensionCardProvider, aggregates real nodes from CommitmentService, FreshStartService, ConversationStore, PartnerEstimateService, and uploaded documents with 50-node cap and loadMore pagination
- AujourdhuiScreen rebuilt with CustomScrollView: MINT wordmark + 3 tension cards (Phase 17) + Cleo loop indicator + "Ton histoire" divider + month-grouped timeline nodes + "Charger plus" button
- TimelineNodeWidget with 5 distinct icons and 3 visual states (earned/pulsing/ghosted)
- MonthHeaderWidget with collapsible chevron (current month expanded, past months collapsed)
- 9 i18n keys in all 6 ARB files, flutter gen-l10n passes, flutter analyze 0 errors

## Task Commits

Each task was committed atomically:

1. **Task 1: TimelineNode model and TimelineProvider** - `3c352d0e` (feat)
2. **Task 2: Timeline widgets, AujourdhuiScreen rebuild, and i18n** - `2811455e` (feat)

## Files Created/Modified
- `apps/mobile/lib/models/timeline_node.dart` - TimelineNode model with 5 NodeType variants and TimelineMonth grouping
- `apps/mobile/lib/providers/timeline_provider.dart` - TimelineProvider extending TensionCardProvider with node aggregation from 5 sources
- `apps/mobile/lib/widgets/timeline/timeline_node_widget.dart` - Individual node rendering with type-specific icons
- `apps/mobile/lib/widgets/timeline/month_header_widget.dart` - Collapsible month header with chevron
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` - Rebuilt with CustomScrollView + tension header + timeline slivers
- `apps/mobile/lib/app.dart` - Provider registration changed to TimelineProvider
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - 9 new timeline i18n keys each

## Decisions Made
- TimelineProvider extends TensionCardProvider (IS-A) so existing tension card consumers work without changes
- Month labels hardcoded in French since the app is French-first
- No animation on individual timeline nodes — only header tension cards pulse per CONTEXT.md decision

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Aujourd'hui tab now shows full living timeline with real service data
- Ready for device verification (Phase 17 tension cards preserved at top, timeline extends below)
- Future enhancements (search, filter, export, animated transitions) deferred per CONTEXT.md

---
*Phase: 18-living-timeline-full-timeline*
*Completed: 2026-04-13*
