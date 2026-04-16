# Milestones

## v2.7 Coach Stabilisation + Document Digestion (Shipped: `<PENDING_DEVICE_GATE>`)

**Status:** Code-complete, awaiting creator-device walkthrough (GATE-01 iPhone + GATE-02 Android).
**Phases completed:** 4 phases (27, 28, 29, 30), 13 plans, ~32 tasks, ~315 new tests.
**Requirements:** 25/25 code-complete (STAB-01..05 + DOC-01..08 + PRIV-01..08 + GATE-01..04).

**Goal:** Le coach fonctionne bout en bout (MSG2 fiable, mémoire typée, réponses denses) ET
MINT digère n'importe quel document (photo / scan / screenshot / PDF) via un contrat canonique
interne, sans jamais afficher "Analyse indisponible".

**Key accomplishments:**

- **Phase 27 — Stabilisation Critique:** Redis-backed token budget (soft-cap → Haiku →
  truncate → hard-cap, 50k/day default); `LLMRouter` Sonnet→Haiku fallback + tenacity retry;
  `SLOMonitor` auto-rollback (2-consecutive-breach, 10-req floor); SHA256 idempotency;
  3 feature flags + admin endpoints for instant rollback; Flutter degraded chip (anti-shame
  italic textSecondary); agent loop re-prompt on empty-text tool_use (fixes MSG2).
- **Phase 28 — Pipeline Document Honnête:** canonical `DocumentUnderstandingResult` Pydantic
  contract shared by coach + scanner + review; fused Vision call (classify + extract in one
  prompt); pymupdf encrypted-PDF preflight + pages_processed transparency; 4 opaque render_mode
  (confirm/ask/narrative/reject); SSE streaming (3 ordered events); native scanners (VisionKit
  iOS + ML Kit Android) + local image pre-reject (16 labels, fail-open); 4 UI bubbles +
  reduced ExtractionReviewSheet (snap 0.3/0.6/0.95).
- **Phase 29 — Compliance & Privacy:** envelope encryption AES-256-GCM + per-user DEK vault +
  crypto-shredding; ISO 29184 granular consent (4 purposes) + HMAC + merkle chain; Presidio PII
  + regex fallback + FPE + fact_key allowlist (8 keys) + CI log-gate; VisionGuard Haiku
  LLM-as-judge (fail-closed) + NumericSanity deterministic bounds + FieldStatus.needs_review
  default; third-party opposable declaration + session-scoped routing; Bedrock EU router
  (off/shadow/primary) + two-stage image masker + DPA technical annex + legal checklist.
- **Phase 30 — Device & Test Gate:** 10 PII-clean corpus fixtures + 17 Vision cassettes +
  golden flow pytest (17 parametrised + 2 aggregators, 19 green) + warn-only CI (graduates
  2026-04-28); bilingual FR/EN device-gate checklist (36 checkboxes covering 25 REQs);
  performance report template; legal sign-off template.

**Known carryover:**

- **GATE-01, GATE-02** — creator-device walkthrough (iPhone + Android) blocking milestone
  shipped-date stamp. Checklist in `docs/DEVICE_GATE_V27_CHECKLIST.md`.
- Pre-existing failures on `test_agent_loop.py` + `test_docling.py` (unrelated to v2.7, out-of-scope).
- Encrypted-PDF VisionGuard overwrite (one-line fix deferred to v2.8).
- Legal sign-off session pending (Walder Wyss / MLL Legal) — template in
  `docs/LEGAL_SIGNOFF_V27.md`.

**Follow-ups to v2.8:** TokenBudget.kind tagging, RAG → LLMRouter migration, JSONB GIN index,
Presidio NER upgrade, default scanner path flip, real-Vision cassette recorder, BEDROCK_EU flip,
MASK_PII_BEFORE_VISION enable.

**Next milestone:** v2.8 "La Confiance" — Privacy Nutrition Label + Data Vault + Trust Mode +
Graduation Protocol v1. Scope TBD via `/gsd-start-milestone v2.8`.

---

## v2.1 Stabilisation v2.0 (Shipped: 2026-04-07)

**Phases completed:** 1 phase (Phase 7), 6 plans, 16/17 STAB requirements DONE

**Goal:** Stabilize v2.0 before TestFlight — close the coach tool-call choreography end-to-end, run the 6-axis façade-sans-câblage audit, refresh Phase 1 tests, clean lints, bring CI green. No new features.

**Key accomplishments:**

- 4 coach tools (route_to_screen, generate_document, generate_financial_plan, record_check_in) wired end-to-end on both BYOK and RAG paths, guarded by a 4/4 integration test (`coach_tool_choreography_test.dart`) and re-exposing `toolCalls` through `CoachLlmService.chat`
- 6-axis façade-sans-câblage audit completed (coach wiring, dead code, orphan routes, contract drift, swallowed errors, tap-render) — root cause `RAGQueryRequest`/`Response` tool-field drift identified and fixed, unblocking the entire `/rag/query` transport for all 7 user-visible tools
- Audit fix sweep: 11 dead services deleted (pulse_hero_engine, recommendations, retirement_budget, scenario_narrator, timeline, fiscal_intelligence, wizard_conditions, +4 dead), 4 P0 providers registered in production `app.dart`, 5 orphan renderer cases removed, 3 backend + 5 mobile black-hole catches surfaced via debug logs
- Phase 1 test refresh aligned `auth_screens_smoke_test.dart` and `intent_screen_test.dart` with the magic-link redesign and the plan_screen ownership move; IntentScreen async-gap fix (BuildContext after await) at line 195
- Lint hygiene: backend ruff 43 → 0 errors, `flutter analyze lib/` warnings → 0
- CI on `dev` brought fully green across Backend / Flutter widgets / services / screens / CI Gate jobs
- AUDIT_TAP_RENDER scaffold delivered: every primary-depth `onTap`/`onPressed`/`onChanged`/`onSubmit` enumerated across 3 tabs + drawer, ready for Julien's manual walkthrough

**Known carryover (see `.planning/backlog/STAB-carryover.md`):**

- ⚠ **STAB-17 — Manual tap-to-render walkthrough**: scaffold ready in `AUDIT_TAP_RENDER.md`, requires real-device interaction. **Explicitly carried into v2.2 as a Phase 0 manual gate blocking TestFlight.** v2.1 ships without it because the human-only nature of the audit is incompatible with closing v2.1, but TestFlight remains gated on its completion.
- 12 orphan GoRouter routes (deferred to v3.0 cleanup, enumerated in AUDIT_ORPHAN_ROUTES.md)
- ~65 NEEDS-VERIFY try/except blocks (best-effort by grep pattern, address opportunistically)
- 1 stale test in `chat_tool_dispatcher_test.dart` (asserts `null`, now returns `/rente-vs-capital` after STAB-01)

---

## v2.0 Mint Systeme Vivant (Shipped: 2026-04-07)

**Phases completed:** 6 phases, 24 plans, 47 tasks

**Key accomplishments:**

- MintLoadingState and MintErrorState reusable widgets with 12 tests, promise_screen refined as single-CTA landing, 16 i18n keys across 6 languages
- Passwordless magic link auth (primary) with SHA-256 token hashing, Resend API email, 30s countdown UX, and post-auth routing to onboarding/home
- 4-screen onboarding pipeline (intent -> quick-start -> chiffre-choc -> plan -> coach) with modern inputs, 4-layer insight engine in backend coach prompt, and 12 firstJob backend tests
- 17 service-level integration tests covering full Lea (22, VD, firstJob) onboarding pipeline: intent routing, data flow, onboarding flag lifecycle, input validation edge cases, and VD regional voice
- Apple Sign-In as secondary iOS auth with nonce-based security, backend JWT verification, and platform-guarded login screen button
- Pre-extraction classification via Claude Vision, DocumentAuditLog with SHA-256 hashed user IDs, and finally-block image deletion for nLPD compliance
- LPP plan type detection (legal/surobligatoire/1e) with conversion rate suppression for 1e plans, cross-field coherence validation with 5% tolerance and 10x error detection, and mandatory source_text enforcement
- Per-field confidence thresholds (salary 0.90, LPP 0.95), LPP 1e/coherence warning banners, source_text display, and 422 pre-validation error handling with 10 i18n keys in 6 languages
- 4-layer insight engine applied to extracted document data with Claude API, displayed on impact screen with graceful degradation and 5 new i18n keys in 6 languages
- Encrypted local SQLite biography store with two-tier freshness decay, graph-linked facts, and Provider state management
- Whitelist anonymization pipeline (salary->5k, LPP/3a->10k) with coach BIOGRAPHY AWARENESS rules enforcing conditional language, source dating, and max 1 biography reference per response
- Privacy control screen ("Ce que MINT sait de toi") with grouped fact cards, inline edit bottom sheet, destructive delete dialog, freshness indicators, and 9 widget tests
- Wired sqflite_sqlcipher production database in BiographyRepository and registered BiographyProvider in app MultiProvider, unblocking encrypted biography storage, coach biography context, and privacy control screen
- Pure stateless AnticipationEngine with 5 trigger types (3a deadline, cantonal tax, LPP rachat, salary increase, age milestone), 26-canton deadline map, and 44 unit tests -- zero async/LLM per ANT-08
- AnticipationProvider with ComplianceGuard gate, AnticipationSignalCard educational widget, MintHomeScreen wiring (after Chiffre Vivant), and 12 i18n keys in 6 languages
- ContextualCard sealed class with 5 subtypes, deterministic ranking service, 3 detectors, and 4 card widgets -- all pure static, 19 tests green, zero DateTime.now()
- Biography-aware CoachOpenerService with 5-priority compliance-validated greeting, ContextualCardProvider orchestrating ranking + opener, MintHomeScreen rewired to unified 5-card feed with deep-links, 25 i18n keys in 6 languages
- 8 persona golden path tests covering all 8 Swiss archetypes with DocumentFactory and error recovery scenarios (220 journey tests pass)
- 9 golden screenshot baselines for 4 v2.0 screens (2 phone sizes + DE) with integration test scripts for onboarding and document flows
- 50 tests validating ComplianceGuard on all 4 v2.0 output channels (alerts, biography, openers, extraction) plus DE/IT financial terminology accuracy at >= 85% coverage
- WCAG 2.1 AA contrast/tap/scaling tests + zero-hardcoded-string detection across 6 ARB languages with 62 total test assertions
- Phase 6 test directories (journeys, accessibility, i18n, golden_screenshots) wired into CI screens shard with 1.5%-tolerant golden comparator and Patrol manual gate policy
- Darkened 4 status colors (error/info/success/warning) to WCAG AA 4.5:1, enforced strict thresholds in tests, aligned QA-09 requirement text with data-factory implementation

---

## v1.0 MVP Pipeline — Complete (31/31 requirements, all gaps resolved)

**Phases completed:** 8 phases, 20 plans, 34 tasks

**Key accomplishments:**

- Deleted lib/services/coach/coach_narrative_service.dart (206-line duplicate) and verified zero broken imports across 6451 passing tests
- 1. [Rule 3 - Blocking] NavigationShellState class embedded in pulse_screen.dart
- One-liner:
- SLM path
- One-liner:
- One-liner:
- One-liner:
- FinancialPlan model + SharedPreferences service + reactive provider with postFrameCallback-safe staleness detection, plus 12 plan card i18n keys across 6 languages
- Calculator-backed plan generation with ArbitrageEngine branching, inline chat PlanPreviewCard with T-04-04 threat mitigation (numbers from provider not LLM), and FinancialPlanProvider registered with staleness wiring in app.dart
- One-liner:
- WidgetRenderer
- One-liner:
- One-liner:
- One-liner:
- 63 standalone Flutter journey tests covering firstJob (19), housingPurchase (21), and newJob (23) E2E flows — intent chip to CapSequence step status to calculator routes, verified against Julien golden profile.
- Fixed 2 navigation-breaking GoRouter route mismatches and added stress_prevoyance case routing firstJob premier eclairage to 3a/compound growth numbers instead of hourly rate
- AnimatedSwitcher crossfade on signal card slot (300ms in/150ms out) and new ConfidenceScoreCard surfacing projection precision with top enrichment action on Aujourd'hui tab
- Explorer hubs show opacity/dot/blocked states driven by CoachProfile field presence, and onboarding routes (/onboarding/intent, /coach/chat) use CustomTransitionPage 350ms fade replacing Material slide

---
