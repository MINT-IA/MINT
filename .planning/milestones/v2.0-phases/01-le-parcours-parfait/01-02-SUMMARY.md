---
phase: 01-le-parcours-parfait
plan: 02
subsystem: auth
tags: [magic-link, jwt, resend, passwordless, fastapi, flutter, gorouter]

# Dependency graph
requires:
  - phase: 01-le-parcours-parfait/01-01
    provides: i18n keys (authSendLink, authLinkSent, authResend, authPasswordFallback)
provides:
  - Magic link backend service (MagicLinkService) with token generation, verification, email sending
  - Two new auth endpoints (POST /auth/magic-link/send, POST /auth/magic-link/verify)
  - MagicLinkTokenModel (single-use, SHA-256 hashed, 15-min expiry)
  - Redesigned login screen with magic link primary UX
  - Post-auth routing (new users -> /onboarding/intent, returning -> /home)
  - Deep link handler /auth/verify for magic link callback
  - AuthProvider.sendMagicLink + verifyMagicLink methods
  - ApiService.sendMagicLink + verifyMagicLink methods
affects: [01-le-parcours-parfait/01-03, 01-le-parcours-parfait/01-05]

# Tech tracking
tech-stack:
  added: [resend-api, httpx]
  patterns: [magic-link-auth, token-hash-storage, post-auth-routing]

key-files:
  created:
    - services/backend/app/services/magic_link_service.py
    - services/backend/app/models/magic_link_token.py
    - services/backend/tests/test_magic_link.py
  modified:
    - services/backend/app/api/v1/endpoints/auth.py
    - services/backend/app/schemas/auth.py
    - services/backend/app/models/__init__.py
    - apps/mobile/lib/screens/auth/login_screen.dart
    - apps/mobile/lib/services/api_service.dart
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/providers/auth_provider.dart
    - apps/mobile/lib/screens/auth/register_screen.dart

key-decisions:
  - "Token stored as SHA-256 hash (never plaintext) matching existing PasswordResetTokenModel pattern"
  - "Auto-create user on first magic link verify (frictionless onboarding, T-01-06)"
  - "Resend API for email sending with graceful fallback (dev mode logs token)"
  - "Post-auth routing uses ReportPersistenceService.isMiniOnboardingCompleted (not hasCompletedOnboarding)"

patterns-established:
  - "Magic link token pattern: secrets.token_urlsafe(32) -> SHA-256 hash -> DB with expiry + used flag"
  - "Post-auth routing: always check isMiniOnboardingCompleted before routing to /home"

requirements-completed: [PATH-02]

# Metrics
duration: 8min
completed: 2026-04-06
---

# Phase 01 Plan 02: Magic Link Auth Summary

**Passwordless magic link auth (primary) with SHA-256 token hashing, Resend API email, 30s countdown UX, and post-auth routing to onboarding/home**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-06T12:01:18Z
- **Completed:** 2026-04-06T12:09:12Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Backend magic link service with token generation (secrets.token_urlsafe), SHA-256 hash storage, 15-min expiry, single-use verification
- Two rate-limited endpoints (5/min): POST /auth/magic-link/send and POST /auth/magic-link/verify
- Redesigned login screen with magic link as primary CTA, 30-second countdown timer, password fallback on demand
- Post-auth routing: new users -> /onboarding/intent, returning users -> /home (both login and register flows)
- Deep link handler /auth/verify for magic link callback with error states
- 14 backend tests passing (unit + integration)

## Task Commits

Each task was committed atomically:

1. **Task 1: Magic link backend service + endpoints (TDD):**
   - `81213d8a` (test) - Failing tests for magic link auth
   - `d50328af` (feat) - Implement magic link backend service + endpoints
2. **Task 2: Login screen redesign + post-auth routing** - `80be6909` (feat)

## Files Created/Modified
- `services/backend/app/services/magic_link_service.py` - Token generation, verification, Resend email sending
- `services/backend/app/models/magic_link_token.py` - MagicLinkTokenModel (SHA-256 hash, expiry, used flag)
- `services/backend/tests/test_magic_link.py` - 14 tests (token gen, hash, verify valid/expired/used/invalid, auto-create, email, endpoints)
- `services/backend/app/api/v1/endpoints/auth.py` - Two new magic link endpoints with rate limiting
- `services/backend/app/schemas/auth.py` - MagicLinkSendRequest/Response, MagicLinkVerifyRequest/Response
- `services/backend/app/models/__init__.py` - Register MagicLinkTokenModel
- `apps/mobile/lib/screens/auth/login_screen.dart` - Magic link primary UX with countdown
- `apps/mobile/lib/services/api_service.dart` - sendMagicLink + verifyMagicLink API methods
- `apps/mobile/lib/app.dart` - /auth/verify deep link route + MagicLinkVerifyScreen
- `apps/mobile/lib/providers/auth_provider.dart` - sendMagicLink + verifyMagicLink auth flow
- `apps/mobile/lib/screens/auth/register_screen.dart` - Post-auth routing with isMiniOnboardingCompleted

## Decisions Made
- Token stored as SHA-256 hash following existing PasswordResetTokenModel pattern
- Auto-create user on first magic link verify for frictionless onboarding (accepted risk per T-01-06)
- Resend API chosen for email sending with graceful dev-mode fallback (logs token if no API key)
- Post-auth routing uses ReportPersistenceService.isMiniOnboardingCompleted (not the aspirational hasCompletedOnboarding from CONTEXT.md)
- Magic link API methods placed in ApiService (not AuthService) to match existing architecture where AuthService = secure storage only

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed timezone-naive comparison in test**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** SQLite stores datetimes without timezone, causing comparison error with timezone-aware datetime.now(timezone.utc)
- **Fix:** Added `.replace(tzinfo=timezone.utc)` guard for naive datetimes in test
- **Files modified:** services/backend/tests/test_magic_link.py
- **Committed in:** d50328af (part of GREEN commit)

**2. [Rule 1 - Bug] Fixed camelCase response assertion in test**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** Test expected `access_token` but Pydantic alias_generator returns `accessToken`
- **Fix:** Updated test assertion to match camelCase response format
- **Files modified:** services/backend/tests/test_magic_link.py
- **Committed in:** d50328af (part of GREEN commit)

---

**Total deviations:** 2 auto-fixed (2 bug fixes in tests)
**Impact on plan:** Minor test adjustments for correct assertions. No scope creep.

## Issues Encountered
None

## User Setup Required

Magic link email delivery requires Resend API configuration:
- `RESEND_API_KEY` - Create at resend.com -> API Keys
- `MAGIC_LINK_BASE_URL` - Set to app deep link base (e.g., https://mint-app.ch/auth/verify)
- Without these, magic links are logged to console (dev mode) but not actually sent

## Threat Model Compliance

All STRIDE mitigations from the plan's threat model were implemented:
- T-01-02: Rate limit 5/min on verify, 32-byte token, single-use, SHA-256 hash
- T-01-04: Rate limit 5/min on send, same response for known/unknown emails
- T-01-05: slowapi rate limiting prevents DoS
- T-01-06: Auto-create accepted (default permissions only)

## Next Phase Readiness
- Magic link auth backend ready for Apple Sign-In integration (Plan 01-05)
- Post-auth routing wired to onboarding (Plan 01-03 mini-onboarding)
- Login screen ready for Apple Sign-In button addition

---
*Phase: 01-le-parcours-parfait*
*Completed: 2026-04-06*
