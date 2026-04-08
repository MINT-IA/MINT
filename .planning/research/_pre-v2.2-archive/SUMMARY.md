# Project Research Summary

**Project:** MINT v2.0 Système Vivant
**Domain:** Swiss fintech mobile app — document intelligence, proactive anticipation, financial biography, contextual UI, Open Banking (bLink)
**Researched:** 2026-04-06
**Confidence:** HIGH (grounded in direct codebase audit of 652 Flutter + 293 backend source files, project planning docs, and Swiss compliance framework)

---

## Executive Summary

MINT v2.0 adds five capability layers on top of an already-functional Swiss fintech app: document intelligence (photo/PDF ingestion with LLM extraction), an anticipation engine (rule-based proactive fiscal alerts), a financial biography (local-only encrypted narrative memory), contextual smart card ranking for the Aujourd'hui tab, and bLink Open Banking sandbox activation. The architecture is evolutionary, not revolutionary — the codebase already contains 80% of the infrastructure (parsers, OCR, triggers, memory services, banking stubs, dashboard curator) but the pieces are either unwired, feature-flagged off, or missing the final integration layer. The primary engineering challenge is wiring, not building from scratch.

The recommended approach is a strictly ordered build sequence driven by data dependencies: document intelligence and financial biography must precede anticipation engine and card ranking, because the latter two consume the outputs of the former two. bLink is the exception — it is architecturally independent and can run in parallel. The capstone is the 9-persona QA matrix, which gates release by validating all capabilities across the full 8-archetype matrix before any feature reaches production.

The key risks are compliance and data integrity, not technical complexity. Three pitfalls can cause irreversible user trust damage: LLM vision hallucinating financial values that pass range validation (wrong LPP projection the user acts on), document images containing PII leaking to logs (nLPD P0 violation), and the financial biography silently injecting exact salary figures into coach context sent to the Anthropic API (nLPD + CLAUDE.md §6 violation). All three are preventable with specific enforcement patterns defined in PITFALLS.md and must be addressed in Phase 1, not retrofitted.

---

## Key Findings

### Recommended Stack

The stack delta for v2.0 is deliberately minimal — 5 new Flutter packages and 3 backend changes against a large existing dependency tree. The existing infrastructure (Flutter + FastAPI + Pydantic v2 + Anthropic SDK + google_mlkit_text_recognition + flutter_local_notifications + flutter_secure_storage) already covers the majority of what is needed. The additions are surgical gap-fills.

**Core new technologies:**
- `sqflite ^2.4.1` (Flutter): Local SQLite for FinancialBiography append-only event store — chosen over Hive (fragile encryption adapter), Isar (major API break in v4), and Drift (build_runner overhead)
- `encrypt ^5.0.3` (Flutter): AES-256-GCM application-layer encryption for biography rows — avoids SQLCipher which would break iOS Podfile.lock and Android NDK config
- `flutter_image_compress ^2.3.0` (Flutter): Compress camera photos from 3-8 MB to ~800 KB before Claude Vision upload — raw images exceed Claude's 5 MB base64 limit
- `flutter_web_auth_2 ^4.0.1` (Flutter): OAuth 2.0 PKCE flow for bLink in system browser (not WebView — SIX explicitly prohibits WebView for consent screens)
- `sqflite_common_ffi ^2.3.4` (Flutter): Desktop/test compatibility for CI on macos-15 runner
- `pillow >=10.4.0,<12.0.0` (Backend): Server-side image normalization (EXIF rotation, greyscale) — Claude Vision does not auto-correct orientation from EXIF metadata
- `pdf2image >=1.17.0,<2.0.0` + system `poppler` (Backend): Convert scanned PDFs (images, not text-layer) to PIL images for the Claude Vision path — `pdfplumber` cannot handle scanned PDFs
- `httpx` promoted from dev to prod (Backend): Async HTTP for bLink API calls — already present in test extras

**Critical implementation note from STACK.md:** Wire the HTTP route to the already-existing `document_vision_service.py` before adding any new packages — the document intelligence backend service exists but has no registered FastAPI endpoint.

### Expected Features

The feature research reveals a consistent pattern: most table-stakes features have existing service shells that are not fully wired. The differentiators require net-new logic but follow established codebase patterns. Anti-features are well-defined and should be enforced as hard constraints from day one.

**Must have (table stakes):**
- Document scan pipeline E2E: camera → OCR → extraction review screen → profile update → confidence delta display — infrastructure exists, needs wiring
- LPP certificate parsing validated against top 10 caisses (obligatoire/surobligatoire split) — parser exists, caisse-specific validation is the gap
- Fiscal calendar alerts (3a deadline Dec 31, cantonal tax deadlines) — highest user value per complexity ratio
- Max 5 ranked smart cards on Aujourd'hui (urgency > CHF impact > deadline proximity) — `DashboardCuratorService` exists, ranking signal expansion needed
- Card dismissal/snooze (7 days per card) and empty state ("Tout est en ordre")
- Lea golden path E2E flawless (28yo, swiss_native, first job, Zurich) — prerequisite gate for all v2.0 features

**Should have (differentiators):**
- LLM-vision extraction for unknown caisses via BYOK (1'400+ caisses in Switzerland; template matching covers ~60%)
- AnonymizedBiographySummary injected into coach context — narrative continuity without PII
- Biography-aware card copy ("Tu n'as pas regarde ton LPP depuis 8 mois" vs generic)
- Swiss fiscal calendar by canton (26 cantonal deadline variants)
- Safe Mode anticipation: suppress optimization prompts when debt stress signals detected
- bLink sandbox: real OAuth flow, consent dashboard wired, salary detection from transaction patterns

**Defer to v3.0+ (explicitly out of scope per PROJECT.md):**
- Background processing / WorkManager for always-on anticipation
- bLink production activation (18-24 months SFTI membership + per-bank contracts)
- Cloud sync for FinancialBiography (requires E2E encryption + server storage — nLPD complexity)
- Transaction categorization ML model (Cleo/Yuh do this better; MINT's value is pension+tax depth)
- Predictive ML anticipation (v3.0 scope; v2.0 is deterministic rule-based only)

### Architecture Approach

The architecture is an extension of the existing Flutter Provider + FastAPI pattern, with four new service directories added to the Flutter layer and three new backend service modules. The critical architectural principle is separation of concerns by privacy boundary: `FinancialBiography` is Flutter-only and never sent externally; `AnticipationEngine` is zero-LLM rule evaluation; only the coach narration of alerts passes through `ComplianceGuard`. The `DataIngestionService` uses an adapter pattern to unify four distinct input channels (photo, PDF, bLink, pension stub) behind a single interface, preventing document-type logic from leaking into screens.

**Major components:**
1. `DataIngestionService` (Flutter) — Adapter facade: detects input type, routes to typed adapter, returns `ProfileEnrichmentDiff`, deletes original image (nLPD)
2. `FinancialBiography` (Flutter-only) — Local append-only SQLite event store; `BiographyAnonymizer` produces PII-free summary for coach context injection
3. `AnticipationEngine` (Flutter) — Pure rule evaluation against `CoachProfile` + fiscal calendar JSON; zero LLM; debounced max once/hour; outputs `AnticipationAlert[]`
4. `CardRankingService` (Flutter) — Scoring formula (urgency x3, CHF impact x2, deadline x2, completeness delta x1, recency penalty x-0.5); max 5 cards; replaces static `DashboardCuratorService` for Aujourd'hui
5. `BlinkAdapterService` (Flutter + Backend) — OAuth 2.0 PKCE via system browser; backend proxies bLink sandbox API; maps account data to `ProfileEnrichmentDiff`
6. `DocumentExtractionService` (Backend) — Extends existing `docling/` + `document_parser/` with LLM extraction, `ProfileEnrichmentDiff` output, and `extractedAt` decay model
7. `ProfileEnrichmentDiff` pattern — All external data sources produce a diff reviewed by the user before any value reaches `CoachProfile` (compliance + OCR error protection)

**`financial_core/` is untouched.** New services are consumers of the 8 existing calculators, not modifiers.

### Critical Pitfalls

1. **LPP 1e plan type blindness** — Applying the 6.8% legal minimum conversion rate to a 1e plan (individual investment risk, no guaranteed rate) produces rente projections 40-60% too high. Prevention: detect plan type (keywords: "enveloppement libre", "1e", "freie Vorsorge") before any conversion-rate extraction; if 1e detected, set `tauxConversion = null` and refuse to project a rente. Address in Phase 1.

2. **LLM Vision hallucinating values that pass range validation** — Claude Vision on a degraded photo returns plausible-but-wrong CHF amounts that pass the existing 0-5M range check. Prevention: require `source_text` for every extracted field; auto-downgrade to LOW confidence if absent; show verbatim source text in confirmation UI. Address in Phase 1.

3. **Document PII leaked to logs or retained after extraction** — `logger.debug()` near base64 image handling writes document fragments (IBANs, names, salaries) to Railway production logs. nLPD art. 6 P0 violation. Prevention: test that log output contains no base64 patterns; explicit `finally` block for temp file deletion. Address in Phase 1.

4. **Alert fatigue from simultaneous rule firing** — New user with complete profile triggers 4-8 rules simultaneously. After two dismissal sessions, MINT has trained the user to ignore all alerts including critical ones. Prevention: hard cap at 3 alert cards (truncation, not guideline); 7-day quiet period per rule post-dismissal; first-session grace (1 alert only). Address in Phase 2.

5. **FinancialBiography leaking PII into coach context** — `saveInsight()` called with unprocessed LLM response injects verbatim salary + employer into the Anthropic API system prompt. Prevention: PII redaction inside `saveInsight()` (non-bypassable); insight summary = topic category + magnitude bucket, never exact CHF amounts. Address in Phase 3.

---

## Implications for Roadmap

Based on research, the dependency graph is unambiguous about phase ordering. FinancialBiography must precede AnticipationEngine and CardRanking (both consume biography signals). Document Intelligence must precede everything else (it feeds biography, boosts confidence, and validates the extraction pipeline the entire app depends on). bLink is independent and can run in parallel. QA is last.

### Phase 1: Document Intelligence (Intelligence Documentaire)
**Rationale:** Highest confidence score impact per user action (+25-30 points from a single LPP cert scan). The pipeline is 80% built — the gap is wiring `document_vision_service.py` to a FastAPI endpoint, adding image compression + normalization, and enforcing the `extractedAt` decay model at extraction time. This is the foundation: every subsequent feature consumes the extracted profile data.
**Delivers:** Full document scan pipeline E2E (photo → OCR → LLM extraction → review screen → profile update → confidence delta display). LPP certificate parser validated against top 10 caisses. `ProfileEnrichmentDiff` pattern established. `extractedAt` decay model enforced at extraction time.
**Addresses features:** Camera + gallery picker, extraction review, per-field source badge, confidence delta, document deletion, LPP E2E with obligatoire/surobligatoire split
**Avoids pitfalls:** Pitfall 1 (1e plan blindness), Pitfall 2 (hallucination + source_text enforcement), Pitfall 3 (PII in logs + temp file cleanup), Pitfall 7 (stale data decay model set at extraction time)
**Stack needed:** `flutter_image_compress`, `pillow`, `pdf2image`, poppler system dep, wire HTTP route to existing `document_vision_service.py`

### Phase 2: Financial Biography (Memoire Narrative)
**Rationale:** Required by both Phase 3 (AnticipationEngine uses last-action-date triggers from biography) and Phase 4 (CardRankingService uses biography for biography-aware card copy). Cannot skip — it unblocks the two highest-value capabilities.
**Delivers:** `FinancialBiography` append-only SQLite store with AES-256-GCM encryption. `BiographyEvent` recorded for document scans, life event triggers, and arbitrage decisions. `AnonymizedBiographySummary` injected into coach context via `ContextInjectorService`.
**Addresses features:** Event log, decision log, milestone log, coach history references, biography-aware card ranking signal
**Avoids pitfalls:** Pitfall 5 (PII in coach context — `_redactPii()` inside `saveInsight()`, topic + magnitude buckets only)
**Stack needed:** `sqflite ^2.4.1`, `sqflite_common_ffi ^2.3.4`, `encrypt ^5.0.3`

### Phase 3: Anticipation Engine (Moteur d'Anticipation)
**Rationale:** Depends on biography (last-action-date triggers) and document pipeline (data freshness signals). By Phase 3, both inputs are stable. The engine itself is pure Dart rule evaluation — zero new packages, zero LLM calls. Core risk is alert fatigue if the hard cap and quiet-period mechanics are not enforced from the first rule added.
**Delivers:** `AnticipationEngine` with Swiss fiscal calendar (3a Dec 31, cantonal tax deadlines), profile-change triggers (stale certificate, salary gap), and lifecycle triggers (age 54 rachat window). All 8 archetypes filtered correctly. Feeds `CardRankingService` and the coach proactive trigger loop.
**Addresses features:** Fiscal calendar alerts, profile-change triggers, stale data warnings, lifecycle event detection, Safe Mode debt suppression
**Avoids pitfalls:** Pitfall 4 (alert fatigue — max 3 cards, 7-day quiet period, first-session grace), Pitfall 8 (archetype filtering — every rule must declare `applicable_archetypes`), Pitfall 7 (staleness alert fires before December deadline)
**Stack needed:** None (pure code: `assets/config/fiscal_calendar.json` + Dart rule classes)

### Phase 4: Contextual Aujourd'hui — Smart Card Ranking
**Rationale:** Integration phase — consumes outputs from all three preceding phases. `CardRankingService` is the last piece to build because it depends on biography events (Phase 2), anticipation engine outputs (Phase 3), and confidence enrichments (Phase 1). This phase delivers the v2.0 core promise of a "living" app.
**Delivers:** `CardRankingService` with multi-signal scoring. Max 5 ranked cards. Biography-aware card copy. Swiss fiscal calendar cards. Empty state. Replaces static `DashboardCuratorService` as the primary Aujourd'hui content source.
**Addresses features:** Max 5 cards, urgency-ranked order, card dismissal/snooze, empty state, coach input bar preserved, multi-signal relevance scoring, biography-aware copy, confidence gap cards, fiscal calendar cards
**Stack needed:** None (pure Dart logic consuming Phase 1-3 outputs)

### Phase 5: bLink Open Banking Sandbox
**Rationale:** Independent from Phases 1-4 — no cross-dependency. Can be developed in parallel if bandwidth allows. Placed last in sequential ordering because it is the most complex OAuth dance and carries the most risk of shaping wrong UX patterns if the OAuth redirect flow is not simulated fully even in sandbox mode.
**Delivers:** `BlinkAdapterService` with real bLink sandbox API calls. Full OAuth 2.0 PKCE flow via system browser. Consent dashboard wired. Account balance + transaction ingestion. Salary detection, mortgage detection, 3a contribution tracking from transaction patterns. `BankingConsentModel` schema production-ready (nullable OAuth token fields added now). `InstitutionalPensionAdapter` and `CantonalTaxAdapter` interface stubs.
**Addresses features:** Sandbox activation, consent dashboard, account ingestion, salary detection, confidence score update (+15-25 points on connection), adapter stubs for v3.0
**Avoids pitfalls:** Pitfall 6 (OAuth gap — schema production-ready with nullable token fields; full redirect flow simulated in sandbox; no in-memory ConsentManager fallback on staging)
**Stack needed:** `flutter_web_auth_2 ^4.0.1`, `httpx` promoted from dev to prod deps

### Phase 6: 9-Persona QA Profond
**Rationale:** Gates release. Cannot begin until all 5 capability phases are functional. The Lea golden path (Phase 1 prerequisite) must pass before this phase opens. The 9-persona matrix validates correctness across all 8 archetypes and hostile scenarios.
**Delivers:** 9 test profiles run against all v2.0 capabilities. ComplianceGuard regression on new LLM output channels. WCAG 2.1 AA audit. i18n validation (6 languages x new ARB keys). Calculation regression gate. Hostile scenario matrix (20 scenarios: debt + disability + expat simultaneously, API down, OCR fails, BYOK invalid key).
**Stack needed:** None (test tooling only)

---

### Phase Ordering Rationale

- **Phases 1 to 4 are strictly ordered by data dependency:** Document pipeline produces `extractedAt` decay data and triggers biography events. Biography provides last-action-date signals. Anticipation engine consumes both. Card ranking integrates all three.
- **Phase 5 is parallel-eligible:** bLink has zero dependency on Phases 1-4. If bandwidth allows, it can start alongside Phase 2 or 3.
- **Phase 6 is always last:** QA validates all capabilities together and cannot open until all features are stable.
- **Lea golden path is the Phase 1 exit gate:** If the baseline persona does not flow flawlessly through document scan → premier eclairage → plan → check-in, Phase 2 does not start.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5 (bLink Sandbox):** bLink/SFTI sandbox API documentation, exact OAuth 2.0 endpoint URLs, required scopes, and sandbox credential provisioning process should be verified against current SFTI docs before implementation. Training knowledge cutoff is Aug 2025 and the bLink API may have changed.
- **Phase 1 (LPP certificate parser validation):** Top 10 Swiss caisses by market share need actual certificate specimens for parser template validation. Coverage gaps will only be known with real documents.

Phases with well-documented patterns (standard implementation, skip deep research):
- **Phase 2 (Financial Biography):** Append-only local SQLite + AES-256-GCM is a standard local-first app pattern. `sqflite` + `encrypt` has established Flutter ecosystem documentation.
- **Phase 3 (Anticipation Engine):** Pure Dart rule evaluation with Swiss fiscal calendar constants. No external integration, no ambiguous patterns.
- **Phase 4 (Card Ranking):** Pure function scoring — deterministic, no external API, well-understood weighted-sum pattern.
- **Phase 6 (QA):** `test/golden/` patterns already established in the codebase. Julien + Lauren golden couple test infrastructure exists.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Direct `pubspec.yaml` + `pyproject.toml` audit; existing package versions confirmed; delta packages are established Flutter/Python ecosystem standards |
| Features | HIGH (table stakes) / MEDIUM (differentiators) | Table stakes grounded in codebase inspection and PROJECT.md; differentiators rely on competitive pattern assessment from pre-Aug 2025 training knowledge |
| Architecture | HIGH | Direct inspection of 652 Flutter + 293 backend source files; component boundaries match existing codebase patterns; data flow derivable from existing service wiring |
| Pitfalls | HIGH | Grounded in MINT's own codebase (actual code paths in `document_vision_service.py`, `lpp_certificate_parser.py`, `blink_connector.py`, `coach_memory_service.dart`) and W1-W14 audit history |

**Overall confidence:** HIGH

### Gaps to Address

- **bLink API current state:** bLink/SFTI sandbox endpoint URLs, current API version, and required scopes should be verified against current SFTI documentation before Phase 5 implementation begins.
- **`encrypt ^5.0.3` version verification:** Verify this is the current stable version on pub.dev before adding to `pubspec.yaml`. MEDIUM confidence from training data.
- **`flutter_image_compress` Android NDK compatibility:** Verify against current `apps/mobile/android/` NDK configuration before adding — Android side requires native build setup.
- **LPP caisse template coverage:** The 60% template-match estimate for known caisses is an approximation. Actual coverage depends on which caisses users have — measure after Phase 1 ships using extraction confidence distribution data.
- **bLink data scope boundary:** LPP pension details, AVS history, and cantonal tax rates are confirmed to be outside bLink's data scope. Any feature that implies bLink can fetch these must be rejected.

---

## Sources

### Primary (HIGH confidence — direct codebase audit)
- `apps/mobile/pubspec.yaml` + `services/backend/pyproject.toml` — current dependency inventory
- `services/backend/app/services/document_vision_service.py` — Vision extraction pipeline (exists, no HTTP route registered)
- `services/backend/app/services/open_banking/blink_connector.py` — sandbox mock structure, `NotImplementedError` production paths
- `services/backend/app/services/document_parser/lpp_certificate_parser.py` — LPP field extraction, plan type gap
- `apps/mobile/lib/services/coach/proactive_trigger_service.dart` — 8 existing triggers, SharedPreferences pattern
- `apps/mobile/lib/services/memory/coach_memory_service.dart` + `memory_context_builder.dart` — PII defense patterns and their gaps
- `apps/mobile/lib/services/ocr_sanitizer.dart` — security contract, AVS masking
- `.planning/PROJECT.md` — feature scope, v2.0 requirements, explicit v3.0 deferrals
- `CLAUDE.md` §5 (LPP constants, plan types), §6 (compliance rules), §8 (golden couple test parameters)
- W1-W14 audit findings: `feedback_facade_sans_cablage.md`, `feedback_audit_inter_layer_contracts.md`

### Secondary (MEDIUM confidence — established ecosystem standards + Swiss law)
- Swiss law: LPP art. 14 (6.8% minimum), LPP art. 79b al. 3 (rachat blocking), nLPD art. 6 (data minimization), nLPD art. 24 (breach notification)
- FINMA Circular 2008/21 (operational risk — document handling)
- `sqflite ^2.4.1` — stable, widely-used Flutter SQLite package (ecosystem standard)
- `flutter_web_auth_2 ^4.0.1` — successor to deprecated `flutter_web_auth`; same maintainer

### Tertiary (LOW-MEDIUM confidence — training knowledge, verify before use)
- bLink/SFTI sandbox API details (endpoints, scopes, credential provisioning) — training data pre-Aug 2025; verify against current SFTI docs
- `encrypt ^5.0.3` specific version — verify on pub.dev before pinning
- `flutter_image_compress` Android NDK compatibility — verify against current project NDK config

---

*Research completed: 2026-04-06*
*Ready for roadmap: yes*
