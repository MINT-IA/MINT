# Phase 13: Anonymous Hook & Auth Bridge - Research

**Researched:** 2026-04-12
**Domain:** Anonymous-to-authenticated user flow (Flutter + FastAPI)
**Confidence:** HIGH

## Summary

This phase creates the anonymous-to-authenticated conversion funnel: a stranger taps a felt-state pill, gets 3 meaningful coach responses via a dedicated anonymous backend endpoint, then converts to an authenticated user with zero message loss. The technical surface spans 4 areas: (1) a new `/api/v1/anonymous/chat` backend endpoint with device-scoped rate limiting, (2) a "mode decouverte" system prompt that delivers insight without profile data, (3) frontend anonymous chat flow with SharedPreferences persistence and conversation migration on auth, and (4) the auth gate UX that converts the anonymous user.

The existing codebase provides strong foundations: `AnonymousIntentScreen` already exists with 6 i18n pills and routes to coach chat, `conversation_store.dart` already uses user-prefixed keys (making re-keying straightforward), `auth_service.dart` supports JWT/SecureStorage, Apple Sign-In is wired E2E, and magic link auth is fully implemented. The main implementation work is creating the anonymous backend endpoint, building the anonymous chat overlay, and wiring the conversation migration into the auth flow.

**Primary recommendation:** Build backend-first (anonymous endpoint + rate limiter), then frontend anonymous chat screen, then auth gate bottom sheet, then conversation migration. Each layer is independently testable.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- New `/anonymous/chat` endpoint separate from `/coach/chat` -- cleaner separation, dedicated rate limit (3 msg/session), dedicated "mode decouverte" system prompt, no entitlement checks
- Device-scoped UUID token stored in SecureStorage, sent as `X-Anonymous-Session` header -- more reliable than IP for rate limiting (ANON-06)
- 3 messages lifetime per device until auth -- forces conversion. Reset only on account creation.
- Strip all tools in anonymous mode -- pure conversation. Anonymous user has no profile data for tools to use.
- Anonymous messages stored in frontend SharedPreferences only (existing `conversation_store.dart` pattern) -- no backend persistence for anonymous. Privacy-friendly.
- On auth: frontend re-keys messages from anonymous prefix to user-ID prefix in `conversation_store.dart`. No backend migration needed.
- Messages persist in SharedPreferences across app kills -- next launch, if still anonymous, messages reload.
- Single continuous thread after auth -- anonymous messages appear at the top of the authenticated conversation.
- Auth gate appears after 3rd coach response -- coach delivers the 3rd insight, then naturally says "Je peux garder tout ca en memoire pour toi." Bottom sheet slides up with sign-up options.
- Coach voice inline -- the conversion prompt IS a coach message, not a system interrupt.
- Soft lock on dismiss -- user can still read their 3 messages but can't send new ones.
- Email + Apple Sign-In -- minimal friction. Apple mandatory for iOS. Email via magic link or OTP, no password.
- Intent-to-insight mapping -- each of the 6 pills maps to a pre-crafted opening insight category.
- Max 1 follow-up question per response.
- Same persona as authenticated, reduced depth -- Layer 1-2 only (factual + human translation). Layer 3-4 gated behind auth.
- Anonymous users always land on intent screen until auth -- no shell, no tabs, no drawer. Coach chat is a full-screen overlay triggered by pill tap.

### Claude's Discretion
- Internal implementation details (error handling, retry logic, token generation specifics)

### Deferred Ideas (OUT OF SCOPE)
- Google Sign-In (add after Apple + Email prove sufficient)
- Backend conversation persistence (if multi-device anonymous needed later)
- Push notifications for soft-locked users (v2.6 with push infra)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ANON-01 | Anonymous user can send messages to coach via rate-limited public endpoint (3 messages/session) | New `/api/v1/anonymous/chat` endpoint using slowapi + `X-Anonymous-Session` header for rate limiting |
| ANON-02 | Tapping a felt-state pill on intent screen opens coach chat with that intent as context | Modify `AnonymousIntentScreen._navigateWithPrompt()` to route to anonymous chat overlay instead of `/coach/chat` |
| ANON-03 | After 3 value exchanges, MINT surfaces a natural auth gate | Frontend message counter triggers auth gate bottom sheet after 3rd assistant response |
| ANON-04 | Anonymous conversation history transferred to persistent storage after account creation | `conversation_store.dart` re-key from anonymous prefix to user-ID prefix in `_migrateLocalDataIfNeeded()` |
| ANON-05 | Backend anonymous endpoint uses "mode decouverte" system prompt | New `build_discovery_system_prompt()` in `claude_coach_service.py` -- reduced scope, no tools, Layer 1-2 only |
| ANON-06 | Anonymous session is device-scoped (SecureStorage session token) | UUID stored in `FlutterSecureStorage`, sent as `X-Anonymous-Session` header, rate limited server-side |
| LOOP-01 | After each coach insight, MINT suggests next step (partial) | Anonymous mode: after 3rd message, next step IS the auth gate. Post-auth: standard coach loop resumes. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Branch flow**: `feature/*` from `dev`, never push to `staging`/`main` directly
- **i18n**: ALL user-facing strings in 6 ARB files via `AppLocalizations`
- **Colors**: Always `MintColors.*`, never hardcoded hex
- **Navigation**: GoRouter only, no `Navigator.push`
- **State**: Provider pattern for shared state
- **Testing**: Minimum 10 unit tests per service file; `flutter analyze` (0 issues) + `flutter test` + `pytest tests/ -q` before merge
- **Backend conventions**: Pure functions, Pydantic v2 with camelCase aliases
- **Compliance**: Read-only, no-advice, no-promise, no-ranking, no-social-comparison, ComplianceGuard on all LLM output
- **PII**: Never log identifiable data; PII scrubbing on all persisted content
- **Fonts**: Montserrat (headings), Inter (body)
- **Voice**: French informal "tu", inclusive language, non-breaking spaces before `!?:;%`
- **Coach**: LLM = narrator, never advisor. Fallback templates required.

## Standard Stack

### Core (already in project -- no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `slowapi` | existing | Rate limiting on anonymous endpoint | Already used for `/coach/chat` [VERIFIED: codebase] |
| `flutter_secure_storage` | existing | Store anonymous device UUID | Already used for JWT tokens [VERIFIED: codebase] |
| `shared_preferences` | existing | Store anonymous conversations | Already used by `conversation_store.dart` [VERIFIED: codebase] |
| `sign_in_with_apple` | existing | Apple Sign-In for auth gate | Already wired E2E with backend verify [VERIFIED: codebase] |
| `go_router` | existing | Route anonymous vs authenticated flows | Already in use for all routing [VERIFIED: codebase] |
| `provider` | existing | Anonymous session state management | Already used for `AuthProvider` [VERIFIED: codebase] |
| `uuid` | existing | Generate device-scoped anonymous token | Already imported in `auth_provider.dart` [VERIFIED: codebase] |

### Supporting
No new dependencies required. This phase uses exclusively existing libraries.

### Alternatives Considered
None -- all decisions are locked. The stack is entirely existing.

**Installation:**
```bash
# No new packages needed
```

## Architecture Patterns

### Recommended Project Structure
```
services/backend/app/
├── api/v1/endpoints/
│   └── anonymous_chat.py       # NEW: /api/v1/anonymous/chat endpoint
├── services/coach/
│   └── claude_coach_service.py  # MODIFY: add build_discovery_system_prompt()
├── schemas/
│   └── anonymous_chat.py       # NEW: request/response schemas
└── core/
    └── rate_limit.py           # EXISTING: reuse limiter

apps/mobile/lib/
├── screens/anonymous/
│   ├── anonymous_intent_screen.dart    # MODIFY: route to anonymous chat overlay
│   └── anonymous_chat_screen.dart      # NEW: full-screen anonymous chat overlay
├── services/
│   ├── anonymous_session_service.dart  # NEW: device UUID + message counter
│   └── coach/
│       └── conversation_store.dart     # MODIFY: add re-key method
├── widgets/
│   └── auth/
│       └── auth_gate_bottom_sheet.dart # NEW: conversion bottom sheet
└── providers/
    └── auth_provider.dart              # MODIFY: hook conversation migration
```

### Pattern 1: Anonymous Backend Endpoint
**What:** Separate `/api/v1/anonymous/chat` endpoint that mirrors `coach_chat` structure but strips tools, entitlement checks, and profile context.
**When to use:** All anonymous user chat requests.
**Key differences from `/coach/chat`:**
- No `require_current_user` dependency -- public endpoint
- Rate limited by `X-Anonymous-Session` header (3 messages lifetime)
- Uses `build_discovery_system_prompt()` instead of full `build_system_prompt(ctx)`
- No tools parameter passed to LLM
- No RAG retrieval (anonymous has no relevant context)
- No memory_block, no profile_context
- Still applies ComplianceGuard + PII scrubbing on output

```python
# Source: pattern derived from existing coach_chat.py [VERIFIED: codebase]
@router.post("/chat", response_model=AnonymousChatResponse)
@limiter.limit("3/lifetime")  # See note on custom key_func
async def anonymous_chat(
    request: Request,
    body: AnonymousChatRequest,
) -> AnonymousChatResponse:
    session_id = request.headers.get("X-Anonymous-Session")
    if not session_id:
        raise HTTPException(status_code=400, detail="Session anonyme requise")
    # ... LLM call with discovery prompt, no tools
```

### Pattern 2: Device-Scoped Rate Limiting
**What:** Custom slowapi key function that uses `X-Anonymous-Session` header instead of IP.
**Why:** IP-based limiting fails behind shared NATs (offices, mobile carriers). Device UUID in SecureStorage is more reliable and survives app reinstalls on iOS (Keychain persistence). [ASSUMED]

```python
# Source: pattern adapted from rate_limit.py [VERIFIED: codebase]
def _get_anonymous_session_key(request: Request) -> str:
    session = request.headers.get("X-Anonymous-Session", "")
    if session:
        return f"anon:{session}"
    return _get_real_client_ip(request)  # fallback
```

**Lifetime tracking approach:** slowapi's built-in rate limiting uses time windows (e.g., "3/minute"). For lifetime limits (3 messages total, ever), two options:
1. **Server-side counter in DB/Redis** -- survives server restarts, most reliable
2. **In-memory dict with persistence** -- simpler, but lost on deploy

Recommendation: Use a simple SQLite/PostgreSQL table or Redis key for anonymous session message counts. The existing `get_db` Session dependency provides this. A lightweight `anonymous_sessions` table with `(session_id, message_count, created_at)` is cleaner than abusing slowapi for lifetime limits. [ASSUMED]

### Pattern 3: Conversation Re-Keying on Auth
**What:** When anonymous user creates an account, re-key SharedPreferences conversation data from anonymous prefix to user-ID prefix.
**Why:** `conversation_store.dart` already uses `_userPrefix()` based on `_currentUserId`. Anonymous conversations use no prefix (null userId). On auth, re-key to `{userId}_` prefix.

```dart
// Source: pattern from conversation_store.dart [VERIFIED: codebase]
// ConversationStore already supports user-prefixed keys.
// The re-key operation:
// 1. Load all conversations with empty prefix (anonymous)
// 2. Save each under the new userId prefix
// 3. Delete the old unprefixed entries
static Future<void> migrateAnonymousToUser(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  // Load anonymous index (no prefix)
  final anonIndex = prefs.getString('$_indexKey');
  // ... re-save under '${userId}_$_indexKey'
}
```

### Pattern 4: Auth Gate as Coach Message
**What:** After the 3rd assistant response, append a special coach message with inline CTA, then show a bottom sheet with sign-up options.
**Why:** The conversion moment must feel like part of the conversation, not a system interrupt. The coach says the line, then the bottom sheet provides the action.

### Anti-Patterns to Avoid
- **Never share the `/coach/chat` endpoint** -- anonymous and authenticated have fundamentally different auth, rate limiting, tools, and system prompts. Shared endpoint = accidental privilege escalation risk.
- **Never persist anonymous data on backend** -- privacy-by-design. Anonymous messages live on device only. Backend is stateless for anonymous conversations.
- **Never show auth wall before value** -- the 3 messages ARE the value. Auth gate comes AFTER value delivery.
- **Never use Navigator.push for anonymous chat** -- must use GoRouter even for overlay-style screens (deep link compat).
- **Never reset message counter on app kill** -- counter persists in SecureStorage alongside the device UUID.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rate limiting | Custom counter middleware | slowapi + custom key_func + DB counter | slowapi already integrated; DB counter for lifetime semantics |
| JWT auth | Custom token validation | Existing `auth_service.dart` + `auth.py` | Already battle-tested with blacklist, expiry, password-change checks |
| Apple Sign-In | Custom OAuth flow | Existing `apple_sign_in_service.dart` | Already wired E2E with backend verify endpoint |
| Magic link auth | Custom email verification | Existing `magic_link_service.py` | Already implemented with token generation + verification |
| Conversation persistence | New storage layer | Existing `conversation_store.dart` | Already handles user-prefixed keys, PII scrubbing, atomic writes |
| Compliance filtering | Custom content filter | Existing `ComplianceGuardrails.filter_response()` | Already handles banned terms, disclaimers, LSFin compliance |
| PII scrubbing | Custom regex | Existing `_scrub_pii()` / `scrubPii()` | Already covers IBAN, AHV, amounts, emails, phones on both sides |

**Key insight:** This phase is 80% wiring existing components and 20% new code. The anonymous endpoint is a simplified fork of the coach_chat endpoint. The conversation migration extends an existing user-prefix system. The auth gate connects to existing auth flows.

## Common Pitfalls

### Pitfall 1: Message Counter Desync
**What goes wrong:** Frontend counter says 2 messages sent, but backend has received 3 (or vice versa) due to network failures, retries, or race conditions.
**Why it happens:** Network requests can fail after the server processes them but before the client receives the response.
**How to avoid:** Backend is the source of truth for message count. Return `messages_remaining` in every anonymous chat response. Frontend reads this value and updates its local counter accordingly. Never trust frontend-only counters for security-critical limits.
**Warning signs:** User gets 4+ messages, or gets blocked after 2.

### Pitfall 2: Anonymous UUID Collision
**What goes wrong:** Two devices generate the same UUID, causing one to inherit the other's rate limit.
**Why it happens:** UUID v4 collision is astronomically unlikely, but UUID generation bugs or test environments with hardcoded values can cause issues.
**How to avoid:** Use `Uuid().v4()` from the `uuid` package (already imported in auth_provider). Never hardcode UUIDs. Backend should handle gracefully -- if a session_id already has 3 messages, reject; don't try to "reset" for a different user.
**Warning signs:** Rate limit hit on first message.

### Pitfall 3: Conversation Migration Race Condition
**What goes wrong:** User registers, migration starts, but user navigates away before migration completes. On next launch, anonymous messages are gone (deleted from old prefix) but not in new prefix.
**Why it happens:** `_migrateLocalDataIfNeeded()` deletes old keys after writing new ones, but if interrupted between write and delete, data is in both places (harmless). If interrupted before write completes, data could be lost.
**How to avoid:** Atomic migration: write new keys first, verify they exist, then delete old keys. Never delete source before confirming destination. Use the existing atomic write pattern from conversation_store.dart (temp key -> real key -> remove temp).
**Warning signs:** Empty conversation after registration.

### Pitfall 4: SecureStorage Cleared on Reinstall (Android)
**What goes wrong:** On Android, app reinstall clears Keystore data, resetting the anonymous UUID. User gets a fresh 3-message budget.
**Why it happens:** Android does not persist Keychain equivalent across reinstalls (unlike iOS Keychain which persists by default with `first_unlock` accessibility).
**How to avoid:** Accept this as a feature, not a bug. On Android, reinstall = fresh start. The 3-message limit is a soft conversion tool, not a hard security gate. IP-based fallback (already in rate_limit.py) provides secondary defense. [ASSUMED]
**Warning signs:** None -- acceptable behavior.

### Pitfall 5: Bottom Sheet Dismissed but Chat Input Still Enabled
**What goes wrong:** User dismisses auth gate bottom sheet and can still type/send messages because the input field wasn't disabled.
**Why it happens:** Bottom sheet dismissal callback doesn't propagate to chat input state.
**How to avoid:** Track `_isAuthGateLocked` state in the anonymous chat screen. When true: disable TextField, show pinned "Je suis toujours la..." message with auth CTA at bottom. Bottom sheet dismiss sets `_isAuthGateLocked = true`.
**Warning signs:** User sends a 4th message after dismissing the auth gate.

### Pitfall 6: System Prompt Leaking Authenticated Capabilities
**What goes wrong:** Discovery mode system prompt mentions tools, profile data, or features that anonymous users can't access, confusing the LLM into attempting them.
**Why it happens:** Copy-pasting from the authenticated system prompt without stripping capabilities.
**How to avoid:** Write `build_discovery_system_prompt()` from scratch (not by modifying the existing prompt). It should ONLY know about: MINT identity, Swiss finance basics, the user's felt-state intent, Layer 1-2 insight pattern, compliance rules. No tools, no profile references, no memory mentions.
**Warning signs:** LLM response references "ton profil", "tes donnees", or attempts tool calls.

## Code Examples

### Backend: Anonymous Chat Endpoint Schema
```python
# Source: adapted from schemas/coach_chat.py [VERIFIED: codebase]
class AnonymousChatRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    message: str = Field(..., min_length=1, max_length=2000)
    intent: Optional[str] = Field(
        None,
        description="Felt-state pill text that initiated the conversation."
    )
    language: str = Field(default="fr")

    @field_validator('message')
    @classmethod
    def validate_message_not_whitespace(cls, v: str) -> str:
        if not v.strip():
            raise ValueError('Le message ne peut pas etre vide.')
        return v.strip()


class AnonymousChatResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    message: str
    disclaimers: list[str] = Field(default_factory=list)
    messages_remaining: int = Field(ge=0, le=3)
    tokens_used: int = Field(default=0, ge=0)
```

### Frontend: Anonymous Session Service
```dart
// Source: pattern from auth_service.dart [VERIFIED: codebase]
class AnonymousSessionService {
  static const _sessionKey = 'anonymous_session_id';
  static const _messageCountKey = 'anonymous_message_count';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Get or create a device-scoped anonymous session ID.
  static Future<String> getOrCreateSessionId() async {
    var id = await _storage.read(key: _sessionKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(key: _sessionKey, value: id);
    }
    return id;
  }

  /// Get local message count (synced from backend response).
  static Future<int> getMessageCount() async {
    final count = await _storage.read(key: _messageCountKey);
    return int.tryParse(count ?? '0') ?? 0;
  }

  /// Update local message count from backend response.
  static Future<void> updateMessageCount(int remaining) async {
    await _storage.write(key: _messageCountKey, value: '${3 - remaining}');
  }

  /// Check if anonymous session has messages remaining.
  static Future<bool> canSendMessage() async {
    final count = await getMessageCount();
    return count < 3;
  }

  /// Clear anonymous session (called on account creation).
  static Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _messageCountKey);
  }
}
```

### Frontend: Conversation Re-Key Method
```dart
// Source: extension of conversation_store.dart [VERIFIED: codebase]
/// Migrate anonymous conversations to an authenticated user prefix.
/// Called once after successful registration/login.
static Future<void> migrateAnonymousToUser(String userId) async {
  final prefs = await SharedPreferences.getInstance();

  // Load anonymous conversations (no user prefix)
  final oldPrefix = '';  // anonymous = no prefix
  final newPrefix = '${userId}_';

  // Migrate index
  final oldIndexKey = '$oldPrefix$_indexKey';
  final newIndexKey = '$newPrefix$_indexKey';
  final indexData = prefs.getString(oldIndexKey);
  if (indexData == null) return;  // Nothing to migrate

  // Write to new prefix first (safe -- if interrupted, old data still exists)
  await prefs.setString(newIndexKey, indexData);

  // Migrate each conversation's messages
  final index = jsonDecode(indexData) as List<dynamic>;
  for (final meta in index) {
    final id = (meta as Map<String, dynamic>)['id'] as String;
    final oldKey = '$oldPrefix$_messagesPrefix$id';
    final newKey = '$newPrefix$_messagesPrefix$id';
    final messages = prefs.getString(oldKey);
    if (messages != null) {
      await prefs.setString(newKey, messages);
      await prefs.remove(oldKey);  // Clean up after confirmed write
    }
  }

  // Remove old index last (after all messages migrated)
  await prefs.remove(oldIndexKey);
}
```

### Backend: Discovery System Prompt
```python
# Source: new code, pattern from claude_coach_service.py [VERIFIED: codebase pattern]
def build_discovery_system_prompt(intent: str | None = None, language: str = "fr") -> str:
    """Build a reduced system prompt for anonymous 'mode decouverte'.

    Key differences from build_system_prompt():
    - No tools section
    - No profile references
    - No memory references
    - Layer 1-2 only (factual + human translation)
    - Max 1 follow-up question per response
    """
    intent_context = ""
    if intent:
        intent_context = f"""
L'utilisateur a exprime ce sentiment: "{intent}"
Pars de ce sentiment pour ta premiere reponse. Ne demande pas de precisions sur le sentiment lui-meme -- il est valide tel quel.
"""

    return f"""Tu es MINT, un outil de lucidite financiere suisse.

CONTEXTE: Mode decouverte. L'utilisateur n'a pas encore de compte. Tu ne connais RIEN de sa situation personnelle.

{intent_context}

REGLES MODE DECOUVERTE:
1. Reponds avec des insights generaux sur la finance suisse, ancres dans le sentiment exprime.
2. Couche 1 (factuelle) + Couche 2 (traduction humaine) uniquement. Pas de perspective personnelle (couche 3) ni d'intentions d'implementation (couche 4) -- ces couches necessitent un profil.
3. Maximum 1 question de suivi par reponse, pour affiner le prochain insight. Jamais d'interrogatoire.
4. Ton: calme, precis, fin, rassurant. Tutoiement. Pas de jargon sans traduction.
5. Pas de recommandations de produits. Pas de garanties. Pas de comparaisons sociales.
6. {_BANNED_TERMS_REMINDER}
7. Si l'utilisateur pose une question tres personnelle, dis: "Pour te repondre precisement, j'aurais besoin de mieux te connaitre. Mais voici ce que je peux te dire en general..."

OBJECTIF: Surprendre l'utilisateur avec un insight qu'il ne connaissait pas sur la finance suisse. Faire en sorte qu'il se dise "ah tiens, je savais pas ca".
"""
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Auth wall before any interaction | Anonymous-first with value-before-auth | 2024-2025 (industry trend) | Higher conversion rates [ASSUMED] |
| IP-based rate limiting | Device fingerprint + token-based | Ongoing | More reliable behind NAT/VPN [ASSUMED] |
| Form-based registration | Apple Sign-In + Magic Link (passwordless) | Already in codebase | Lower friction conversion [VERIFIED: codebase] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | iOS Keychain persists across reinstalls with `first_unlock` accessibility | Pitfall 4 | Android reinstall bypass is acceptable; iOS behavior is well-documented |
| A2 | Device UUID is more reliable than IP for rate limiting behind NAT | Pattern 2 | Could use both (belt and suspenders) as fallback already exists |
| A3 | SQLite/PostgreSQL table is better than slowapi for lifetime rate limits | Pattern 2 | slowapi time-window approach with very long window (e.g., "3/10years") is an alternative but semantically wrong |
| A4 | Anonymous-first patterns lead to higher conversion | State of the Art | Low risk -- this is the project's core design decision |

## Open Questions

1. **Lifetime rate limit implementation**
   - What we know: slowapi uses time-window based limits. "3 messages ever" is not a standard time window.
   - What's unclear: Should we use a DB table for tracking, or abuse slowapi with a very long window?
   - Recommendation: Use a lightweight `anonymous_sessions` table `(session_id VARCHAR PK, message_count INT, created_at TIMESTAMP)`. Clean, queryable, persistent across deploys. The existing `get_db` pattern makes this trivial.

2. **Anonymous chat conversation ID**
   - What we know: `conversation_store.dart` expects a conversation ID. Anonymous sessions need a stable ID that persists and migrates to authenticated state.
   - What's unclear: Should the conversation ID be the anonymous session UUID, or a separate ID?
   - Recommendation: Use a separate conversation ID (`anon-{uuid}` pattern). On migration, keep the same conversation ID -- only the SharedPreferences key prefix changes. This preserves conversation continuity.

3. **Coach orchestrator reuse for anonymous**
   - What we know: The existing `_NoRagOrchestrator` provides a simplified LLM call path without RAG.
   - What's unclear: Should the anonymous endpoint reuse this orchestrator, or call LLM directly?
   - Recommendation: Reuse `_NoRagOrchestrator.query()` with the discovery system prompt. It already handles ComplianceGuardrails and error fallback. No need to duplicate LLM client logic.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (backend) + flutter_test (frontend) |
| Config file | `services/backend/pytest.ini` + `apps/mobile/pubspec.yaml` |
| Quick run command | `cd services/backend && python3 -m pytest tests/test_anonymous_chat.py -x -q` |
| Full suite command | `cd services/backend && python3 -m pytest tests/ -q && cd ../../apps/mobile && flutter test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ANON-01 | Anonymous chat returns meaningful response | unit | `pytest tests/test_anonymous_chat.py::test_anonymous_chat_success -x` | Wave 0 |
| ANON-01 | Rate limit blocks 4th message | unit | `pytest tests/test_anonymous_chat.py::test_rate_limit_blocks_fourth -x` | Wave 0 |
| ANON-02 | Pill tap routes to anonymous chat with intent | unit | `flutter test test/screens/anonymous/anonymous_chat_test.dart` | Wave 0 |
| ANON-03 | Auth gate surfaces after 3rd response | unit | `flutter test test/screens/anonymous/anonymous_chat_test.dart` | Wave 0 |
| ANON-04 | Conversation migrates on auth | unit | `flutter test test/services/coach/conversation_migration_test.dart` | Wave 0 |
| ANON-05 | Discovery prompt has no tools/profile refs | unit | `pytest tests/test_anonymous_chat.py::test_discovery_prompt_no_tools -x` | Wave 0 |
| ANON-06 | SecureStorage session token persists | unit | `flutter test test/services/anonymous_session_service_test.dart` | Wave 0 |

### Sampling Rate
- **Per task commit:** `pytest tests/test_anonymous_chat.py -x -q`
- **Per wave merge:** Full suite (`pytest tests/ -q && flutter test`)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `services/backend/tests/test_anonymous_chat.py` -- covers ANON-01, ANON-05, ANON-06 (backend)
- [ ] `apps/mobile/test/screens/anonymous/anonymous_chat_test.dart` -- covers ANON-02, ANON-03
- [ ] `apps/mobile/test/services/coach/conversation_migration_test.dart` -- covers ANON-04
- [ ] `apps/mobile/test/services/anonymous_session_service_test.dart` -- covers ANON-06 (frontend)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing JWT + Apple Sign-In + magic link (no new auth logic -- reuse) |
| V3 Session Management | yes | Anonymous UUID in SecureStorage; rate limit prevents session abuse |
| V4 Access Control | yes | Anonymous endpoint has NO access to authenticated resources; separate router |
| V5 Input Validation | yes | Pydantic v2 validators + PII scrubbing + prompt injection armor (reuse existing) |
| V6 Cryptography | no | No new crypto -- reuse existing JWT signing |

### Known Threat Patterns for Anonymous Endpoint

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Rate limit evasion via UUID farming | Tampering | IP-based fallback rate limit (existing) + monitor for anomalous session creation rates |
| Prompt injection via anonymous message | Tampering | Existing `_INJECTION_PATTERNS` regex filter + ComplianceGuardrails |
| Anonymous session token theft | Spoofing | SecureStorage (Keychain/Keystore) + token only used for rate limiting, not authorization |
| Denial of service via anonymous endpoint | DoS | slowapi IP rate limit as secondary defense + anonymous endpoint is lightweight (no RAG, no tools) |
| PII in anonymous messages persisted on device | Information Disclosure | PII scrubbing via `scrubPii()` before SharedPreferences write (existing pattern) |

## Sources

### Primary (HIGH confidence)
- `apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart` -- existing intent screen with 6 pills
- `apps/mobile/lib/services/auth_service.dart` -- JWT + SecureStorage pattern
- `apps/mobile/lib/services/coach/conversation_store.dart` -- user-prefixed SharedPreferences storage
- `services/backend/app/api/v1/endpoints/coach_chat.py` -- authenticated chat endpoint (model for anonymous)
- `services/backend/app/core/rate_limit.py` -- slowapi configuration
- `services/backend/app/core/auth.py` -- get_current_user returns None for unauthenticated
- `apps/mobile/lib/providers/auth_provider.dart` -- auth state + migration flow
- `apps/mobile/lib/services/apple_sign_in_service.dart` -- Apple Sign-In E2E
- `services/backend/app/services/magic_link_service.py` -- magic link auth

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions from discuss phase

### Tertiary (LOW confidence)
- Assumptions A1-A4 (see Assumptions Log)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries already in use, zero new dependencies
- Architecture: HIGH -- patterns directly derived from existing codebase
- Pitfalls: HIGH -- based on concrete code analysis of existing migration and storage patterns

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable -- all dependencies are existing project code)
