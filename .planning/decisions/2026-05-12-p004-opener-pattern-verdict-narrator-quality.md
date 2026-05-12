---
type: expert-verdict
role: narrator-quality
status: Decided
decided_at: 2026-05-12
panel_question: opener-pattern-option-a-vs-b
---

# P004 — Opener pattern verdict (narrator-quality engineer)

## Verdict

**OPTION A — templated client-side opener with source_card hydration.**

## Score

**9 / 10** confidence.

## Rationale

The decisive factor is the closed-world citation gate fall-through profile on opener turns, not the ceiling of LLM output. Phase 94's gate is binary : a number must live in `whitelist_numbers ∪ user_input_numbers`, or the entire NarrativeSleeve is rejected and `FALLBACK_TEMPLATED_TEXT` is served. On opener turns the user has typed nothing, so `user_input_numbers = ∅`. Any source_card-derived figure the model wants to surface (7'056 plafond 3a, taux LPP, contributions AVS) must already be whitelisted. P003 measured this regime and confirmed it is the COMMON case : the narrator naturally reaches for regulatory figures to feel concrete, those figures are whitelisted, but the gate blocked because the specific surface form (apostrophe, separator, contextual phrasing) didn't normalise into the whitelist. The result : Option B's opener degrades to a less personalised template than Option A's opener would have been — strictly worse on the dominant path.

On personalisation depth, Option A wins on the floor and matches Option B on the median. The 96-entry `metaphors.toml` is hand-curated against canton × archetype × life_event ; combined with computed_facts hydration on hook/caption/next_step, the 4 slots become deterministically personalised. Option B's success path has a higher ceiling — fresh, surprising phrasing — but openers are the worst possible context to spend that ceiling : zero user signal, highest gate-fall-through, most generic prompt context.

Voice-drift risk reinforces Option A. The LLM is voice-drift-prone (LSFin banned-term leakage, register slippage toward « optimal » / « garanti ») ; `metaphors.toml` is voice-reviewed once and is stable. Golden-set evaluation cost is the third multiplier : Option B requires per-(archetype × intent × life_event) golden sets — minimally 8 × 5 × 18 = 720 anchors. Option A's quality surface is a 96-row metaphors review plus a 4-slot template lint, an order of magnitude cheaper to maintain.

Option B's higher ceiling is real, but it belongs on turn 2+ where the user has typed and `user_input_numbers` becomes non-empty, raising gate success rate sharply.

## Counter-arguments and data gaps

- We do not have a measured gate-fall-through rate on opener turns across archetypes — P003 is one observation, not a distribution. A 50-opener telemetry pass would harden the verdict.
- `metaphors.toml` coverage for rare (archetype × life_event) cells (e.g. `expat_us` × `divorce_split`) may be thin ; if hit-rate < 80 %, Option A degrades to a generic metaphor and loses some of its personalisation edge.
- Option B fall-through could be reduced by widening `whitelist_numbers` normalisation (apostrophe / locale variants) rather than abandoning the LLM path ; we have not measured how much of the P003 failure was normalisation vs genuinely-out-of-set numbers.
- Bias risk : I am scoring « known cheap and safe » against « unknown but higher ceiling » — a structural conservatism. A small Option B A/B on turn-2+ would calibrate.

## Migration path

Option B unlocks for openers in v2.10+ when ALL three thresholds hold over a rolling 14-day window on staging telemetry :

1. **Gate-fall-through rate on opener turns < 8 %** (measured : NarrativeSleeve served from LLM path / total opener turns).
2. **Voice-drift incidents (LSFin banned-term hits + register flags) < 1 per 1 000 opener turns** on the LLM path.
3. **Golden-set coverage ≥ 80 %** across the 8 × 5 × 18 archetype × intent × life_event matrix, with per-cell PASS rate ≥ 90 %.

Until then : Option A is the opener pattern ; Option B remains the turn-2+ pattern where user_input_numbers is typically non-empty and gate-fall-through collapses to the edge case it was designed to handle.
