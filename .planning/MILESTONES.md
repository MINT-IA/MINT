# Milestones

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
