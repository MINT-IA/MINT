# Milestones

## v2.8 L'Oracle & La Boucle (Shipped: 2026-04-25)

**Phases completed:** 5 phases, 17 plans, 40 tasks

**Key accomplishments:**

- pytest + node:test stubs, drift dashboard CLI skeleton, memory_gate CLI, 20 golden prompts, A4+A7 spikes (both GREEN), and CLAUDE.md structural lint skeletons — all 21 tests collected, smoke.sh green, zero production logic.
- Ships CTX-02 end-to-end: 5-table drift.db schema, 6-subcommand CLI, 4 ingesters, 2 early-ship FR lints, gsd-prompt-guard.js v1.33.0 with never-throw context_hits logging, and baseline J0 snapshot locked per D-12 (drift=79.5%, context_hit=4.8%, token_cost=206.9M tokens/session avg). 9 pytest passes + 3 node test passes.
- 1. [Rule 1 — Bug] Pre-existing orphan link in MEMORY.md surfaced by new verify gate
- None — plan executed exactly as written.
- Found during:
- CTX-05 spike dogfoods the v2.8 context-sanity refonte by bumping `sentry_flutter 8 -> 9.14.0`, wrapping `MintApp` with `SentryWidget`, and pinning `options.privacy.maskAllText/maskAllImages = true` on a fresh-context branch; 5/5 mechanical grid + 0 dashboard regression = D-21 PASS, kill-policy D-01 Modeste 1 fallback NOT triggered, Phase 30.6 ships.
- Dedicated Python 3.11 venv with pinned mcp SDK, additive scan_text(text) helper for accent_lint_fr.py, and CLAUDE.md baseline captured (121 lines / 8019 bytes / ~2004 est-tokens) for Wave 3 trim verification.
- Shipped `get_swiss_constants(category)` and `check_banned_terms(text)` as pure Python wrappers over the backend RegulatoryRegistry singleton and ComplianceGuard Layer 1 — zero constant duplication, 21 new pytest cases green, ComplianceGuard cold-start 150 ms (target < 500 ms).
- Shipped `validate_arb_parity()` (subprocess wrapper with Phase-34-graceful fallback) and `check_accent_patterns(text)` (wraps Wave 0 `scan_text`) as pure Python functions with Pydantic v2 response envelopes — 32 new pytest cases green, full suite 74 passing, zero PATTERNS duplication, `tools/checks/arb_parity.py` confirmed absent pre-Phase-34.
- FastMCP stdio server shipped with 4 `@mcp.tool()` wrappers over Wave 1 surfaces, stdout is JSON-RPC only (Pitfall 1 regression gate green), `.mcp.json` at repo root pins `python3.11` + `PYTHONPATH` — Wave 3 CLAUDE.md trim unblocked.
- CLAUDE.md trimmed atomically -30% on 3/3 dimensions via MCP tools migration. Commit `43a38dff` ships as the single-commit kill-switch target. T2 semantic cold-read + kill-switch rehearsal passed ; Julien APPROVED 2026-04-22. J0 fresh-session smoke deferred to post-merge on creator's machine (documented below).
- 17 scaffolding artefacts + sentry-cli 3.3.5 + OBS-01 mechanically verified SHIPPED on CTX-05 output — Wave 1-4 executors now have mechanical gates (not façade claims).
- 3 atomic commits on `feature/v2.8-phase-31-instrumenter`. 2 new lib files + 6 edits + 8 test files flipped live (15 tests green). 10 VALIDATION rows 31-01-01..10 automated green.
- FastAPI `global_exception_handler` now surfaces `trace_id` + `sentry_event_id` in the 500 JSON body, echoes `X-Trace-Id` in headers, and reads inbound mobile `sentry-trace` to close the end-to-end Sentry cross-project link. 3 backend tests green, zero regression, staging integration proven.
- OBS-06 kill-gate artefact signed `automated (pre-creator-device) — 2026-04-19`. 5 sensitive screens inventoried; 1 CustomPaint found, 1 wrapped in MintCustomPaintMask. audit_artefact_shape.py exit 0. Prod sessionSampleRate stays 0.0 per D-01 Option C — this plan does NOT authorise a prod flip.
- OBS-07 budget artefact + fresh pricing fetch shipped. A3 assumption (Business tier $80/mo) VERIFIED on 2026-04-19. D-02 Option A single-project + env-tag and D-04 $160/mo ceiling documented end-to-end with quota projection, sample rate reference, spend alerting, 4 revisit triggers, and secrets inventory. sentry_quota_smoke.sh upgraded with 24h [PASS] probe + 30d MTD summary + pace heuristic + MINT_QUOTA_DRY_RUN fixture mode. Phase 31 now ready for `/gsd-verify-phase 31`.
- Empirical 147-route + 43-redirect baseline locked against app.dart HEAD-b7a88cc8, M-3 per-site breadcrumb contract published, 10 Wave 0 scaffolds block no Wave 1-4 compilation errors.
- `kRouteRegistry` const Map shipped with 147 RouteMeta entries bijective with app.dart paths, 15-owner enum locked, D-01 first-segment-wins rule enforced by 16 live tests (0 skipped).
- `./tools/mint-routes` CLI shipped with 3 subcommands (health, redirects, reconcile) + purge-cache + --verify-token. nLPD D-09 controls active (5 regex redaction patterns + 7d cache TTL + token-scope verifier). Python↔Dart schema parity mechanically asserted via `kRouteHealthSchemaVersion = 1`. 14/14 pytest + 2/2 Flutter tests green, 0 skipped, 0 failed.
- `/admin/routes` schema viewer shipped behind compile-time + runtime double gate (D-10). 43 legacy redirects emit `mint.routing.legacy_redirect.hit` breadcrumbs with path-only aggregates (nLPD D-09 §2). Admin mount emits `mint.admin.routes.viewed` aggregates-only processing record (nLPD Art. 12 / D-09 §4). All 4 Wave 0 Flutter stubs + 1 new pytest live. 31/31 Flutter tests + 3/3 pytest green.
- Route registry parity lint shipped standalone per MAP-04. Regex extracts 148 path literals from app.dart, compares against 147 kRouteRegistry keys; 1 admin-conditional + 7 nested-profile entries exempted symmetrically via explicit allow-list in the lint source (KNOWN-MISSES.md Category 5 + 7) → 140 routes parity OK on pristine HEAD. 9/9 pytest green (including end-to-end shell-wrapper exercise). Runtime 30ms (CI budget 30s). stdlib-only (zero pip install on CI). lefthook.yml + .github/workflows/ci.yml untouched — wiring deferred to Phase 34 + Plan 05 respectively.
- Wave 4b closing plan — 4 CI jobs wired (route-registry-parity + mint-routes-tests + admin-build-sanity + cache-gitignore-check) + operator playbook docs/SETUP-MINT-ROUTES.md + walker.sh `--admin-routes` smoke mode + 6 D-11 J0 empirical gates executed with explicit PASS/BLOCKED/FAIL verdicts per M-4 strict 3-branch hierarchy. Verdict: AMBER — 3 PASS (tree-shake + parity + DRY_RUN pytest) + 3 BLOCKED (Keychain inaccessible to non-interactive subprocess → Sentry smoke + live batch + walker screenshots deferred to Julien's local dev). `nyquist_compliant: false` STAYS false per strict 3-branch rule — Julien's acknowledgment of §Risks block is the gate, not the code state. Phase 32 ready for /gsd-verify-work + secure-phase; 0 FAIL outcomes, 0 code P0s, 0 regressions.

---

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
