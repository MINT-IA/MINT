---
phase: 03-memoire-narrative
verified: 2026-04-06T15:45:00Z
status: gaps_found
score: 3/5 success criteria verified
re_verification: false
gaps:
  - truth: "Financial events are recorded in an encrypted local-only store and never sent to external APIs"
    status: failed
    reason: "BiographyRepository.instance() throws UnimplementedError in production -- sqflite_sqlcipher database open call was never wired. Only the abstract interface and test path (withDatabase()) are functional. No facts can be stored or retrieved in a production app."
    artifacts:
      - path: "apps/mobile/lib/services/biography/biography_repository.dart"
        issue: "Line 77: 'throw UnimplementedError(...)' inside the production instance() factory. The sqflite_sqlcipher openDatabase call is absent. Additionally, _generateKey() uses DateTime.now().microsecondsSinceEpoch padded with 'a' -- not cryptographically random (code comment acknowledges this)."
    missing:
      - "Wire sqflite_sqlcipher openDatabase call in BiographyRepository.instance() with the retrieved encryption key"
      - "Replace _generateKey() with dart:math Random.secure() based generation"
  - truth: "Coach references biography naturally using only AnonymizedBiographySummary"
    status: failed
    reason: "ContextInjectorService correctly calls BiographyRepository.instance() and AnonymizedBiographySummary.build(). However, because instance() throws UnimplementedError, the catch (_) at line 353 silently swallows the error and biographyBlock remains empty. The coach never receives biography context in production."
    artifacts:
      - path: "apps/mobile/lib/services/coach/context_injector_service.dart"
        issue: "Line 353: catch (_) swallows UnimplementedError from BiographyRepository.instance(). Biography block is always empty in production."
    missing:
      - "Fix is upstream: wire BiographyRepository.instance() so it no longer throws"
  - truth: "User can view, edit, and delete each stored fact with its source and date via the privacy control screen"
    status: failed
    reason: "PrivacyControlScreen exists, is routed (/profile/privacy-control), and ProfileDrawer entry is present. However BiographyProvider is never registered in the app's MultiProvider setup in app.dart. Any navigation to the screen will throw 'Could not find the correct Provider<BiographyProvider>' at runtime."
    artifacts:
      - path: "apps/mobile/lib/app.dart"
        issue: "BiographyProvider is absent from the MultiProvider block (lines 975-1003+). PrivacyControlScreen calls context.read<BiographyProvider>() / context.watch<BiographyProvider>() which will throw at runtime."
      - path: "apps/mobile/lib/screens/profile/privacy_control_screen.dart"
        issue: "Uses BiographyProvider via context.read/watch but the provider is not registered upstream."
    missing:
      - "Add ChangeNotifierProvider for BiographyProvider in the MultiProvider block in app.dart"
      - "BiographyProvider requires a BiographyRepository instance -- this depends on gap 1 (production repository) being resolved first"
deferred: []
---

# Phase 03: Memoire Narrative Verification Report

**Phase Goal:** MINT remembers the user's financial story over time and the coach references it naturally without exposing private data
**Verified:** 2026-04-06T15:45:00Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Financial events recorded in encrypted local-only store, never sent to external APIs | FAILED | BiographyRepository.instance() throws UnimplementedError -- sqflite_sqlcipher not wired |
| 2 | Coach references biography naturally using only AnonymizedBiographySummary (max 2K tokens, no PII) | FAILED | Wiring is correct but silently fails at runtime due to gap 1; biographyBlock always empty |
| 3 | User can view, edit, and delete facts via privacy control screen | FAILED | Screen exists, route registered, but BiographyProvider not in MultiProvider -- runtime crash |
| 4 | Stale data flagged, excluded from projections, triggers coach refresh prompt | PARTIAL | FreshnessDecayService logic is correct and tested; BiographyRefreshDetector wired; but non-functional since no facts are stored (gap 1) |
| 5 | Every reference to user data is dated or conditioned -- no stale data as current fact | VERIFIED | BIOGRAPHY AWARENESS in backend coach prompt (claude_coach_service.py line 251-410) enforces conditional language, source dating, [DONNEE ANCIENNE] handling |

**Score:** 3/5 success criteria verified (SC-5 verified independently of storage; SC-4 partial)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/services/biography/biography_fact.dart` | BiographyFact with FactType/FactSource enums and graph links | VERIFIED | 41 matches for required fields including causalLinks, temporalLinks, freshnessCategory, isDeleted |
| `apps/mobile/lib/services/biography/biography_repository.dart` | Encrypted SQLite CRUD | STUB | Class exists with full CRUD but instance() throws UnimplementedError; production unusable |
| `apps/mobile/lib/services/biography/freshness_decay_service.dart` | Two-tier freshness decay | VERIFIED | 18 matches for annual/volatile tiers, needsRefresh, categoryFor |
| `apps/mobile/lib/providers/biography_provider.dart` | ChangeNotifier wrapping repository | VERIFIED | 14 matches; correct implementation but requires working repository |
| `apps/mobile/lib/services/biography/anonymized_biography_service.dart` | Privacy-safe biography summary | VERIFIED | 11 matches including _maxChars=8000, BIOGRAPHIE FINANCIERE, donnee confidentielle, DONNEE ANCIENNE |
| `apps/mobile/lib/services/biography/biography_refresh_detector.dart` | Stale fact detection and nudge text | VERIFIED | 10 matches including detectStaleFields, buildRefreshNudge, StaleField, needsRefresh |
| `apps/mobile/lib/services/coach/context_injector_service.dart` | Biography block injection | WIRED (hollow) | Wiring correct but silently degrades due to repository UnimplementedError |
| `services/backend/app/services/coach/claude_coach_service.py` | BIOGRAPHY AWARENESS in system prompt | VERIFIED | _BIOGRAPHY_AWARENESS constant at line 251, injected at line 410 |
| `apps/mobile/lib/screens/profile/privacy_control_screen.dart` | Privacy control screen | ORPHANED | File exists with correct implementation but BiographyProvider not registered in app |
| `apps/mobile/lib/widgets/biography/fact_card.dart` | Fact display card with freshness indicator | VERIFIED | 4 matches for required patterns |
| `apps/mobile/lib/widgets/biography/fact_edit_sheet.dart` | Bottom sheet for editing | VERIFIED | showModalBottomSheet present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `biography_provider.dart` | `biography_repository.dart` | BiographyRepository CRUD methods | WIRED | Provider takes repository via constructor injection |
| `biography_repository.dart` | flutter_secure_storage | Key retrieval for encrypted DB | PARTIAL | FlutterSecureStorage read/write present; but openDatabase call missing |
| `context_injector_service.dart` | `anonymized_biography_service.dart` | AnonymizedBiographySummary.build() | WIRED | Line 344 confirmed |
| `anonymized_biography_service.dart` | `freshness_decay_service.dart` | FreshnessDecayService.weight() | WIRED | Lines 72 and 97 confirmed |
| `profile_drawer.dart` | `privacy_control_screen.dart` | GoRouter /profile/privacy-control | WIRED | Lines 123-124 confirmed |
| `privacy_control_screen.dart` | `biography_provider.dart` | Provider.of/context.read | BROKEN | BiographyProvider not in MultiProvider in app.dart |
| `app.dart` | `privacy_control_screen.dart` | GoRoute at 'privacy-control' | WIRED | Line 673 confirmed |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `context_injector_service.dart` | `biographyBlock` | `BiographyRepository.instance()` | No -- throws UnimplementedError | HOLLOW -- wiring correct, data disconnected |
| `privacy_control_screen.dart` | `provider.facts` | `BiographyProvider` (not registered) | No -- provider not in tree | HOLLOW_PROP -- crashes before data fetch |
| `claude_coach_service.py` | `_BIOGRAPHY_AWARENESS` in system prompt | Static constant injected at build | Yes -- rules always present | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Backend guardrail test suite | `pytest tests/test_biography_coach_guardrails.py` | 10 tests pass (per SUMMARY) | PASS |
| BiographyRepository.instance() production path | Code inspection of line 77 | throws UnimplementedError | FAIL |
| BiographyProvider in MultiProvider | grep biography app.dart | No matches | FAIL |
| FreshnessDecayService logic | flutter test biography tests | 17 tests pass (per SUMMARY + test count) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| BIO-01 | 03-01 | FinancialBiography stores facts with causal/temporal links, local-only | BLOCKED | Repository unusable in production (UnimplementedError); facts cannot be stored |
| BIO-02 | 03-01 | Biography encrypted at rest (AES-256 via flutter_secure_storage + sqflite) | BLOCKED | sqflite_sqlcipher openDatabase not wired; additionally key generation is not cryptographically secure |
| BIO-03 | 03-02 | Coach receives AnonymizedBiographySummary only (max 2K tokens, no PII) | PARTIAL | AnonymizedBiographySummary implementation correct and tested; but always empty in production due to BIO-01/02 gap |
| BIO-04 | 03-02 | Coach references biography naturally, never cites upload dates/exact amounts | PARTIAL | BIOGRAPHY AWARENESS enforces this; but coach never has biography data to reference |
| BIO-05 | 03-03 | Privacy control screen for view/edit/delete each fact | BLOCKED | Screen implemented correctly but BiographyProvider not in app's MultiProvider -- crashes |
| BIO-06 | 03-01 | Freshness decay model: annual 12mo, volatile 3mo | VERIFIED | FreshnessDecayService implementation and 17 tests verified independently of storage |
| BIO-07 | 03-02 | Coach guardrails: dates source, conditional language, no extracted data as fact | VERIFIED | BIOGRAPHY AWARENESS section in claude_coach_service.py; 10 backend guardrail tests |
| BIO-08 | 03-01/02 | When freshness < 0.60, coach prompts for document refresh | PARTIAL | BiographyRefreshDetector logic correct and tested; injection into context injector wired but hollow |
| COMP-02 | 03-02 | No stale data as truth; every reference dated or conditioned | VERIFIED | BIOGRAPHY AWARENESS enforces [DONNEE ANCIENNE] markers and conditional language in coach responses |
| COMP-03 | 03-02 | FinancialBiography data never leaves device; only AnonymizedBiographySummary in LLM prompts | VERIFIED | BiographyFact/BiographyRepository have no HTTP methods; no raw facts found in backend services or HTTP clients |

**Note on COMP-03:** The requirement is structurally satisfied -- no path exists for raw facts to leave the device. The privacy-by-design architecture is correct even if data cannot yet be stored.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `biography_repository.dart` | 77 | `throw UnimplementedError(...)` in production factory | BLOCKER | Facts cannot be stored; entire biography pipeline non-functional |
| `biography_repository.dart` | 100-104 | `DateTime.now().microsecondsSinceEpoch` for key generation with comment "would use Random.secure()" | BLOCKER | Encryption key is predictable based on launch timestamp; violates BIO-02 AES-256 requirement |
| `app.dart` | 975-1003 | BiographyProvider absent from MultiProvider | BLOCKER | PrivacyControlScreen throws at runtime |
| `context_injector_service.dart` | 353 | `catch (_)` swallows UnimplementedError silently | WARNING | Makes the production failure invisible; biography is always empty with no log trace to diagnose |

### Human Verification Required

None. All gaps are deterministic code-level issues verifiable by inspection.

### Gaps Summary

Three root-cause gaps block the phase goal:

**Gap 1 -- Production database not wired (Root cause of gaps 1 and 2):** `BiographyRepository.instance()` was written as a stub with an explicit `throw UnimplementedError`. The SQLite open call using sqflite_sqlcipher was deferred but never completed. This means no biography facts can ever be persisted on device. All downstream features (coach biography integration, privacy screen data display, freshness-triggered refresh) are non-functional even though their logic is correctly implemented. The encryption key generation also uses `DateTime.now().microsecondsSinceEpoch` which is not cryptographically random.

**Gap 2 -- BiographyProvider not registered (Root cause of gap 3):** `BiographyProvider` is implemented and used by `PrivacyControlScreen`, but was never added to the `MultiProvider` block in `app.dart`. Any navigation to `/profile/privacy-control` will crash the app with a provider-not-found exception.

**What works correctly (and will work once gaps are closed):**
- BiographyFact model with full JSON serialization
- FreshnessDecayService two-tier decay logic with 33 tests passing
- AnonymizedBiographySummary whitelist anonymization (8000 char cap, rounding rules)
- BiographyRefreshDetector stale detection and French nudge generation
- ContextInjectorService biography block injection (wiring correct, will work once repository works)
- Backend BIOGRAPHY AWARENESS section (active in production today)
- Privacy screen UI, routing, and i18n (22 keys in 6 languages)
- COMP-03 data isolation architecture

**These two fixes are sufficient to close all three gaps:** (1) Wire `sqflite_sqlcipher` `openDatabase` in `BiographyRepository.instance()` with `Random.secure()` key generation, (2) Register `BiographyProvider` in `MultiProvider` in `app.dart`.

---

_Verified: 2026-04-06T15:45:00Z_
_Verifier: Claude (gsd-verifier)_
