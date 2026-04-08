# Feature Research

**Domain:** Swiss fintech v2.0 — document intelligence, proactive anticipation, financial biography, contextual UI, Open Banking (bLink)
**Researched:** 2026-04-06
**Confidence:** HIGH (grounded in project docs + codebase inspection) / MEDIUM where competitive patterns rely on training knowledge

---

## Context: What Already Exists

These capabilities exist in the codebase and are NOT net-new for v2.0:

| Existing Service | Location | Status |
|------------------|----------|--------|
| `LppCertificateParser` | `services/document_parser/` | Regex-based OCR field extraction, FR+DE, Swiss number format |
| `TaxDeclarationParser` | `services/document_parser/` | Tax doc field extraction |
| `AvsExtractParser` | `services/document_parser/` | AVS CI PDF parsing |
| `SalaryCertificateParser` | `services/document_parser/` | Salary slip parsing |
| `DocumentScanScreen` + `ExtractionReviewScreen` | `screens/document_scan/` | UI pipeline for camera → OCR → review |
| `ProactiveTriggerService` | `services/coach/` | 7 rule-based triggers (lifecycle, recap, goal, seasonal, inactivity, confidence, cap) |
| `JitaiNudgeService` | `services/nudge/` | JITAI trigger engine |
| `MemoryContextBuilder` | `services/memory/` | Cross-session LLM context injection (max 1500 chars) |
| `CoachMemoryService` | (coach layer) | Coach insights persistence |
| `OpenBankingService` | `services/` | FULLY MOCKED — architecture ready, `isEnabled=false` |
| `EnhancedConfidenceService` | `services/confidence/` | 4-axis confidence scoring |
| `DashboardCuratorService` | `services/` | Card ranking by urgency > impact > deadline (max 4) |
| `MintHomeScreen` | `screens/main_tabs/` | Tab 0 "Aujourd'hui" — 1 chiffre vivant + 1 lever + 1 signal + coach bar |

v2.0 builds on these foundations. Research below focuses on what is genuinely new.

---

## Feature Landscape

### Capability 1: Document Intelligence (Intelligence Documentaire)

**What needs to be built:** The individual parsers exist. The gap is the end-to-end pipeline: a generic document parser for unknown caisses, a LLM-vision extraction path for BYOK users, per-field extraction confidence, and the document impact insight (confidence delta display). The scan UX screens exist but are not fully wired to the confidence scoring + biography pipelines.

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Camera + gallery picker (screenshots primary) | "Balance-moi le print screen" — PROJECT.md confirms screenshots are primary input | LOW | `image_picker` package in Flutter ecosystem; `camera` for live capture; no new infrastructure |
| Extraction review screen with editable fields | Compliance requires human confirmation; users cannot trust blind auto-extraction | LOW | `extraction_review_screen.dart` exists; needs wiring to generic parser output |
| Per-field source badge ("from document" vs "estimated") | Sets user expectation; motivates completing profile | LOW | `DataSource` enum exists in `document_models.dart`; surface in UI |
| Confidence delta display after scan | "+27 points de confiance" — immediate, visible value | LOW | `document_impact_screen.dart` exists; needs calculation diff logic wired to `EnhancedConfidenceService` |
| Document deletion after extraction | nLPD requirement — original image never stored | LOW | Pattern documented in `DATA_ACQUISITION_STRATEGY.md`; must be enforced at pipeline level, not just in specs |
| LPP certificate parsing wired E2E (obligatoire/surobligatoire split) | Without this, rente vs capital arbitrage is unreliable — the #1 precision gap per DATA_ACQUISITION_STRATEGY.md | MEDIUM | `LppCertificateParser` exists; needs integration testing against real certificates from top 20 caisses |
| Tax declaration parsing (marginal rate extraction) | Marginal rate drives all tax-related arbitrages | MEDIUM | `TaxDeclarationParser` exists; 26 cantonal formats to validate |
| AVS extract (CI) guidance + parsing | AVS rente is the largest retirement income component; RAMD error = CHF 200-500/month projection error | MEDIUM | `AvsExtractParser` + `avs_guide_screen.dart` exist; guide UX flow needs completion |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| LLM-vision extraction for unknown caisses (BYOK path) | 1'400+ caisses in Switzerland; template matching covers ~60%; LLM covers the long tail | MEDIUM | Image sent through BYOK Claude/GPT-4o; user's own API key = their consent; requires explicit nLPD opt-in flow |
| Generic document parser with LLM fallback | Handles any Swiss financial document format not in the template library | MEDIUM | `generic_document_parser.dart` listed in DATA_ACQUISITION_STRATEGY.md but not yet in codebase; net-new service |
| Per-field extraction confidence with cross-validation | "Ce montant semble bas pour ton âge" — catches OCR errors before they corrupt projections | MEDIUM | `CrossValidationService` exists; extend to cover OCR-extracted values, not just user input |
| Progressive precision nudge at point of need | Ask for scan when user opens rente vs capital — not during onboarding; higher conversion | LOW | Extend `ProactiveTriggerService` with `documentPrecisionNeeded` trigger type |
| Annual fiscal refresh prompt (Feb-Apr) | "C'est la saison fiscale" — natural re-engagement aligned to Swiss calendar | LOW | `SeasonalEventService` exists; add `fiscal_refresh` event for Feb-Apr window |
| Document impact screen with before/after projection delta | Shows exactly what changed after scan — makes the value tangible | MEDIUM | `document_impact_screen.dart` skeleton exists; needs calculator diff logic |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic cloud OCR by default (Google Document AI / Azure) | High accuracy, less dev effort | Document leaves device — nLPD violation without explicit per-document consent; ongoing API cost per scan (~$0.02-0.10/page) | On-device ML Kit OCR as default (privacy-first); LLM via BYOK as opt-in for unknown formats |
| Storing original document images for re-extraction | "Better accuracy later" | No lawful basis under nLPD for storing financial documents; massive liability | Delete immediately after extraction; re-scan if user wants to update |
| Email forwarding adapter for automatic import | "Auto-import PDF statements" | Email access = high privacy risk; nLPD complexity; explicitly out of scope in PROJECT.md | User-initiated photograph or file upload only |
| Batch document processing | "Process all my documents at once" | UX complexity; OCR errors compound; review step skipped under batch pressure | One document at a time; review required per document |

---

### Capability 2: Anticipation Engine (Moteur d'Anticipation)

**What needs to be built:** `ProactiveTriggerService` handles coach session openers (7 triggers). The v2.0 anticipation engine is a broader concept: rule-based fiscal/legislative/profile-change alerts that appear as Aujourd'hui smart cards — persistent between sessions, not just coach openers. New trigger categories: Swiss fiscal calendar, LPP lifecycle events, legislative annual updates, stale data warnings.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Fiscal calendar alerts (3a deadline Dec 31, tax deadline Mar 31) | Swiss users routinely miss the 3a annual contribution; this is the #1 missed savings action | LOW | `DashboardCuratorService` has deadline logic; extend with Swiss fiscal calendar constants |
| Profile-change triggers (salary change → LPP cert outdated) | Profile update should immediately yield a relevant action — otherwise the update feels pointless | LOW | Listen to `CoachProfileProvider` changes; fire `documentStalenessAlert` trigger |
| Stale data warnings (certificate > 12 months old) | Data freshness axis already computed by `EnhancedConfidenceService`; surface as card | LOW | Read `freshness` axis; threshold at < 0.50 (> 12 months per DATA_ACQUISITION_STRATEGY.md scoring) |
| Legislative update notifications (annual LPP constants change) | Projections shift when conversion rates or limits change each January | MEDIUM | Flag in constants file when updated; trigger notification to users whose projections are affected |
| Lifecycle event detection → proactive card | User turns 54 → "rachat LPP window du point fiscal optimal dans 11 mois" | MEDIUM | `LifecycleDetector` + `LifecycleContentService` exist; wire output to Aujourd'hui card renderer |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Swiss fiscal calendar by canton (26 cantons) | Tax deadlines vary by canton; personalized card beats generic reminder | MEDIUM | `CantonalBenchmarkService` has 26-canton data structure; add fiscal calendar fields |
| Proactive premier éclairage recalculation on data change | When profile changes (salary, doc scan), auto-recompute and surface the delta | MEDIUM | Pipeline: profile change → recalculate key metrics → diff → format card |
| Safe Mode anticipation (debt signal detection) | Disable optimization prompts when user shows financial stress signals | MEDIUM | `DebtPreventionService` exists; wire to anticipation card suppression logic |
| JITAI-timed delivery | Show anticipation at optimal workflow moment — post-salary deposit, pre-deadline | MEDIUM | `JitaiNudgeService` trigger engine exists; extend trigger type list |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Background push notifications for every trigger | "Stay top of mind" | Notification fatigue; WorkManager out of scope for v2.0 (PROJECT.md); iOS background execution limits | In-app Aujourd'hui cards on next open; single opt-in push only for hard deadlines (3a Dec 30) |
| Predictive ML anticipation | "AI predicts your next need" | LLM cost per trigger; non-deterministic; requires training data; v2.0 scope is rule-based (PROJECT.md) | Pure rule-based; ML anticipation deferred to v3.0 |
| Daily notification cadence | Frequency = engagement | Churn driver when notifications aren't personally relevant; JITAI research shows contextual > scheduled | Session-triggered only; max 1 new card per app open |

---

### Capability 3: Financial Biography (Mémoire Narrative)

**What needs to be built:** A local-only, structured event log of financial facts, decisions, and milestones indexed by date and life event type. This is net-new — nothing in the codebase maps to it. It is distinct from `CoachMemoryService` (coach insights for LLM context) and `MemoryContextBuilder` (LLM prompt injection). The FinancialBiography is the raw source of truth. It feeds an `AnonymizedBiographySummary` for coach context and a confidence timeline for the user.

**Confidence:** MEDIUM — net-new concept; architecture pattern informed by local-first apps (Obsidian, Bear, Day One) and the project's own privacy-first principles.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Local-only storage (never sent externally) | Privacy-first — financial data is the most sensitive category; loss of trust = permanent churn | LOW | SQLite (via `sqflite` Flutter package) or SharedPreferences for simple logs; `PrivacyService` pattern in codebase |
| Event log: what happened, when, what changed | "On avait discuté de ça en janvier" — continuity is the foundation of the "companion" feeling | MEDIUM | Data model: `BiographyEvent(id, date, lifeEventTag, fieldsChanged, notes?)` |
| Decision log: actions user committed to | Track whether user followed through on CAP recommendations | MEDIUM | Linked to `CapEngine` CAP sequences and `GoalTrackerService` |
| Milestone log: first éclairage, first document scan, first arbitrage completion | Progress visualization; motivates continued engagement | LOW | Reuse `MilestoneV2Service` event types; serialize to biography |
| Export / delete all biography data | nLPD right to portability + erasure | LOW | JSON export + full delete; follow `PrivacyService` pattern |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| AnonymizedBiographySummary for coach (no PII) | Coach references history without exposing exact figures — trust without privacy risk | MEDIUM | Transform raw events → narrative text with ranges, never exact values; inject into `ContextInjectorService` |
| Biography-driven narrative coach opener | "La dernière fois tu t'inquiétais de ton LPP. Bonne nouvelle..." | MEDIUM | `CoachNarrativeService` reads biography summary; static fallback template if no biography exists |
| Biography-aware card ranking in Aujourd'hui | "Tu n'as pas regardé ton LPP depuis 8 mois" vs generic "Scanne ton certificat" | MEDIUM | `CardRankingService` reads biography for last action date per topic |
| Confidence timeline visualization | Show how confidence score evolved as user added data — makes progress tangible | LOW | Line chart from `BiographyEvent` timestamps + confidence values stored at each event |
| Life event tagging (18 events) | Biography entries tagged for filtering by event type (housing, family, career...) | LOW | `LifeEvent` enum already exists in codebase; add as tag on `BiographyEvent` model |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Cloud sync for biography | "Access on multiple devices" | Requires E2E encryption + server storage = nLPD complexity + cloud risk; explicitly out of scope (PROJECT.md) | Local-only in v2.0; encrypted iCloud/device sync is v3.0 |
| Biography data sent to LLM verbatim | "Better personalization" | Exact financial figures in LLM API prompt = privacy violation; LLM APIs are external services | Anonymized summary only; ranges not exact values; `CoachContext` rule: never salary/IBAN/name |
| Open-ended note-taking | "Let me write my thoughts" | Creates freeform PII storage; scope creep into journaling app territory | Structured events only; user notes live in coach chat conversation (already persisted) |
| Shared biography with partner | "My partner should see this" | Multi-user auth complexity; nLPD consent per person; v2.0 is single-user | Couple features via `CoachProfile` couple fields; biography stays per-device |

---

### Capability 4: Contextual Aujourd'hui (Interface Contextuelle)

**What needs to be built:** The current `MintHomeScreen` has a fixed layout: 1 chiffre vivant + 1 lever + 1 signal + coach bar. v2.0 introduces `CardRankingService`: a pure function that takes profile + biography + anticipation triggers + confidence gaps as inputs and returns up to 5 ranked `SmartCard` objects for the Aujourd'hui feed. This makes the tab dynamic — different content on every open when something relevant has changed.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Max 5 cards, never more | Cognitive overload = abandonment; "1 screen = 1 intention" principle | LOW | `DashboardCuratorService` already enforces max 4; extend to 5 for v2.0 |
| Urgency-ranked card order (deadline proximity > impact CHF > recency) | Most critical action must appear first — user only sees top 1-2 | LOW | Ranking logic in `DashboardCuratorService`; extend scoring inputs |
| Card dismissal / snooze (7 days) | User agency; prevents "I keep seeing this card" frustration | LOW | Snooze state in SharedPreferences per card ID |
| Empty state ("Tout est en ordre") | Healthy state should feel good, not broken or empty | LOW | Illustration + copy; shown only when zero urgent or medium cards exist |
| Coach input bar (always visible) | Primary entry to coaching; must never disappear | LOW | Already implemented in `MintHomeScreen`; preserve in v2.0 layout |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multi-signal card relevance scoring | Fuses: lifecycle phase, confidence gaps, biography events (last action date), fiscal calendar, anticipation triggers | MEDIUM | Pure function: `CardRankingService.rank(profile, biography, triggers) → List<SmartCard>`; deterministic + testable |
| Biography-aware card copy | "Tu n'as pas regardé ton LPP depuis 8 mois" vs generic prompt | MEDIUM | Card copy varies based on `biography.lastEventDateFor(topic)` |
| Confidence gap cards (actionable enrichment prompts) | "3 données manquantes pour des projections fiables" | LOW | `EnhancedConfidenceService.topEnrichments` already returns ranked prompts; wrap as SmartCard |
| Swiss fiscal calendar cards (date-anchored) | "3a: il te reste 14 jours pour verser CHF 3'480" | LOW | Hard-code 12 Swiss annual fiscal events + canton-specific deadlines |
| Anticipation event cards (lifecycle triggers) | "Tu approches 54 ans: la fenêtre fiscale LPP s'ouvre" | MEDIUM | Anticipation engine output → SmartCard renderer |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| More than 5 cards | "Show everything important" | Cognitive overload; users stop reading after 3; defeats intelligent ranking | Hard cap at 5; remaining accessible via "Voir tout" in Explorer |
| Financial news / market commentary feed | "Keep users informed" | Not MINT's mission; compliance risk with market commentary (LSFin); topic drift | Educational inserts from `EducationalInsertService` only; no external news integration |
| Social feed / community cards in Aujourd'hui | Community engagement | No social comparison (CLAUDE.md §5); Swiss privacy culture; feels intrusive in personal tab | Cantonal benchmarks opt-in in Explorer hub; never in main feed |
| User customization of card types | "Let me choose what I see" | Defeats intelligent ranking; users often don't know what they need | Relevance-ranked by algorithm; user signals via card dismissal (implicit feedback) |

---

### Capability 5: bLink Sandbox + Adapter Stubs

**What needs to be built:** `OpenBankingService` is fully mocked (`isEnabled=false`). v2.0 activates the sandbox path with real API calls to the bLink test environment, wires the consent dashboard, and adds typed adapter interfaces (not implementations) for pension fund and tax data. Goal: validate the end-to-end architecture with test data before production activation (v3.0).

**bLink/SFTI facts (MEDIUM confidence — training knowledge pre-Aug 2025 + project docs):**
- SFTI = Swiss Fintech Innovations industry body; bLink = Swiss Open Banking standard
- Sandbox: public test environment, no SFTI membership needed for sandbox access
- Production: SFTI membership + per-bank bilateral contracts; estimated 18-24 months (PROJECT.md)
- Data available via bLink: account balances, transaction history, 3a bank balances, mortgage details
- Data NOT available via bLink: LPP pension details, AVS history, cantonal tax rates (all separate systems)
- Consent model: explicit per-account, read-only, max 90 days, revocable at any time

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sandbox activation (real API calls to test environment) | Architecture validation; find integration bugs before production; demonstrate the flow to users | MEDIUM | Set `OpenBankingService.isEnabled=true` for sandbox env; update base URLs; parse real sandbox response format |
| Consent dashboard wired (who sees what, revoke all) | nLPD + FINMA requirement for explicit consent per data scope | LOW | `consent_dashboard_screen.dart` exists; wire to real consent model (not mock) |
| Account balance + transaction ingestion from sandbox | Core Open Banking value proof | MEDIUM | Sandbox → parse → `ProfileField<T>` with `DataSource.openBanking` |
| Salary detection from transaction patterns | More accurate than user self-report; largest regular credit = salary | MEDIUM | Rule-based: identify largest recurring monthly credit from employer |
| Confidence score update on connection | "+15-25 points" — immediate visible value per DATA_ACQUISITION_STRATEGY.md | LOW | `EnhancedConfidenceService` already has `openBanking` source weight (1.00); wire on successful connection |
| `InstitutionalPensionAdapter` interface (stub, not implementation) | Architecture contract for Publica/BVK/CPEV connections in v3.0 | LOW | Define interface + mock; no real API calls |
| `CantonalTaxAdapter` interface (stub, not implementation) | Architecture contract for AFC cantonal data | LOW | Define interface + mock |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Mortgage detection from transaction patterns | Auto-populate mortgage remaining + rate from bank feed; eliminates manual entry | MEDIUM | Identify recurring large debit from known mortgage providers (UBS, Raiffeisen, BCV, etc.) |
| 3a contribution tracking from transactions | Real annual 3a utilization vs. user estimate | LOW | Detect transfers to known 3a providers (Frankly, TrueWealth, VZ, bank 3a accounts) |
| Net salary inference from regular deposits | More precise than gross-to-net ratio estimation | LOW | From largest regular credit; detect 13th salary month from December credit pattern |
| Biography event on bLink connection | Record connection date + accuracy improvement in FinancialBiography | LOW | Fire `BiographyEvent(type: openBankingConnected, confidenceDelta: +X)` |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Production bLink activation in v2.0 | "Why wait?" | SFTI membership + per-bank contracts = 18-24 months; regulatory consultation required; explicitly out of scope (PROJECT.md) | Sandbox only; production is v3.0 |
| Transaction categorization ML model | "Smart spending insights like Cleo" | Scope creep; training data needed; Cleo/Yuh already do this better; MINT's value is pension+tax depth | Simple rule-based detection for salary/mortgage/3a only |
| Automatic investment advice from idle cash | "You have CHF 20k idle — invest it" | LSFin violation — crosses from education to advice | Surface idle cash as enrichment prompt; user initiates simulation |
| Continuous background sync | "Always up to date" | WorkManager out of scope (PROJECT.md); battery drain; 90-day consent window limits frequency anyway | User-initiated refresh on app open; alert when consent expires |

---

### Capability 6: 9-Persona QA Profond

**What needs to be built:** A structured test matrix covering 9 user archetypes — from Léa (Phase 1 baseline) to hostile edge cases. This is a delivery quality gate, not a user-facing feature. It ensures the 5 capabilities above work correctly for the full range of Swiss residents.

**Persona definitions (from PROJECT.md + CLAUDE.md archetypes):**
1. Léa — 28yo, Swiss native, first real job, Zurich, no LPP split yet (baseline)
2. Laurent — 45yo, swiss_native, married, property owner, mid-career LPP
3. Sofia — 38yo, expat_eu (Spanish), Geneva, EU totalisation applicable
4. Jake — 35yo, expat_us, FATCA, PFIC concerns, Lauren archetype
5. Marie-Claire — 52yo, cross_border frontalier, VD/France, impôt source
6. Pierre — 58yo, independent_no_lpp, 3a max, near-retirement planning
7. Mei — 29yo, independent_with_lpp, recent 3a opener, housing intent
8. Thomas — 61yo, returning_swiss (8 years abroad), rachat avantageux window
9. Couple test — Julien + Lauren golden couple (married, mixed archetypes)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Léa golden path E2E (landing → premier éclairage → plan → check-in flawless) | Foundation of v2.0 — every other capability is worthless if this breaks | MEDIUM | Léa: 28yo, swiss_native, first job, Zurich, no LPP yet |
| All 8 archetypes covered with representative profile | 8 archetypes × 18 life events = correctness matrix; missing coverage = hidden bugs | HIGH | Use `test/golden/` patterns; one test profile per archetype |
| Error recovery scenarios (API down, OCR fails, BYOK invalid key) | Mobile users have poor connectivity; graceful degradation is non-negotiable | MEDIUM | `FallbackTemplates` exists; test each failure path explicitly |
| WCAG 2.1 AA compliance audit | Switzerland has disability law; 50+ users are a primary MINT segment | MEDIUM | Contrast ratios (4.5:1 min), screen reader labels, 44px tap targets |
| Multilingual validation (6 languages × new strings) | i18n already shipped; v2.0 adds new ARB keys; diacritic errors are regressions | LOW | Check all new `BiographyEvent`, `SmartCard`, anticipation trigger keys across all 6 ARBs |
| Golden couple regression (Julien + Lauren) | Prevent calculation drift on validated reference values | LOW | Extend `test/golden/` with new v2.0 calculation flows |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Hostile scenario matrix (debt + disability + expat simultaneously) | Real life is complex; clean-path QA misses critical failure modes | HIGH | Define 20 hostile scenarios; automate with test profiles; track pass rate |
| OCR extraction accuracy tracking (per caisse) | Know which caisses have poor template match; prioritize template improvements | MEDIUM | Log extraction confidence per caisse; surface in internal analytics |
| ComplianceGuard regression on new LLM outputs | Biography narratives, smart card copy, anticipation messages = new output channels | MEDIUM | Run `/autoresearch-compliance-hardener` against all new text generation paths |
| Calculation regression gate (before/after v2.0 features) | Ensure document scanning doesn't alter existing projections for users who don't scan | MEDIUM | Golden value snapshot diff on every PR against baseline |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Manual QA by humans as primary correctness gate | "Real users find bugs" | Slow, not reproducible, expensive; MINT already has 12,892 automated tests | Human testing for emotional response + UX feel only (usability study); automated for correctness |
| QA with real user data | "Test on real data" | nLPD violation; production data cannot be used for testing | Synthetic profiles with realistic-but-fake data based on golden couple parameters |

---

## Feature Dependencies

```
[Camera/image picker]
    └──required by──> [Document scan pipeline E2E]

[Document scan pipeline E2E]
    └──requires──> [LppCertificateParser (exists, needs caisse validation)]
    └──requires──> [GenericDocumentParser (new — LLM fallback)]
    └──requires──> [ExtractionReviewScreen (exists, needs wiring)]
    └──feeds──> [EnhancedConfidenceService] (existing)
    └──feeds──> [FinancialBiography event log] (new)
    └──feeds──> [SmartCard: confidence gap resolved] (new)

[FinancialBiography]
    └──requires──> [BiographyEvent data model] (new)
    └──requires──> [Local SQLite or SharedPreferences storage]
    └──feeds──> [AnonymizedBiographySummary] (new)
    └──feeds──> [ContextInjectorService] (existing)
    └──feeds──> [CardRankingService: biography-aware ranking] (new)
    └──feeds──> [AnticipationEngine: last-action-date triggers] (new)

[AnticipationEngine]
    └──extends──> [ProactiveTriggerService] (existing — add new trigger types)
    └──requires──> [Swiss fiscal calendar data] (new constant, ~100 lines)
    └──requires──> [EnhancedConfidenceService freshness axis] (existing)
    └──requires──> [LifecycleDetector] (existing)
    └──feeds──> [CardRankingService] (new)

[CardRankingService]
    └──requires──> [AnticipationEngine outputs]
    └──requires──> [FinancialBiography events]
    └──requires──> [EnhancedConfidenceService.topEnrichments] (existing)
    └──extends──> [DashboardCuratorService] (existing)
    └──drives──> [MintHomeScreen Aujourd'hui layout] (existing, needs update)

[bLink Sandbox]
    └──requires──> [OpenBankingService.isEnabled=true for sandbox]
    └──requires──> [ConsentDashboardScreen wiring] (exists, unwired)
    └──feeds──> [EnhancedConfidenceService] (openBanking source weight 1.00)
    └──feeds──> [FinancialBiography event log]
    └──does NOT feed──> [LPP/AVS projections] (bank ≠ pension data)
    └──independent from──> [Document scan pipeline]

[InstitutionalPensionAdapter] (stub only)
    └──independent from──> [bLink Sandbox]
    └──does NOT feed──> [any calculation in v2.0]

[9-Persona QA]
    └──requires──> [Léa golden path complete] (prerequisite gate)
    └──requires──> [All 5 capabilities functional]
    └──validates──> [All 5 capabilities]
```

### Dependency Notes

- **FinancialBiography unblocks several capabilities:** Biography-aware card ranking, narrative coach openers, and biography-aware anticipation triggers all require the biography data model to exist first.
- **Anticipation engine depends on fiscal calendar data:** New constant file (Swiss fiscal events by canton); low complexity but must exist before engine can fire date-based triggers.
- **bLink sandbox is independent:** Can be developed in parallel with biography + anticipation work.
- **CardRankingService is the integration point:** It is the last piece to build — depends on biography events, anticipation engine outputs, and confidence enrichments all being stable.
- **9-persona QA is last and gates release:** Cannot validate until all features are functional.
- **Generic document parser (LLM-vision) is P2:** The template-based parsers cover 60% of users; the LLM fallback is a differentiator but not blocking for Phase 1.

---

## MVP Definition

### Launch With (v2.0 Phase 1 — Léa Golden Path)

- [ ] Document scan pipeline E2E: camera → OCR → extraction review → profile update → confidence delta display — **why:** Highest confidence score impact per user action (+25-30 pts from single LPP cert scan)
- [ ] LPP certificate parser validated against top 10 caisses by market share — **why:** LPP oblig/suroblig split is the single field that makes rente vs capital arbitrage reliable
- [ ] FinancialBiography data model + local storage (event log only, no export yet) — **why:** Required for biography-aware card ranking and coach history references
- [ ] Anticipation Engine phase 1: fiscal calendar triggers (3a Dec 31, tax Mar 31) surfaced as Aujourd'hui cards — **why:** Highest value / lowest complexity; concrete Swiss need
- [ ] CardRankingService: multi-signal ranking, max 5 cards, urgency-ranked — **why:** Makes the app feel "alive"; core v2.0 promise
- [ ] Léa golden path E2E flawless (QA persona 1) — **why:** Foundation gate; everything else builds from here

### Add After Validation (v2.0 Phase 2-5)

- [ ] Tax declaration parsing (marginal rate) — trigger: Phase 1 LPP parser stable
- [ ] AVS extract guidance + parsing — trigger: document pipeline validated
- [ ] AnonymizedBiographySummary injected into coach context — trigger: biography has ≥ 3 events per user
- [ ] bLink sandbox activation + consent dashboard wiring — trigger: Phase 1 QA passes; 9-persona matrix starts
- [ ] Generic document parser with LLM-vision fallback (BYOK) — trigger: > 20% users encountering unknown caisse format
- [ ] Remaining 8 personas QA + hostile scenario matrix — trigger: Léa golden path stable for 2 weeks
- [ ] WCAG 2.1 AA audit — trigger: all new screens complete
- [ ] `InstitutionalPensionAdapter` + `CantonalTaxAdapter` stubs — trigger: bLink sandbox validated

### Future Consideration (v3.0+)

- [ ] bLink production activation (SFTI membership + per-bank contracts) — defer: 18-24 month process
- [ ] Cloud sync for FinancialBiography — defer: E2E encryption required
- [ ] Institutional LPP API live connections (Publica, BVK, CPEV) — defer: B2B partnerships needed
- [ ] Background push notifications for anticipation — defer: WorkManager complexity + iOS restrictions
- [ ] Spending-pattern-based Safe Mode trigger — defer: transaction categorization at scale

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| LPP certificate scan E2E wiring | HIGH — unlocks reliable arbitrage | MEDIUM — parser exists, needs caisse testing | P1 |
| Fiscal calendar anticipation cards | HIGH — Swiss users miss 3a deadline | LOW — data + card renderer | P1 |
| FinancialBiography data model | HIGH — enables biography-aware everything | LOW — data model + storage | P1 |
| CardRankingService (Aujourd'hui) | HIGH — core "living system" experience | MEDIUM — multi-signal fusion | P1 |
| Léa golden path QA | HIGH — delivery gate | MEDIUM — comprehensive scenarios | P1 |
| Tax declaration parsing (marginal rate) | HIGH — drives all tax arbitrage | MEDIUM — 26 cantonal formats | P2 |
| bLink sandbox activation | MEDIUM — architecture validation | MEDIUM — env switch + consent wiring | P2 |
| AnonymizedBiographySummary for coach | MEDIUM — continuity, trust | MEDIUM — anonymization rules | P2 |
| AVS extract guidance + parsing | HIGH — RAMD accuracy | MEDIUM — guide flow exists | P2 |
| 9-persona QA + hostile matrix | HIGH — delivery quality gate | HIGH — 9 profiles × scenarios | P2 |
| WCAG 2.1 AA audit | MEDIUM — legal + 50+ users | MEDIUM — systematic audit | P2 |
| Generic parser + LLM-vision fallback | MEDIUM — long-tail caisses | HIGH — BYOK path + nLPD consent | P2 |
| InstitutionalPensionAdapter stub | LOW — future architecture | LOW — interface only | P3 |
| CantonalTaxAdapter stub | LOW — future architecture | LOW — interface only | P3 |

**Priority key:**
- P1: Must have for v2.0 to deliver its core promise
- P2: v2.0 is incomplete without these; phase in across milestones
- P3: Architecture investment for v3.0; safe to include as stubs

---

## Competitor Feature Analysis

**Note:** MEDIUM confidence — based on training knowledge (pre-Aug 2025) cross-validated against `visions/MINT_Analyse_Strategique_Benchmark.md` (March 2026, 40+ apps analyzed).

| Feature | Best Competitor | How They Do It | MINT Approach |
|---------|-----------------|----------------|---------------|
| Swiss pension document OCR | None (market gap) | No competitor has LPP-specific extraction | MINT is first mover; Swiss template library (top 20 caisses) is a durable moat |
| Proactive fiscal alerts | Cleo (UK/US), Plum (UK) | Cleo: AI-driven from transactions; Plum: rule-based savings nudges | Rule-based Swiss fiscal calendar (deterministic, cheaper, LSFin-safe); JITAI timing |
| Financial biography / memory | Cleo 3.0 | LLM-native long-term memory, cloud-stored | MINT: local-only event graph, anonymized LLM summary — privacy-first differentiator |
| Open Banking | bunq (EU), Plum (UK), Monarch (US) | Deep real-time integration; spending insights; ML categorization | MINT: bLink/SFTI sandbox (CH-specific); read-only posture; no ML categorization in v2.0 |
| Smart home screen (relevance-ranked) | Copilot Money (US) | ML-ranked insights from transaction data | MINT: rule-based + biography-aware; multi-signal fusion; no ML overhead |
| Swiss-specific depth (LPP oblig/suroblig, 8 archetypes, 26 cantons) | No competitor | n/a | Unreplicable by foreign competitor in < 18 months; structural moat |

---

## Sources

- `/Users/julienbattaglia/Desktop/MINT/docs/DATA_ACQUISITION_STRATEGY.md` — Definitive spec for document intelligence channels and OCR architecture (HIGH confidence)
- `/Users/julienbattaglia/Desktop/MINT/visions/MINT_Analyse_Strategique_Benchmark.md` — 40+ app benchmark, March 2026 (HIGH confidence)
- `/Users/julienbattaglia/Desktop/MINT/visions/vision_features.md` — Feature landscape including bLink/SFTI architecture (HIGH confidence)
- `/Users/julienbattaglia/Desktop/MINT/.planning/PROJECT.md` — v2.0 milestone scope, explicit out-of-scope list (HIGH confidence)
- `/Users/julienbattaglia/Desktop/MINT/CLAUDE.md` — Business rules, archetypes, life events, compliance constraints (HIGH confidence)
- Codebase inspection: `apps/mobile/lib/services/`, `apps/mobile/lib/screens/document_scan/`, `apps/mobile/lib/screens/main_tabs/` — Actual implementation state confirmed by file listing (HIGH confidence)
- `apps/mobile/lib/services/open_banking_service.dart` — bLink service: fully mocked, `isEnabled=false` confirmed (HIGH confidence)
- `apps/mobile/lib/services/coach/proactive_trigger_service.dart` — 7 existing triggers confirmed (HIGH confidence)
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` — Current Aujourd'hui layout confirmed (HIGH confidence)
- Competitor patterns (Cleo 3.0, Plum, Copilot Money, bunq Finn) — Training knowledge pre-Aug 2025, cross-validated against benchmark doc (MEDIUM confidence)
- bLink/SFTI sandbox requirements — Training knowledge + project docs (MEDIUM confidence; verify current SFTI sandbox URL before activation)

---

*Feature research for: MINT v2.0 — document intelligence, anticipation engine, financial biography, contextual Aujourd'hui, bLink sandbox*
*Researched: 2026-04-06*
