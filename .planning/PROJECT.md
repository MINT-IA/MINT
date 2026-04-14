# MINT — Fondation

## What This Is

MINT is a Swiss financial lucidity & education app (Flutter + FastAPI) that gives users financial peace-of-mind, clarity, and control with near-zero effort. MINT is a living dossier that collects, understands, and reveals what matters about the user's financial life. Infrastructure plumbing is fixed (v2.4). This milestone transforms MINT from working infrastructure into a product that hooks, converts, and retains users through the anonymous→value→premium flow and the 5 expert audit innovations.

## Core Value

**Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.**

## Current Milestone: v2.5 Transformation

**Goal:** Transform MINT into a living product: anonymous hook → auth conversion → value delivery → premium retention → dossier vivant. Implement the 5 tier-1 innovations from the expert audit.

**Target features:**
- Anonymous→Auth flow end-to-end (backend anonymous endpoint, rate limiting, conversation transfer post-login)
- Commitment devices (implementation intentions, fresh-start anchors, pre-mortem)
- Mode couple dissymetrique (asymmetric partner awareness questionnaire)
- Coach intelligence (provenance journal via conversation, earmarking implicite, intent-first suggestions)
- Premium gate wiring (gratuit vs premium line, Stripe/RevenueCat, 15 CHF/mois)
- Living timeline direction (tension-based home screen for authenticated users)

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

See `.planning/REQUIREMENTS.md` for full v2.4 requirements with REQ-IDs.

### Out of Scope

- New features (Monte Carlo UI, withdrawal sequencing UI, tornado sensitivity) — foundation only
- i18n remaining ~120 strings — P2 priority, not blocking
- Keyboard policy unification — P2, not blocking core flows
- Cloud backup of conversations — P2, not blocking
- Orphan provider cleanup — P2, cosmetic
- P2/P3 findings from audit (CORS, JWT bypass, migration naming, docling) — tracked but deferred

## Context

### Codebase State (2026-04-12, post v2.4 Fondation)
- Flutter: 0 compile errors, 9256+ tests pass
- Backend: Railway deployed (staging + production), Claude Sonnet LIVE with tool calling
- v2.4 fixed: RAG persistence, URL double-prefix, camelCase mismatch, shell/tabs/drawer, navigation
- Anonymous intent screen built (quick-260412-kue): 6 felt-state pills, warm white, timed animation
- 5 expert audit (2026-04-11): 10 innovations proposed, 5 tier-1 adopted, lucidite-first pivot
- Source of truth for vision: `docs/MINT_IDENTITY.md` + `.planning/architecture/13-AUDIT.md`
- Monetisation design: memory/project_hook_monetization_2026_04_12.md

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
*Last updated: 2026-04-12 after milestone v2.4 start*
