---
type: expert-verdict
role: ux-narrator
status: Decided
decided_at: 2026-05-12
panel_question: opener-pattern-option-a-vs-b
---

# P004 — Opener pattern verdict (UX narrator)

**Verdict : OPTION A** — templated client-side render, populated with user's actual numbers + canton + archetype-curated metaphor from `metaphors.toml`.

**Score : 9 / 10**

## Rationale

Three converging arguments make Option A the right answer for the opener slot.

**Voice-system alignment.** `docs/VOICE_SYSTEM.md` defines 6 registers with strict FR-vouvoiement / tu-form rules and LSFin banned-term hygiene. The `metaphors.toml` 96-cell table (8 archetypes × 3 intents × 2 cantons × 2 life_events) was hand-curated and peer-reviewed against exactly that voice contract. LLM generation, even with a strong system prompt, drifts on long tails — register slippage, banned-term creep (« optimal », « garanti »), tu/vous inconsistency across a single overlay. Spending LLM tokens on the *opener* trades a deterministic, voice-clean asset for a probabilistic, voice-drift-prone one. That's an asset-leverage failure.

**70/30 wiki/narration doctrine.** The opener is structurally a *card render*, not turn 1 of a conversation. It surfaces what the source_card already knows (plafond, canton, life_event, computed_facts) plus one curated metaphor. That is wiki-side work. Narration currency should be spent on the *response to the user's first typed turn*, where the user has expressed intent the wiki cannot anticipate. Spending LLM on the opener dilutes the 70/30 differentiation and conditions the user to expect AI prose on every tap — which inflates latency budget and cost for zero added signal.

**Earned-narration heuristic.** The verb-chip tap is high-signal, but the user hasn't said anything yet. The signal is *« I want context on this card »*, not *« coach me through a unique situation »*. Template populated with their plafond (e.g. *« vous avez encore CHF 4'380 de marge sur votre 3a 2026 »*) + their canton-specific metaphor reads as MORE thoughtful than a 3-second LLM pause, because instant + personal-numbers + curated-voice beats slow + generic-prose every time. Perceived effort tracks responsiveness × specificity, not token count.

The Karpathy #2 simplicity-first test seals it : 96 hand-tuned cells already solve the problem. Adding an LLM layer is an abstraction not requested.

## Counter-arguments and data gaps

- **Long-tail coverage gap.** 8 × 3 × 2 × 2 = 96 cells assumes the matrix is exhaustive. If a future archetype (e.g. `expat_us_fatca` × `housing_first_buy` × `vaud`) lands outside the curated set, Option A falls back to a generic template. Data gap : we have no telemetry yet on how often users land on uncovered cells. Mitigation : ship a `cell_miss` counter from day 1.
- **Template fatigue.** Users who tap verb chips on 5+ cards in one session may notice structural repetition (« hook → caption → next_step → metaphor » in identical order). Data gap : no longitudinal usage data yet — chat-as-verb is brand new. Mitigation : A/B the slot ordering after 4 weeks of telemetry.
- **Voice-system drift on OUR side.** If the metaphor table isn't versioned + lint-checked against `VOICE_SYSTEM.md` on every edit, the curated asset rots. Data gap : no CI gate on `metaphors.toml` yet.
- **I could be wrong if** Julien's product intuition is that the « voice » a user falls in love with is specifically the LLM's prose rhythm, not the curated voice. That would be a strategic disagreement I'd defer to him on.

## Migration path

Option A wins now. Unlock Option B (or hybrid A→B) when ONE of these signals fires :

1. **Cell-miss rate > 8%** on `metaphors.toml` lookups over 4 weeks of post-launch telemetry — long tail is real, LLM fills the gap.
2. **Qualitative signal** : ≥5 user-interview quotes saying the opener feels « robotic » or « same every time », validated by a UX researcher (not a panel auditor).
3. **Engagement asymmetry** : verb-chip → typed-reply conversion < 15% — users see the opener and bounce, suggesting template isn't pulling them into conversation.

Until then : ship Option A, instrument, hold the line on narration-as-currency.
