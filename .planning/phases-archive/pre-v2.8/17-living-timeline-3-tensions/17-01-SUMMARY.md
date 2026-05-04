---
phase: 17-living-timeline-3-tensions
plan: 01
subsystem: ui
tags: [flutter, provider, tension-cards, cleo-loop, i18n, gorouter]

requires:
  - phase: 14-commitment-devices
    provides: CommitmentService with getCommitments/updateStatus API
  - phase: 14-commitment-devices
    provides: FreshStartService with fetchLandmarks API
  - phase: 13-anonymous-to-auth
    provides: ConversationStore with SharedPreferences persistence
  - phase: 16-couple-mode-dissymetrique
    provides: PartnerEstimateService with load/save API
provides:
  - TensionCard model with TensionType enum (earned/pulsing/ghosted) and CleoLoopPosition enum
  - TensionCardProvider ChangeNotifier aggregating 4 services into 3 tension cards
  - AujourdhuiScreen replacing LandingScreen for authenticated users on Tab 0
  - TensionCardWidget with 3 visual states (solid/animated/ghosted)
  - CleoLoopIndicator pill showing Cleo service loop position
  - 16 i18n keys across 6 ARB files
affects: [18-premium-gate, aujourdhui-tab, coach-chat-deeplinks]

tech-stack:
  added: []
  patterns: [tension-card-pattern, auth-aware-route-builder, cleo-loop-indicator]

key-files:
  created:
    - apps/mobile/lib/models/tension_card.dart
    - apps/mobile/lib/providers/tension_card_provider.dart
    - apps/mobile/lib/widgets/tension/tension_card_widget.dart
    - apps/mobile/lib/widgets/tension/cleo_loop_indicator.dart
    - apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb

key-decisions:
  - "Auth-aware GoRouter builder using context.watch<AuthProvider>() for reactive auth state"
  - "Title keys stored as string identifiers in TensionCard, resolved to i18n at widget level"
  - "Ghosted card uses 0.4 opacity wrapper instead of CustomPainter dashed border for simplicity"
  - "ConversationStore read via SharedPreferences directly to avoid coupling"

patterns-established:
  - "Tension card pattern: model stores i18n key names, widget resolves them"
  - "Auth-aware route builder: context.watch<AuthProvider>() in GoRoute builder"

requirements-completed: [TIME-01, TIME-02, LOOP-03]

duration: 6min
completed: 2026-04-12
---

# Phase 17 Plan 01: Living Timeline 3 Tensions Summary

**3 living tension cards (earned/pulsing/ghosted) on Aujourd'hui tab with Cleo loop indicator, auth-aware routing, and 16 i18n keys in 6 languages**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-12T18:57:16Z
- **Completed:** 2026-04-12T19:03:27Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments
- TensionCardProvider aggregates CommitmentService, FreshStartService, ConversationStore, and PartnerEstimateService into exactly 3 tension cards
- AujourdhuiScreen replaces static LandingScreen for authenticated users with living data-driven cards
- Visual states: earned (solid green border + checkmark), pulsing (animated opacity cycling), ghosted (0.4 opacity)
- CleoLoopIndicator pill shows current position in Insight/Plan/Conversation/Action/Memory cycle
- Full i18n: 16 keys in all 6 ARB files (fr, en, de, es, it, pt)

## Task Commits

Each task was committed atomically:

1. **Task 1: TensionCard model, TensionCardProvider, and i18n keys** - `c30a6187` (feat)
2. **Task 2: TensionCardWidget, CleoLoopIndicator, AujourdhuiScreen, and router wiring** - `5d8c1a6b` (feat)

## Files Created/Modified
- `apps/mobile/lib/models/tension_card.dart` - TensionCard model, TensionType and CleoLoopPosition enums
- `apps/mobile/lib/providers/tension_card_provider.dart` - Aggregates 4 services into 3 tension cards
- `apps/mobile/lib/widgets/tension/tension_card_widget.dart` - Visual card with 3 states + pulse animation
- `apps/mobile/lib/widgets/tension/cleo_loop_indicator.dart` - Pill showing Cleo loop position
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` - Authenticated home screen with 3 cards
- `apps/mobile/lib/app.dart` - Auth-aware GoRoute builder + TensionCardProvider registration
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - 16 tension/cleo i18n keys each

## Decisions Made
- Used `context.watch<AuthProvider>().isLoggedIn` in GoRoute builder for reactive auth-aware routing (synchronous, no async needed)
- Stored i18n key names as strings in TensionCard model, resolved at widget level via S.of(context) — avoids passing BuildContext into provider
- Used 0.4 opacity wrapper for ghosted cards instead of CustomPainter dashed border — simpler, equally effective visual
- Read ConversationStore index directly from SharedPreferences to avoid tight coupling to store class

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all cards are wired to real service data (CommitmentService, FreshStartService, ConversationStore, PartnerEstimateService). Empty states handled gracefully.

## Next Phase Readiness
- Aujourd'hui tab is now alive for authenticated users
- Cards deep-link to coach chat with contextual prompts
- Ready for premium gate wiring (Phase 18) which can wrap tension card features

---
*Phase: 17-living-timeline-3-tensions*
*Completed: 2026-04-12*
