---
phase: 13-anonymous-hook-auth-bridge
plan: 02
subsystem: ui
tags: [flutter, anonymous-chat, auth-gate, i18n, secure-storage, gorouter]

# Dependency graph
requires:
  - phase: 13-anonymous-hook-auth-bridge/01
    provides: POST /api/v1/anonymous/chat backend endpoint with rate limiting
provides:
  - AnonymousSessionService for device-scoped UUID and message tracking
  - AnonymousChatScreen with full-screen chat UX and 3-message limit
  - AuthGateBottomSheet for conversational conversion after message limit
  - Intent-to-chat routing via /anonymous/chat route
  - sendAnonymousMessage API client on CoachChatApiService
affects: [13-anonymous-hook-auth-bridge/03, auth-bridge, premium-gate]

# Tech tracking
tech-stack:
  added: []
  patterns: [anonymous-session-via-secure-storage, conversational-auth-gate, public-route-outside-shell]

key-files:
  created:
    - apps/mobile/lib/services/anonymous_session_service.dart
    - apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart
    - apps/mobile/lib/widgets/auth/auth_gate_bottom_sheet.dart
    - apps/mobile/test/services/anonymous_session_service_test.dart
    - apps/mobile/test/screens/anonymous/anonymous_chat_screen_test.dart
  modified:
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart
    - apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/app_fr.arb (+ 5 other ARB files)

key-decisions:
  - "Static methods on CoachChatApiService for anonymous chat (no instance needed, mirrors backend pattern)"
  - "Auth gate as conversational bottom sheet (feels like coach suggestion, not system interrupt)"
  - "Route /anonymous/chat outside ShellRoute (no tabs/drawer for anonymous users)"

patterns-established:
  - "Anonymous session via FlutterSecureStorage with device-scoped UUID v4"
  - "Public routes outside StatefulShellRoute for pre-auth experiences"
  - "Conversational conversion UX (coach avatar + message, not system dialog)"

requirements-completed: [ANON-02, ANON-03, ANON-06, LOOP-01]

# Metrics
duration: 9min
completed: 2026-04-12
---

# Phase 13 Plan 02: Anonymous Chat Frontend Summary

**Full-screen anonymous chat with device-scoped session, 3-message limit, typing indicator, and conversational auth gate conversion UX in 6 languages**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-12T14:27:29Z
- **Completed:** 2026-04-12T14:36:24Z
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments
- AnonymousSessionService manages device-scoped UUID in SecureStorage with message counter synced from backend
- AnonymousChatScreen provides full-screen chat with animated typing indicator, message bubbles, and soft input lock
- AuthGateBottomSheet surfaces naturally as coach suggestion after 3rd message (not a system interrupt)
- All 8 i18n keys added to 6 languages (fr, en, de, es, it, pt) with proper accents
- 13 tests passing (8 unit + 5 widget)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AnonymousSessionService and anonymous chat API client** - `6f4fefa3` (feat)
2. **Task 2: Build AnonymousChatScreen with auth gate bottom sheet** - `92055f45` (feat)

## Files Created/Modified
- `apps/mobile/lib/services/anonymous_session_service.dart` - Device UUID management and message counter via SecureStorage
- `apps/mobile/lib/services/coach/coach_chat_api_service.dart` - Added sendAnonymousMessage with X-Anonymous-Session header
- `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` - Full-screen chat with 3-message limit, typing indicator, auth gate trigger
- `apps/mobile/lib/widgets/auth/auth_gate_bottom_sheet.dart` - Conversational conversion bottom sheet with create/login/dismiss
- `apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart` - Navigation updated from /coach/chat to /anonymous/chat
- `apps/mobile/lib/app.dart` - /anonymous/chat route registered as public outside shell
- `apps/mobile/lib/l10n/app_*.arb` - 8 new keys in all 6 ARB files
- `apps/mobile/test/services/anonymous_session_service_test.dart` - 8 unit tests for session service
- `apps/mobile/test/screens/anonymous/anonymous_chat_screen_test.dart` - 5 widget tests for chat screen

## Decisions Made
- Used static methods on CoachChatApiService for anonymous chat rather than a separate service (keeps API calls centralized)
- Auth gate bottom sheet uses conversational tone with coach avatar (feels like part of the conversation, not a paywall)
- Route placed outside ShellRoute so anonymous users never see tabs/drawer (clean full-screen experience)
- Message count synced from backend response (backend is source of truth, frontend mirrors)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all data paths wired to backend endpoint.

## Next Phase Readiness
- Anonymous chat frontend fully wired to Plan 01 backend endpoint
- Ready for Plan 03: conversation claim on auth (migrating anonymous messages to authenticated account)
- Auth gate currently routes to /auth/register and /auth/login; post-auth conversation migration is Plan 03 scope

---
*Phase: 13-anonymous-hook-auth-bridge*
*Completed: 2026-04-12*
