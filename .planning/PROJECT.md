# MINT — Fondation

## What This Is

MINT is a Swiss financial lucidity & education app (Flutter + FastAPI) that compiles with 9256 tests passing but is non-functional for real users. The backend pipes are broken (RAG corpus ephemeral, URLs 404, tool calling dead), there is zero navigation shell (no tabs, no drawer mounted), and the user is trapped on a single chat screen. This milestone makes the plumbing work so a real human can use MINT end-to-end.

## Core Value

**Un humain externe peut ouvrir MINT sur son iPhone, naviguer sans être piégé, uploader un document, recevoir un premier éclairage, poser une question au coach, et recevoir une réponse pertinente basée sur ses données. Zero crash. Zero 404. Zero boucle. Zero feature morte visible.**

## Current Milestone: v2.4 MINT v2.4 — Fondation

**Goal:** Fix all infrastructure pipes, front-back connections, and navigation architecture so MINT is usable by a real human end-to-end.

**Target features:**
- Phase 1 — Les tuyaux: backend infra hardening (SQLite fail-fast, RAG persistence, agent timeout, Docker paths)
- Phase 2 — Les connexions: front-back wiring (5x URL double-prefix, camelCase mismatch, DNS cleanup)
- Phase 3 — La navigation: shell architecture (tabs, drawer, back button, zombie cleanup, Explorer surface)
- Phase 4 — La preuve: end-to-end human validation on real device

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

### Codebase State (2026-04-12)
- Flutter: 0 compile errors, 9256 tests pass
- Backend: Railway deployed (staging + production), ANTHROPIC_API_KEY present, Claude Sonnet LIVE
- 2 Sentry errors fixed (RAG graceful fallback) — commit 2f65bf01, 11093e46
- 32 findings from 3-axis deep audit: `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md`
- RAG corpus EMPTY on staging/prod (ChromaDB ephemeral)
- 5 Flutter→Backend URLs are 404 (double /api/v1 prefix)
- Tool calling silently dead (camelCase mismatch)
- Zero shell/tabs/drawer in app (specs say 3 tabs + ProfileDrawer)

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
