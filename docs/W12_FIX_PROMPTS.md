# Wave 12 — Fix Prompts (8 agents)

> Ce document contient les 8 prompts chirurgicaux pour fermer TOUS les findings de la Wave 12.
> Chaque prompt est autonome et peut être lancé indépendamment via un agent.
>
> **Vague 1 (parallèle)** : Prompts 1, 2, 3, 4 (fichiers indépendants)
> **Vague 2 (après merge vague 1)** : Prompts 5, 6, 7, 8
>
> **Convention** : chaque prompt crée sa propre feature branch depuis `dev`.

---

## PROMPT 1 — Backend entitlement enforcement (2 P0, 1 P1)

```
You are a senior Python/FastAPI engineer fixing EXACTLY these entitlement enforcement bugs. Fix ONLY what's listed. Do NOT refactor.

## CONTEXT
- Create branch: `feature/S62-w12-entitlements`
- Run `pytest tests/ -q` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: /coach/chat endpoint missing entitlement check (P0)
**File:** `services/backend/app/api/v1/endpoints/coach_chat.py`
**Bug:** The `/chat` POST endpoint only checks authentication (require_current_user), NOT subscription tier. Free users can call the LLM directly via curl.
**Action:**
1. Import the entitlement helper:
   ```python
   from app.services.billing_service import get_entitlement_snapshot
   ```
2. After the `_user` dependency, add entitlement check at the TOP of the function body:
   ```python
   snapshot = get_entitlement_snapshot(db, str(_user.id))
   if "coachLlm" not in snapshot.get("features", []):
       raise HTTPException(
           status_code=status.HTTP_403_FORBIDDEN,
           detail="Un abonnement Premium est requis pour le coaching IA.",
       )
   ```
3. If `get_entitlement_snapshot` doesn't exist, use:
   ```python
   from app.services.billing_service import recompute_entitlements
   effective_tier, active_features = recompute_entitlements(db, str(_user.id))
   if "coachLlm" not in active_features:
       raise HTTPException(403, "Un abonnement Premium est requis pour le coaching IA.")
   ```

### FIX 2: /documents/upload endpoint missing entitlement check (P0)
**File:** `services/backend/app/api/v1/endpoints/documents.py`
**Bug:** Upload endpoint has no subscription check. Free users can upload unlimited documents.
**Action:**
1. Add entitlement check at the top of `upload_document()`:
   ```python
   effective_tier, active_features = recompute_entitlements(db, str(_user.id))
   if "vault" not in active_features:
       # Free users: enforce 2-document limit
       doc_count = db.query(DocumentModel).filter(
           DocumentModel.user_id == str(_user.id)
       ).count()
       if doc_count >= 2:
           raise HTTPException(
               status_code=status.HTTP_403_FORBIDDEN,
               detail="Limite de 2 documents atteinte. Passe à Premium pour plus.",
           )
   ```
2. Import `recompute_entitlements` from billing_service

### FIX 3: INTERNAL_ACCESS_ENABLED production guard (P1)
**File:** `services/backend/app/core/config.py`
**Bug:** If INTERNAL_ACCESS_ENABLED is accidentally True in production, ALL users get premium.
**Action:** Add a startup guard after settings are loaded:
```python
# At the end of config.py, after Settings class:
if (
    os.getenv("ENVIRONMENT", "development") == "production"
    and settings.INTERNAL_ACCESS_ENABLED
    and settings.INTERNAL_ACCESS_ALLOWLIST.strip() == "*"
):
    raise RuntimeError(
        "CRITICAL: INTERNAL_ACCESS_ENABLED=true with wildcard allowlist in production. "
        "This grants ALL users premium access. Set INTERNAL_ACCESS_ALLOWLIST to specific emails."
    )
```

### VALIDATION
1. `pytest tests/ -q` — all pass
2. Test manually: curl POST /coach/chat with free user token → expect 403
3. `git commit`: "fix(entitlements): W12 — backend enforcement on /coach/chat + /documents/upload"
```

---

## PROMPT 2 — Regex & ReDoS fixes (2 P1, 5 P2)

```
You are a senior Flutter/Dart + Python engineer fixing EXACTLY these regex vulnerabilities. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w12-regex`
- Run `flutter analyze` + `flutter test` + `pytest tests/ -q` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: ReDoS in compliance_guard.dart (P1 — CRITICAL)
**File:** `apps/mobile/lib/services/coach/compliance_guard.dart`
**Bug:** Line ~161: `r'sans\s+(?:\w+\s+)*risque'` has nested quantifier `(?:\w+\s+)*` causing catastrophic backtracking.
**Action:** Limit the repetition:
```dart
// BEFORE (ReDoS vulnerable):
static final _sansRisquePattern = RegExp(r'sans\s+(?:\w+\s+)*risque', caseSensitive: false);
// AFTER (bounded):
static final _sansRisquePattern = RegExp(r'sans\s+(?:\w+\s+){0,10}risque', caseSensitive: false);
```

### FIX 2: Homoglyph bypass on banned terms (P1)
**File:** `apps/mobile/lib/services/coach/compliance_guard.dart`
**Bug:** Banned terms can be bypassed using Greek/Cyrillic lookalike characters (e.g., Greek omicron ο instead of Latin o in "optimal").
**Action:** Add a homoglyph normalization step BEFORE banned term matching. In the `_sanitizeBannedTerms()` method, before the regex loop:
```dart
static String _sanitizeBannedTerms(String text) {
  // FIX-W12: Normalize common homoglyphs before banned term matching
  var normalized = text
      .replaceAll('ο', 'o')  // Greek omicron → Latin o
      .replaceAll('а', 'a')  // Cyrillic a → Latin a
      .replaceAll('е', 'e')  // Cyrillic e → Latin e
      .replaceAll('і', 'i')  // Cyrillic i → Latin i
      .replaceAll('р', 'p')  // Cyrillic r → Latin p
      .replaceAll('с', 'c')  // Cyrillic s → Latin c
      .replaceAll('ⅼ', 'l')  // Roman numeral l → Latin l
      .replaceAll('ⅿ', 'm'); // Roman numeral m → Latin m
  // Continue with existing banned term replacement on normalized text
  for (final entry in _bannedTermPatterns.entries) {
    normalized = normalized.replaceAll(entry.value, entry.key.contains(' ') ? '***' : '***');
  }
  return normalized;
}
```

### FIX 3: Add missing AHV/AVS number pattern (P2)
**Files:**
- `apps/mobile/lib/services/coach/conversation_store.dart`
- `services/backend/app/api/v1/endpoints/coach_chat.py`
**Bug:** Swiss AHV numbers (756.xxxx.xxxx.xx) are NOT scrubbed from PII.
**Action:** Add pattern to BOTH files:
```dart
// Flutter (conversation_store.dart) — add to scrubPii() patterns list:
RegExp(r'\b756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2}\b'),
```
```python
# Python (coach_chat.py) — add to _PII_PATTERNS list:
re.compile(r"\b756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2}\b"),
```

### FIX 4: dateOfBirth regex not anchored at end (P2)
**File:** `services/backend/app/schemas/profile.py`
**Bug:** Pattern `r"^\d{4}-\d{2}-\d{2}"` missing `$` anchor — accepts trailing garbage.
**Action:** Change to: `r"^\d{4}-\d{2}-\d{2}$"`

### FIX 5: Swiss phone number pattern too loose (P2)
**Files:** Both conversation_store.dart and coach_chat.py
**Action:** Replace current loose pattern with stricter Swiss format:
```dart
// Flutter:
RegExp(r'(?:\+41|0)[\s.-]?(?:76|77|78|79|[1-4]\d)[\s.-]?\d{3}[\s.-]?\d{2}[\s.-]?\d{2}'),
```
```python
# Python:
re.compile(r"(?:\+41|0)[\s.\-]?(?:76|77|78|79|[1-4]\d)[\s.\-]?\d{3}[\s.\-]?\d{2}[\s.\-]?\d{2}"),
```

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — all pass
3. `pytest tests/ -q` — all pass
4. Test ReDoS: `"sans " + "word " * 1000 + "notrisque"` must complete in <100ms
5. `git commit`: "fix(regex): W12 — ReDoS bounded, homoglyph normalization, AHV+phone patterns"
```

---

## PROMPT 3 — Database performance (3 P0, 4 P1)

```
You are a senior Python/FastAPI engineer fixing EXACTLY these database performance bugs. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w12-db-perf`
- Run `pytest tests/ -q` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Privacy export unbounded queries (P0)
**File:** `services/backend/app/api/v1/endpoints/privacy.py`
**Bug:** Lines 80, 109, 124, 139, 148 — all use `.all()` without LIMIT. OOM risk with 100K+ events.
**Action:** Add pagination with reasonable limits:
```python
# For analytics events (highest volume):
MAX_EXPORT_ROWS = 10000
events = db.query(AnalyticsEvent).filter(
    AnalyticsEvent.user_id == user_id
).order_by(AnalyticsEvent.timestamp.desc()).limit(MAX_EXPORT_ROWS).all()

# For other tables (lower volume, 1000 is sufficient):
profiles = db.query(ProfileModel).filter(ProfileModel.user_id == user_id).limit(1000).all()
docs = db.query(DocumentModel).filter(DocumentModel.user_id == user_id).limit(1000).all()
snapshots = db.query(SnapshotModel).filter(SnapshotModel.user_id == user_id).limit(1000).all()
consents = db.query(ConsentModel).filter(ConsentModel.user_id == user_id).limit(100).all()
```

### FIX 2: Account deletion sequential — add explicit transaction (P0)
**File:** `services/backend/app/api/v1/endpoints/auth.py`
**Bug:** Lines 1000-1112 — 16+ DELETE operations without explicit transaction boundary.
**Action:** Wrap all deletions in a single try/except with explicit rollback:
```python
try:
    # All existing DELETE operations stay the same
    # ...
    db.commit()
except Exception as e:
    db.rollback()
    logger.error("Account deletion failed for user %s: %s", user_id, e)
    raise HTTPException(500, "Account deletion failed. Please try again or contact support.")
```

### FIX 3: Missing index on audit_event.created_at (P1)
**File:** `services/backend/app/models/audit_event.py`
**Bug:** `created_at` column has no index — full table scans on date queries.
**Action:** Add `index=True`:
```python
created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
```

### FIX 4: Missing compound index on analytics (user_id, timestamp) (P1)
**File:** `services/backend/app/models/analytics_event.py`
**Action:** Add compound index:
```python
__table_args__ = (
    Index("ix_analytics_user_timestamp", "user_id", "timestamp"),
)
```

### FIX 5: ScenarioModel FK references wrong table (P1)
**File:** `services/backend/app/models/scenario.py`
**Bug:** `profile_id` has `ForeignKey("users.id")` — should be `ForeignKey("profiles.id")`.
**Action:** Change to:
```python
profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
```
NOTE: This may require a new Alembic migration. Create one if needed:
```bash
cd services/backend && alembic revision --autogenerate -m "fix_scenario_fk_profiles"
```

### FIX 6: Household dissolution N+1 entitlement recompute (P1)
**File:** `services/backend/app/services/household_service.py`
**Bug:** Lines 481-496 — recompute_entitlements() called per member in a loop.
**Action:** Collect all user_ids first, then batch recompute:
```python
# Collect member user_ids to recompute
user_ids_to_recompute = []
for member in non_owner_members:
    if member.status in ("active", "pending"):
        member.status = "revoked"
        revoked_count += 1
        user_ids_to_recompute.append(member.user_id)

db.flush()  # Persist status changes first

# Batch recompute after all status changes
for uid in user_ids_to_recompute:
    recompute_entitlements(db, uid)
```

### FIX 7: Analytics GROUP BY without limit (P0)
**File:** `services/backend/app/api/v1/endpoints/analytics.py`
**Bug:** Lines 143-162 — GROUP BY returns unbounded results.
**Action:** Add `.limit(100)` to both GROUP BY queries:
```python
category_counts = db.query(...).group_by(...).limit(100).all()
screen_counts = db.query(...).group_by(...).limit(100).all()
```

### VALIDATION
1. `pytest tests/ -q` — all pass
2. `git commit`: "fix(db-perf): W12 — pagination, transaction safety, indexes, FK fix, N+1"
```

---

## PROMPT 4 — Context window & cost control (5 P1)

```
You are a senior Python + Flutter engineer fixing EXACTLY these context window management bugs. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w12-context-window`
- Run `flutter analyze` + `flutter test` + `pytest tests/ -q` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Agent loop hard stop without graceful degradation (P1)
**File:** `services/backend/app/api/v1/endpoints/coach_chat.py`
**Bug:** Lines 834-840 — when token budget (8000) is exceeded, loop breaks abruptly.
**Action:** Add graceful degradation message:
```python
if iteration > 0 and total_tokens >= MAX_AGENT_LOOP_TOKENS:
    logger.warning(
        "Agent loop token budget exhausted (%d/%d) at iteration %d for user %s",
        total_tokens, MAX_AGENT_LOOP_TOKENS, iteration, user_id,
    )
    # Append a completion note to the last answer
    if answer_text:
        answer_text += "\n\n_Note : certaines informations n'ont pas pu être chargées. Repose ta question pour plus de détails._"
    break
```

### FIX 2: Per-request token budget (P1)
**File:** `services/backend/app/api/v1/endpoints/coach_chat.py`
**Bug:** No per-request token limit. A 10-message conversation could use unlimited tokens.
**Action:** Add a per-request guard at the TOP of the coach_chat function:
```python
MAX_REQUEST_TOKENS = 4000  # Per-request budget

# Track tokens used in this request
request_tokens_used = 0

# In the agent loop, after each LLM call, accumulate:
request_tokens_used += result.get("tokens_used", 0)
if request_tokens_used >= MAX_REQUEST_TOKENS:
    logger.warning("Per-request token budget exceeded: %d", request_tokens_used)
    break
```

### FIX 3: Tool results summarization (P1)
**File:** `services/backend/app/api/v1/endpoints/coach_chat.py`
**Bug:** Lines 854-870 — tool results accumulate as raw text. After 3 iterations = 1500+ tokens.
**Action:** Truncate each tool result to 500 chars max:
```python
for call in internal_calls:
    result_text = _execute_internal_tool(call, memory_block, profile_context)
    # FIX-W12: Truncate tool results to prevent context explosion
    if len(result_text) > 500:
        result_text = result_text[:500] + "... [tronqué]"
    # Existing injection pattern sanitization
    for pattern in _INJECTION_PATTERNS:
        result_text = pattern.sub("[FILTERED]", result_text)
    tool_results.append(f"[{call.get('name', 'unknown')}] {result_text}")
```

### FIX 4: Cross-session insights cap (P1)
**File:** `apps/mobile/lib/services/coach/context_injector_service.dart`
**Bug:** Cross-session memory block from CoachMemoryService can grow unboundedly.
**Action:** Find where insights are injected into the memory block and add a cap:
```dart
// FIX-W12: Cap cross-session insights to prevent context overflow
final insights = await CoachMemoryService.getRecentInsights();
final cappedInsights = insights.take(10).toList(); // Max 10 insights in context
```

### FIX 5: System prompt size warning (P1)
**File:** `apps/mobile/lib/services/coach/coach_orchestrator.dart`
**Bug:** System prompt consumes up to 59% of 2048-token SLM context with no warning.
**Action:** Add a check before sending to SLM:
```dart
// FIX-W12: Warn if system prompt exceeds 40% of context
final systemPromptChars = systemPrompt.length;
final maxSystemChars = (_maxPromptChars * 0.4).floor();
if (systemPromptChars > maxSystemChars) {
  debugPrint('[Coach] WARNING: System prompt $systemPromptChars chars exceeds 40% budget ($maxSystemChars). Truncating memory block.');
  // Truncate memory block (keep base prompt, trim dynamic context)
}
```

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — all pass
3. `pytest tests/ -q` — all pass
4. `git commit`: "fix(context-window): W12 — token budget, tool truncation, insights cap, graceful degradation"
```

---

## PROMPT 5 — File upload security (4 P1, 1 P2)

```
You are a senior Python + Flutter engineer fixing EXACTLY these file upload security bugs. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w12-upload-security`
- Run `pytest tests/ -q` + `flutter analyze` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Add PDF magic bytes validation (P1)
**File:** `services/backend/app/api/v1/endpoints/documents.py`
**Bug:** Only checks MIME type header (spoofable) and file extension. No binary signature validation.
**Action:** After the existing MIME/extension checks, add magic bytes validation:
```python
# FIX-W12: Validate PDF magic bytes (first 5 bytes must be %PDF-)
content = await file.read()
await file.seek(0)  # Reset for downstream processing
if not content[:5] == b"%PDF-":
    raise HTTPException(
        status_code=400,
        detail="File is not a valid PDF (invalid magic bytes).",
    )
```

### FIX 2: Reject application/octet-stream MIME type (P1)
**File:** `services/backend/app/api/v1/endpoints/documents.py`
**Bug:** `application/octet-stream` is accepted alongside `application/pdf`. This is too permissive.
**Action:** Remove `application/octet-stream` from accepted types:
```python
if file.content_type and file.content_type != "application/pdf":
    raise HTTPException(400, "Only PDF files are accepted (Content-Type: application/pdf).")
```

### FIX 3: Strip EXIF metadata from images before Vision API (P2)
**File:** `apps/mobile/lib/screens/document_scan/document_scan_screen.dart`
**Bug:** Images sent to Claude Vision API contain EXIF metadata (GPS, camera info).
**Action:** Before base64-encoding the image for Vision, strip EXIF:
```dart
// FIX-W12: Strip EXIF metadata before sending to Vision API
import 'package:image/image.dart' as img;
// After reading bytes:
final decoded = img.decodeImage(bytes);
if (decoded != null) {
  // Re-encode without EXIF (PNG has no EXIF)
  bytes = Uint8List.fromList(img.encodePng(decoded));
}
```
Note: If the `image` package is not already a dependency, add a TODO comment instead:
```dart
// TODO(P2-W12): Strip EXIF metadata before Vision API call.
// Requires `image` package. GPS location and camera info currently exposed.
```

### FIX 4: Add per-user document storage quota (P1)
**File:** `services/backend/app/api/v1/endpoints/documents.py`
**Bug:** No total storage quota per user. A user could upload hundreds of 20MB PDFs.
**Action:** Add a total document count limit (not just free tier):
```python
# FIX-W12: Enforce per-user document limit (all tiers)
MAX_DOCUMENTS_PER_USER = 100
total_docs = db.query(DocumentModel).filter(
    DocumentModel.user_id == str(_user.id)
).count()
if total_docs >= MAX_DOCUMENTS_PER_USER:
    raise HTTPException(400, f"Limite de {MAX_DOCUMENTS_PER_USER} documents atteinte.")
```

### FIX 5: Document DB encryption note (P1)
**Action:** This requires infrastructure change (SQLite → encrypted PostgreSQL). Add TODO:
```python
# TODO(P0-INFRA): Database is currently unencrypted SQLite.
# PII (salary, pension data) stored in plaintext JSON columns.
# Migration to encrypted PostgreSQL required before production launch.
# See: services/backend/app/core/database.py
```
Add this comment at the top of `services/backend/app/models/document.py`.

### VALIDATION
1. `pytest tests/ -q` — all pass
2. `flutter analyze` — 0 errors
3. Test: upload a .txt file renamed to .pdf → expect 400 (magic bytes fail)
4. `git commit`: "fix(upload-security): W12 — magic bytes, MIME strict, quota, EXIF note"
```

---

## PROMPT 6 — Feature flags consistency (2 P1, 3 P2)

```
You are a senior Python + Flutter engineer fixing EXACTLY these feature flag consistency bugs. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w12-feature-flags`
- Run `flutter analyze` + `pytest tests/ -q` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Sync 4 missing feature flags from backend to frontend (P1)
**File:** `services/backend/app/api/v1/endpoints/config.py`
**Bug:** Backend config endpoint only returns 5 flags. Frontend expects 9. Missing: enableOpenBanking, enablePensionFundConnect, enableExpertTier, enableAdminScreens.
**Action:** Add the 4 missing flags to the config endpoint response:
```python
# In the config endpoint, add to the response dict:
"enableOpenBanking": os.getenv("FF_ENABLE_BLINK_PRODUCTION", "false").lower() in ("1", "true"),
"enablePensionFundConnect": os.getenv("FF_ENABLE_CAISSE_PENSION_API", "false").lower() in ("1", "true"),
"enableExpertTier": os.getenv("FF_ENABLE_EXPERT_TIER", "false").lower() in ("1", "true"),
"enableAdminScreens": os.getenv("FF_ENABLE_ADMIN_SCREENS", "false").lower() in ("1", "true"),
```

### FIX 2: Hide admin buttons when flag is false (P2)
**File:** `apps/mobile/lib/screens/profile_screen.dart`
**Bug:** Admin buttons are always visible even when `enableAdminScreens` is false.
**Action:** Find the admin buttons (lines ~752-773) and wrap with feature flag check:
```dart
if (FeatureFlags.enableAdminScreens) ...[
  // existing admin observability button
  // existing beta tester analytics button
],
```

### FIX 3: Document FF_ environment variables (P2)
**File:** `services/backend/.env.example` (create if not exists)
**Action:** Add all feature flags with documentation:
```env
# Feature Flags (all default to false)
FF_ENABLE_COUPLE_PLUS_TIER=false
FF_ENABLE_SLM_NARRATIVES=false
FF_ENABLE_DECISION_SCAFFOLD=false
FF_VALEUR_LOCATIVE_2028_REFORM=false
FF_SAFE_MODE_DEGRADED=false
FF_ENABLE_BLINK_PRODUCTION=false
FF_ENABLE_CAISSE_PENSION_API=false
FF_ENABLE_EXPERT_TIER=false
FF_ENABLE_ADMIN_SCREENS=false
FF_ENABLE_AVS_INSTITUTIONAL=false
INTERNAL_ACCESS_ENABLED=false
INTERNAL_ACCESS_ALLOWLIST=
```

### VALIDATION
1. `flutter analyze` — 0 errors
2. `pytest tests/ -q` — all pass
3. `git commit`: "fix(feature-flags): W12 — sync 4 missing flags, hide admin buttons, document env vars"
```

---

## PROMPT 7 — Error UX consistency (1 P0, 14 P1)

```
You are a senior Flutter/Dart engineer fixing EXACTLY these error message bugs. Fix ONLY what's listed. Prioritize P0 and P1 only.

## CONTEXT
- Create branch: `feature/S62-w12-error-ux`
- Run `flutter analyze` + `flutter test` + `flutter gen-l10n` BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Hardcoded French error in institutional API (P0)
**File:** `apps/mobile/lib/services/institutional/institutional_api_service.dart`
**Bug:** Line ~240: hardcoded `'Erreur réseau : impossible de joindre le serveur'`.
**Action:** Replace with localized key. If `apiErrorOffline` exists in ARB, use it:
```dart
throw ApiException.offline();
```
If in a context without `BuildContext`, throw ApiException with error code and let the caller localize.

### FIX 2: Raw Exception in api_service.dart (P1 — 5 instances)
**File:** `apps/mobile/lib/services/api_service.dart`
**Bug:** Lines ~320, 353, 382, 454, 1174 — throw `Exception('POST/PUT/DELETE $endpoint failed: ${response.body}')` with raw backend response body.
**Action:** Replace ALL 5 instances with ApiException:
```dart
// BEFORE:
throw Exception('POST $endpoint failed: ${response.body}');
// AFTER:
throw ApiException(
  _extractErrorDetail(response.body, fallback: 'Request failed'),
  statusCode: response.statusCode,
);
```

### FIX 3: Household service hardcoded errors (P1 — 4 instances)
**File:** `apps/mobile/lib/services/household_service.dart`
**Bug:** Lines ~60, 86, 108, 134 — throw `Exception('Erreur invitation/acceptation/revocation/transfert')`.
**Action:** Replace each with ApiException that wraps the backend detail:
```dart
// BEFORE:
throw Exception('Erreur invitation');
// AFTER:
throw ApiException(
  _extractErrorDetail(response.body, fallback: 'Invitation failed'),
  statusCode: response.statusCode,
);
```
Where `_extractErrorDetail` is the same helper from api_service.dart. If not accessible, extract the detail inline:
```dart
final detail = jsonDecode(response.body)['detail'] ?? 'Operation failed';
throw ApiException(detail, statusCode: response.statusCode);
```

### FIX 4: RAG service hardcoded French errors (P1 — 2 instances)
**File:** `apps/mobile/lib/services/rag_service.dart`
**Bug:** Lines ~258, 341 — `'Erreur serveur (${response.statusCode}).'` with raw status code.
**Action:** Replace with generic localized error:
```dart
throw RagApiException(
  code: response.statusCode,
  message: 'Service temporarily unavailable',
);
```

### FIX 5: SLM download hardcoded French (P1 — 4 instances)
**File:** `apps/mobile/lib/services/slm/slm_download_service.dart`
**Bug:** Lines ~480, 483, 486, 488 — hardcoded French error messages.
**Action:** Add i18n keys to all 6 ARB files:
- `slmDownloadErrorNetwork`: "Erreur réseau pendant le téléchargement. Vérifie le Wi-Fi." / "Network error during download. Check your Wi-Fi." / etc.
- `slmDownloadErrorStorage`: "Espace de stockage insuffisant." / etc.
- `slmDownloadErrorGeneric`: "Erreur de téléchargement du modèle." / etc.
Then use `S.of(context)!.slmDownloadErrorNetwork` etc. If no context available, use the French string as fallback with TODO.

### FIX 6: Document scan exposing exception details (P1)
**File:** `apps/mobile/lib/screens/document_scan/document_scan_screen.dart`
**Bug:** Line ~1098 — passes raw `e.toString()` to user-facing snackbar.
**Action:** Replace with generic message:
```dart
// BEFORE:
_showErrorSnack(S.of(context)!.docScanBackendParsingError(e.toString()));
// AFTER:
_showErrorSnack(S.of(context)!.docScanBackendParsingError(''));
```
Or better: use a generic key without the exception parameter.

### VALIDATION
1. `flutter gen-l10n` — 0 errors (if new ARB keys added)
2. `flutter analyze` — 0 errors
3. `flutter test` — all pass
4. `git commit`: "fix(error-ux): W12 — localize errors, hide technical details, ApiException consistency"
```

---

## PROMPT 8 — Golden couple documentation + minor fixes (3 P2)

```
You are a senior engineer updating documentation and fixing minor discrepancies. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w12-golden-couple`

## FIXES REQUIRED

### FIX 1: CLAUDE.md replacement rate methodology note (P2)
**File:** `CLAUDE.md`
**Bug:** §8 says "Taux remplacement 65.5%" but code calculates 44.8%. Different baseline assumptions.
**Action:** Add a note after the replacement rate line:
```markdown
| Taux remplacement | **65.5%** (~8'505 vs 12'978 net/mois) |
> Note : le taux de 65.5% utilise le revenu net combiné du couple (Julien + Lauren).
> Le code peut produire un résultat différent selon la projection LPP utilisée
> (formule légale standard vs certificat CPE Plan Maxi).
```

### FIX 2: Privacy Policy — add Google Fonts disclosure (P2)
**File:** `legal/PRIVACY.md`
**Bug:** Google Fonts CDN not listed as data processor (sends IP to Google).
**Action:** In the processors section (section 4 or 7.3), add:
```markdown
**Google Fonts** (Google LLC, États-Unis)
- Données : adresse IP (lors du téléchargement initial des polices)
- Durée : ponctuel (polices mises en cache localement)
- Base légale : intérêt légitime (affichage typographique)
```

### FIX 3: Privacy Policy — add planned Swiss hosting mention (P2)
**File:** `legal/PRIVACY.md`
**Bug:** Cross-border section mentions Railway US + SCC but not planned Swiss hosting.
**Action:** Find the cross-border transfer section and add:
```markdown
En Phase 2, nous prévoyons un hébergement en Suisse pour les données utilisateurs.
```

### VALIDATION
1. Read updated files to verify coherence
2. `git commit`: "docs(golden-couple+privacy): W12 — methodology note, Google Fonts, Swiss hosting"
```

---

## CHECKLIST DE LANCEMENT

| # | Prompt | Branch | Fichiers principaux | Parallélisable avec |
|---|--------|--------|---------------------|---------------------|
| 1 | Entitlements | `feature/S62-w12-entitlements` | coach_chat.py, documents.py, config.py | 2, 3, 4 |
| 2 | Regex | `feature/S62-w12-regex` | compliance_guard.dart, conversation_store.dart, coach_chat.py, profile.py | 1, 3, 4 |
| 3 | DB performance | `feature/S62-w12-db-perf` | privacy.py, auth.py, models/*.py, analytics.py, household_service.py | 1, 2, 4 |
| 4 | Context window | `feature/S62-w12-context-window` | coach_chat.py, context_injector_service.dart, coach_orchestrator.dart | 1, 2, 3 |
| 5 | Upload security | `feature/S62-w12-upload-security` | documents.py, document_scan_screen.dart, document.py | 6, 7, 8 |
| 6 | Feature flags | `feature/S62-w12-feature-flags` | config.py, profile_screen.dart, .env.example | 5, 7, 8 |
| 7 | Error UX | `feature/S62-w12-error-ux` | api_service.dart, household_service.dart, rag_service.dart, ARB files | 5, 6, 8 |
| 8 | Golden couple docs | `feature/S62-w12-golden-couple` | CLAUDE.md, PRIVACY.md | 5, 6, 7 |

**ATTENTION conflits potentiels :**
- Prompts 1 et 4 touchent TOUS LES DEUX `coach_chat.py` — merger 1 d'abord, puis 4
- Prompts 2 et 4 touchent `coach_chat.py` (PII patterns vs tool truncation) — sections différentes, pas de conflit
- Prompts 1 et 5 touchent `documents.py` — merger 1 d'abord, puis 5
- Prompts 1 et 3 touchent `auth.py` (entitlement) et `privacy.py` (pagination) — sections différentes

**Vague 1** : Prompts 2, 3, 6, 8 (pas de conflit)
**Vague 2** : Prompts 1, 4 (coach_chat.py), puis 5, 7 (documents.py, ARB)
