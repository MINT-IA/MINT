---
description: Phase 96 discuss-phase audit trail — fully auto-resolved by PM Claude (Product Leader) from the 96-ux panel + master synthesis + sequencing-compliance panel. NOT consumed by downstream agents ; audit trail only.
---

# Phase 96: MVP-CHAT-AS-VERB - Discussion Log (Auto-Resolved)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-11
**Phase:** 96-mvp-chat-as-verb
**Mode:** auto (--auto --chain via `/gsd-discuss-phase 96 --auto --chain`)
**Resolved by:** PM Claude (Product Leader, autonomous loop per Julien 2026-05-10) drawing from 3-panel synthesis
**Areas analyzed:** Chat-tab kill, MintCardActionBar, 3-turn cap, SerializedCardContext, NarrativeSleeve schema, metaphor library, GroundingPack consumption, wave split, compliance gates

---

## Auto-Resolution Methodology

Per `/gsd-discuss-phase` workflow `--auto` mode : « for each discussion question, choose the recommended option (first option, or the one marked "recommended") without using AskUserQuestion ».

Decisions auto-selected from the 3 expert panels convened 2026-05-10 (commit `0302fb9b`) :

1. **96-ux panel** (`2026-05-10-phase-96-ux-panel.md`) — Phase 96 UX/Flutter brief
2. **95-architect panel** (`2026-05-10-phase-95-architect-panel.md`) — upstream GroundingPack contract surface
3. **sequencing-compliance panel** (`2026-05-10-phase-95-96-sequencing-compliance-panel.md`) — pre-merge gates + stop conditions

The PM master synthesis (`2026-05-10-95-96-autonomous-sequence-master.md`) is the consolidated answer sheet.

---

## Chat-tab kill mechanism (D-01..D-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Remove tab index 2 (tabCoach) behind FeatureFlags.chatTabVisible flag-gate | 3-tab nav when flag false ; 4-tab unchanged when true ; GoRoute + screen stay registered for overlay | ✓ |
| Stub the chat route to redirect to a landing screen | Loses overlay reuse ; breaks in-flight state | |
| Delete the route entirely | No kill-switch rollback path ; high blast radius | |

**Auto-resolved:** Feature-flag gate. 96-ux panel §1.

---

## MintCardActionBar (D-04..D-07)

| Option | Description | Selected |
|--------|-------------|----------|
| Inline animated row (48dp, 200ms easeOut) revealed below card on tap | Modern, no modal overlay overhead, preserves card context | ✓ |
| Bottom sheet on tap | Heavy ; loses card visibility ; adds modal navigation step | |
| Persistent toolbar below card | Visual noise on every card | |

**Auto-resolved:** Inline animated row. 96-ux panel §2.

---

## Verb-set (D-05)

| Option | Description | Selected |
|--------|-------------|----------|
| « Explique-moi » / « Simule » / « Rassure-moi » | Final FR copy, 3 distinct intents | ✓ |
| « Explique » / « Simule » / « Rassure » (impératif court) | Less personal, more terminal-feeling | |
| 5-verb set (add « Compare » + « Anticipe ») | Choice fatigue ; dilutes intent classification | |

**Auto-resolved:** 3-verb FR copy. 96-ux panel §2.

---

## Verb routing (D-06)

| Option | Description | Selected |
|--------|-------------|----------|
| « Simule » → Explorer deep-link (zero turns, no LLM) ; others → MintChatOverlay | LLM cost zero on simulate ; preserves « narrator is a precision tool » doctrine | ✓ |
| All 3 verbs → MintChatOverlay | All verbs cost tokens ; loses Explorer integration | |
| « Simule » → inline simulation widget on the card | Adds widget complexity per card | |

**Auto-resolved:** Simule deep-links. 96-ux panel §2.

---

## 3-turn cap policy (D-08..D-11)

| Option | Description | Selected |
|--------|-------------|----------|
| STRICT 3-turn cap, server-side, per source_card_id × app-session, terminal template at turn 4 | Zero LLM cost on cap-hit ; per-card scope encourages exploration | ✓ |
| Soft cap (warn + allow extend) | Loses behavioral contract ; user can drift indefinitely | |
| Per-session global cap (not per-card) | Penalizes exploration across multiple cards | |
| Per-day cap | Resets too often ; doesn't reflect single-session attention | |

**Auto-resolved:** STRICT per-card-session cap. 96-ux panel §3.

---

## Cap reset criterion (D-09)

| Option | Description | Selected |
|--------|-------------|----------|
| Per source_card_id × app-session | Resets on app relaunch + new card | ✓ |
| Per source_card_id × day | Resets at midnight only | |
| Per source_card_id × week | Too rare for exploration loop | |

**Auto-resolved:** Per source_card_id × app-session. 96-ux panel §3.

---

## Cap-hit instrumentation (D-11)

| Option | Description | Selected |
|--------|-------------|----------|
| Sentry metric chat_overflow_turn_4 + 7-day baseline pull pre-flag-flip | Catches > 40% real-user cap-hit rate ; flag walks back via server override | ✓ |
| No instrumentation | Ships blind ; can't measure cap-hit rate | |
| Custom analytics endpoint | Duplicate of Sentry breadcrumb infrastructure | |

**Auto-resolved:** Sentry + baseline pull. 96-ux panel §3 + sequencing-panel §3.

---

## SerializedCardContext schema (D-12..D-13)

| Option | Description | Selected |
|--------|-------------|----------|
| Pydantic v2 frozen+forbid with card_id / card_type / computed_facts / grounding_keys / life_event / canton / archetype | Strict schema ; no PII ; financial_core values only | ✓ |
| Plain dict | Loose typing ; PII risk | |
| Card object reference (pass full card model) | Heavy ; PII risk ; coupling to mobile-side model | |

**Auto-resolved:** Pydantic v2 frozen schema. 96-ux panel §4.

---

## NarrativeSleeve schema (D-14..D-16)

| Option | Description | Selected |
|--------|-------------|----------|
| 4-field envelope (hook digit-free + caption cited + next_step verb-first ≤12 words + metaphor TOML) with response-middleware linter | Catches LLM violations at runtime ; never 500s | ✓ |
| 3-field envelope (drop metaphor) | Loses archetype/canton/event flavor | |
| Linter as pre-commit only | Doesn't catch runtime LLM output | |
| Linter that 500s on violation | Breaks happy path on any narrator drift | |

**Auto-resolved:** 4-field envelope + middleware linter with fallback swap. 96-ux panel §4-5.

---

## Metaphor library (D-17..D-19)

| Option | Description | Selected |
|--------|-------------|----------|
| TOML v1 bootstrap, 6-10 entries × 3 archetypes × 2 cantons × 2 events ; expand post-v2.9 | Minimal scope per Karpathy #2 ; expandable | ✓ |
| Full 8 × 26 × 18 matrix bootstrap | Content sprint scope creep | |
| JSON instead of TOML | Less human-readable for content sprint | |
| Generated via LLM per request | Inconsistent voice ; cost ; LSFin risk | |

**Auto-resolved:** TOML v1 bootstrap. 96-ux panel §6.

---

## GroundingPack consumption (D-20..D-21)

| Option | Description | Selected |
|--------|-------------|----------|
| ProjectionGroundingPack \| None SOFT dependency on Phase 95 W2 | Phase 96 W1 ships independently ; double-lookup already in place | ✓ |
| HARD dependency on Phase 95 GO-prod | Adds 2-4 weeks wall-clock to Phase 96 timeline | |
| Phase 96 ignores GroundingPack entirely (use CITATION_REGISTRY only) | Loses calc-first wiring for Phase 96 v1 | |

**Auto-resolved:** SOFT dependency. sequencing-panel §1.

---

## Plan / wave split (D-22)

| Option | Description | Selected |
|--------|-------------|----------|
| 3 plans / 3 waves (W1 Flutter ~2d / W2 Backend ~2d BLOCKS Phase 95 W2 merge / W3 cross-stack ~1d BLOCKS W2) | Clean dependency boundary ; W1 ships parallel to Phase 95 | ✓ |
| 1 plan monolith | Hard to roll back if W2 reveals contract issue | |
| 4 plans (separate metaphor library plan) | Over-decomposition for ≤10 TOML entries | |
| 2 plans (merge W3 into W2) | Cross-stack work mixed with backend | |

**Auto-resolved:** 3 plans / 3 waves. 96-ux panel §8-10.

---

## Compliance gates (D-23..D-28)

| Option | Description | Selected |
|--------|-------------|----------|
| All Phase 95 gates + flutter analyze + flutter test ≥229 + ARB parity 6-locale + MintColors only + G1 Maestro + G2 Julien sim | Full 5-gate exit contract | ✓ |
| Skip G1 Maestro (defer to post-merge) | Risks merging UI without end-to-end verify | |
| Skip G2 Julien sim (production-only) | Memory `feedback_perimeter_5_gates` requires G2 device-by-Julien | |

**Auto-resolved:** Full 5-gate. sequencing-panel §3-7.

---

## Claude's Discretion

The following items were not user-facing decisions but PLAN-level details intentionally left for the planner agent :

- Internal widget structure of MintCardActionBar + MintChatOverlay (Stateless/Stateful, key handling)
- TOML parser choice (existing `toml` package vs stdlib manual parse)
- Exact hook digit-free fallback library (1 fallback string vs rotation of 3-5)
- Sentry breadcrumb naming convention for non-locked events (e.g. `card_action_tap_explique`)
- `turn_count` persistence backend (default in-memory per-process ; Redis backing only if multi-process drift surfaces)

The planner reads existing patterns first and decides per Karpathy #2 simplicity-first.

## Deferred Ideas (carried to backlog post-v2.9)

- Full CITATION_REGISTRY removal — post-96 cleanup
- Sobol / NSGA-II / HMM / Bayesian CIs — backlog 999.x
- Metaphor library full matrix expansion — content sprint post-v2.9
- Phase 94.2 narrator-prompt iter 2 — backlog 999.5 (independent)
- ChatTab permanent route deletion — post-4-week-soak cleanup
- Server-side turn_count persistence (Redis/Postgres) — patch if multi-process drift

## Auto-Resolved Items Summary

| Area | Auto-selected | Source panel |
|------|---------------|--------------|
| Chat-tab kill | FeatureFlags.chatTabVisible gate | 96-ux §1 |
| MintCardActionBar | Inline animated row 48dp 200ms easeOut | 96-ux §2 |
| Verb-set | « Explique-moi / Simule / Rassure-moi » | 96-ux §2 |
| Verb routing | Simule deep-links to Explorer, others overlay | 96-ux §2 |
| 3-turn cap | STRICT server-side per source_card × session | 96-ux §3 |
| Cap reset | Per source_card_id × app-session | 96-ux §3 |
| Instrumentation | Sentry chat_overflow_turn_4 + 7-day baseline | 96-ux §3 + sequencing §3 |
| SerializedCardContext | Pydantic v2 frozen schema | 96-ux §4 |
| NarrativeSleeve | 4-field envelope + middleware linter | 96-ux §4-5 |
| Metaphor library | TOML v1 bootstrap 6-10 entries | 96-ux §6 |
| GroundingPack consumption | SOFT dependency on Phase 95 W2 | sequencing §1 |
| Wave split | 3 plans / 3 waves | 96-ux §8-10 |
| Compliance | Full 5-gate exit contract | sequencing §4-7 |

All decisions traceable to the master synthesis with counter-arguments + data gaps already documented.
