---
name: wave-1b-CONTEXT
description: Phase CONTEXT for wave-1b-citation-chips — activate Wave 1a's inputs_hash as user-visible citation chips via `source_kind="tool_call_id"` CITATION_REGISTRY entries + narrator placeholder grammar + Flutter chip-tap modal. Couples Wave 1a flag flip with Wave 1b UI ship.
type: context
phase: wave-1b-citation-chips
date: 2026-05-14
status: locked
related:
  - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md
  - services/backend/app/services/coach/citation_registry.py
  - services/backend/app/services/coach/citation_parser.py
  - MILESTONE-CHAT-AS-VERB-2026-05-09.md
---

# Wave 1b — Citation Chips Activation — CONTEXT

## Why this phase, why now

Wave 1a shipped 6 server-side coach tools that emit `BudgetSnapshotResponse`, `RetirementProjectionResponse`, `CrossPillarAnalysisResponse`, `CoupleOptimizationResponse`, BM25 memories, and cap-CHF-garde-validated cap text — every numeric output carries a `inputsHash` (64-char SHA-256 hex). The 5 server-side flags ship default OFF. **Wave 1a is currently invisible to users**: flipping the flags makes the LLM receive JSON, but the frontend has no consumer for `inputs_hash`. The chip-tap UI promise from the v2.9 Chat-as-Verb doctrine ("Every number carries a citation chip. Narrator LLM is mathematically incapable of emitting an un-cited number.") is half-built — Phase 94 shipped the `{{cite:<key>}}` grammar + placeholder substitution, but only for `source_kind ∈ {profile, reasoning, adr, spec}`. The 5th declared source kind, `tool_call_id` (`citation_registry.py:54`), has **zero entries** in `_REGISTRY` today. That's the gap Wave 1b closes.

The natural ship event = Wave 1a's flag flip on Railway staging COUPLED with Wave 1b's UI shipping. Decoupling them is wrong: flag flip alone = invisible win; UI alone (without the tool flags ON) = chips render against legacy formatter strings without inputs_hash → empty modal. Couple them.

## Hard constraints

1. **CLAUDE.md TOP rules** — banned terms (LSFin), 100% FR accents, MINT ≠ retirement app, `financial_core` reuse, i18n via ARB, 0-trust 0-cited-claim.
2. **5-gate exit contract per [[feedback_perimeter_5_gates]]**: G1 Maestro flow, G2 Claude autonomous Maestro+sim (per [[g2-claude-autonomous-not-julien-token]] — Julien correction 2026-05-14), G3 dev CI, G4 regression (backend pytest + Flutter), G5 LSFin + accent_lint + ARB parity (6 locales).
3. **No new `_compute_*` dispatcher branches** — Wave 1a owns those; Wave 1b only EXTENDS the citation-registry consumer side.
4. **No change to `_RE_CURRENCY` / `_RE_PERCENT` regexes** in `citation_parser.py` — those are single source of truth from Phase 94.
5. **Mobile chip renderer reuses the existing chip widget from Phase 94 / 96** — no new design-system primitive.
6. **Flag-flip discipline**: 5 Railway env vars (`COACH_TOOL_SERVER_SIDE_*=true`) flip ONLY at Wave 1b ship time, in lock-step with the dev→staging merge of this phase.

## What ships (in-scope)

- **Backend**:
  - `CITATION_REGISTRY` extended with N `tool_call_id` entries (one per Wave 1a tool: budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories). Each entry's `resolve()` reads the `inputs_hash` + `computed_at` + `flag_state` from the latest tool response payload.
  - Narrator prompt updated with grammar instruction: when emitting a number from a Wave 1a tool, attach `{{cite:tool_call_id:<inputs_hash>}}` placeholder immediately after.
  - New Sentry breadcrumb `coach.citation.tool_call_id.emitted` (5-kwarg per D-15: tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state).
- **Mobile**:
  - Chip renderer recognizes `tool_call_id` source kind (separate icon — maybe ⚙ for "computed" vs 📖 for "spec"/ordinance).
  - Chip-tap → modal showing: tool name, inputs_hash, computed_at timestamp, raw JSON response (collapsible), flag_state badge, "souviens-toi de cette source" CTA.
  - ARB strings for 6 locales (fr/en/de/es/it/pt) for: chip label, modal title, JSON viewer label, flag-state badge, CTA.
- **Tests**:
  - Backend: ≥ 6 registry entries × ≥ 3 assertions each = ≥ 18 new tests + Sentry breadcrumb contract tests.
  - Mobile: golden test for chip rendering + widget test for tap-to-modal.
- **5-gate close**:
  - Maestro G1 flow: tap a card → "Explique-moi" → coach response includes citation chip → tap chip → modal renders.
  - Claude autonomous G2 on iPhone-17-Pro sim.
  - LSFin + accent_lint + ARB parity (6 locales).
- **Ship coupling**:
  - dev→staging PR contains both Wave 1a backlog commits (21 commits) AND Wave 1b shipping commits.
  - Railway env vars flipped to `true` immediately after staging deploy lands.

## What does NOT ship (non-goals)

- **pgvector retrieve_memories** — Wave 2+ if BM25 recall insufficient (CONTEXT D-07 Wave 1a).
- **Wave 1c 20-Q&A parity suite** — separate Wave 1c scope.
- **CapEngine Flutter→Python port** — re-litigation trigger on Sentry breadcrumb threshold (CONTEXT D-17 Wave 1a).
- **Phase 92 / 92.5 / 93 / 97 / 97.5** — sequenced after Wave 1b.
- **Citation chip for legacy `_format_*` formatter outputs** — only the server-side JSON path carries `inputs_hash`. Legacy path has no chip; that's fine because flags ON path is the future.

## Decision log (D-XX)

- **D-01 — Couple Wave 1a flag flip with Wave 1b UI ship**. Reason: decoupling = invisible win or empty modal. Flip on dev→staging deploy as one atomic ship event.
- **D-02 — `tool_call_id` source kind already declared in `citation_registry.py:54` Literal**. No schema change needed — just add entries.
- **D-03 — Chip-tap modal is read-only, no edit/refresh**. Reason: Wave 1a's `inputs_hash` is deterministic, recomputing client-side adds no value. Future: "force-recompute" CTA in a later wave if Sentry shows users tapping repeatedly.
- **D-04 — Coupling with Wave 1a's 21-commit backlog on dev**. Reason: dev→staging merge is overdue regardless; bundling Wave 1b's shipping commits avoids two staging deploys in one week.
- **D-05 — G2 = Claude autonomous (per [[g2-claude-autonomous-not-julien-token]])**. No `checkpoint:human-verify` in Wave 1b plans.
- **D-06 — Chip strings ship in 6 ARB locales at plan time, not deferred**. Reason: ARB parity gate G5 fails closed; deferring loses CI green.

## Open questions (for /gsd-plan-phase to resolve)

1. How does the narrator LLM know WHICH `inputs_hash` to attach to which number? The tool response gives ONE `inputs_hash` per tool call, but the response may contain multiple numbers (e.g. `RetirementProjectionResponse` has rente AVS, rente LPP, total). Options: (a) one chip per tool call attached to ALL its numbers, (b) sub-hashes per slice (complex), (c) only the FIRST number gets the chip (simplest). Plan default: (a) — single chip per tool call, attached to the response container.
2. Chip placement in the chat overlay: inline next to each number, or as a footer "Sources" row? Plan default: footer row (less visual noise).
3. Modal JSON viewer: pretty-print + syntax highlight? Or raw text? Plan default: pretty-print, no syntax highlight (Karpathy #2 simplicity).
4. Backward compat: when flags are OFF (legacy text path), what does the chip renderer do? Plan default: no chip (legacy = no inputs_hash = no chip). User sees the old behavior unchanged.

## 5-gate close-out script (extends Wave 1a's wave_1a_close.sh pattern)

`tools/checks/wave_1b_close.sh` will run:
- G3+G4: backend pytest (≥ +18 new) + Flutter test (≥ +5 new)
- G5: banned_terms_python + accent_lint_fr on Wave-1b-touched files + ARB parity on 6 locales

## Counter-arguments

- **Counter-arg 1**: "Why not run Phase 92 (fonts) first? Fonts are user-visible immediately and ship faster." — Rebuttal: Phase 92 doesn't unblock the doctrine ("every number with a citation"). Wave 1b is doctrine-critical. Fonts are polish.
- **Counter-arg 2**: "Why couple Wave 1a flag flip with Wave 1b UI ship? You could flip flags now, ship Wave 1b later." — Rebuttal: per [[feedback_zero_trust_protocol]] + [[project_coach_forced_tool_invocation]] doctrine, the LLM should HAVE NO CHOICE but to cite. If flags ON without `tool_call_id` registry entries, the LLM emits numbers without citations and the gate from Phase 94 either rejects them or lets them through silently — both outcomes are wrong.
- **Counter-arg 3**: "21 commits of dev backlog is too much to bundle." — Rebuttal: those commits include the wshobson + VoltAgent agents adoption (already committed, only PR-staged) + engram infra (already in production via Mac mini DB) + Wave 0 docs ratification (planning-only). The actual code-runtime delta is Wave 1a + S98 observability. Safe to bundle.

## Data gaps

- **No real-user volume baseline for citation-chip taps**. We don't know what % of users will tap chips. Sentry breadcrumb `coach.citation.tool_call_id.emitted` will establish the baseline post-ship. If tap rate < 5% / week, the chip UX may need a redesign (Wave 2 backlog).
- **No A/B test infra for chip visibility**. All users get chips ON simultaneously. Acceptable risk for a numeric-trust feature where being mathematically correct beats being statistically optimized.
