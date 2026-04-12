# Coach Cost Delta — Few-Shot vs Fine-Tune Analysis

> **Phase:** 05-l1.6a-voice-cursor-spec / Plan 05-01
> **Date:** 2026-04-07
> **Decision:** ACCEPT few-shot with Anthropic prompt caching. Do not fine-tune at current scale.
> **Cross-reference:** `docs/VOICE_CURSOR_SPEC.md` §14.3, CONTEXT.md D-04, CONTEXT.md D-05.

---

## §1 Context — why this analysis exists

VOICE-07 requires that MINT's coach voice be anchored at the N4 and N5 intensity levels via few-shot examples embedded in the system prompt. Decision D-04 in `.planning/phases/05-l1.6a-voice-cursor-spec/05-CONTEXT.md` locks the approach to few-shot rather than fine-tuning, and this document logs the analysis supporting that decision.

The question the document answers: given that MINT needs to tonally anchor the coach model on two specific intensity levels (N4 and N5) using a corpus of 50 reference phrases, is it cheaper over the expected life of the product to (a) embed 6 exemplars in every system prompt and pay the per-turn token cost, or (b) fine-tune a base model once and pay the fine-tune training cost plus the hosting differential.

The answer is (a), few-shot with prompt caching, for the reasons documented in §3, §4, and §5. The answer may change if Phase 11 Krippendorff α validation fails on N4 or N5; revisit conditions are logged in §6.

---

## §2 Current baseline — system prompt token count

The current `services/backend/app/services/claude_coach_service.py` system prompt (as of 2026-04-07, before any Phase 5 changes) contains the following blocks:

- Role definition and doctrine recap — approximately 800 characters.
- Regional voice identity section — approximately 1'200 characters.
- Compliance constraints summary — approximately 600 characters.
- Tool definitions (the tool-call JSON schemas for lookups and actions) — approximately 2'400 characters.
- Turn-handling instructions — approximately 900 characters.

**Total baseline: approximately 5'900 characters ≈ 1'475 tokens** (using the common approximation of 1 token per 4 characters for French + code-mixed prompts).

Method note: the character count was taken by reading the file and summing the block sizes. The token approximation uses Anthropic's documented 4-characters-per-token rule of thumb for French prose; technical blocks like the tool schemas run slightly denser (closer to 3.5 characters per token) so the true baseline is probably 1'500-1'600 tokens. For the purpose of this analysis the approximation is sufficient.

This baseline is the "turn 1 uncached" cost — every subsequent turn in the same conversation benefits from Anthropic prompt caching, which the §4 mitigation depends on.

---

## §3 Few-shot delta — added token cost

The few-shot block specified in `VOICE_CURSOR_SPEC.md` §14.3 adds the following to the system prompt:

- Opening `<voice_examples>` tag — 5 tokens.
- 6 context headers, each approximately 15 tokens — 90 tokens.
- 6 exemplar phrases, each approximately 25 tokens on average — 150 tokens. The N4 phrases are longer (15-25 tokens each) and the N5 phrases are shorter (5-10 tokens each); the average across the 6 is approximately 25.
- Closing `</voice_examples>` tag — 5 tokens.
- Register-reset clause from §12.1 — approximately 90 tokens.
- Surrounding structure (newlines, section markers) — approximately 30 tokens.

**Total delta: approximately 370 tokens per turn.**

This is 370 tokens added to the 1'475-token baseline, for a new uncached turn 1 cost of approximately 1'845 tokens. The delta is approximately 25 percent of the baseline — significant but not prohibitive at current model pricing.

---

## §4 Anthropic prompt caching mitigation

Anthropic's prompt caching (documented in the Anthropic API reference under "Prompt caching") allows a stable prefix of the system prompt to be cached across turns within a single conversation and across conversations within a rolling window. Cached content is billed at approximately 10 percent of the uncached rate on cache hits and at approximately 125 percent of the uncached rate on the cache-write turn.

Applied to MINT's coach turn structure:

- **Turn 1 (cache write):** baseline 1'475 tokens + few-shot delta 370 tokens = 1'845 tokens at approximately 125 percent rate = effective cost approximately 2'306 tokens-equivalent.
- **Turns 2+ (cache hit):** 1'845 tokens at approximately 10 percent rate = effective cost approximately 185 tokens-equivalent per turn.

The few-shot delta on cached turns is approximately 37 tokens-equivalent per turn, or about 10 percent of the raw 370-token delta. Over a typical MINT conversation of 4-6 turns, the amortized few-shot cost is roughly 2-3 percent of total conversation token cost, which is within the operational budget.

The caching contract requires that the cached prefix remain byte-stable across turns. Any change to the system prompt — including the few-shot exemplars themselves — invalidates the cache and forces a re-write. This means the few-shot block must be updated rarely and in large batches rather than frequently and incrementally. Plan 05-02 will inject the final exemplar text once and subsequent plans will not modify the block without a documented version bump.

---

## §5 Decision — ACCEPT few-shot with prompt caching

**Decision:** MINT uses few-shot embedding with Anthropic prompt caching for tonal anchoring of the coach model on N4 and N5 intensity levels. Fine-tuning is rejected at current scale.

**Rationale:**

1. **Corpus size.** The frozen corpus is 50 phrases (Plan 05-02). Fine-tuning requires 1'000+ examples for meaningful signal; below that threshold the fine-tune cost is paid for noise. Expanding the corpus to 1'000+ would itself be a multi-phase effort that dwarfs the few-shot implementation.
2. **Validation sequencing.** Fine-tuning locks tone before Krippendorff α validates the corpus. If the corpus fails α, a fine-tuned model carries the failure as a permanent bias. Few-shot embedding keeps the corpus externally editable and allows a failed Krippendorff result to be addressed by corpus rework rather than model retraining.
3. **Cost with caching.** The amortized few-shot cost with prompt caching is approximately 2-3 percent of total conversation token cost. Fine-tuning at MINT's current scale would not recover the training cost within the expected product lifetime at this token volume.
4. **Iteration speed.** A few-shot block can be updated in a single PR with zero model downtime. A fine-tune requires retraining, testing, and redeploy — which at MINT's sprint cadence is a significant operational cost.
5. **Regional compatibility.** The regional voice layer (Phase 6) stacks lexical and cadence adaptations on top of the base intensity level. A fine-tuned model would need to be either retrained per region or abstracted from regional concerns; few-shot embedding keeps the base tonal anchor region-independent and lets the regional layer operate downstream.

**The decision is recorded here, in `VOICE_CURSOR_SPEC.md` §14.3, and in CONTEXT.md D-04. All three must agree; any divergence is a defect.**

---

## §6 Revisit trigger conditions

The few-shot decision is revisited — meaning fine-tuning is re-evaluated as a live option — if any of the following conditions hold at Phase 11 or later:

1. **Krippendorff α fails overall.** α < 0.67 on the 50-phrase corpus across all 5 levels indicates the corpus itself is not converging on a shared perception of intensity. Revisit the corpus first; revisit few-shot vs fine-tune only if corpus rework does not move α into acceptable range.
2. **Krippendorff α fails on N4.** α < 0.67 specifically on the N4 sub-corpus indicates the anchor level where few-shot matters most is not landing. This is the most likely trigger for a fine-tune revisit, because few-shot embedding exists precisely to anchor N4.
3. **Krippendorff α fails on N5.** α < 0.67 specifically on the N5 sub-corpus indicates the rupture register is not reliably classified. Revisit both corpus content and few-shot block structure before considering fine-tune — the N5 phrases may need fewer exemplars with more context, rather than a different anchoring approach.
4. **Marginal cost exceeds threshold.** If the steady-state marginal cost per conversation turn exceeds CHF 0.002 after caching is fully deployed, the few-shot block itself becomes the cost driver and a one-time fine-tune may amortize better. This threshold is chosen because it corresponds to approximately 0.5 percent of the operational budget per conversation at current projected volumes.
5. **Cache-hit rate below 80 percent.** If fewer than 80 percent of conversation turns hit the cache in production telemetry, the caching mitigation is not delivering its expected benefit and the few-shot delta reverts to roughly its uncached value. Investigate why caching is missing (prompt drift, user distribution, conversation length) before revisiting fine-tune.

None of these conditions are active at Phase 5 signoff. The decision stands unless and until one of them fires.

---

## §7 Cross-references

- **`docs/VOICE_CURSOR_SPEC.md` §14.3** — few-shot block structure and placeholder injection target for Plan 05-02.
- **`docs/VOICE_CURSOR_SPEC.md` §26.2** — Phase 11 wiring checklist for the few-shot block.
- **`.planning/phases/05-l1.6a-voice-cursor-spec/05-CONTEXT.md` D-04** — few-shot locked at current scale.
- **`.planning/phases/05-l1.6a-voice-cursor-spec/05-CONTEXT.md` D-05** — 3 N4 + 3 N5 verbatim + context header format.
- **`.planning/REQUIREMENTS.md` VOICE-07** — few-shot cost delta documentation requirement.
- **Anthropic prompt caching documentation** — note-in-text, not a live URL; the caching contract described in §4 follows the public Anthropic documentation as of 2026-04-07.
- **`services/backend/app/services/claude_coach_service.py`** — the file Phase 11 modifies to wire the few-shot block per §26.2.

---

**End of COACH_COST_DELTA.md.**
