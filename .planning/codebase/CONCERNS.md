# Codebase Concerns

**Analysis Date:** 2026-04-22
**Sources:** TRIAGE.md (2026-04-15), Phase 32 deferred items, MEMORY.md open findings, live grep of backend + Flutter code, ADRs.

---

## Tech Debt

### 1. God-file proliferation (13+ files > 1000 LOC)

**Backend:**
- `services/backend/app/api/v1/endpoints/coach_chat.py` — **2616 LOC** for one endpoint. 58 git touches in 90 days. Contains routing, intent parsing, tool execution, response formatting, SLM fallback, SSE streaming, and entitlement gate all in one file.
- `services/backend/app/api/v1/endpoints/auth.py` — **1355 LOC**
- `services/backend/app/api/v1/endpoints/documents.py` — **1390 LOC**

**Flutter:**
- `apps/mobile/lib/models/coach_profile.dart` — **3272 LOC**, consumed by **126 files**. Changing its schema requires auditing 126 consumers. Touched 77 times in 90 days. Contains one `@Deprecated` field at line 3152 still referenced by callers.
- `apps/mobile/lib/providers/coach_profile_provider.dart` — **2443 LOC**
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — **2251 LOC**
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart` — **2116 LOC**
- `apps/mobile/lib/app.dart` — **1857 LOC**. **145 git touches in 90 days** — the most-touched file in the project. A stable app entry should receive <5 touches/month.
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` — **2096 LOC**
- `apps/mobile/lib/screens/expat_screen.dart` — **1719 LOC**
- `apps/mobile/lib/services/coach_narrative_service.dart` — **1458 LOC** (plus a second 206-LOC file `lib/services/coach/coach_narrative_service.dart` — canonical not settled)
- `apps/mobile/lib/services/cap_engine.dart` — **1389 LOC**, partially duplicates `mint_state_engine.dart` + `cap_sequence_engine.dart`
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` — **1407 LOC**

**Fix approach:** Split `coach_chat.py` into router + intent_service + tool_executor + response_formatter. Split `coach_profile.dart` into ProfileSchema + ProfileExtensions + ProfileStorage, migrate 126 consumers by batch.

---

### 2. financial_core barrel bypassed (ADR violation)

**ADR:** `decisions/ADR-20260223-unified-financial-engine.md` status "Implemented" is partially false.

**Issue:** 20+ files import sub-modules directly instead of through the barrel `lib/services/financial_core/financial_core.dart`. Examples:
- `apps/mobile/lib/services/first_job_service.dart` — imports `financial_core/tax_calculator.dart`
- `apps/mobile/lib/services/independants_service.dart` — imports `financial_core/avs_calculator.dart`
- `apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart` — imports `financial_core/arbitrage_engine.dart`, `arbitrage_models.dart`, `tax_calculator.dart` individually
- `apps/mobile/lib/services/retirement_projection_service.dart` (1249 LOC) — contains calculation logic that should have been migrated to `financial_core/`

**Impact:** Future calculator changes require hunting all direct-import callsites, not just the barrel. High regression risk for Swiss-legal calculation accuracy.

**Fix approach:** Phase 2 of ADR-20260223 — replace direct imports with barrel import across 20+ files, extract residual calc logic from `retirement_projection_service.dart` into `financial_core/`.

---

### 3. MultiProvider root with async I/O in `create()` (architecture scar)

**File:** `apps/mobile/lib/app.dart:1411-1510`

**Issue:** 18 `ChangeNotifierProvider` declarations at MultiProvider root. At least 4 trigger async I/O inline in `create()`: `AuthProvider.checkAuth()`, `CoachProfileProvider.loadFromWizard()`, `ByokProvider.loadSavedKey()`, `SlmProvider.init()`. No `ProxyProvider` chain declares dependencies, so initialization order is non-deterministic on cold start.

**Impact:** Race conditions between auth state and profile load. Historical root cause of multiple Gate 0 P0 bugs. `MintStateProvider` and `NotificationsWiringService` now use `ChangeNotifierProxyProvider` (fixed in Wave B-minimal), but remaining 4 plain providers still fire async I/O unsafely.

**Fix approach:** Migrate async-init providers to `ChangeNotifierProxyProvider` with explicit dependency chain, or migrate to Riverpod. Requires ~3-5 day effort.

---

### 4. Monthly check-ins not synced to backend

**File:** `apps/mobile/lib/providers/coach_profile_provider.dart:1133`

```dart
// TODO(P2): Sync monthly check-ins to backend for cross-device access
```

**Impact:** Check-in history is SharedPreferences-only. Installing the app on a second device or reinstalling loses all check-in data. No cross-device continuity.

**Fix approach:** Add `POST /api/v1/checkins` endpoint; call from `CoachProfileProvider.saveCheckIn()`.

---

### 5. `suggest_actions` tool not handled in Flutter

**Backend:** `services/backend/app/services/coach/coach_tools.py:615` — `suggest_actions` tool is fully defined and shipped.
**Flutter:** No handler found in `apps/mobile/lib/` for `suggest_actions` tool use response. Chips displayed in coach chat are static.

**Impact:** Coach cannot dynamically drive chip suggestions from its own inference. Every user sees the same static chips regardless of context. Documented as P1 in TRIAGE.md §1.

**Fix approach:** Add `suggest_actions` case to `ChatToolDispatcher.dispatch()` in Flutter; map returned actions to chip list displayed in `CoachChatScreen`.

---

### 6. `fire-and-forget` profile sync — silent data loss risk

**Files:** `apps/mobile/lib/providers/coach_profile_provider.dart:522, 820, 1284, 1493`

All four calls to `_syncToBackend()` are fire-and-forget (`.catchError` only logs `debugPrint`). If Railway is unreachable at the moment of a `save_fact` write, the fact is lost server-side with no user-visible error and no retry queue.

**Impact:** Profile data that the coach extracted from user speech may never reach the backend. Next session starts with stale profile.

**Fix approach:** Add an offline write queue (SQLite local buffer) with retry-on-reconnect, or at minimum surface a non-blocking sync-failed indicator in UI.

---

### 7. Couple data client-side only

**Status:** Documented in MEMORY.md §OPEN FINDINGS.

**Issue:** `ConjointProfile` in `apps/mobile/lib/models/coach_profile.dart` stores partner data in SharedPreferences only via `CoachProfileProvider`. The backend schemas in `services/backend/app/schemas/family.py` have `conjoint` fields, but no `/api/v1/profile/partner` endpoint exists and there is no backend sync for couple data.

**Impact:** All couple-mode projections (AVS survivor rente, succession tax, dual-income tax optimization) are calculated locally without server persistence. Data lost on reinstall.

---

### 8. AVS income splitting for married couples not modeled

**File:** `services/backend/app/services/retirement/avs_estimation_service.py:165`

```python
# TODO(deferred): LAVS art. 29quinquies — income splitting during marriage not yet modeled.
```

**Impact:** AVS rente projections for married users (`swiss_native`, `expat_eu` archetypes with spouse) are wrong by LAVS art. 29quinquies rules. The error is silent — no disclaimer is shown to users. Affects golden test coverage for 2/8 archetypes.

---

### 9. Reengagement consent uses in-memory store

**File:** `services/backend/app/api/v1/endpoints/reengagement.py:137`

```python
logger.warning("V5-1: Consent state uses in-memory store pending DB migration. "
               "Feature-gated — acceptable for now. TODO: wire SQLAlchemy session.")
```

**Impact:** Reengagement consent toggles (nLPD art. 6 compliance) are lost on every Railway deployment. This is a legal risk if the feature is activated before migration.

---

### 10. Coach narrative service duplication unresolved

**Files:**
- `apps/mobile/lib/services/coach_narrative_service.dart` — 1458 LOC, historical
- `apps/mobile/lib/services/coach/coach_narrative_service.dart` — ~206 LOC, recent

Both files exist. The canonical version is not formally decided. Any caller importing the wrong one gets divergent behavior. Flagged in TRIAGE.md §3.4 as "Décision founder requise."

---

## Security Considerations

### S1. PII stored in plaintext SQLite in development / pre-production

**File:** `services/backend/app/models/document.py:1`

```python
# TODO(deferred-pre-launch): Database is currently unencrypted SQLite.
# PII (salary, pension data) stored in plaintext JSON columns.
# Migration to encrypted PostgreSQL required before production launch.
```

Production uses PostgreSQL (enforced by fail-fast guard in `services/backend/app/core/config.py:129`), but staging may still run SQLite if `DATABASE_URL` is not set. Any staging data breach exposes real salary + LPP + AVS numbers.

**Current mitigation:** Hard fail on Railway if `sqlite` in `DATABASE_URL` and `ENVIRONMENT=production`.
**Remaining risk:** Staging environment must explicitly be checked. SQLite files written to Railway ephemeral disk are not encrypted.

---

### S2. Rate limiting uses in-memory backend by default (no `REDIS_URL`)

**File:** `services/backend/app/core/rate_limit.py:48`

If `REDIS_URL` is not set in Railway, rate limits are per-process and reset on restart/scale-out. With multiple Railway replicas, each process has an independent counter — effective rate is `limit × replica_count`.

**Impact:** Brute-force on `/api/v1/auth/login` or `/api/v1/coach/chat` is under-throttled when scaled horizontally.

**Fix approach:** Set `REDIS_URL` in Railway environment. Add an alert if startup detects multi-replica without Redis.

---

### S3. Open Banking `BlinkConnector` raises `NotImplementedError`

**File:** `services/backend/app/services/open_banking/blink_connector.py:213,246,275`

Three methods (`connect`, `fetch_transactions`, `sync_balance`) raise `NotImplementedError`. The endpoint `GET /api/v1/open-banking/connect` routes to this service. Any call to these methods in production throws a 500.

**Current mitigation:** Feature is likely flag-guarded in Flutter; `FeatureFlags.openBanking` referenced in `providers/coach_profile_provider.dart:2200`.
**Risk:** If flag is ever enabled without completing the implementation, users get silent 500 errors on banking connect.

---

### S4. Billing entitlement gate bypassed during beta

**File:** `services/backend/app/api/v1/endpoints/coach_chat.py:2075`

```python
# TODO(billing): Re-enable full entitlement gate when billing goes live.
# BETA EXCEPTION: When using server-side API key (no BYOK), allow all authenticated users.
```

All users with server-side API key bypass the `coachLlm` entitlement check. This is intentional for beta but must be closed before any paid tier launch. No automated reminder or kill-switch exists.

---

## Known Bugs

### B1. 3 flaky full-suite Flutter tests (pre-existing, not regression)

**Files:**
- `apps/mobile/test/data_injection_test.dart` — `ForecasterService` test fails under parallel execution
- `apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart` — passes in isolation, fails in full suite
- `apps/mobile/test/widgets/plan_reality_home_test.dart` — parallel SharedPreferences mock timing

**Root cause:** Shared `SharedPreferences` mock state not isolated between tests. `premier_eclairage_card_test.dart` passes 8/8 when run alone.

**Impact:** CI shows intermittent failures unrelated to PR changes. Engineers cannot trust `flutter test` output as a clean gate.

**Fix approach:** Add `SharedPreferences.setMockInitialValues({})` in `setUp` for these test files. Tracked in Phase 32 deferred items.

---

### B2. Scanner screen — text clipping on 4th button

**File:** `apps/mobile/lib/screens/document_scan/document_scan_screen.dart`

"Utiliser un exemple de test" last line is truncated on iPhone 17 Pro. Layout overflow P1. Documented in `.planning/backlog/scan-screen-ux-audit-2026-04-20.md`.

---

### B3. Missing accent in scan screen UI

**File:** `apps/mobile/lib/screens/document_scan/document_scan_screen.dart`

"Certificat de **prevoyance** LPP" — accent missing (`prévoyance`). The `accent_lint_fr.py` tool either does not cover this file or the string is assembled dynamically. Documented in `.planning/backlog/scan-screen-ux-audit-2026-04-20.md`.

**Note:** `prevoyance` (without accent) is also used as a Dart field name throughout `apps/mobile/lib/models/coach_profile.dart` and `providers/coach_profile_provider.dart`. This is an internal identifier and not directly user-visible, but the lint rule CLAUDE.md §2 says ASCII `e` = bug.

---

## Performance Bottlenecks

### P1. `coach_chat.py` — 2616 LOC single endpoint, 58 git touches in 90 days

Every feature request touching the coach requires modifying the most complex file in the codebase. No isolation between SSE streaming logic, tool execution, and response formatting.

**Fix approach:** Extract into `router`, `intent_service`, `tool_executor`, `response_formatter` modules. XL effort (15-20 days), requires feature-freeze on coach for 2 weeks.

---

### P2. Rate limiting resets on Railway deployment

When Railway redeploys (including autoscale), all in-memory rate limit counters reset. During the reset window, any burst request can bypass per-minute limits. No Redis configured by default.

---

## Fragile Areas

### F1. `app.dart` — 1857 LOC, 145 git touches in 90 days

**File:** `apps/mobile/lib/app.dart`

Contains: GoRouter with 147 routes + 43 redirects, MultiProvider root (18 providers), auth listener, deep-link handling, splash gate. Any routing or provider change requires modifying this file. Historical root of most Gate 0 P0 bugs.

**Safe modification:** Always run `flutter test test/routes/` after any change. Never modify provider order without testing cold-start auth flow.

---

### F2. `coach_profile.dart` — 3272 LOC, 126 consumers

**File:** `apps/mobile/lib/models/coach_profile.dart`

Any schema change (add/rename/remove field) requires auditing 126 import sites. `fromJson`/`toJson` are hand-rolled (no code generation), so any typo in field names causes silent null deserialization.

**Safe modification:** Run golden tests (`test/golden/Julien/` and `test/golden/Lauren/`) after any field change. Verify `CoachProfileProvider.loadFromWizard()` key strings match model field names.

---

### F3. Golden test suite — 6/8 archetypes lack regression baseline

**Files:** `apps/mobile/test/golden/Julien/`, `apps/mobile/test/golden/Lauren/`, `services/backend/tests/`

Only `swiss_native` (Julien) and `swiss_native_couple` (Lauren) have golden values. Six archetypes have no regression protection: `expat_eu`, `expat_non_eu`, `independent_with_lpp`, `independent_no_lpp`, `cross_border`, `returning_swiss`.

**Risk:** Any change to `avs_calculator.dart`, `lpp_calculator.dart`, or `arbitrage_engine.dart` could silently produce wrong numbers for 6 of 8 archetypes.

---

### F4. `s4_response_card_golden_test.dart` — all tests skipped

**File:** `apps/mobile/test/goldens/s4_response_card_golden_test.dart`

All 3 golden tests have `skip: true` with comment "awaiting 04-02". Golden masters were never committed. The test file exists purely as a placeholder — no visual regression protection for the S4 response card component.

---

### F5. 9 backend tests gated on missing fixtures / ChromaDB

**Files:** `services/backend/tests/test_rag_ingestion.py` (skipif ChromaDB not installed), `services/backend/tests/integration/test_golden_document_flow.py`, and 7 others

These tests never run in CI because their preconditions (PDF fixtures, ChromaDB, Sentry token) are absent on the CI runner. The document extraction pipeline (`services/backend/app/services/docling/`) has no automated regression protection in CI.

---

## Scaling Limits

### SC1. Snapshots endpoint — in-memory fallback loses data on restart

**File:** `services/backend/app/api/v1/endpoints/snapshots.py:52`

When no DB session is available, snapshots use in-memory fallback and return `X-Storage-Mode: in-memory` header. Data is lost on every Railway restart. With Railway's ephemeral dynos and auto-sleep, this affects all free-tier deployments.

---

### SC2. Rate limiting not distributed

Without Redis (`REDIS_URL` unset), rate limits are per-process. Any horizontal scale-out on Railway multiplies the effective rate limit by replica count. The auth endpoint at 60/minute becomes 120/minute with 2 replicas.

---

## Missing Critical Features

### M1. FATCA asset reporting not modeled

**Status:** Documented in MEMORY.md §OPEN FINDINGS.

Users with US person status (`expat_us` archetype) have no FATCA-specific guidance in MINT. No `FBAR`/`Form 8938` foreign asset thresholds are surfaced. The archetype exists in `services/backend/app/schemas/precision.py:163` but the downstream logic treats `expat_us` identically to `expat_eu`.

---

### M2. Frontalier tax (impôt à la source) — backend exists, Flutter unwired

**Backend:** `services/backend/app/api/v1/endpoints/expat.py:58` — `POST /expat/frontalier/source-tax` fully implemented.
**Flutter:** `apps/mobile/lib/screens/frontalier_screen.dart` (1488 LOC) exists. Wiring status unverified — likely one of the 45 backend endpoints not called from Flutter (TRIAGE.md §3.7).

**Impact:** Frontalier users (Permis G, cross-border workers) cannot use the tax simulation. One of the largest Swiss expat segments.

---

### M3. POST/PATCH profile, `/overview/me`, `/budget` CRUD, `/fri/*` — backend exists, Flutter unwired

**Status:** Documented in MEMORY.md §OPEN FINDINGS (deferred v2.8).

These backend endpoints are implemented but have no Flutter callers. Profile updates are handled via `CoachProfileProvider`'s fire-and-forget `_syncToBackend()` rather than a proper `PATCH /profile` call.

---

### M4. Tax Phase 0 (XML eCH-0119 + Dossier Fiscal Vivant) — not started

**ADR:** `decisions/ADR-20260501-tax-phase-0-wedge.md` status "Proposed".
**Precondition:** Gate 0 must be resolved first (auth, coach context, markdown, scanner). The ADR explicitly blocks kickoff until Gate 0 issues are closed.

---

## Test Coverage Gaps

### T1. Markdown rendering — zero tests

**Finding from TRIAGE.md §4.1:** `grep MarkdownBody` returns 0 test files. The `softLineBreak` behavior in `apps/mobile/lib/widgets/coach/` coach message rendering has no widget test coverage.

**Risk:** Regression to literal asterisks / broken line breaks undetectable in CI.
**Priority:** High (was a Gate 0 P0 bug historically)

---

### T2. Auth state propagation post-login — zero integration tests

**Finding from TRIAGE.md §4.1:** No test verifies that logging in updates router state and all 4 tabs reflect the authenticated user. The GoRouter `refreshListenable` wiring is untested.

**Risk:** Auth regression ships undetected.
**Priority:** High

---

### T3. Coach multi-turn context retention — shallow test

**File:** `services/backend/tests/` — one `test_coach_memory_roundtrip` test exists but does not verify that turn 2 of a conversation cites content from turn 1.

**Risk:** Context window truncation or history cap regression is undetected.
**Priority:** High

---

### T4. i18n — ~120 hardcoded strings in 24 secondary service files

**Status:** Documented in MEMORY.md §OPEN FINDINGS (D4 priority 2).

Approximately 120 user-facing strings in secondary service files are not routed through `AppLocalizations`. French-only strings in these files will display incorrectly for EN/DE/ES/IT/PT users.

---

### T5. 1864 orphaned ARB keys (21% of i18n corpus)

From TRIAGE.md §3.6: 1,864 of 8,852 ARB keys are not referenced in any `.dart` file. These are dead strings from redesigned landing pages, onboarding flows, and deprecated features. They inflate ARB file size (~20 KB × 6 languages = ~120 KB excess) and make it harder to identify active strings.

---

## Dependencies at Risk

### D1. LLM cost spike — `MINT_LLM_TIER` env var required for MVP

**File:** `services/backend/app/services/llm/tier.py` (untracked as of 2026-04-22)

A new `tier.py` module was created after a ~$40 API cost incident (2026-04-22). It switches coach + RAG from Sonnet 4.5 to Haiku 4.5 when `MINT_LLM_TIER=mvp` is set. The module is untracked in git and not yet wired into `claude_coach_service.py` or RAG endpoints.

**Risk:** File is untracked — it will be lost on a fresh clone. The cost control it was designed to provide is not yet active.

**Fix approach:** Commit `tier.py`, wire `resolve_primary_model()` into `services/backend/app/services/coach/claude_coach_service.py` and any RAG endpoint using Sonnet, set `MINT_LLM_TIER=mvp` in Railway staging env.

---

*Concerns audit: 2026-04-22*
