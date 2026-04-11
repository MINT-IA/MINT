# Technical Specification — Anonymous Coach Hook

**Date:** 2026-04-11
**Status:** Ready for implementation

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  FLUTTER (no JWT yet)                                       │
│  ┌───────────────────────────────────────────┐             │
│  │  device_id (UUID v4, persisted SharedPref)│             │
│  │  counter: local mirror (authoritative = BE)│             │
│  └───────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ POST /api/v1/coach/chat/anonymous
                         │ Headers: X-Device-Id: <uuid>
                         │ Body: { message, language, cash_level }
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  BACKEND                                                    │
│                                                              │
│  1. Rate limit by IP (SlowAPI: 15/hour)                    │
│  2. Validate X-Device-Id header                             │
│  3. Lookup anonymous_usage WHERE device_id = ?              │
│  4. If count >= 3 → return 200 with requires_auth=true     │
│  5. If count < 3:                                           │
│     a. Call RAG orchestrator (same as auth'd path)          │
│     b. Use server-side ANTHROPIC_API_KEY                    │
│     c. max_tokens=500 (shorter than auth'd = 2000)         │
│     d. Apply ComplianceGuard                                │
│     e. INSERT OR UPDATE anonymous_usage (count+1)          │
│     f. Return 200 with response + remaining count           │
│  6. Cleanup job: delete anonymous_usage rows > 90 days old  │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ After signup (Apple Sign-In or magic link)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  MIGRATION PATH                                             │
│                                                              │
│  On successful login:                                       │
│  1. Flutter reads device_id                                 │
│  2. POST /api/v1/auth/claim-anonymous                       │
│     { device_id } (JWT required)                            │
│  3. Backend: UPDATE anonymous_usage SET user_id=? WHERE dev │
│  4. Backend: marks device as "claimed" (no more anon use)   │
│  5. Flutter: clears local "anonymous mode" flag             │
└─────────────────────────────────────────────────────────────┘
```

---

## Backend Changes

### New endpoint: POST /api/v1/coach/chat/anonymous

**Why a separate endpoint (not modifying existing `/coach/chat`):**
- Clear separation of concerns — anonymous path has different rate limits, different max_tokens, different auth
- Easier to disable/monitor independently
- Existing authenticated endpoint stays untouched (no regression risk)

**Request:**
```json
POST /api/v1/coach/chat/anonymous
Headers:
  Content-Type: application/json
  X-Device-Id: <uuid-v4>
Body:
  {
    "message": "C'est quoi les 3 piliers suisses ?",
    "language": "fr",
    "cash_level": 3
  }
```

**Response (success, messages remaining):**
```json
200 OK
{
  "message": "Les 3 piliers suisses sont un système de prévoyance...",
  "sources": [{"title": "LAVS art. 21", "file": "avs.md"}],
  "disclaimers": ["Outil éducatif. Ne constitue pas un conseil financier."],
  "tool_calls": [],
  "tokens_used": 180,
  "anonymous_usage": {
    "used": 1,
    "limit": 3,
    "remaining": 2,
    "requires_auth": false
  }
}
```

**Response (limit reached, soft paywall at message 3):**
```json
200 OK
{
  "message": "...real answer to their question...",
  "sources": [...],
  "disclaimers": [...],
  "anonymous_usage": {
    "used": 3,
    "limit": 3,
    "remaining": 0,
    "requires_auth": true,
    "paywall_message": "Tu as eu 3 conversations avec Mint. Sauve-les en te connectant — Mint se souviendra de toi."
  }
}
```

**Response (blocked, hard paywall at message 4+):**
```json
403 Forbidden
{
  "detail": "anonymous_limit_exceeded",
  "paywall_message": "Pour continuer avec Mint, crée ton espace gratuit. 1 tap avec Apple.",
  "upgrade_options": [
    {"method": "apple_sign_in", "label": "Sign in with Apple", "primary": true},
    {"method": "magic_link", "label": "Email magic link"},
    {"method": "password", "label": "Mot de passe"}
  ]
}
```

**Rate limiting:**
- **SlowAPI decorator**: `@limiter.limit("15/hour")` (per IP)
- **Device-ID limit**: 3 messages lifetime per device_id (enforced in query logic)
- **IP reasoning**: 15/hour lets a household share a WiFi. 3/device means max 5 devices per hour per IP before IP rate limit kicks in.

**max_tokens:**
- Anonymous: **500 tokens** (enough for a quality answer, not enough for essays)
- Authenticated: **2000 tokens** (unchanged)

**System prompt:**
- Same as authenticated `/coach/chat`
- MUST cover all 18 life events
- MUST include compliance guard post-processing

### New endpoint: POST /api/v1/auth/claim-anonymous

**Purpose:** Migrate anonymous conversation to authenticated account after signup.

**Request:**
```json
POST /api/v1/auth/claim-anonymous
Headers:
  Authorization: Bearer <jwt>
  Content-Type: application/json
Body:
  { "device_id": "<uuid>" }
```

**Response:**
```json
200 OK
{
  "claimed": true,
  "messages_migrated": 3
}
```

**Logic:**
- Verify JWT
- Find `anonymous_usage` rows WHERE `device_id = ?`
- Set `user_id = <jwt.user_id>` and `claimed_at = NOW()`
- If the table also stores conversation snippets (see DB schema below), attach them to the user's conversation history

### Database schema

**New table: `anonymous_coach_usage`**

```sql
CREATE TABLE anonymous_coach_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    message_count INTEGER NOT NULL DEFAULT 0,
    first_message_at TIMESTAMP NOT NULL,
    last_message_at TIMESTAMP NOT NULL,
    ip_address_hash TEXT,  -- SHA-256 of IP for abuse tracking without storing raw IP
    claimed_by_user_id TEXT,  -- NULL until user signs up
    claimed_at TIMESTAMP,
    UNIQUE(device_id)
);

CREATE INDEX idx_anon_device ON anonymous_coach_usage(device_id);
CREATE INDEX idx_anon_claimed ON anonymous_coach_usage(claimed_by_user_id)
  WHERE claimed_by_user_id IS NOT NULL;
CREATE INDEX idx_anon_cleanup ON anonymous_coach_usage(last_message_at)
  WHERE claimed_by_user_id IS NULL;
```

**Optional table (v2): `anonymous_messages` for conversation content**

For v1, we DON'T persist actual message content in anonymous mode — only the counter. This is intentional:
- Simpler (no text storage)
- Privacy-friendly (nothing to leak)
- Forces urgency ("sign in NOW or lose your conversation")

If we later want to persist for migration purposes, add:
```sql
CREATE TABLE anonymous_messages (
    id INTEGER PRIMARY KEY,
    device_id TEXT NOT NULL,
    role TEXT NOT NULL,  -- 'user' or 'assistant'
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    claimed_by_user_id TEXT,
    FOREIGN KEY (device_id) REFERENCES anonymous_coach_usage(device_id)
);
```

For now: **v1 does NOT persist messages**. The migration on signup just preserves the counter and marks the device as "claimed" so it can't be reused anonymously.

### Cleanup job

```python
# scripts/cleanup_anonymous_usage.py
# Run daily via cron or Railway scheduled job
DELETE FROM anonymous_coach_usage
WHERE claimed_by_user_id IS NULL
  AND last_message_at < NOW() - INTERVAL '90 days';
```

Unclaimed records older than 90 days are deleted. Claimed records are kept for audit.

---

## Flutter Changes

### Device ID handling

**File:** `apps/mobile/lib/services/device_id_service.dart` (new)

```dart
class DeviceIdService {
  static const _key = '_mint_device_id';
  static String? _cached;

  /// Returns a persistent device UUID. Generated on first call, reused after.
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }

  /// Called on logout to NOT reset (device stays the same).
  /// But the anonymous flag on the account is cleared.
  static Future<void> markClaimed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('_mint_device_claimed', true);
  }

  static Future<bool> isClaimed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('_mint_device_claimed') ?? false;
  }
}
```

**NOTE:** `_mint_device_id` already exists in the codebase (see audit data). Check if it's a UUID or something else and reuse if compatible. If not, add this service.

### CoachOrchestrator changes

**File:** `apps/mobile/lib/services/coach/coach_orchestrator.dart`

Current chain: SLM → BYOK → Server-key (JWT required) → Fallback

**New chain:**
- If user is authenticated: SLM → BYOK → Server-key (JWT) → Fallback
- If user is NOT authenticated: SLM → BYOK → **Anonymous Server-key (device_id)** → Fallback

Add new method `_tryAnonymousServerKeyChat()`:

```dart
static Future<CoachResponse?> _tryAnonymousServerKeyChat({
  required String userMessage,
  required List<ChatMessage> history,
  required CoachContext ctx,
  String? memoryBlock,
  String language = 'fr',
  int cashLevel = 3,
}) async {
  final deviceId = await DeviceIdService.get();
  final service = AnonymousCoachChatApiService();
  
  try {
    final response = await service.chat(
      deviceId: deviceId,
      message: userMessage,
      profileContext: {...},  // same as server-key path
      language: language,
      cashLevel: cashLevel,
    ).timeout(_byokTimeout);

    // If anonymous limit reached, attach paywall metadata to response
    if (response.anonymousUsage.requiresAuth) {
      return CoachResponse(
        message: response.message,
        disclaimer: ComplianceGuard.standardDisclaimer,
        sources: response.sources,
        disclaimers: response.disclaimers,
        // NEW FIELD: signals UI to show paywall after this message
        anonymousPaywall: AnonymousPaywallState(
          remaining: response.anonymousUsage.remaining,
          message: response.anonymousUsage.paywallMessage,
        ),
      );
    }
    
    // Normal path (messages remaining)
    return CoachResponse(
      message: response.message,
      ...
    );
  } on AnonymousLimitExceededException {
    // 4th+ attempt: return a special response that triggers hard paywall UI
    return CoachResponse(
      message: '',
      disclaimer: '',
      anonymousPaywall: AnonymousPaywallState.blocked(),
    );
  } catch (e) {
    debugPrint('[Orchestrator] Anonymous chat error: $e');
    return null;
  }
}
```

### Logic change in generateChat

```dart
static Future<CoachResponse> generateChat({...}) async {
  // 1. SLM (unchanged)
  if (_slmEligible()) {...}

  // 2. BYOK (unchanged)
  if (byokConfig != null && byokConfig.hasApiKey) {...}

  // 2.5. NEW: Server-key tier, branches on auth state
  if (!FeatureFlags.safeModeDegraded) {
    final isAuthenticated = await AuthService.getToken() != null;
    
    if (isAuthenticated) {
      // Authenticated server-key (existing path)
      final response = await _tryServerKeyChat(...);
      if (response != null) return response;
    } else {
      // NEW: Anonymous server-key (device_id based)
      final response = await _tryAnonymousServerKeyChat(...);
      if (response != null) return response;
    }
  }

  // 3. Fallback (unchanged, last resort)
  return _chatFallback(language);
}
```

### New service: AnonymousCoachChatApiService

**File:** `apps/mobile/lib/services/coach/anonymous_coach_chat_api_service.dart` (new)

Similar to `CoachChatApiService` but:
- No JWT header
- Sends `X-Device-Id` header
- Calls `/coach/chat/anonymous` endpoint
- Parses `anonymous_usage` metadata
- Throws `AnonymousLimitExceededException` on 403

### UI Changes

**File:** `apps/mobile/lib/screens/coach/coach_chat_screen.dart`

1. **Message counter display:**
   - Show "3 messages restants" below input bar while anonymous
   - Only visible if user is NOT authenticated
   - Fades in subtly, not anxiety-inducing
   - Updates after each successful response

2. **Soft CTA at message 3:**
   - Inline card below the 3rd assistant message
   - Text: "Tu as eu 3 conversations avec Mint. Sauve-les pour qu'il se souvienne de toi."
   - Two buttons: "Sign in with Apple" (primary) | "Plus tard" (dismiss)

3. **Hard paywall at message 4+:**
   - Modal bottom sheet, non-dismissible except via signup or "Close app"
   - Full-screen-ish, dominant CTA
   - Text: "Pour continuer avec Mint, crée ton espace gratuit. 1 tap avec Apple."

4. **Post-signup confirmation:**
   - Once user signs in, show a brief toast: "Bon retour. Mint se souvient de toi maintenant."
   - Call `/auth/claim-anonymous` silently in background

### New widget: AnonymousPaywallCard

**File:** `apps/mobile/lib/widgets/coach/anonymous_paywall_card.dart` (new)

Inline card rendered below an assistant message when `anonymousPaywall != null`.

Two variants:
- **Soft** (message 3): inline, dismissible, not modal
- **Blocked** (message 4+): modal bottom sheet, forces action

---

## Security & Abuse Prevention

1. **IP hashing**: Store SHA-256 of IP, not raw. Backend only reads first 8 chars for rate limit lookup.
2. **Device ID is a hint, not identity**: Easy to reset by reinstall. That's OK because IP rate limit is the real protection.
3. **No PII in anonymous state**: No email, no phone, no name. Only device_id (pseudo) and question content.
4. **Logs**: Anonymous requests logged with device_id hash only. No question content in logs (privacy).
5. **Shared WiFi scenario**: 15 requests/hour per IP = enough for a family of 5, not enough for scraping.
6. **Token budget cap**: 500 max_tokens × 3 messages = ~$0.15 per anonymous user at Sonnet rates.

---

## Testing Strategy

### Unit tests (backend)
- `test_anonymous_coach_chat.py`
- Test counter increments correctly
- Test 403 at message 4
- Test claim migration updates user_id
- Test rate limit kicks in at 15/hour

### Integration tests (backend)
- Full HTTP POST flow: device_id → 3 messages → claim → 4th message as authenticated

### Flutter tests
- `test_anonymous_coach_chat_api_service_test.dart`
- Test service sends device_id header
- Test service parses paywall metadata
- Test orchestrator routes to anonymous service when no JWT

### End-to-end (manual, on device)
1. Fresh install → 3 messages → real responses
2. 4th message → hard paywall
3. Apple Sign-In → claim → 5th message works as authenticated
4. Reinstall app → new device_id → 3 more messages possible (expected behavior)

---

## Performance Targets

- Response time (anonymous): ≤ 5s (same as authenticated path, no additional latency from counter lookup)
- Counter lookup: single indexed query < 10ms
- Migration (claim): < 100ms
- Backend concurrent anonymous users: 10+ without degradation

---

## Rollout Plan

1. Deploy backend to Railway staging
2. Update Flutter to call new endpoint
3. Build TestFlight staging
4. Creator walks the flow end-to-end
5. Fix discovered issues
6. Deploy to production (after PR staging → main approval)
