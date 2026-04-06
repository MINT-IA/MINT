# Stack Research

**Domain:** Swiss fintech mobile app — v2.0 new feature additions
**Researched:** 2026-04-06
**Confidence:** HIGH (based on existing codebase audit + known library capabilities)

---

## What This Document Covers

Five new capability areas for v2.0:
1. Document Intelligence (photo/PDF ingestion + LLM extraction)
2. Anticipation Engine (rule-based proactive alerts, fiscal calendar)
3. Financial Biography (encrypted local-only narrative memory)
4. bLink Open Banking (OAuth 2.0, SFTI sandbox integration)
5. Contextual Aujourd'hui (smart card ranking)

**Existing stack already present — do not re-add:**
`flutter`, `fastapi`, `pydantic v2`, `anthropic`, `image_picker ^1.1.2`, `google_mlkit_text_recognition ^0.15.0`, `file_picker ^8.0.0`, `flutter_secure_storage ^9.0.0`, `shared_preferences ^2.3.2`, `flutter_local_notifications ^18.0.1`, `pdfplumber` (in `[docling]` extras), `sqlalchemy`, `alembic`, `pyjwt`

---

## Feature 1: Document Intelligence

### What Already Exists

The codebase already has a **functioning 3-layer document pipeline**:

- **On-device OCR**: `google_mlkit_text_recognition ^0.15.0` — handles LPP certificates, salary slips in French and German. Pure-Dart parsers (regex) for field extraction.
- **Claude Vision backend**: `document_vision_service.py` uses `anthropic` SDK (already installed) for image-to-JSON extraction. Handles 8 document types including `lpp_plan`, `lease_contract`, `insurance_contract`.
- **PDF text extraction**: `pdfplumber` in `[docling]` optional extras for server-side PDF parsing.
- **Upload screens**: `document_scan_screen.dart`, `document_impact_screen.dart` exist.
- **Models**: `DocumentType`, `ExtractedField`, `ExtractionResult` defined in both Flutter and FastAPI.

### What Is Missing

#### Flutter side

**`flutter_image_compress`** — needed for photo pre-processing before Claude Vision upload. Raw camera images from `image_picker` are 3-8 MB. Claude Vision accepts max ~5 MB per image (base64). Compression to JPEG 85% quality reduces to ~400-800 KB without losing OCR accuracy.

**No new camera library needed.** `image_picker ^1.1.2` already handles both camera and gallery. The `initialImageFromCamera` source parameter covers the "balance-moi le print screen" use case natively.

#### Backend side

**`python-multipart`** is already present for file upload. No new dependency.

**`pillow>=10.4.0,<12.0.0`** — needed server-side for image pre-processing (rotation correction, EXIF normalization, grey-scale for low-contrast Swiss documents). Claude Vision does not auto-correct orientation from EXIF metadata — a rotated LPP certificate photograph will produce garbage extraction.

**`pdf2image>=1.17.0,<2.0.0`** + system dependency `poppler` — needed for scanned PDF handling (PDFs that are images, not text-layer). `pdfplumber` extracts text from text-layer PDFs only. A scanned LPP certificate saved as PDF is invisible to `pdfplumber`. `pdf2image` converts each page to a PIL image that can then go through the Claude Vision path.

**Do NOT add** `pypdf`, `PyMuPDF (fitz)`, or `camelot` — they duplicate `pdfplumber` functionality that is already wired. `pdf2image` covers the only gap (scanned PDFs).

### Recommended Additions

| Component | Addition | Version | Purpose |
|-----------|----------|---------|---------|
| Flutter | `flutter_image_compress` | `^2.3.0` | Compress camera photos to ~800 KB before upload |
| Backend | `pillow` | `>=10.4.0,<12.0.0` | Server-side image normalization (rotation, EXIF, grey-scale) |
| Backend | `pdf2image` | `>=1.17.0,<2.0.0` | Convert scanned PDFs to images for Claude Vision path |

### Integration Points

- Flutter `document_scan_screen.dart` calls `image_picker` -> compress with `flutter_image_compress` -> base64 encode -> POST to `/api/v1/document/vision`
- Backend endpoint receives base64 -> `pillow` normalizes -> Claude Vision extracts -> returns `VisionExtractionResponse` (already schema'd)
- `document_vision_service.py` already exists — it needs to be wired to a FastAPI endpoint (currently no HTTP route registered for it)
- On-device MLKit path remains as fallback when user has no API key (BYOK disabled) — privacy-first: no image leaves device in that mode

---

## Feature 2: Anticipation Engine

### What Already Exists

`proactive_trigger_service.dart` implements 8 trigger types (lifecycle change, weekly recap, goal milestone, seasonal reminder, inactivity, confidence improvement, new cap, contract deadline). This is the foundation — it fires when the Coach tab opens.

`flutter_local_notifications ^18.0.1` + `timezone ^0.10.1` are already present for scheduled notification delivery.

`shared_preferences ^2.3.2` stores trigger state (last fired date, stored phase, etc.).

### What Is Missing

The anticipation engine for v2.0 needs two capabilities not yet in the existing trigger service:

1. **Fiscal calendar** — hardcoded Swiss fiscal deadlines (3a deadline 31 Dec, tax declaration deadlines by canton, LPP rachat fiscal year end). These are **static data**, not a library. They belong in a new `assets/config/fiscal_calendar.json` file, not a new package.

2. **Scheduled background checks** — the existing triggers fire only when the user opens the Coach tab. The anticipation engine must also fire when the app is backgrounded (e.g. "3a deadline in 7 days" notification at 9 AM on 24 December). This requires `flutter_local_notifications` (already present) + scheduling logic.

**No new Dart packages are needed** for the anticipation engine. The entire engine is pure rule evaluation on `CoachProfile` fields against the fiscal calendar JSON. The `flutter_local_notifications` `zonedSchedule()` method (already available) handles the notification delivery.

**Do NOT add** `workmanager` or `background_fetch` — these are explicitly out of scope for v2.0 (see PROJECT.md: "Background processing / WorkManager for anticipation — v3.0"). The anticipation engine in v2.0 triggers on app-open only, plus scheduled notifications via `flutter_local_notifications`.

### Recommended Additions

| Component | Addition | Version | Purpose |
|-----------|----------|---------|---------|
| Flutter | none (code only) | — | Fiscal calendar as `assets/config/fiscal_calendar.json` |
| Backend | none (code only) | — | New `/api/v1/anticipation/evaluate` endpoint using pure Python rules |

### Integration Points

- New `AnticipationEngine` Dart class reads `fiscal_calendar.json` + `CoachProfile` -> emits `AnticipationAlert` list
- `ProactiveTriggerService` gains one new trigger type: `fiscalDeadlineApproaching` (joins existing 8)
- Backend endpoint is optional/future — the v2.0 engine is 100% client-side rule evaluation
- `flutter_local_notifications.zonedSchedule()` handles TZ-aware scheduling — no new package needed

---

## Feature 3: Financial Biography (Local Graph Memory)

### What Already Exists

`shared_preferences` stores flat key-value state. `flutter_secure_storage ^9.0.0` handles encrypted key storage. No structured event store exists yet.

### What Is Missing

The Financial Biography is a **local-only, encrypted, append-only structured store** of financial facts, decisions, and events. Requirements:

- Encrypted at rest (nLPD compliance)
- Structured queries ("what did the user decide about their LPP 6 months ago?")
- Append-only with timestamps (never delete, only supersede)
- Zero network egress (local-only constraint from PROJECT.md)
- `AnonymizedBiographySummary` subset passed to coach context (no PII)

**`sqflite ^2.4.1`** — SQLite for Flutter. The correct choice because:
- Append-only event table with indexed timestamps is a trivial SQL pattern
- `flutter_secure_storage` provides the encryption key; `encrypt` handles at-rest encryption
- Avoids Hive/Isar complexity and breaking changes

**`sqflite_common_ffi ^2.3.4`** — enables sqflite on desktop/test environments (macOS CI, web tests). Not required for iOS/Android production but prevents CI failures on the existing GitHub Actions `macos-15` runner.

**`encrypt ^5.0.3`** — pure Dart AES-256-GCM. Encrypts each row's payload before SQLite insertion. Decrypts on read. The AES key is stored in `flutter_secure_storage` (already present — no new secure storage needed).

**Do NOT use** `hive`, `hive_flutter`, `isar`, or `objectbox`:
- Hive v2 — encryption adapter (`hive_flutter`) has known null-safety issues, not maintained
- Isar 4 — major API break from v3; community still migrating as of early 2026
- ObjectBox — binary/commercial license, overkill for append-only event log
- Drift (moor) — valid alternative but requires `build_runner` code-gen; sqflite is simpler for this schema

**Do NOT add** `sqlcipher_flutter_libs` — requires CocoaPods changes and Android NDK changes that will break the existing Podfile.lock and CI pipeline.

### Recommended Additions

| Component | Addition | Version | Purpose |
|-----------|----------|---------|---------|
| Flutter | `sqflite` | `^2.4.1` | Local structured event store for FinancialBiography |
| Flutter | `sqflite_common_ffi` | `^2.3.4` | Desktop/test compatibility for CI |
| Flutter | `encrypt` | `^5.0.3` | AES-256-GCM application-layer encryption before insertion |

### Integration Points

- `FinancialBiographyStore` — new service, uses `sqflite` + `flutter_secure_storage` key + `encrypt`
- Schema: single `biography_events` table: `(id TEXT PK, event_type TEXT, payload_encrypted BLOB, created_at INTEGER, superseded_by TEXT)`
- `AnonymizedBiographySummary` — serializes recent events, strips PII fields, passes to `CoachContextBuilder` (already exists)
- `CoachContextBuilder` is the integration point for enriching LLM prompts — add a `biographySummary` field to it

---

## Feature 4: bLink Open Banking (OAuth 2.0 + SFTI Sandbox)

### What Already Exists

`blink_connector.py` exists with full mock data (UBS, PostFinance, Raiffeisen accounts + realistic transactions). The connector class signature (`get_accounts`, `get_transactions`, `get_balances`) is production-ready. It currently raises `NotImplementedError` for the production path.

`pyjwt ^2.8.0` is present for JWT handling.

`httpx` is present in `[dev]` extras for tests.

`consent_manager.dart` and `account_aggregator.py` exist and are the integration points.

### What Is Missing

For v2.0 sandbox activation (not production), two gaps exist:

1. **OAuth 2.0 PKCE flow in Flutter** — bLink uses OAuth 2.0 Authorization Code + PKCE. The mobile app must launch the bank's authorization URL in a system browser, receive the redirect with auth code, exchange for access token. `flutter_web_auth_2 ^4.0.1` is the correct package:
   - Launches the OAuth URL in a system browser (not WebView — SIX explicitly prohibits WebView for bLink consent screens)
   - Receives the redirect callback via custom URL scheme (`mintapp://oauth/callback`)
   - Uses iOS `ASWebAuthenticationSession`, Android Custom Tabs natively
   - Successor to deprecated `flutter_web_auth` (same maintainer, active)

2. **`httpx`** promoted from `[dev]` to production dependencies — needed for async HTTP calls to bLink API when the production path is activated (sandbox or production).

**Do NOT add** `authlib` — overkill for a single PKCE token exchange. `pyjwt` (existing) + `httpx` covers the full flow.
**Do NOT use** a WebView approach — bLink sandbox and production explicitly require system browser for consent.
**Do NOT add** `app_links` — it handles deep links but not the full OAuth URL launch + callback cycle.

### Recommended Additions

| Component | Addition | Version | Purpose |
|-----------|----------|---------|---------|
| Flutter | `flutter_web_auth_2` | `^4.0.1` | OAuth 2.0 PKCE flow in system browser |
| Backend | `httpx` (move from dev to prod) | `>=0.27.0,<1.0.0` | Async HTTP for bLink API calls |

### Platform Configuration Required (Not a Package)

**iOS `Info.plist`:**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>mintapp</string></array>
  </dict>
</array>
```

**Android `AndroidManifest.xml`** (add to existing `Runner` activity):
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="mintapp" android:host="oauth" />
</intent-filter>
```

### Integration Points

- New `BLinkOAuthService` in Flutter — calls `flutter_web_auth_2.authenticate()` with bLink sandbox URL, stores access token in `flutter_secure_storage` (already present)
- Backend `blink_connector.py` `get_accounts()` — replace `NotImplementedError` with `httpx.AsyncClient` call to `https://api.blink.six-group.com/v2/accounts` with Bearer token
- `consent_manager.dart` (already exists) — add bLink consent record type
- `account_aggregator.py` (already exists) — wires account data into profile enrichment pipeline

---

## Feature 5: Contextual Aujourd'hui (Smart Card Ranking)

### What Already Exists

`dashboard_curator_service.dart` exists for card selection. `lifecycle_detector.dart` and `lifecycle_phase.dart` define scoring signals. `CapMemoryStore` tracks recently served caps.

### What Is Missing

No new packages are required. The smart card ranking is pure business logic: score cards by relevance using a weighted sum of lifecycle phase, recent biography events, fiscal calendar proximity, profile completeness signals. All weights are constants — no ML.

**Do NOT add** any recommendation or ML library (`tflite`, `ml_kit`, `vertex_ai`) — the PROJECT.md explicitly specifies rule-based ranking. Max 5 cards per day, deterministic, auditable.

The only addition is a new `CardRankingEngine` Dart class that reads `CoachProfile` + `fiscal_calendar.json` + `CapMemoryStore` + `FinancialBiographyStore` and returns an ordered list of at most 5 `DashboardCard` objects. All inputs are either already available or introduced by Features 2 and 3 above.

### Recommended Additions

| Component | Addition | Version | Purpose |
|-----------|----------|---------|---------|
| Flutter | none (code only) | — | `CardRankingEngine` service using existing + new signals |

---

## Complete Delta: New Packages Only

### Flutter (`pubspec.yaml` additions)

```yaml
dependencies:
  # Document Intelligence
  flutter_image_compress: ^2.3.0   # Compress camera photos before Claude Vision upload

  # Financial Biography
  sqflite: ^2.4.1                  # Local encrypted event store
  sqflite_common_ffi: ^2.3.4       # Desktop/test compat (CI on macos-15)
  encrypt: ^5.0.3                  # AES-256-GCM application-layer encryption

  # bLink Open Banking
  flutter_web_auth_2: ^4.0.1       # OAuth 2.0 PKCE system browser flow
```

Total: **5 new Flutter packages**

### Backend (`pyproject.toml` additions)

```toml
# Add to main dependencies list:
"pillow>=10.4.0,<12.0.0",        # Image normalization (rotation, EXIF)
"pdf2image>=1.17.0,<2.0.0",      # Scanned PDF -> image for Claude Vision
"httpx>=0.27.0,<1.0.0",          # Move from [dev] to prod for bLink async calls
```

Total: **3 backend changes** (2 new, 1 promotion from dev)

### System Dependency (Railway/Docker build)

```dockerfile
RUN apt-get install -y poppler-utils   # Required by pdf2image
```

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `workmanager` / `background_fetch` | Out of scope v2.0 (PROJECT.md explicit) | `flutter_local_notifications.zonedSchedule()` (already present) |
| `hive` / `hive_flutter` | Encryption adapter fragile; not maintained | `sqflite` + `encrypt` |
| `isar` | Major API break in v4; community unstable as of 2026 | `sqflite` |
| `sqlcipher_flutter_libs` | Breaks iOS Podfile.lock + Android NDK | Application-layer `encrypt` |
| `drift` (moor) | Requires `build_runner` code-gen overhead | `sqflite` |
| `pypdf` / `PyMuPDF (fitz)` | Duplicates `pdfplumber`; PyMuPDF has GPL risk | `pdfplumber` (existing) + `pdf2image` |
| `authlib` | Overkill for single PKCE exchange | `pyjwt` (existing) + `httpx` |
| `requests` | Sync-only, old pattern in async FastAPI | `httpx` |
| `aiohttp` | Already have `httpx`; two HTTP clients = confusion | `httpx` |
| `flutter_web_auth` | Deprecated, unmaintained | `flutter_web_auth_2 ^4.0.1` |
| `tflite` / `vertex_ai` | ML overkill for deterministic rule-based ranking | Pure Dart `CardRankingEngine` |
| `objectbox` | Commercial/binary license | `sqflite` |
| `camelot-py` | Only for table extraction from text-layer PDFs; `pdfplumber` already does this | `pdfplumber` |
| `app_links` | Deep link handler only, not OAuth URL launch | `flutter_web_auth_2` |

---

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not |
|---------|-------------|-------------|---------|
| Local DB | `sqflite` | `drift` | Drift adds `build_runner` code-gen; sqflite simpler for append-only log |
| Local DB | `sqflite` | `isar` | Isar v4 API break; community instability in early 2026 |
| Encryption | `encrypt` (app layer) | `sqlcipher_flutter_libs` | SQLCipher breaks iOS Podfile.lock + Android NDK config |
| OAuth flow | `flutter_web_auth_2` | `app_links` | `app_links` handles deep links but not the OAuth URL launch + callback cycle |
| Image compression | `flutter_image_compress` | `image` (pure Dart) | `image` package is ~10x slower for compression; `flutter_image_compress` uses native codecs |
| Scanned PDF | `pdf2image` + poppler | `PyMuPDF` | GPL license risk; `pdf2image` + poppler is MIT |
| bLink HTTP | promote `httpx` to prod | `aiohttp` | `httpx` already in dev extras; consistent pattern; httpx supports both sync/async |

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|----------------|-------|
| `sqflite ^2.4.1` | Flutter SDK `^3.6.0` | No conflicts; uses `dart:io` |
| `sqflite_common_ffi ^2.3.4` | `sqflite ^2.4.1` | Must use matching sqflite version |
| `encrypt ^5.0.3` | `flutter_secure_storage ^9.0.0` | No overlap; complementary |
| `flutter_image_compress ^2.3.0` | `image_picker ^1.1.2` | No overlap; compress the `XFile` bytes after picking |
| `flutter_web_auth_2 ^4.0.1` | `go_router ^13.2.0` | Custom URL scheme handled before GoRouter; no conflict |
| `pillow >=10.4.0,<12.0.0` | `pydantic v2`, `fastapi` | Pure image processing; no FastAPI integration required |
| `pdf2image >=1.17.0,<2.0.0` | `pdfplumber >=0.11.0` | Complementary: pdfplumber for text-layer, pdf2image for scanned |
| `httpx >=0.27.0,<1.0.0` | `fastapi`, `pytest-asyncio` | Already used in tests; promotion to prod is safe |

---

## Implementation Order Recommendation

1. **Document Intelligence** first — highest user value, pipeline already 80% built. Missing: wire HTTP route to `document_vision_service.py`, add `flutter_image_compress`, add `pillow`/`pdf2image` backend.
2. **Financial Biography** second — enables the memory layer that Anticipation Engine and smart card ranking need as input signals.
3. **Anticipation Engine** third — reads from Biography + fiscal calendar JSON; depends on #2 being present.
4. **Contextual Aujourd'hui** fourth — reads from Biography + Anticipation Engine signals; pure ranking logic.
5. **bLink Sandbox** last — isolated feature, no dependency on the others; most complex OAuth dance but most self-contained.

---

## Sources

- Direct codebase audit: `apps/mobile/pubspec.yaml`, `services/backend/pyproject.toml` — HIGH confidence
- `services/backend/app/services/document_vision_service.py` — confirmed Claude Vision pipeline exists, needs HTTP route wiring
- `services/backend/app/services/open_banking/blink_connector.py` — confirmed sandbox mock structure + `NotImplementedError` production path
- `services/backend/app/services/docling/parser.py` — confirmed pdfplumber integration (text-layer PDFs only)
- `apps/mobile/lib/services/coach/proactive_trigger_service.dart` — confirmed 8 triggers, SharedPreferences pattern
- `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` — confirmed image_picker + MLKit wiring
- PROJECT.md — "Background processing / WorkManager for anticipation — v3.0", "bLink production — v3.0", "Cloud sync FinancialBiography — v3.0" (explicit out-of-scope)
- `flutter_web_auth_2` — known successor to deprecated `flutter_web_auth`; maintained (MEDIUM confidence — training data)
- `sqflite ^2.4.1` — stable, widely used Flutter SQLite package (HIGH confidence — established ecosystem standard)
- `encrypt ^5.0.3` — pure Dart AES-256-GCM (MEDIUM confidence — training data, verify version on pub.dev before use)
- `flutter_image_compress` — widely used Flutter image compression package (MEDIUM confidence — training data)

---
*Stack research for: MINT v2.0 Système Vivant — new feature additions*
*Researched: 2026-04-06*
