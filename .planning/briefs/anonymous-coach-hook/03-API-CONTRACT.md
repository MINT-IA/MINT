# API Contract — Anonymous Coach Hook

**Date:** 2026-04-11
**Version:** v1

---

## Endpoint 1: POST /api/v1/coach/chat/anonymous

**Purpose:** Send a message to the coach without requiring authentication, limited to 3 messages per device.

**Auth:** None (public endpoint)

### Request

```http
POST /api/v1/coach/chat/anonymous HTTP/1.1
Host: mint-staging.up.railway.app
Content-Type: application/json
X-Device-Id: 550e8400-e29b-41d4-a716-446655440000
```

**Body:**
```json
{
  "message": "C'est quoi les 3 piliers suisses ?",
  "language": "fr",
  "cash_level": 3,
  "profile_context": null
}
```

**Required fields:**
- `message` (string, 1-2000 chars)
- `X-Device-Id` header (UUID v4)

**Optional fields:**
- `language` (default: "fr", allowed: "fr" | "de" | "en" | "it" | "es" | "pt")
- `cash_level` (default: 3, range: 1-5 — voice intensity)
- `profile_context` (default: null — anonymous users don't have profile data yet)

### Response 200 — Success with messages remaining

```json
{
  "message": "Les 3 piliers suisses sont un système de prévoyance articulé en trois niveaux :\n\n1. **1er pilier (AVS/AI)** : obligatoire, couvre les besoins vitaux\n2. **2e pilier (LPP)** : prévoyance professionnelle obligatoire dès 22'680 CHF/an\n3. **3e pilier** : épargne individuelle facultative, avantages fiscaux (3a)\n\n[... real Claude response ...]",
  "sources": [
    {
      "title": "LAVS art. 21-40",
      "file": "avs_system.md",
      "section": "Régime des rentes"
    }
  ],
  "disclaimers": [
    "Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin."
  ],
  "tool_calls": [],
  "tokens_used": 245,
  "anonymous_usage": {
    "used": 1,
    "limit": 3,
    "remaining": 2,
    "requires_auth": false,
    "paywall_message": null
  }
}
```

### Response 200 — Success at message 3 (soft paywall)

```json
{
  "message": "[...real answer to user's 3rd question...]",
  "sources": [...],
  "disclaimers": [...],
  "tool_calls": [],
  "tokens_used": 198,
  "anonymous_usage": {
    "used": 3,
    "limit": 3,
    "remaining": 0,
    "requires_auth": true,
    "paywall_message": "Tu as eu 3 conversations avec Mint. Sauve-les en te connectant — Mint se souviendra de toi et personnalisera ses conseils."
  }
}
```

**UI interpretation:** Display the normal coach response. Then render the `AnonymousPaywallCard` (soft variant) inline below the message.

### Response 403 — Hard paywall (message 4+)

```json
{
  "detail": "anonymous_limit_exceeded",
  "paywall_message": "Pour continuer avec Mint, crée ton espace gratuit. 1 tap avec Apple.",
  "upgrade_options": [
    {
      "method": "apple_sign_in",
      "label": "Sign in with Apple",
      "primary": true
    },
    {
      "method": "magic_link",
      "label": "Email magic link",
      "primary": false
    },
    {
      "method": "password",
      "label": "Mot de passe",
      "primary": false
    }
  ],
  "anonymous_usage": {
    "used": 3,
    "limit": 3,
    "remaining": 0
  }
}
```

**UI interpretation:** No coach response to render. Immediately show modal bottom sheet with upgrade options.

### Response 400 — Invalid request

```json
{
  "detail": "Invalid X-Device-Id header: must be a valid UUID v4"
}
```

### Response 429 — Rate limit (IP-level)

```json
{
  "detail": "Rate limit exceeded: 15 requests per hour per IP"
}
```

**Retry-After header:** included

### Response 503 — Backend error

```json
{
  "detail": "Coach AI temporarily unavailable. Please try again in a moment."
}
```

---

## Endpoint 2: POST /api/v1/auth/claim-anonymous

**Purpose:** Migrate anonymous device usage to an authenticated user account after signup.

**Auth:** JWT required

### Request

```http
POST /api/v1/auth/claim-anonymous HTTP/1.1
Authorization: Bearer eyJhbGc...
Content-Type: application/json
```

**Body:**
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Response 200 — Successfully claimed

```json
{
  "claimed": true,
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "messages_migrated": 3,
  "claimed_at": "2026-04-11T10:23:45Z"
}
```

### Response 200 — Device not found (already claimed or never used)

```json
{
  "claimed": false,
  "reason": "device_not_found_or_already_claimed"
}
```

**Note:** This is not an error. The Flutter app can call this on every login without checking state — the backend handles gracefully.

### Response 409 — Device claimed by different user

```json
{
  "detail": "Device already claimed by another account"
}
```

**This prevents:** User A uses device anonymously → friend borrows phone → friend signs in as User B → User B tries to claim User A's device usage.

---

## Rate Limiting

### IP-level (SlowAPI)
- `/coach/chat/anonymous`: **15 requests per hour per IP**
- Applies to ALL anonymous endpoints
- Returns 429 with Retry-After header

### Device-level (database logic)
- **3 messages per device_id LIFETIME** (not per day, per lifetime)
- Enforced by querying `anonymous_coach_usage.message_count`
- At count = 3, returns success + `requires_auth: true`
- At count >= 4, returns 403

---

## Backward Compatibility

- Existing `/api/v1/coach/chat` (authenticated) is **unchanged**
- Existing `/api/v1/rag/query` is **unchanged**
- Flutter orchestrator adds new branch in `generateChat()`, doesn't modify existing paths
- SLM + BYOK + authenticated server-key paths are untouched

---

## Security Notes

1. **No PII stored.** Device_id is a pseudo-random UUID, not linked to identity.
2. **IP is hashed before storage** (SHA-256, first 16 chars) for abuse tracking without privacy leak.
3. **Messages are NOT persisted** in anonymous state (v1). The database stores only the counter.
4. **Bearer JWT** never leaks to the anonymous endpoint (different route, different middleware).
5. **CORS**: same policy as existing public endpoints (mobile app origins only).

---

## Monitoring

Add these metrics:
- `anonymous_coach_requests_total` (counter, by status_code)
- `anonymous_coach_users_unique_daily` (gauge, count of distinct device_ids/day)
- `anonymous_coach_converted_to_signup` (counter, device_ids that called /claim)
- `anonymous_coach_abandoned_at_paywall` (counter, hit 403 then never claimed)

Conversion rate = `converted / unique_daily`

Target: >10% conversion at message 3.

---

## Example cURL Sequences

### Happy path (3 messages then signup)

```bash
DEVICE=$(uuidgen)
URL=https://mint-staging.up.railway.app/api/v1

# Message 1
curl -X POST $URL/coach/chat/anonymous \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" \
  -d '{"message":"Hello Mint","language":"fr","cash_level":3}'

# Message 2
curl -X POST $URL/coach/chat/anonymous \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" \
  -d '{"message":"Comment optimiser mon 3e pilier ?","language":"fr","cash_level":3}'

# Message 3 (soft paywall returned alongside answer)
curl -X POST $URL/coach/chat/anonymous \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" \
  -d '{"message":"Je gagne 80k, je cotise combien ?","language":"fr","cash_level":3}'

# Message 4 (hard paywall, 403)
curl -X POST $URL/coach/chat/anonymous \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" \
  -d '{"message":"Une autre question","language":"fr","cash_level":3}'
# → 403

# User signs up via Apple Sign-In → gets JWT
JWT="eyJhbGc..."

# Claim anonymous device
curl -X POST $URL/auth/claim-anonymous \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"device_id\":\"$DEVICE\"}"
# → {"claimed":true,"messages_migrated":3}

# Now message 5 works via /coach/chat (authenticated)
curl -X POST $URL/coach/chat \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"message":"Merci","language":"fr","cash_level":3}'
# → 200 OK, authenticated response
```
