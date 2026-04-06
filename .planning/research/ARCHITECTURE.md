# Architecture Research

**Domain:** v2.0 "Mint Système Vivant" — integration of DataIngestionService, AnticipationEngine, FinancialBiography, bLink adapters, and smart card ranking into existing Flutter + FastAPI app
**Researched:** 2026-04-06
**Confidence:** HIGH (based on direct codebase inspection across 652 Flutter source files, 293 backend source files, and existing planning documents)

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         FLUTTER (Client)                                  │
│                                                                           │
│  ┌─────────────────┐  ┌────────────────┐  ┌───────────────────────────┐  │
│  │  Aujourd'hui    │  │  Coach Tab     │  │  Explorer Hubs            │  │
│  │  (smart cards)  │  │  (chat + nav)  │  │  (7 domains)              │  │
│  └────────┬────────┘  └───────┬────────┘  └─────────────┬─────────────┘  │
│           │                   │                          │               │
│  ┌────────▼───────────────────▼──────────────────────────▼────────────┐  │
│  │                     PROVIDERS (14 + 3 new)                         │  │
│  │  CoachProfileProvider  |  AnticipationProvider  |  BiographyProv.  │  │
│  └────────┬───────────────────────────────────────────────────────────┘  │
│           │                                                               │
│  ┌────────▼───────────────────────────────────────────────────────────┐  │
│  │                    SERVICE LAYER (v2.0 additions)                  │  │
│  │  DataIngestionService  AnticipationEngine  FinancialBiography      │  │
│  │  CardRankingService    BlinkAdapterService  DocumentVaultService   │  │
│  └────────┬──────────────────────────────────┬────────────────────────┘  │
│           │                                  │                           │
│  ┌────────▼──────────────┐   ┌───────────────▼────────────────────────┐  │
│  │   financial_core/     │   │       LOCAL PERSISTENCE                │  │
│  │  (pure calculators)   │   │  SharedPrefs  |  SecureStorage          │  │
│  │  unchanged for v2.0   │   │  biography.json (local-only graph)     │  │
│  └───────────────────────┘   └────────────────────────────────────────┘  │
└───────────────────────────────────────┬──────────────────────────────────┘
                                        │ HTTPS REST /api/v1
┌───────────────────────────────────────▼──────────────────────────────────┐
│                         FASTAPI (Backend)                                  │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  Endpoints (v2.0 additions)                                          │ │
│  │  POST /documents/ingest   POST /anticipation/evaluate                │ │
│  │  GET  /blink/sandbox      GET  /cards/ranked                         │ │
│  └──────────────────────────────────┬───────────────────────────────────┘ │
│                                     │                                     │
│  ┌──────────────────────────────────▼───────────────────────────────────┐ │
│  │  Services (v2.0 additions)                                           │ │
│  │  DocumentExtractionService  AnticipationRuleEngine  BlinkAdapter    │ │
│  │  (extend existing docling + document_parser)                        │ │
│  └──────────────────────────────────┬───────────────────────────────────┘ │
│                                     │                                     │
│  ┌──────────────────────────────────▼───────────────────────────────────┐ │
│  │  Existing Infrastructure                                             │ │
│  │  ComplianceGuard  |  CoachTools  |  RAG (ChromaDB)  |  PostgreSQL   │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `DataIngestionService` (Flutter) | Adapter pattern: unified pipeline for photo/PDF/bLink/pension inputs. Detects document type, routes to correct parser, calls backend for LLM extraction, merges result into CoachProfile | NEW |
| `AnticipationEngine` (Flutter) | Rule-based trigger evaluation (fiscal deadlines, profile changes, legislative). Zero LLM cost. Runs on app open, writes `AnticipationAlert` list to provider | NEW (extends existing `ProactiveTriggerService`) |
| `FinancialBiography` (Flutter) | Local-only append-only graph of financial facts, decisions, and life events. Never sent to external APIs. `AnonymizedBiographySummary` generated for coach context injection | NEW |
| `CardRankingService` (Flutter) | Scores Aujourd'hui cards by relevance (urgency × impact CHF × deadline proximity × profile completeness delta). Max 5 cards. Replaces static card list in `MintHomeScreen` | NEW (extends `DashboardCuratorService`) |
| `BlinkAdapterService` (Flutter+Backend) | Sandbox-only OAuth adapter for bLink Open Banking. Client initiates consent flow; backend proxies bLink API calls; maps account data to CoachProfile fields | NEW (extends existing `OpenBankingService` stub) |
| `DocumentExtractionService` (Backend) | LLM-powered field extraction from OCR text. Extends existing `docling/` and `document_parser/` services. Adds ProfileEnrichmentDiff output with `extractedAt` + decay model | EXTEND existing |
| `AnticipationRuleEngine` (Backend) | Server-side version of anticipation rules for batch evaluation (e.g., legislative changes that affect all users). Writes alerts to DB for client pull | NEW (optional in v2.0) |

---

## Recommended Project Structure

### Flutter additions

```
apps/mobile/lib/
├── services/
│   ├── ingestion/                    # NEW — DataIngestionService adapter pattern
│   │   ├── data_ingestion_service.dart       # Entry point: detects type, routes
│   │   ├── ingestion_adapter.dart            # Abstract adapter interface
│   │   ├── photo_scan_adapter.dart           # ML Kit OCR → backend LLM extraction
│   │   ├── pdf_adapter.dart                  # PDF bytes → backend extraction
│   │   ├── blink_adapter.dart                # bLink OAuth → account data → profile
│   │   ├── pension_fund_adapter.dart         # Pension API stub (feature-flagged)
│   │   └── ingestion_models.dart             # IngestionResult, ProfileEnrichmentDiff
│   │
│   ├── anticipation/                  # NEW — AnticipationEngine
│   │   ├── anticipation_engine.dart          # Rule runner, returns AnticipationAlert[]
│   │   ├── anticipation_rules.dart           # Fiscal, profile, legislative rule defs
│   │   ├── anticipation_models.dart          # AnticipationAlert, AlertType enum
│   │   └── anticipation_persistence.dart     # SharedPrefs: seen alerts, last eval date
│   │
│   ├── biography/                     # NEW — FinancialBiography
│   │   ├── financial_biography.dart          # Local append-only graph (local JSON)
│   │   ├── biography_models.dart             # BiographyFact, BiographyEvent, BiographyDecision
│   │   └── biography_anonymizer.dart         # AnonymizedBiographySummary for coach context
│   │
│   ├── cards/                         # NEW — Smart card ranking
│   │   ├── card_ranking_service.dart         # Scoring engine (extends DashboardCuratorService)
│   │   ├── card_models.dart                  # RankedCard, CardScore, CardType enum
│   │   └── card_registry.dart                # All possible card definitions
│   │
│   ├── coach/
│   │   └── context_injector_service.dart     # MODIFY: add biography summary injection
│   │
│   └── document_parser/               # EXISTING — extend, do not restructure
│       └── document_models.dart              # MODIFY: add ProfileEnrichmentDiff
│
├── providers/
│   ├── anticipation_provider.dart     # NEW — AnticipationAlert[] + loading state
│   ├── biography_provider.dart        # NEW — FinancialBiography reactive wrapper
│   └── ingestion_provider.dart        # NEW — IngestionResult + progress state
│
├── models/
│   └── profile_enrichment_diff.dart   # NEW — delta between old/new CoachProfile from ingestion
│
└── screens/
    ├── document_scan/
    │   └── ingestion_review_screen.dart  # EXTEND existing scan flow to show diff preview
    └── home/
        └── mint_home_screen.dart         # MODIFY: feed ranked cards from CardRankingService
```

### Backend additions

```
services/backend/app/
├── api/v1/endpoints/
│   ├── documents.py                   # EXISTING — add /ingest endpoint
│   ├── anticipation.py                # NEW — GET /anticipation/alerts
│   └── blink.py                       # NEW — sandbox OAuth + account data proxy
│
├── services/
│   ├── document_extraction/           # NEW — extends docling + document_parser
│   │   ├── llm_extractor.py           # LLM call + structured field extraction
│   │   ├── profile_enrichment.py      # Maps extracted fields → ProfileEnrichmentDiff
│   │   └── extraction_models.py       # ProfileEnrichmentDiff, FieldWithDecay
│   │
│   ├── anticipation/                  # NEW — server-side rule engine (optional batch)
│   │   ├── rule_engine.py             # Legislative + batch rule evaluator
│   │   └── anticipation_models.py     # AnticipationAlert dataclass
│   │
│   └── blink/                         # NEW — bLink sandbox adapter
│       ├── blink_client.py            # HTTP client for bLink sandbox API
│       ├── account_mapper.py          # bLink accounts → CoachProfile fields
│       └── consent_manager.py         # OAuth token lifecycle (sandbox only)
│
├── schemas/
│   ├── ingestion.py                   # NEW — IngestionRequest, ProfileEnrichmentDiffResponse
│   ├── anticipation.py                # NEW — AnticipationAlertResponse
│   └── blink.py                       # NEW — BlinkConsentRequest, AccountSummaryResponse
│
└── models/
    └── anticipation_alert.py          # NEW — SQLAlchemy model (if server-side persistence needed)
```

### Structure Rationale

- **`services/ingestion/`:** Groups all input channel adapters behind a single interface. Adapter pattern prevents document-type-specific logic from leaking into screens.
- **`services/anticipation/`:** Isolated from `coach/` because it runs without LLM. Pure rule evaluation that the coach layer then optionally narrates.
- **`services/biography/`:** Completely local — no backend service equivalent. Separation enforces the privacy constraint: biography data never leaves device.
- **`services/cards/`:** Split from `DashboardCuratorService` (which is retirement-focused) because v2.0 cards span all 18 life events.

---

## Architectural Patterns

### Pattern 1: Adapter Pattern for DataIngestionService

**What:** A single `DataIngestionService` facade accepts any input (photo bytes, PDF bytes, bLink token, pension fund ID) and returns a uniform `IngestionResult` containing a `ProfileEnrichmentDiff`. The facade delegates to typed adapters (`PhotoScanAdapter`, `PdfAdapter`, `BlinkAdapter`, `PensionFundAdapter`).

**When to use:** Any time a new data source is added in v3.0+. Adding a new adapter doesn't touch existing screens.

**Trade-offs:** Adds one indirection layer. Justified because there are 4 distinct input channels in v2.0, each with different auth/privacy/compliance requirements.

**Example:**

```dart
// ingestion_adapter.dart
abstract class IngestionAdapter {
  Future<IngestionResult> ingest(IngestionRequest request);
  bool canHandle(IngestionRequest request);
}

// data_ingestion_service.dart
class DataIngestionService {
  final List<IngestionAdapter> _adapters;

  Future<IngestionResult> ingest(IngestionRequest request) async {
    final adapter = _adapters.firstWhere(
      (a) => a.canHandle(request),
      orElse: () => throw UnsupportedError('No adapter for ${request.source}'),
    );
    final result = await adapter.ingest(request);
    // After ingestion: delete original (nLPD), return diff
    return result;
  }
}
```

### Pattern 2: Append-Only Local Graph for FinancialBiography

**What:** `FinancialBiography` stores an append-only list of `BiographyFact` objects (extracted field + source + timestamp + context), `BiographyEvent` (life event triggered), and `BiographyDecision` (user made a conscious choice — e.g., "chose rente over capital"). Never modified, only appended. Persisted as a local JSON file via `path_provider`.

**When to use:** Any time a document is ingested, a life event is triggered, or the user makes a significant choice in an arbitrage screen.

**Trade-offs:** Append-only means no field correction — if a field is updated, the newer fact takes precedence by timestamp. Requires a `latestFact(fieldName)` accessor. Size must be capped (e.g., 500 entries max, oldest dropped).

**Privacy guarantee:** `FinancialBiographyService` is called locally only. `BiographyAnonymizer` produces an `AnonymizedBiographySummary` (topic-level, no CHF amounts, no IBAN, no employer) that is safe to inject into coach prompts via `ContextInjectorService`.

**Example:**

```dart
// biography_models.dart
class BiographyFact {
  final String fieldName;       // e.g., "lppHavingTotal"
  final dynamic value;          // the extracted value
  final String source;          // "document_scan" | "user_entry" | "blink"
  final DateTime recordedAt;
  final String? documentId;     // link to vault document
}

// financial_biography.dart
class FinancialBiography {
  static Future<void> appendFact(BiographyFact fact) async { ... }
  static Future<BiographyFact?> latestFact(String fieldName) async { ... }
  static Future<AnonymizedBiographySummary> buildSummary() async { ... }
}
```

### Pattern 3: Rule-Based AnticipationEngine (Zero-LLM)

**What:** `AnticipationEngine` evaluates a fixed set of typed rules against the current `CoachProfile` + current date. Returns a sorted list of `AnticipationAlert`. No LLM call. Runs on every app open (debounced: max once per hour via SharedPreferences timestamp).

**Rule categories:**
- **Fiscal deadlines:** 3a contribution deadline (Dec 31), tax declaration (canton-specific), LPP rachat window
- **Profile change triggers:** LPP certificate older than 12 months → "update your certificate", salary gap > 10% from last known
- **Legislative triggers:** regulatory_sync_service detects new parameter version → push alert

**When to use:** Anticipation that is deterministic — no ambiguity, no personalization needed. Coach AI then optionally narrates the alert when the user opens Coach tab.

**Trade-offs:** Rules are hardcoded Dart logic — requires a deploy to update. Acceptable for v2.0. v3.0 can add server-pushed rule definitions.

**Example:**

```dart
// anticipation_rules.dart
abstract class AnticipationRule {
  AnticipationAlert? evaluate(CoachProfile profile, DateTime now);
}

class Pillar3aDeadlineRule implements AnticipationRule {
  @override
  AnticipationAlert? evaluate(CoachProfile profile, DateTime now) {
    if (profile.annualIncome == null) return null;
    final daysToYearEnd = DateTime(now.year, 12, 31).difference(now).inDays;
    if (daysToYearEnd <= 60 && !profile.has3aContributedThisYear) {
      return AnticipationAlert(
        type: AlertType.fiscalDeadline,
        priority: daysToYearEnd <= 14 ? AlertPriority.urgent : AlertPriority.normal,
        i18nKey: 'alert_3a_deadline',
        daysRemaining: daysToYearEnd,
      );
    }
    return null;
  }
}
```

### Pattern 4: ProfileEnrichmentDiff for Safe Profile Updates

**What:** Ingestion never writes directly to `CoachProfile`. Instead it produces a `ProfileEnrichmentDiff` — a typed set of `(fieldName, oldValue, newValue, source, confidence, extractedAt)` pairs. The diff is shown to the user in a review screen before any values are applied. User confirms, rejects, or corrects each field.

**When to use:** Every time an external source (document scan, bLink, pension API) produces profile data.

**Trade-offs:** Extra confirmation step adds friction. Justified because: (a) OCR errors are real, (b) compliance requires user consent to profile changes (nLPD), (c) confidence scores below 0.85 require confirmation regardless.

**Example:**

```dart
// profile_enrichment_diff.dart
class ProfileFieldDelta {
  final String fieldName;
  final dynamic oldValue;
  final dynamic newValue;
  final String source;          // "document_scan" | "blink" | "user_entry"
  final double confidence;      // 0-1
  final DateTime extractedAt;
  final bool requiresReview;    // true if confidence < 0.85
}

class ProfileEnrichmentDiff {
  final List<ProfileFieldDelta> deltas;
  final String documentId;      // reference for biography graph
  final DocumentType documentType;

  // Apply only confirmed deltas to CoachProfile
  CoachProfile applyTo(CoachProfile profile, Set<String> confirmedFields) { ... }
}
```

### Pattern 5: CardRankingService with Scoring Formula

**What:** `CardRankingService` computes a `CardScore` for each candidate card, sorts descending, returns top N (max 5). Score = weighted sum of urgency (× 3), CHF impact (normalized, × 2), deadline proximity (× 2), profile completeness delta (× 1), and recency penalty (how long since last shown, × −0.5).

**When to use:** Called from `MintHomeScreen` on each build via a `FutureBuilder` (or pre-computed in `AnticipationProvider` on app open).

**Trade-offs:** Weights are hardcoded — requires deploy to tune. Acceptable for v2.0. The scoring is transparent (log scores in debug mode).

---

## Data Flow

### Document Ingestion Flow

```
User taps "Scan" / drops PDF
        ↓
DataIngestionService.ingest(request)
        ↓
PhotoScanAdapter: ML Kit OCR on-device (no upload)
        ↓
POST /api/v1/documents/ingest  {text, documentType, userId}
        ↓
Backend DocumentExtractionService
   → LLM extraction (Claude, structured JSON output)
   → ExtractionConfidenceScorer
   → ProfileEnrichmentDiff assembled
        ↓
DELETE original image (nLPD) on device
        ↓
IngestionResult returned to Flutter
        ↓
IngestionProvider.notifyListeners()
        ↓
IngestionReviewScreen (shows diff with confidence bars)
        ↓
User confirms/corrects deltas
        ↓
CoachProfileProvider.applyEnrichmentDiff(confirmedDeltas)
        ↓
FinancialBiography.appendFact(fact) for each confirmed delta
        ↓
AnticipationEngine re-evaluates (profile changed)
        ↓
CardRankingService re-scores (profile completeness delta changed)
        ↓
Aujourd'hui refreshes with new ranked cards
```

### Anticipation Engine Flow

```
App open / resume
        ↓
AnticipationEngine.evaluate(profile, now)
  (debounced: skips if last eval < 1h ago)
        ↓
Runs all AnticipationRule instances in parallel
        ↓
AnticipationAlert[] sorted by priority
        ↓
AnticipationProvider.setAlerts(alerts)
        ↓
Two consumers:
  1. CardRankingService: urgent alerts → top-ranked cards
  2. CoachOrchestrator: if user opens Coach tab within 30min
     of a new urgent alert → ProactiveTriggerService fires
     "anticipation" trigger type
```

### FinancialBiography → Coach Context Flow

```
ContextInjectorService.buildEnrichedContext(profile)
        ↓ (existing flow, add new step)
FinancialBiography.buildSummary()
  → AnonymizedBiographySummary {
      recentDecisions: ["chose rente March 2026"],
      recentFacts: ["LPP updated via scan Feb 2026"],
      activeEvents: ["firstJob 2024", "housingPurchase 2025"]
    }
        ↓
Injected into coach system prompt as new section:
  --- BIOGRAPHIE FINANCIÈRE ---
  [anonymized summary]
  --- FIN BIOGRAPHIE ---
```

### bLink Sandbox Flow

```
User taps "Connect bank" in ProfileDrawer / onboarding
        ↓
BlinkAdapterService.initiateConsent(bankId)
        ↓
POST /api/v1/blink/consent/initiate
        ↓
Backend BlinkClient calls bLink sandbox OAuth endpoint
        ↓
Returns authorization_url to Flutter
        ↓
Flutter launches WebView / SFSafariViewController
        ↓
User completes OAuth in bank's UI
        ↓
Redirect to deep link: mint://blink/callback?code=xxx
        ↓
Flutter intercepts, calls POST /api/v1/blink/consent/complete
        ↓
Backend: exchange code → access token → fetch accounts (sandbox)
        ↓
AccountMapper: bLink account data → ProfileEnrichmentDiff
        ↓
Same confirmation flow as document ingestion
        ↓
ConsentManager stores token (90-day expiry) — backend DB
```

### Smart Card Ranking Flow

```
MintHomeScreen.build()
        ↓
CardRankingService.rankedCards(
  profile: CoachProfileProvider.profile,
  alerts: AnticipationProvider.alerts,
  biography: BiographyProvider.biography,
)
        ↓
For each candidate card:
  score = (urgency × 3) + (chfImpact_normalized × 2)
        + (deadlineProximity × 2) + (profileDelta × 1)
        - (daysSinceShown × 0.5)
        ↓
Sort descending, take top 5
        ↓
List<RankedCard> rendered in Aujourd'hui tab
```

---

## Component Modification Map

### Existing components that need modification

| Component | What Changes | Why |
|-----------|-------------|-----|
| `CoachProfileProvider` | Add `applyEnrichmentDiff(ProfileEnrichmentDiff, Set<String>)` method | Profile updates from ingestion go through the diff review pattern |
| `context_injector_service.dart` | Add `AnonymizedBiographySummary` injection block | Coach needs narrative context from biography |
| `ProactiveTriggerService` | Add `anticipation` trigger type (new enum value) | Anticipation alerts feed the coach proactive loop |
| `DashboardCuratorService` | Retire as primary card source; `CardRankingService` replaces it for Aujourd'hui | Expand beyond retirement to all 18 life events |
| `MintHomeScreen` | Replace static card list with `CardRankingService.rankedCards()` | Smart ranking replaces manual ordering |
| `OpenBankingService` | Replace mock with `BlinkAdapterService` (behind feature flag) | bLink sandbox is the v2.0 concrete implementation |
| `RegulatorySyncService` | Emit `LegislativeChangeEvent` when parameters update | Feeds into `AnticipationEngine.legislativeRules` |
| `app.dart` (MultiProvider) | Register `AnticipationProvider`, `BiographyProvider`, `IngestionProvider` | New providers need root registration |
| `FeatureFlags` | Add `FF_BLINK_SANDBOX`, `FF_ANTICIPATION_ENGINE`, `FF_BIOGRAPHY` | New features gated for safe rollout |
| Backend `documents.py` endpoint | Add `POST /documents/ingest` with full extraction pipeline | Photo/PDF ingestion needs a new endpoint beyond existing `/scan` |
| Backend `coach_tools.py` | Add `trigger_ingestion` tool so coach can request document upload | Coach can ask user to scan their LPP certificate mid-conversation |

### New components (no existing equivalent)

| Component | Location | Depends On |
|-----------|----------|------------|
| `DataIngestionService` + adapters | `lib/services/ingestion/` | Existing `document_parser/`, new backend `DocumentExtractionService` |
| `AnticipationEngine` | `lib/services/anticipation/` | `CoachProfile`, `RegulatorySyncService`, `financial_core/` for thresholds |
| `FinancialBiography` | `lib/services/biography/` | `path_provider`, `CoachProfile` |
| `BiographyAnonymizer` | `lib/services/biography/` | `FinancialBiography` |
| `CardRankingService` | `lib/services/cards/` | `AnticipationProvider`, `CoachProfile`, `DashboardCuratorService` (for scoring logic reuse) |
| `AnticipationProvider` | `lib/providers/` | `AnticipationEngine`, `CoachProfileProvider` |
| `BiographyProvider` | `lib/providers/` | `FinancialBiography` |
| `IngestionProvider` | `lib/providers/` | `DataIngestionService` |
| `ProfileEnrichmentDiff` model | `lib/models/` | Pure model, no dependencies |
| `IngestionReviewScreen` | `lib/screens/document_scan/` | `IngestionProvider`, `CoachProfileProvider` |
| Backend `DocumentExtractionService` | `services/backend/app/services/document_extraction/` | Existing `docling/parser.py`, `document_parser/`, Claude API |
| Backend `BlinkClient` + `AccountMapper` | `services/backend/app/services/blink/` | `httpx`, bLink sandbox API, existing schemas |
| Backend anticipation endpoint | `services/backend/app/api/v1/endpoints/anticipation.py` | New `AnticipationRuleEngine` |

---

## Integration Points with Existing Architecture

### financial_core/ — No Changes Required

The 8 existing calculators remain untouched. `AnticipationEngine` calls them for threshold checks (e.g., "is user's LPP rachat_max > 50k CHF?") via the same import pattern all other services use. New features are consumers, not modifiers of `financial_core/`.

### ComplianceGuard — Extend, Not Replace

`CardRankingService` card titles and `AnticipationAlert` i18n keys are static strings (ARB files) — they do not pass through ComplianceGuard. Only the coach narration of anticipation alerts passes through ComplianceGuard (because it is LLM-generated). This is correct: static rule-based text is pre-approved, LLM text is always guarded.

### ConfidenceScorer — Extend for Ingestion

`ProfileEnrichmentDiff` fields carry `source` values that map directly to `DataSource` enum in `document_models.dart` (backend). The existing `DATA_SOURCE_ACCURACY` weights already handle `document_scan` (0.85) and `open_banking` (1.00). `EnhancedConfidence` recalculation after applying a diff is automatic — `CoachProfileProvider` triggers it on profile change.

### CoachOrchestrator — No Structural Change

The 3-tier priority chain (SLM → BYOK → fallback) is unchanged. `AnticipationEngine` feeds `ProactiveTriggerService` which `CoachOrchestrator` already calls. The only change is a new enum value in `ProactiveTriggerType`.

### ContextInjectorService — One New Block

The biography injection is additive. The existing memory block format (`--- MÉMOIRE MINT ---`) gets a new section appended. This is the minimal invasive change: one new `await FinancialBiography.buildSummary()` call before block assembly.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0–10k users | Monolith backend is fine. bLink sandbox. AnticipationEngine client-only. Biography local-only. |
| 10k–100k users | Add server-side anticipation batch (push legislative alerts to all users without per-device rules). Consider caching ProfileEnrichmentDiff results server-side for 24h. |
| 100k+ users | bLink production (SFTI membership, per-bank contracts). Document extraction queue (async job, webhook callback to Flutter). Biography cloud sync with E2E encryption. |

### v2.0 Scaling Priority

First bottleneck: LLM extraction calls on document ingestion. Each scan = 1 Claude API call. At 10k daily active users with 1 scan/week each = ~1400 calls/day. Within free-tier quota at current settings (30 req/user/day). Bottleneck emerges when users scan 3+ documents in a session — mitigate by caching extraction results server-side by document hash.

Second bottleneck: CardRankingService on every Aujourd'hui render. If profile is large and biography has 500 entries, `buildSummary()` is slow. Mitigate by caching `AnonymizedBiographySummary` in `BiographyProvider` and invalidating only on new `BiographyFact.appendFact()` call.

---

## Anti-Patterns

### Anti-Pattern 1: Writing Directly to CoachProfile from Ingestion

**What people do:** `CoachProfileProvider.profile.lppHavingTotal = extractedValue` from inside an adapter.
**Why it's wrong:** Bypasses the diff review screen, violates nLPD consent requirement for profile changes from external sources, and makes testing impossible.
**Do this instead:** Always produce a `ProfileEnrichmentDiff`, route through `IngestionReviewScreen`, apply only confirmed fields via `applyEnrichmentDiff()`.

### Anti-Pattern 2: Sending FinancialBiography to Backend

**What people do:** `POST /api/v1/biography/sync` to back up biography data.
**Why it's wrong:** Biography contains exact CHF amounts, document references, and decision history — PII under nLPD. PROJECT.md explicitly marks cloud sync as out of scope for v2.0.
**Do this instead:** Biography stays local. Only `AnonymizedBiographySummary` (no CHF amounts, no employer, no IBAN) is passed to coach context injection. If backup is needed in v3.0, it requires E2E encryption with user-held keys.

### Anti-Pattern 3: Using AnticipationEngine for Personalized Recommendations

**What people do:** Adding rules like "user should buy LPP rachat because their score is low."
**Why it's wrong:** Crosses the line from education (LSFin-compliant) to advice (requires FINMA licence). Anticipation = "deadline approaching", "data may be stale" — never "you should do X".
**Do this instead:** Alert text always uses informational framing ("Ton certificat LPP date de 14 mois — veux-tu le mettre à jour\u00a0?"). Action suggested = "review", never "buy/invest/transfer".

### Anti-Pattern 4: Rebuilding DocumentCuratorService Logic Inside CardRankingService

**What people do:** Copy-paste `DashboardCuratorService.computeAlertUrgency()` and `getDeadlineDaysForTip()` into `CardRankingService`.
**Why it's wrong:** Creates divergent urgency logic. Two services disagree on what "urgent" means.
**Do this instead:** `CardRankingService` imports and reuses `DashboardCuratorService` scoring utilities as pure functions. `DashboardCuratorService` keeps its existing retirement dashboard role; `CardRankingService` is the broader-scope consumer.

### Anti-Pattern 5: Triggering AnticipationEngine on Every Screen Build

**What people do:** Calling `AnticipationEngine.evaluate()` from `MintHomeScreen.build()`.
**Why it's wrong:** Engine runs 10+ rules including date arithmetic and SharedPrefs reads on every frame.
**Do this instead:** Engine runs once per app open (in `main.dart` background init, or `AnticipationProvider.init()`) with a 1-hour debounce via SharedPreferences timestamp. `MintHomeScreen` reads from `AnticipationProvider` (already computed list), never calls the engine directly.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| bLink sandbox | Backend proxy: Flutter → POST /api/v1/blink/* → bLink API | Never expose bLink token to client; backend manages consent lifecycle. Feature flag `FF_BLINK_SANDBOX` |
| Pension Fund API (stub) | `PensionFundAdapter` returns mock data; real API behind `FF_ENABLE_CAISSE_PENSION_API` | Backend config already has `CAISSE_PENSION_API_URL`. Stub in v2.0, real in v3.0 |
| Claude API (document extraction) | Extend existing `claude_coach_service.py` or new `llm_extractor.py` with structured output mode | Use Claude's JSON mode for extraction. Add to existing `COACH_DAILY_QUOTA` accounting |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `AnticipationEngine` ↔ `CoachOrchestrator` | Via `ProactiveTriggerService` (existing) + new `AlertType.anticipation` | No direct dependency; loose coupling via shared enum |
| `FinancialBiography` ↔ `ContextInjectorService` | `FinancialBiography.buildSummary()` returns `AnonymizedBiographySummary` | One-way read; biography never modified by coach |
| `DataIngestionService` ↔ `CoachProfileProvider` | Via `ProfileEnrichmentDiff` + explicit `applyEnrichmentDiff()` call | Never direct write |
| `CardRankingService` ↔ `AnticipationProvider` | `CardRankingService` reads `AnticipationProvider.alerts` at ranking time | Provider is the shared state; service is pure function given inputs |
| Flutter ingestion ↔ Backend extraction | `POST /api/v1/documents/ingest` → JSON response with `ProfileEnrichmentDiff` | Image bytes sent, image deleted after backend acknowledges extraction complete |

---

## Suggested Build Order

Build order considers three constraints: (1) data dependencies between components, (2) compliance gate requirements (ComplianceGuard must be verified before each new output channel), (3) the "facade sans câblage" risk — each phase must produce a testable end-to-end flow before the next starts.

### Phase 1 — Foundation Models and Ingestion Pipeline
Build `ProfileEnrichmentDiff`, `IngestionResult`, and `DataIngestionService` with `PhotoScanAdapter`. Extend backend with `/documents/ingest` endpoint and `DocumentExtractionService`. Build `IngestionReviewScreen` with diff preview and confirm/reject. Wire `CoachProfileProvider.applyEnrichmentDiff()`. **Gate:** Full scan → extraction → review → profile update flow works end-to-end with LPP certificate.

### Phase 2 — FinancialBiography
Build `BiographyFact`, `FinancialBiography`, `BiographyAnonymizer`. Append facts after confirmed enrichment diffs. Build `BiographyProvider`. Extend `ContextInjectorService` with biography summary block. **Gate:** After scanning a document, biography summary appears in coach context; coach can reference "you updated your LPP last month."

### Phase 3 — AnticipationEngine
Build `AnticipationRule` hierarchy (fiscal, profile, legislative rules). Build `AnticipationProvider`. Extend `ProactiveTriggerService` with anticipation trigger type. **Gate:** With a profile missing 3a data in November, anticipation alert fires and proactive coach trigger activates.

### Phase 4 — Smart Card Ranking
Build `CardRankingService` with scoring formula. Build `CardRegistry` with all candidate cards. Modify `MintHomeScreen` to consume ranked cards. **Gate:** Aujourd'hui shows maximum 5 cards in a deterministic order that changes when profile or alerts change.

### Phase 5 — bLink Sandbox
Build `BlinkAdapterService` client-side. Build backend `BlinkClient`, `AccountMapper`, `ConsentManager`. Add `BlinkAdapter` to `DataIngestionService`. Wire consent OAuth deep link. **Gate:** Full bLink sandbox consent flow → account data → ProfileEnrichmentDiff → review screen → confirmed profile update.

### Phase 6 — QA and Compliance Hardening
9-persona validation (Léa golden path + 8 additional). WCAG 2.1 AA audit. Multilingual validation (all 6 ARB files complete for new keys). Compliance review: all anticipation alert i18n keys pre-approved (no banned terms, no advice framing). **Gate:** 0 flutter analyze errors, 0 new test failures, all 9 personas complete their flows.

---

## Sources

- Direct inspection of `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/` (652 source files)
- Direct inspection of `/Users/julienbattaglia/Desktop/MINT/services/backend/app/` (293 source files)
- `.planning/codebase/ARCHITECTURE.md` — existing architecture analysis (2026-04-05)
- `.planning/codebase/INTEGRATIONS.md` — existing integration inventory (2026-04-05)
- `.planning/codebase/STRUCTURE.md` — existing structure map (2026-04-05)
- `.planning/PROJECT.md` — v2.0 milestone scope and constraints
- `apps/mobile/lib/services/coach/proactive_trigger_service.dart` — existing trigger pattern
- `apps/mobile/lib/services/dashboard_curator_service.dart` — existing card scoring
- `apps/mobile/lib/services/document_parser/document_models.dart` — existing doc models
- `services/backend/app/services/document_parser/document_models.py` — backend doc models with `DATA_SOURCE_ACCURACY`
- `apps/mobile/lib/providers/coach_profile_provider.dart` — central state management pattern
- `apps/mobile/lib/services/coach/context_injector_service.dart` — existing coach context injection

---

*Architecture research for: MINT v2.0 Système Vivant — new feature integration into Flutter + FastAPI*
*Researched: 2026-04-06*
