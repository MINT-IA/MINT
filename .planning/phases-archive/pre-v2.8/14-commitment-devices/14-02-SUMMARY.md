---
phase: 14-commitment-devices
plan: 02
subsystem: ui, api
tags: [flutter, fastapi, commitment-devices, implementation-intentions, notifications, i18n]

# Dependency graph
requires:
  - phase: 14-01
    provides: CommitmentDevice DB model, show_commitment_card tool definition, system prompt directives
provides:
  - CommitmentCard widget with editable WHEN/WHERE/IF-THEN fields
  - POST/GET/PATCH /api/v1/coach/commitment backend endpoints
  - CommitmentService API client for Flutter
  - Notification scheduling for accepted commitments (ID range 5000+)
  - 6 widget tests covering rendering, editing, accept, dismiss, styling, i18n
affects: [14-03-pre-mortem, coach-chat, notification-service]

# Tech tracking
tech-stack:
  added: []
  patterns: [commitment-card-inline-chat, tool-call-to-persistence-pipeline]

key-files:
  created:
    - apps/mobile/lib/widgets/coach/commitment_card.dart
    - apps/mobile/lib/services/commitment_service.dart
    - services/backend/app/api/v1/endpoints/commitment.py
    - apps/mobile/test/widgets/commitment_card_test.dart
  modified:
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/services/notification_service.dart
    - services/backend/app/api/v1/router.py
    - apps/mobile/lib/l10n/app_fr.arb (+ en, de, es, it, pt)

key-decisions:
  - "Notification scheduling pulled into Task 1 to avoid compile error in widget_renderer (Rule 3 deviation)"
  - "Notification ID uses commitmentId.hashCode % 1000 + 5000 base to avoid collisions with other notification ranges"
  - "Backend enforces 50 pending commitments max per user (T-14-08 DoS mitigation)"

patterns-established:
  - "Tool call to persistence pipeline: LLM tool call -> CommitmentCard widget -> CommitmentService.saveCommitment() -> backend POST -> DB"
  - "Commitment notification range: 5000-5999 reserved for commitment reminders"

requirements-completed: [CMIT-01, CMIT-02]

# Metrics
duration: 11min
completed: 2026-04-12
---

# Phase 14 Plan 02: Commitment Devices Frontend Summary

**Editable WHEN/WHERE/IF-THEN commitment card rendered inline in coach chat, persisted via dedicated backend endpoint, with local notification reminder scheduling**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-12T17:23:53Z
- **Completed:** 2026-04-12T17:35:16Z
- **Tasks:** 2
- **Files modified:** 19

## Accomplishments
- CommitmentCard widget with 3 editable TextFormFields, Dismissible wrap, and accept/dismiss callbacks
- Backend CRUD endpoints (POST/GET/PATCH) with IDOR protection, length validation, and rate limiting
- Full tool-call-to-persistence pipeline: show_commitment_card -> CommitmentCard -> CommitmentService -> backend -> DB
- Notification scheduling with consent check, unique ID range (5000+), and cancel support
- 8 i18n keys across all 6 ARB files (fr, en, de, es, it, pt)
- 6 widget tests all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Backend persistence endpoint and CommitmentCard widget with renderer wiring** - `5f00ad17` (feat)
2. **Task 2: Notification scheduling for accepted commitments and widget tests** - `f0b04e7d` (test)

## Files Created/Modified
- `services/backend/app/api/v1/endpoints/commitment.py` - POST/GET/PATCH endpoints with auth, validation, rate limiting
- `services/backend/app/api/v1/router.py` - Router registration for commitment endpoints
- `apps/mobile/lib/widgets/coach/commitment_card.dart` - Editable WHEN/WHERE/IF-THEN card widget
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` - show_commitment_card case + _buildCommitmentCard builder
- `apps/mobile/lib/services/commitment_service.dart` - API client for commitment persistence
- `apps/mobile/lib/services/notification_service.dart` - scheduleCommitmentReminder + cancelCommitmentReminder methods
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - 8 commitment i18n keys each
- `apps/mobile/test/widgets/commitment_card_test.dart` - 6 widget tests

## Decisions Made
- Notification scheduling pulled into Task 1 commit (was planned for Task 2) because widget_renderer references scheduleCommitmentReminder and would not compile without it
- Backend uses Pydantic field_validator for 500-char max and non-empty validation (T-14-07)
- PATCH endpoint filters by both commitment_id AND user_id from JWT (T-14-06 IDOR protection)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Notification methods pulled into Task 1**
- **Found during:** Task 1 verification (flutter analyze)
- **Issue:** widget_renderer.dart references NotificationService.scheduleCommitmentReminder which was planned for Task 2, causing compile error
- **Fix:** Added scheduleCommitmentReminder and cancelCommitmentReminder to notification_service.dart in Task 1
- **Files modified:** apps/mobile/lib/services/notification_service.dart
- **Verification:** flutter analyze reports 0 errors
- **Committed in:** 5f00ad17 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Task boundary shifted but all functionality delivered. No scope creep.

## Issues Encountered
- Dismissible widget test initially failed because TextFormFields consumed horizontal drag gestures. Fixed by targeting the header icon for fling gesture in tests.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Commitment device flow is end-to-end: LLM proposes -> user edits -> accept persists + schedules notification
- Pre-mortem protocol (Plan 03) can build on same backend model and widget patterns
- CoachContext already includes commitment data from Plan 01

---
*Phase: 14-commitment-devices*
*Completed: 2026-04-12*
