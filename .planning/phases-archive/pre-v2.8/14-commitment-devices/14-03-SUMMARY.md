---
phase: 14-commitment-devices
plan: 03
subsystem: api, notifications
tags: [fastapi, flutter, fresh-start, behavioral-economics, notifications, landmarks]

# Dependency graph
requires:
  - phase: 14-01
    provides: commitment_devices table, CommitmentDevice model
provides:
  - GET /api/v1/coach/fresh-start endpoint with 5 landmark types and personalized messages
  - FreshStartService for Flutter with notification scheduling
  - Server-side and client-side rate limiting (max 2 per month)
affects: [coach-chat, notification-system, retention]

# Tech tracking
tech-stack:
  added: []
  patterns: [landmark-date-computation, template-message-generation, dual-rate-limiting]

key-files:
  created:
    - services/backend/app/api/v1/endpoints/fresh_start.py
    - services/backend/tests/test_fresh_start.py
    - apps/mobile/lib/services/fresh_start_service.dart
  modified:
    - services/backend/app/api/v1/router.py
    - apps/mobile/lib/services/notification_service.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb

key-decisions:
  - "Job anniversary uses July 1 midpoint (first_employment_year provides year only, not month)"
  - "MINT anniversary requires 330+ days account age (not strict 365) for scheduling flexibility"
  - "Dual rate limiting: server-side primary (apply_rate_limit), client-side SharedPreferences as UX backup"

patterns-established:
  - "Fresh-start landmark pattern: pure date computation + pure message generation + rate limiting"
  - "Notification ID range 6000+ for fresh-start (5000+ for commitments, 3000+ for 3a, 4000+ for tax)"

requirements-completed: [CMIT-03, CMIT-04, LOOP-01]

# Metrics
duration: 6min
completed: 2026-04-12
---

# Phase 14 Plan 03: Fresh-Start Anchors Summary

**Fresh-start landmark detection with 5 date types, personalized template messages, dual rate limiting, and notification scheduling at 9 AM local time**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-12T17:37:08Z
- **Completed:** 2026-04-12T17:43:00Z
- **Tasks:** 2
- **Files modified:** 17

## Accomplishments
- Backend endpoint computing 5 landmark types (birthday, month_start, year_start, job_anniversary, mint_anniversary) with personalized French messages using conditional language
- Server-side rate limiting (max 2 landmarks per calendar month) with pure function architecture
- Flutter FreshStartService with client-side SharedPreferences rate limiting and NotificationService extension (6000+ ID range, 9 AM scheduling, consent-checked)
- 22 backend tests covering date computation edge cases, message generation, banned term absence, and rate limiting

## Task Commits

Each task was committed atomically:

1. **Task 1: Backend fresh-start endpoint** - `ae14d5ea` (feat)
2. **Task 2: Flutter fresh-start service with notifications** - `2d89b072` (feat)

## Files Created/Modified
- `services/backend/app/api/v1/endpoints/fresh_start.py` - Pure functions for landmark computation + message generation + GET endpoint
- `services/backend/tests/test_fresh_start.py` - 22 tests covering all landmark types, edge cases, messages, banned terms, rate limiting
- `services/backend/app/api/v1/router.py` - Registered fresh_start router at /coach/fresh-start
- `apps/mobile/lib/services/fresh_start_service.dart` - API client + notification scheduling with SharedPreferences rate limit
- `apps/mobile/lib/services/notification_service.dart` - scheduleFreshStart() + cancelAllFreshStarts() in 6000+ ID range
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - freshStartNotificationTitle key added to all 6 languages

## Decisions Made
- Job anniversary computed from July 1 midpoint since first_employment_year has no month granularity
- MINT anniversary threshold set to 330 days (not strict 365) to ensure notification can be scheduled before the exact date
- Dual rate limiting strategy: server returns max 2/month, client-side SharedPreferences prevents re-scheduling

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 14 (Commitment Devices) is now complete: all 3 plans executed
- Implementation intentions (Plan 01), persistence + notifications + system prompt (Plan 02), and fresh-start anchors (Plan 03) form a complete behavioral moat
- Ready for phase transition

---
*Phase: 14-commitment-devices*
*Completed: 2026-04-12*
