# MINT

## What This Is

Swiss financial protection & education app (Flutter + FastAPI) that tells users what nobody has an interest in telling them. MINT illuminates blind spots in financial products and decisions through personalized insights covering 18 life events — not just retirement.

## Core Value

A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next.

## Current Milestone: v2.0 Mint Système Vivant

**Goal:** Transform MINT from a well-wired but passive app into a living financial intelligence system that ingests documents, anticipates life events, remembers the user's financial narrative, and proactively coaches — while respecting LSFin/nLPD at every layer.

**Target features:**
- Le Parcours Parfait: Léa golden path end-to-end (landing → insight → plan → check-in)
- Intelligence Documentaire: Photo/PDF upload → LLM extraction → profile enrichment → instant insight
- Moteur d'Anticipation: Rule-based proactive alerts (fiscal deadlines, profile changes, legislative)
- Mémoire Narrative: FinancialBiography (local-only graph of facts, decisions, events)
- Interface Contextuelle: Smart Aujourd'hui cards ranked by relevance
- QA Profond: 9 personas, error recovery, accessibility, multilingual validation
- Connexions Externes: bLink sandbox + pension/tax adapter stubs

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

<!-- v2.0 Mint Système Vivant milestone scope. -->

- [ ] Léa golden path: landing → onboarding → premier éclairage → plan → check-in (flawless)
- [ ] Document intelligence: photo/PDF upload → LLM extraction → profile enrichment → instant insight
- [ ] Anticipation engine: rule-based proactive alerts (fiscal, profile, legislative triggers)
- [ ] Financial biography: local-only narrative memory with anonymized coach integration
- [ ] Contextual Aujourd'hui: smart card ranking by relevance (max 5 cards)
- [ ] QA profond: 9 personas with error recovery, accessibility (WCAG 2.1 AA), multilingual validation
- [ ] External connections: bLink sandbox + pension/tax adapter stubs

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
*Last updated: 2026-04-06 after milestone v2.0 initialization*
