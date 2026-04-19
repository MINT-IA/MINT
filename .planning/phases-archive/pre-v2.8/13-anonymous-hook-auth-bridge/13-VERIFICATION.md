---
phase: 13-anonymous-hook-auth-bridge
verified: 2026-04-12T17:45:00Z
status: human_needed
score: 5/5 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "User who creates an account sees their entire anonymous conversation preserved in chat history (zero message loss)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Complete anonymous-to-auth flow on real device"
    expected: "Pill tap -> 3 messages -> auth gate -> create account -> migrated conversation visible with welcome message"
    why_human: "Full navigation flow across screens, auth service interaction, and visual verification of message preservation cannot be tested programmatically"
  - test: "Verify auth gate bottom sheet feels conversational, not like a paywall"
    expected: "Coach avatar, conversational copy, soft dismiss -- feels like part of the conversation"
    why_human: "UX quality and emotional tone require human judgment"
  - test: "Verify typing indicator animation during coach response loading"
    expected: "Three animated dots appear with staggered fade while waiting for LLM response"
    why_human: "Animation smoothness requires visual inspection"
---

# Phase 13: Anonymous Hook & Auth Bridge Verification Report

**Phase Goal:** A stranger opens MINT, taps a felt-state pill, gets a premier eclairage that surprises them, and converts to an authenticated user without losing a single message
**Verified:** 2026-04-12T17:45:00Z
**Status:** human_needed
**Re-verification:** Yes -- after gap closure (Plan 13-04)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Anonymous user can send 3 messages to coach and receive meaningful responses without creating an account | VERIFIED | Backend POST /api/v1/anonymous/chat with _NoRagOrchestrator LLM call, ComplianceGuardrails filtering, DB-backed 3-message rate limit. Frontend AnonymousChatScreen wired via CoachChatApiService.sendAnonymousMessage with X-Anonymous-Session header. 11 backend tests + 5 widget tests. |
| 2 | Tapping a felt-state pill on the intent screen opens coach chat with that intent as conversation context | VERIFIED | anonymous_intent_screen.dart:93 navigates to `/anonymous/chat?intent=...`. AnonymousChatScreen extracts intent from query params, auto-sends as first message. Backend build_discovery_system_prompt injects intent into system prompt. |
| 3 | After the 3rd value exchange, MINT surfaces a natural auth prompt -- not a wall, not a popup | VERIFIED | AnonymousChatScreen:137 checks messagesRemaining==0, appends conversion coach message, then calls showModalBottomSheet with AuthGateBottomSheet (coach avatar + conversational copy + "Plus tard" dismiss). |
| 4 | User who creates an account sees their entire anonymous conversation preserved in chat history (zero message loss) | VERIFIED | **GAP CLOSED by Plan 13-04.** anonymous_chat_screen.dart:134 calls `_persistToSharedPreferences()` after every coach response (fire-and-forget). Line 151 persists again after conversion prompt. Method (lines 183-198) sets `ConversationStore.setCurrentUserId(null)` and calls `saveConversation`. Dead `_onAuthenticated` callback removed entirely. `onAuthenticated` parameter removed from AuthGateBottomSheet (line 14-21 confirms only `onDismissed` remains). auth_provider.dart:530-531 calls `migrateAnonymousToUser` + `clearSession` after auth. 2 new tests verify the eager-persist-then-migrate path. |
| 5 | A second anonymous session from the same device cannot bypass the 3-message rate limit | VERIFIED | AnonymousSessionService stores UUID in FlutterSecureStorage (persists across app kills). Backend enforces via AnonymousSession DB model keyed by session_id. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/api/v1/endpoints/anonymous_chat.py` | Anonymous chat POST endpoint | VERIFIED | 274 lines, endpoint with rate limiting, discovery prompt, PII scrubbing, compliance filtering |
| `services/backend/app/schemas/anonymous_chat.py` | Request/response schemas | VERIFIED | Pydantic v2 with camelCase aliases |
| `services/backend/app/models/anonymous_session.py` | DB model for session tracking | VERIFIED | SQLAlchemy model with session_id, message_count, created_at |
| `services/backend/tests/test_anonymous_chat.py` | Backend tests | VERIFIED | 287 lines, 11 test functions |
| `apps/mobile/lib/services/anonymous_session_service.dart` | Device UUID and message counter | VERIFIED | 56 lines, SecureStorage with getOrCreateSessionId, canSendMessage, clearSession |
| `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` | Full-screen anonymous chat with eager persistence | VERIFIED | 467 lines, full chat UI with eager SharedPreferences persistence (lines 134, 151, 183-198), dead _onAuthenticated removed |
| `apps/mobile/lib/widgets/auth/auth_gate_bottom_sheet.dart` | Conversion bottom sheet | VERIFIED | 155 lines, onAuthenticated parameter removed (Plan 13-04), clean conversational UI with coach avatar, only onDismissed callback |
| `apps/mobile/lib/services/coach/conversation_store.dart` | migrateAnonymousToUser method | VERIFIED | Atomic write-before-delete migration |
| `apps/mobile/test/services/anonymous_session_service_test.dart` | Session service tests | VERIFIED | 8 tests |
| `apps/mobile/test/screens/anonymous/anonymous_chat_screen_test.dart` | Chat screen + eager persistence tests | VERIFIED | Includes "Anonymous conversation eager persistence" group (lines 80-170) verifying saveConversation + migrateAnonymousToUser path |
| `apps/mobile/test/services/coach/conversation_migration_test.dart` | Migration tests | VERIFIED | 248 lines, 8 tests |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| router.py | anonymous_chat.py | include_router /anonymous prefix | WIRED | Line 203 in router.py |
| anonymous_chat.py | anonymous_session.py | db.query(AnonymousSession) | WIRED | DB-backed rate limit enforcement |
| anonymous_intent_screen.dart | anonymous_chat_screen.dart | GoRouter /anonymous/chat | WIRED | Line 93 in intent screen |
| anonymous_chat_screen.dart | /api/v1/anonymous/chat | CoachChatApiService.sendAnonymousMessage | WIRED | HTTP POST with X-Anonymous-Session header |
| anonymous_chat_screen.dart | auth_gate_bottom_sheet.dart | showModalBottomSheet | WIRED | Lines 159-169, onDismissed only |
| anonymous_chat_screen.dart | conversation_store.dart | saveConversation after each coach response | WIRED | Lines 134, 151, 183-198 -- eager persistence (Plan 13-04 fix) |
| auth_provider.dart | conversation_store.dart | migrateAnonymousToUser | WIRED | Line 530 |
| auth_provider.dart | anonymous_session_service.dart | clearSession | WIRED | Line 531 |
| app.dart | AnonymousChatScreen | GoRoute /anonymous/chat | WIRED | Lines 237-241 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| anonymous_chat.py | LLM response | _NoRagOrchestrator.query() via Anthropic API | Yes | FLOWING |
| anonymous_chat_screen.dart | _messages list | CoachChatApiService.sendAnonymousMessage() | Yes | FLOWING |
| anonymous_chat_screen.dart | conversation for migration | _persistToSharedPreferences() -> ConversationStore.saveConversation() | Yes (eagerly saved after each response) | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED (requires running backend server and Flutter app)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| ANON-01 | 13-01 | Anonymous user can send messages via rate-limited public endpoint | SATISFIED | POST /api/v1/anonymous/chat with 3-message DB-backed limit |
| ANON-02 | 13-02 | Pill tap arrives in coach chat with intent as context | SATISFIED | Intent passed as query param, auto-sent, injected into system prompt |
| ANON-03 | 13-02 | After 3 exchanges, natural auth gate surfaces | SATISFIED | Coach conversion message + AuthGateBottomSheet on messagesRemaining==0 |
| ANON-04 | 13-03, 13-04 | Anonymous conversation transferred on account creation (zero loss) | SATISFIED | Eager persistence after each response (Plan 13-04) + auth_provider migration + clearSession |
| ANON-05 | 13-01 | Backend uses "mode decouverte" system prompt | SATISFIED | build_discovery_system_prompt -- no tool/profile/memory/dossier references |
| ANON-06 | 13-01, 13-02 | Device-scoped session via SecureStorage | SATISFIED | AnonymousSessionService UUID + backend AnonymousSession DB model |
| LOOP-01 | 13-02 | After coach insight, suggest next step (partial) | SATISFIED | Auth gate is the natural next step after 3rd message |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | Previous blockers resolved | - | Plan 13-04 removed dead _onAuthenticated callback and unused onAuthenticated parameter |

### Human Verification Required

1. **Complete anonymous-to-auth flow on real device**
   **Test:** Build app, see intent screen, tap pill, send 3 messages, create account, check chat history
   **Expected:** All 3 anonymous messages + coach responses visible in authenticated chat with "Maintenant je me souviendrai de tout." welcome message
   **Why human:** Full navigation flow across screens, auth service interaction, and visual verification of message preservation cannot be tested programmatically

2. **Auth gate UX quality**
   **Test:** After 3rd message, observe the auth gate bottom sheet
   **Expected:** Feels like a coach suggestion (avatar, conversational copy), not a system paywall
   **Why human:** Emotional tone and UX quality need human judgment

3. **Typing indicator animation**
   **Test:** Send a message, observe loading state
   **Expected:** Three animated dots with staggered fade animation
   **Why human:** Animation smoothness requires visual inspection

### Gaps Summary

No automated gaps remain. The previous gap (ANON-04 -- broken migration path due to dead _onAuthenticated callback) has been closed by Plan 13-04. The fix introduced eager persistence to SharedPreferences after each coach response (lines 134, 151, 183-198 in anonymous_chat_screen.dart) and removed the dead callback chain from both AnonymousChatScreen and AuthGateBottomSheet. The data-flow trace now shows FLOWING for the migration path: messages are eagerly saved under unprefixed keys, and auth_provider._migrateLocalDataIfNeeded() migrates them to the user namespace after account creation.

Three items require human verification on a real device before the phase can be marked fully passed.

---

_Verified: 2026-04-12T17:45:00Z_
_Verifier: Claude (gsd-verifier)_
