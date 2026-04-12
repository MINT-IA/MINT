# Phase 13: Anonymous Hook & Auth Bridge - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

A stranger opens MINT, taps a felt-state pill, gets a premier eclairage that surprises them, and converts to an authenticated user without losing a single message. Covers: anonymous backend endpoint, device-scoped session, rate limiting (3 messages lifetime), mode decouverte system prompt, auth gate UX, conversation migration on sign-up.

</domain>

<decisions>
## Implementation Decisions

### Anonymous Backend Architecture
- New `/anonymous/chat` endpoint separate from `/coach/chat` — cleaner separation, dedicated rate limit (3 msg/session), dedicated "mode decouverte" system prompt, no entitlement checks
- Device-scoped UUID token stored in SecureStorage, sent as `X-Anonymous-Session` header — more reliable than IP for rate limiting (ANON-06)
- 3 messages lifetime per device until auth — forces conversion. Reset only on account creation.
- Strip all tools in anonymous mode — pure conversation. Anonymous user has no profile data for tools to use. Coach responds with general Swiss finance insight based on felt-state only.

### Conversation Persistence & Migration
- Anonymous messages stored in frontend SharedPreferences only (existing `conversation_store.dart` pattern) — no backend persistence for anonymous. Privacy-friendly, messages live on device until claimed.
- On auth: frontend re-keys messages from anonymous prefix to user-ID prefix in `conversation_store.dart`. No backend migration needed since backend is stateless for conversations.
- Messages persist in SharedPreferences across app kills — next launch, if still anonymous, messages reload. Device token in SecureStorage survives too.
- Single continuous thread after auth — anonymous messages appear at the top of the authenticated conversation. Coach says "Maintenant je me souviendrai de tout." Zero visual break.

### Auth Gate UX — The Conversion Moment
- Auth gate appears after 3rd coach response (ANON-03) — coach delivers the 3rd insight, then naturally says "Je peux garder tout ca en memoire pour toi — il te suffit de creer un compte." Bottom sheet slides up with sign-up options.
- Coach voice inline — the conversion prompt IS a coach message, not a system interrupt. Subtle CTA button below the message.
- Soft lock on dismiss — user can still read their 3 messages but can't send new ones. Coach message: "Je suis toujours la quand tu voudras continuer." Auth CTA stays pinned at bottom of input area.
- Email + Apple Sign-In — minimal friction. Apple mandatory for iOS. Email via magic link or OTP, no password. Google optional later.

### Mode Decouverte — What the Anonymous Coach Says
- Intent-to-insight mapping — each of the 6 pills maps to a pre-crafted opening insight category. LLM personalizes from the category. Layer 1-2 only (factual + human translation).
- Max 1 follow-up question per response — coach can ask ONE clarifying question to sharpen the next insight. Never form-style interrogation.
- Same persona as authenticated, reduced depth — same voice/tone (calme, precis, fin), but Layer 3-4 (personal perspective + implementation intentions) gated behind auth.
- Anonymous users always land on intent screen until auth — no shell, no tabs, no drawer. Coach chat is a full-screen overlay triggered by pill tap.

### Claude's Discretion
- Internal implementation details (error handling, retry logic, token generation specifics)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart` — 6 felt-state pills, animation sequence, already navigates to `/coach/chat?prompt=X`
- `apps/mobile/lib/services/auth_service.dart` — JWT + SecureStorage pattern, `saveToken()`, `isLoggedIn()`
- `apps/mobile/lib/services/coach/conversation_store.dart` — SharedPreferences-based, user-prefixed keys, max 150 messages
- `services/backend/app/core/rate_limit.py` — slowapi with Redis/in-memory, IP extraction from X-Forwarded-For
- `services/backend/app/core/auth.py` — `get_current_user()` returns None if no Bearer token (already supports optional auth)

### Established Patterns
- Backend auth: JWT with `require_current_user` dependency injection. `get_current_user` already handles missing tokens gracefully.
- Frontend storage: `FlutterSecureStorage` for sensitive tokens, `SharedPreferences` for conversation data
- Rate limiting: slowapi decorators on endpoints, per-IP by default
- Coach chat: Full agent loop with system prompt, RAG, tool execution, compliance guard

### Integration Points
- Anonymous intent screen already routes to `/coach/chat?prompt=X` — needs to route to anonymous chat flow instead
- `conversation_store.dart` needs anonymous prefix support and re-key method
- Backend needs new `/api/v1/anonymous/chat` endpoint mirroring coach_chat structure but with reduced scope
- GoRouter needs anonymous vs authenticated routing logic

</code_context>

<specifics>
## Specific Ideas

- Auth gate message: "On a deja decouvert 3 choses ensemble. Si tu veux que je m'en souvienne..."
- Post-auth coach message: "Maintenant je me souviendrai de tout."
- Soft lock message: "Je suis toujours la quand tu voudras continuer."
- Pill-to-insight categories: each pill maps to a Swiss finance blind spot (contracts, avoidance, costly mistakes, procrastination, life change, clarity seeking)

</specifics>

<deferred>
## Deferred Ideas

- Google Sign-In (add after Apple + Email prove sufficient)
- Backend conversation persistence (if multi-device anonymous needed later)
- Push notifications for soft-locked users (v2.6 with push infra)

</deferred>
