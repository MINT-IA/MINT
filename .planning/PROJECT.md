# MINT

## What This Is

Swiss financial protection & education app (Flutter + FastAPI) that tells users what nobody has an interest in telling them. MINT illuminates blind spots in financial products and decisions through personalized insights covering 18 life events — not just retirement.

## Core Value

A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next.

## Current Milestone: v1.0 UX Journey

**Goal:** Transform disconnected components into a seamless user journey — from first launch to first personalized insight in under 3 minutes, with zero friction and zero noise.

**Target features:**
- User Journey Map (end-to-end flows for 3+ life events)
- Navigation overhaul (simplify 67 routes into logical journeys)
- Onboarding -> first insight -> next action pipeline (< 3 min)
- Remove duplicates, dead screens, generic LLM noise
- Real wiring: calculators feed the journey, not the showcase

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

<!-- v1.0 UX Journey milestone scope. -->

- [ ] User Journey Map defining end-to-end flows
- [ ] Navigation simplified from 67 routes to coherent paths
- [ ] Onboarding -> first insight pipeline under 3 minutes
- [x] Duplicate screens and dead routes eliminated — Validated in Phase 01: pre-refactor-cleanup
- [ ] Calculators wired into user-facing journeys (not showcase)

### Out of Scope

<!-- Explicit boundaries for v1.0. -->

- Coach personality improvements — already good (regional, multi-ton), next milestone
- New calculators or financial features — existing 8 are sufficient
- Backend API changes — focus is frontend UX assembly
- B2B / institutional features — Phase 4 roadmap
- Voice AI — Phase 3 roadmap
- Money movement / investment advice — never (compliance)

## Context

- **Brownfield**: 6 sprints shipped, 14 audit waves, ~450 findings addressed
- **Core problem**: Components work individually but aren't connected ("facade sans cablage")
- **Navigation**: 67 canonical routes exist but form a labyrinth, not a journey
- **Post-onboarding gap**: User completes intent screen... then what?
- **Retirement bias**: Historically over-indexed on retirement; corrected in identity pivot but UX still reflects old framing
- **LLM genericism**: Coach responses feel verbose, statistical, not deep or surprising
- **Wire Spec V2**: Existing navigation spec (NAVIGATION_GRAAL_V10.md) as starting point
- **Codebase map**: .planning/codebase/ (7 docs, snapshot — verify before acting)

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
| UX Journey before Coach depth | Fix the house before decorating rooms | Pending |

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
*Last updated: 2026-04-05 after Phase 01 (pre-refactor-cleanup) completion*
