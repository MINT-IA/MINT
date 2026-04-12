---
phase: 16-couple-mode-dissymetrique
plan: 02
subsystem: ui, auth
tags: [flutter, secure-storage, couple, confidence, privacy]

# Dependency graph
requires:
  - phase: 16-01
    provides: Backend ack-only handlers for save/update_partner_estimate tools
provides:
  - PartnerEstimateService with SecureStorage CRUD for partner estimates
  - CoupleQuestionGenerator with 5 template-based gap questions
  - Tool call interception in widget_renderer for partner estimate persistence
  - CoachContext partner aggregate injection (partner_declared + partner_confidence)
  - Confidence degradation method for couple projections
affects: [couple-projections, coach-context, financial-planning]

# Tech tracking
tech-stack:
  added: []
  patterns: [fire-and-forget tool call interception, aggregate-only backend communication, geometric mean confidence blending]

key-files:
  created:
    - apps/mobile/lib/services/partner_estimate_service.dart
    - apps/mobile/lib/services/couple_question_generator.dart
    - apps/mobile/test/services/partner_estimate_service_test.dart
    - apps/mobile/test/services/couple_question_generator_test.dart
  modified:
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart
    - apps/mobile/lib/services/financial_core/confidence_scorer.dart

key-decisions:
  - "Partner aggregate injected in coach_chat_api_service.chat() rather than 3 orchestrator locations — single injection point covers all paths"
  - "degradeForPartnerEstimate as static method on ConfidenceScorer (not a new class) — minimal surface area, existing callers can opt-in"

patterns-established:
  - "Aggregate-only backend communication: actual partner data stays in SecureStorage, only boolean+float flags sent to backend"
  - "Fire-and-forget tool call interception: widget_renderer intercepts tool calls and persists locally without blocking UI"

requirements-completed: [COUP-01, COUP-02, COUP-03, COUP-04]

# Metrics
duration: 7min
completed: 2026-04-12
---

# Phase 16 Plan 02: Flutter Couple Mode Summary

**SecureStorage partner estimates with gap question generator, tool call interception, and degraded confidence for couple projections**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-12T18:36:31Z
- **Completed:** 2026-04-12T18:43:53Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- PartnerEstimateService stores partner data exclusively in FlutterSecureStorage (COUP-04 privacy guarantee)
- CoupleQuestionGenerator produces 5 prioritized gap questions with French typography (COUP-02)
- widget_renderer intercepts save/update_partner_estimate tool calls for local-only persistence
- CoachContext sends only partner_declared (bool) + partner_confidence (float) to backend — zero actual partner data
- ConfidenceScorer.degradeForPartnerEstimate blends couple projection confidence via geometric mean
- 29 Flutter tests passing, flutter analyze clean

## Task Commits

Each task was committed atomically:

1. **Task 1: PartnerEstimateService, CoupleQuestionGenerator, and tool call interception** - `98c4df17` (feat)
2. **Task 2: CoachContext aggregate injection and couple projection wiring with degraded confidence** - `e9221227` (feat)

## Files Created/Modified
- `apps/mobile/lib/services/partner_estimate_service.dart` - PartnerEstimate model + PartnerEstimateService (SecureStorage CRUD, aggregate flags)
- `apps/mobile/lib/services/couple_question_generator.dart` - CoupleQuestion model + CoupleQuestionGenerator (5 template questions by priority)
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` - Added save/update_partner_estimate tool call interception
- `apps/mobile/lib/services/coach/coach_chat_api_service.dart` - Injected partner aggregate flags into profileContext
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart` - Added degradeForPartnerEstimate static method
- `apps/mobile/test/services/partner_estimate_service_test.dart` - 20 tests for PartnerEstimate model
- `apps/mobile/test/services/couple_question_generator_test.dart` - 9 tests for CoupleQuestionGenerator

## Decisions Made
- Partner aggregate injected in coach_chat_api_service.chat() rather than 3 orchestrator locations — single injection point covers all paths
- degradeForPartnerEstimate as static method on ConfidenceScorer (not a new class) — minimal surface area, existing callers can opt-in

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 16 (couple mode dissymetrique) is now complete: backend tools (16-01) + Flutter wiring (16-02)
- Partner estimates flow: coach conversation -> backend ack-only tool call -> Flutter intercepts -> SecureStorage persistence
- Ready for next phase in the v2.5 roadmap

---
*Phase: 16-couple-mode-dissymetrique*
*Completed: 2026-04-12*
