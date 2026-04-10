# MINT Recovery — Platform Redressement

## What This Is

MINT is a Swiss financial protection & education app (Flutter + FastAPI) that compiles with 9256 tests passing but is non-functional for real users. After cascading agent-driven changes, the app's core features are broken: the AI coach is silent (endpoint never wired), authentication is a facade (logout doesn't logout, state doesn't persist), 12 navigation routes lead nowhere, and key financial calculations are wrong by 35%. This project recovers MINT to a working state where a real user can open the app and use it.

## Core Value

**A real user can cold-start MINT on their iPhone, talk to an AI coach that actually responds, get correct financial insights, and navigate without dead ends.** Everything else is secondary until this works.

## Requirements

### Validated

- ✓ AVS calculations (rente, couple, 13th, gaps, deferral) — golden tests pass, values verified
- ✓ Capital withdrawal tax (progressive brackets, married discount) — golden tests pass
- ✓ Constants sync (Flutter ↔ backend, 2025/2026 values) — verified
- ✓ Confidence scorer (11 components, Bayesian, 86 usages) — well wired
- ✓ Design system (MintColors, MintTextStyles, MintSpacing) — 0 hardcoded colors
- ✓ Compliance guard (5 layers, PII scrubbing, disclaimer injection) — functional
- ✓ CI pipeline (7 workflows, accessibility/readability gates) — healthy
- ✓ Token security (JWT in SecureStorage, BYOK in SecureStorage) — proper compartmentation

### Active

- [ ] **COACH-01**: User without BYOK key gets AI responses via server-side Anthropic key
- [ ] **COACH-02**: Coach responds with RAG-augmented, compliance-filtered, tool-calling responses
- [ ] **COACH-03**: Coach works for ALL life events (not just retirement) — 18 event types
- [ ] **AUTH-01**: Login button is visible and discoverable on landing screen
- [ ] **AUTH-02**: Logout calls AuthProvider.logout() and purges all local data
- [ ] **AUTH-03**: Auth state persists across app restarts (checkAuth() called at startup)
- [ ] **AUTH-04**: BYOK keys cleared on logout (security on shared devices)
- [ ] **NAV-01**: Zero dead routes — every navigation call resolves to an existing route
- [ ] **NAV-02**: Intent router, contextual services, profile drawer, settings sheet all reference valid routes
- [ ] **NAV-03**: Back button works predictably on every screen (not just safePop to coach)
- [ ] **CALC-01**: LPP projections correct when bonificationRateOverride + salaireAssureOverride used together
- [ ] **CALC-02**: Golden couple Julien+Lauren — all 19 tests pass (currently 16/19)
- [ ] **CALC-03**: Taux de remplacement correct (65.5% for golden couple, not 44.75%)
- [ ] **INFRA-01**: feature/cso-security-fixes merged to dev, CI green
- [ ] **INFRA-02**: dev merged to staging, TestFlight builds successfully
- [ ] **INFRA-03**: staging synced to main (resolve 674-commit divergence)

### Out of Scope

- New features (Monte Carlo integration, withdrawal sequencing UI, tornado sensitivity) — recovery only
- Onboarding flow redesign — current chat-first is a design choice, not a bug
- Tab navigation / home screen — current coach-as-shell is intentional
- i18n remaining ~120 strings — P2 priority, not blocking
- Keyboard policy unification — P2, not blocking core flows
- Cloud backup of conversations — P2, not blocking
- Orphan provider cleanup — P2, cosmetic
- Backend test coverage for untested endpoints — P2, not blocking user-facing flows

## Context

### Codebase State (2026-04-10)
- Flutter: 0 compile errors, 9256 tests pass, 11 fail, 6 skipped
- Branch: feature/cso-security-fixes (9 commits ahead of dev, 39 uncommitted files)
- Uncommitted changes: safePop() additions across 39 screens (legitimate fix, partial)
- Backend: Railway deployed (staging + production), ANTHROPIC_API_KEY present
- CI: TestFlight credential fix resolved (last 9 commits), not yet merged to dev

### Audit Sources (7 deep audits, 2026-04-10)
- Auth end-to-end: checkAuth() dead code, logout facade, hidden login
- Coach AI pipeline: 3-tier chain (SLM→BYOK→fallback), /coach/chat endpoint dead
- Navigation: 12 dead routes across intent_router, contextual services, profile_drawer
- Data/state: 3-6 orphan providers, feature flags not persisted, minimal profile shadow
- Backend API: 135+ endpoints, /coach/chat has server-key but never called
- UX surface: chat-first architecture, no home/tabs, landing→coach direct
- Financial core: LPP bonification override bug, 3/19 golden tests fail

### External Audit (ChatGPT, 2026-04-10)
- Confirmed coach back button no-op (fixed in uncommitted changes)
- Confirmed drawer placeholders and dead routes
- Confirmed auth contract broken
- Confirmed contextual services emit stale routes

## Constraints

- **Device gate**: Every phase verified by creator (Julien) via `flutter run --release` on iPhone connected to Mac Mini
- **No retirement framing**: MINT is NOT a retirement app. 18 life events. Every fix must serve 18-99 equally.
- **Branch protocol**: feature/* → dev → staging → main. Never push to staging/main directly.
- **Compliance**: All coach output through ComplianceGuard. No banned terms. Educational only.
- **Sequential execution**: One plan at a time to avoid conflicts (lesson learned from cascading agent damage)
- **No new features**: Recovery only. Fix what's broken, don't add capabilities.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wire Flutter to /coach/chat endpoint (not add server-key to /rag/query) | /coach/chat already has agent loop, tools, server-key fallback, system prompt | — Pending |
| Archive old GSD project, start fresh | The recovery IS the project now, not a milestone on the old roadmap | ✓ Good |
| Fine-grained phases (8-12) | Each incident isolated, verifiable independently, prevents cascading failures | — Pending |
| Sequential execution, no parallel plans | Parallel agents caused the current mess — one change at a time | — Pending |
| All workflow agents enabled (research, plan check, verifier) | Maximum rigor to prevent repeating the facade-without-wiring pattern | — Pending |
| Device gate (flutter run --release on iPhone) | 9256 tests green + audit passed ≠ app works. Only device walkthrough proves it. | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-10 after initialization (recovery project)*
