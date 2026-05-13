# Phase 91: MVP-EXTRACTOR-V2 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `91-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 91-mvp-extractor-v2
**Mode:** RESEARCH-driven single-pass (accept-all)
**Areas covered:** Narrator model strategy, Confirmation gate UX, Extractor scope, Operational gates, Cache + history

---

## Discussion Format

This phase used a single-pass accept-all flow rather than per-area deep-dive. Justification:
- RESEARCH.md (848 lines) already documented all 6+ open questions (OQ-1..7) with explicit per-question recommendations.
- 12 D-XX decisions were pre-mâchées by Claude based on RESEARCH §3, §4, §5, §6, §10, §13, §14.
- Julien selected « Accept all 12 — écris CONTEXT.md (Recommended) » in one prompt, locking all 12 simultaneously.

No per-question table is reproduced here because no question was deep-dived. The decision rationale lives in `91-CONTEXT.md` `<decisions>` and references back to RESEARCH.md sections.

---

## D-01: Narrator Model Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Haiku-first with Stage 3 eval gate | Default Haiku 4.5 ; eval gate ≥95% Sonnet pass-rate ; fallback Sonnet if fails. -2.5% per turn if pass, +54% if fail-back. | ✓ |
| Sonnet-default with Haiku as future opt-in | Guarantees compliance ; +54% per turn permanent. | |
| Skip Stage 3 entirely | Ship with Sonnet narrator, no eval pack. | |

**Rationale:** Cost outcome hinges on Stage 3 eval. RESEARCH §5 documents both scenarios. Haiku-first is the only path that potentially reduces per-turn cost vs today.

## D-02: Confirmation Gate UX (High-Stakes Keys)

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Pending confirmation | Extractor flags `pending_confirmation=True` ; narrator prompts ; next turn's regex-confirmation persists. Safer ; double-turn tax. | |
| (b) Persist immediately + narrator surface | Extractor persists ; narrator surfaces « j'ai mis à jour ton canton — c'est correct ? » with undo. Faster ; rare false-positive change visible. | ✓ |
| (c) No gate | Trust extractor entirely (rely on source_quote substring + range guards). | |

**Rationale:** Option (b) reduces friction for the high-frequency happy-path while keeping recovery via undo tool. RESEARCH §6 Counter-arg #3 + Pitfall 5.

## D-03/04/05: Extractor Scope

| Decision | Selected | Rationale |
|----------|----------|-----------|
| D-03 Intent classification → extractor absorbs | ✓ | RESEARCH OQ-3 — recall lift on unusual phrasings |
| D-04 Extractor runs on anonymous chat (in-memory only) | ✓ | RESEARCH OQ-4 — ABC funnel coaching quality, ~$0.018/turn cost acceptable |
| D-05 `save_insight` stays narrator-side | ✓ | RESEARCH OQ-7 — insight = narrative judgment ≠ fact extraction |

## D-06/07/08/09: Operational Gates

| Decision | Selected | Rationale |
|----------|----------|-----------|
| D-06 Stage 3 eval as discrete 1-day blocking task | ✓ | Single-variable test ; carve out before Stage 4 soak |
| D-07 Stage 0 telemetry baseline (1h grep) | ✓ | Mitigates DG-3 « is the production drift real? » |
| D-08 Maestro G1 multi-fact flow | ✓ | Stronger gate than 1-fact ; also exercises anonymous-chat path |
| D-09 Regex extractor kept forever as floor | ✓ | Karpathy #2 simplicity ; ~50 LOC maintenance is cheap insurance |

## D-10/11/12: Cache + History

| Decision | Selected | Rationale |
|----------|----------|-----------|
| D-10 Cache backend Redis (in-memory fallback) | ✓ | Already wired via `app.core.rate_limit` |
| D-11 Cache payload = persisted facts (no PII) | ✓ | Pitfall 4 mitigation |
| D-12 Conversation history 6 turns both LLMs | ✓ | Match today ; revisit only if soak shows multi-turn miss |

---

## Claude's Discretion (carried into PLAN.md scope)

- Pydantic schema field naming + validation rules within the contract
- Extractor system prompt wording (skeleton in RESEARCH §3)
- Narrator system prompt diff (which lines of `_BASE_SYSTEM_PROMPT` to remove)
- Retry message wording on JSON parse failure
- Stage breakdown granularity within Stages 1-5
- Eval fixture sampling methodology (50 hand-picked turns nominal)
- Test fixture specifics (RESEARCH §4 Stage 1 T1.3 provides 7 cases)
- Logging verbosity

## Deferred Ideas (from RESEARCH §14 + §16, restated in CONTEXT.md `<deferred>`)

- CITATION-GATE parser (Phase 94)
- DAG-INVALIDATION (Phase 95)
- CHAT-AS-VERB (Phase 96)
- `save_insight` move to extractor (follow-up phase if symptom emerges)
- Prompt registry pattern (OQ-5 follow-up)
- Parallel extractor + narrator (asyncio.gather, REJECTED for Phase 91)
- OpenAI structured-outputs as alternate extractor (REJECTED — single-provider BYOK)
- Replace `extract_profile_facts` regex (NEVER — D-09)
- Multi-language extraction beyond FR+EN regex baseline
- Anthropic model registry refresh + pricing re-verification (Stage 0 tasks)

---

*Discussion complete: 2026-05-09. CONTEXT.md ready for `/gsd-plan-phase 91`.*
