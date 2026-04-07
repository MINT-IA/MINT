# MINT

## What This Is

Swiss financial protection & education app (Flutter + FastAPI) that tells users what nobody has an interest in telling them. MINT illuminates blind spots in financial products and decisions through personalized insights covering 18 life events — not just retirement.

## Core Value

A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next.

## Current State

**Last shipped:** v2.1 Stabilisation v2.0 (2026-04-07) — 16/17 STAB requirements DONE, coach tool choreography wired E2E, 6-axis façade-sans-câblage audit + fixes complete, CI dev green, lints clean.

**TestFlight gate (carried into v2.2 Phase 0):** STAB-17 manual tap-to-render walkthrough — see `.planning/backlog/STAB-carryover.md`.

**Next milestone:** v2.2 La Beauté de Mint (Design v0.2.3) — start with `/gsd-new-milestone --reset-phase-numbers`. Source of truth: `visions/MINT_DESIGN_BRIEF_v0.2.3.md` + `.planning/MILESTONE-CONTEXT.md`.

## Requirements

### Validated

<!-- Shipped in S51-S56 + zero debt sprints, confirmed working. -->

- Chat AI with Claude (tool calling, compliance guard, BYOK fallback) — S51+S56
- 8 financial calculators in financial_core/ (AVS, LPP, tax, arbitrage, Monte Carlo, confidence, withdrawal, tornado) — S51-S53
- 18 life events, 8 archetypes with detection — S53
- 3-tab shell (Aujourd'hui | Coach | Explorer) + ProfileDrawer — S52+S56
- 7 Explorer hubs (Retraite, Famille, Travail, Logement, Fiscalite, Patrimoine, Sante) — S52
- Design system (MintColors, Montserrat/Inter, Material 3) — S54
- i18n 6 languages (fr template + en/de/es/it/pt) — S55
- Coach with regional voice (Romande, Deutschschweiz, Svizzera Italiana) — S55
- Intent-based onboarding screen — S56
- 12,892 tests green, flutter analyze 0 errors — zero debt sprint

### Active

<!-- v2.1 Stabilisation v2.0 milestone scope. -->

- [ ] **STAB-01**: route_to_screen tool call rendered end-to-end (intent → route → user-visible screen)
- [ ] **STAB-02**: generate_document tool call rendered visible (case in widget_renderer)
- [ ] **STAB-03**: generate_financial_plan exposed in coach_orchestrator BYOK + toolCalls re-exposed in CoachLlmService.chat()
- [ ] **STAB-04**: record_check_in exposed in coach_orchestrator BYOK + toolCalls re-exposed
- [ ] **STAB-05**: auth_screens_smoke_test.dart aligned with login_screen.dart magic-link redesign
- [ ] **STAB-06**: intent_screen_test.dart aligned with Phase 1 rewiring (setOnboardingCompleted moved to plan_screen)
- [ ] **STAB-07**: IntentScreen async-gap fix (BuildContext captured before await, line 195)
- [ ] **STAB-08**: Backend ruff zero errors (43 → 0)
- [ ] **STAB-09**: Flutter analyze warnings on production code fixed (test/style lints acceptable)
- [ ] **STAB-10**: CI dev branch green on all jobs (Backend, Flutter widgets/services/screens, CI Gate)
- [ ] **STAB-11**: Coach end-to-end test covers tool call → render → user-visible widget for the 4 tools
- [ ] **STAB-12**: Coach surface audit — every tool traced end-to-end (definition → render → visible)
- [ ] **STAB-13**: Provider/Service consumer audit — flag dead/orphan, delete or wire each
- [ ] **STAB-14**: Route reachability audit — every GoRouter `path:` reachable from current shell, or deleted
- [ ] **STAB-15**: Backend → mobile contract audit — flag fields backend sends that mobile silently drops
- [ ] **STAB-16**: Try/except black-hole audit — fix every silently-swallowed error on non-best-effort paths
- [ ] **STAB-17**: Tap-to-render audit — manually walk every interactive element on 3 tabs + drawer (TestFlight gate)

<!-- v2.0 features all shipped — pending validation through TestFlight after v2.1. -->
- [x] Léa golden path: landing → onboarding → premier éclairage → plan → check-in (shipped, awaiting device validation)
- [x] Document intelligence: photo/PDF upload → LLM extraction → profile enrichment → instant insight (shipped)
- [x] Anticipation engine: rule-based proactive alerts (shipped)
- [x] Financial biography: local-only narrative memory (shipped)
- [x] Contextual Aujourd'hui: smart card ranking (shipped)
- [x] QA profond: 9 personas + accessibility + multilingual (shipped)
- [x] External connections: bLink sandbox + pension/tax stubs (shipped)

### Out of Scope

<!-- Explicit boundaries for v2.0. -->

- bLink production (requires SFTI membership + per-bank contracts) — v3.0+
- Background processing / WorkManager for anticipation — v3.0
- Cloud sync for FinancialBiography (requires E2E encryption) — v3.0
- Email forwarding adapter — v3.0
- Voice AI — Phase 3 roadmap
- Multi-LLM routing — Phase 3 roadmap
- B2B / institutional features — Phase 4 roadmap
- Money movement / investment advice — never (compliance)
- Product recommendations / ranking — never (compliance)

## Context

- **Post v1.0**: 8 phases shipped (cleanup → tool dispatch → onboarding → plan gen → suivi → calc wiring → journeys → UX polish). Journey pipeline works end-to-end.
- **Core shift**: v1.0 wired the house; v2.0 makes it alive. MINT still waits for user — v2.0 makes MINT come to the user.
- **Document intelligence**: Screenshots/photos are the most natural input ("balance-moi le print screen"). Primary input method ahead of PDF.
- **Compliance evolution**: New output channels (alerts, narratives, openers) all need ComplianceGuard validation.
- **Privacy**: Document originals deleted after extraction (nLPD). FinancialBiography local-only. AnonymizedBiographySummary for coach.
- **Data freshness**: Every extracted field carries extractedAt + decay model. Stale data = conservative fallback.
- **LPP plan types**: Must detect légal vs surobligatoire vs 1e — applying 6.8% to 1e capital = massive overestimate.
- **9 personas**: Incremental QA from Léa (Phase 1) to full 9-persona coverage (Phase 6).
- **Codebase map**: .planning/codebase/ (snapshot — verify before acting)

## Constraints

- **Tech stack**: Flutter + FastAPI, no changes this milestone
- **Compliance**: Read-only, no advice, no ranking, no promises (LSFin/FINMA)
- **Identity**: "Mint te dit ce que personne n'a interet a te dire" — protection-first, not retirement-first
- **Target**: ALL Swiss residents 18-99, segmented by life event, never by age
- **Branch flow**: feature/* -> dev -> staging -> main (no direct push to staging/main)
- **Testing**: flutter analyze 0 errors + flutter test + pytest before any merge

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 3-tab + drawer (not 4 tabs) | Dossier tab removed, profile in drawer | Good |
| Coach-first, UI-assisted | AI as narrative layer, not chatbot-first | Good |
| Protection-first identity | Not retirement app, not calculator, not dashboard | Good |
| financial_core/ as single source | All calcs centralized, consumers import only | Good |
| Intent-based onboarding | Ask what user cares about, not demographics | Pending |
| UX Journey before Coach depth | Fix the house before decorating rooms | ✓ Good |
| DataIngestionService adapter pattern | Unified pipeline for all input channels (doc, bank, pension) | — Pending |
| FinancialBiography local-only | Privacy-first: never sent to external APIs | — Pending |
| Rule-based anticipation triggers | Zero LLM cost, deterministic, instant | — Pending |
| bLink sandbox only for v2.0 | Production requires SFTI + per-bank contracts (18-24 months) | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-07 after milestone v2.1 initialization*
