---
description: Phase 97.5 W1-T1 master ADR — opener pattern for MintChatOverlay on verb-chip tap (P004 fix). 4-expert mini-panel verdict (LSFin compliance / Latency / UX narrator / Narrator quality) converges 4/4 on OPTION A (templated client-side, zero LLM call) with mean confidence 9/10. Locks Wave 2 dependency : W2-T1 implements Option A template-fill path ; W2-T2 collapses to ~1h schema-only confirmation per PLAN.md v4 conditional-scope clause.
type: decision
phase: 97.5
authority: orchestrator-full-autonomy-julien-go-2026-05-12T09:55Z
status: Decided
panel_question: opener-pattern-option-a-vs-b
decided_at: 2026-05-12
created: 2026-05-12
---

# ADR — Opener pattern for MintChatOverlay on verb-chip tap (P004 fix)

## Context

Phase 97.5 R2 perimeter B.1 — P004 « MintChatOverlay body is empty on intent=explain tap » (surfaced 2026-05-12 by Pillar 0.a SCOUT walkthrough on iPhone 17 Pro sim, staging build post-PR-#574). The overlay opens with header « explain » + turn counter « 0 / 3 » + bare input — body completely empty. Maestro flows passed structurally (assertVisible `mint_chat_overlay`) but the semantic value prop collapsed : « Explique-moi » functionally identical to « tap Coach tab ».

The fix requires populating the `NarrativeSleeve` envelope (hook + caption + next_step + metaphor) AS SOON AS the overlay opens. The opener is BEFORE the user types — `user_input_numbers = ∅` for the closed-world citation gate.

Two patterns considered :

- **Option A** : templated client-side. Flutter reads `source_card` (already populated via `SerializedCardContext` from CapDuJourBanner — `computed_facts` + `grounding_keys` + `life_event` + `canton` + `archetype`) + looks up a metaphor in `metaphors.toml` (96 entries : 8 archetypes × 3 intents × 2 cantons × 2 life_events ; HOOK_FALLBACK covers gaps). Renders the 4 envelope slots from deterministic inputs. Zero LLM call. Free turn (not counted against 3-turn cap).
- **Option B** : LLM-generated. Dart fires `POST /coach/chat` with `is_opener=True` on overlay open. Backend calls Anthropic Claude API with the source_card as context. Renders after response. Counts against the 3-turn cap or exempt-via-flag (debate within Option B).

## Decision

**OPTION A — templated client-side opener, zero LLM call, free turn.**

Authority : orchestrator full-autonomy grant (Julien 2026-05-12T09:55Z). Confirmed by 4-expert mini-panel convergence 4/4 (mean confidence 9/10) and Phase 97.5 PLAN.md §C orchestrator recommendation.

## Panel verdicts (4/4 converge on Option A)

| Expert | Verdict | Score | Key argument |
|---|---|---|---|
| **LSFin compliance** | OPTION A | 9/10 | LSFin Art 8 « ability to demonstrate compliance » : Option A is mechanically auditable (template + 96-entry lookup PR-time banned-terms-prescanned). Option B fires `TRANSFER_US_ANTHROPIC` on every overlay-open while ConsentService is still `log_only` (nLPD Art 6 consent-debt). Multiplies free-form LSFin failure surface by verb-tap rate → Phase 97 D-30 « zero violation in 7-day soak » unreachable. |
| **Latency engineer** | OPTION A | 9/10 | Option A paints fully-resolved 4 slots at ~16ms (next frame). Option B's best case is 0ms skeleton + 1.2s p50 / 4.1s p95 / 8s+ Railway cold-start tail — Sentry `coach_chat.first_token` p95 already blows Doherty's 2s engagement threshold. Cellular handover + Anthropic dependency = unbounded tail. |
| **UX narrator** | OPTION A | 9/10 | (1) Voice-system alignment : 96-cell `metaphors.toml` is hand-curated + LSFin-clean ; LLM drifts on long tails. (2) 70/30 wiki/narration doctrine : the opener is *card render* (wiki side), narration currency should be spent on the user's first typed turn. (3) Earned-narration heuristic : instant + personal-numbers + curated-voice beats slow + generic-prose. |
| **Narrator quality** | OPTION A | 9/10 | Closed-world citation gate fall-through on opener turns is the COMMON case, not edge case : `user_input_numbers = ∅` means any regulatory figure the LLM emits risks rejection → Option B collapses to a LESS-personalised FALLBACK_TEMPLATED_TEXT than Option A would have rendered. Option A wins on floor + matches on median + is order-of-magnitude cheaper to evaluate. |

Convergence is unanimous on the question (« which pattern for v2.9 ? ») AND on the score (9/10 each — the missing 1 point is consistently « if user research signals demand vivid AI prose, Option B's ceiling is higher ; not relevant in v2.9 »).

## Implementation contract (consumed by W2-T1 + W2-T2)

### W2-T1 — Dart auto-fire on overlay open (Option A path)

`apps/mobile/lib/widgets/mint_chat_overlay.dart` — on `initState()` :

1. Read `widget.sourceCard` (`SerializedCardContext`) — already populated by parent route.
2. Look up metaphor via `MetaphorService.resolve(archetype, intent, canton, life_event)` reading `assets/metaphors.toml` (96 entries + HOOK_FALLBACK).
3. Construct 4 envelope slots :
   - `hook` : template literal interpolated with `source_card.computed_facts` (e.g. `« Avec un plafond 3a de {plafond} CHF, tu... »` where `{plafond}` is the canton-archetype-specific value).
   - `caption` : intent-specific caption from `metaphors.toml`.
   - `next_step` : verb-specific suggestion (e.g. for `intent=explain` : « Tape une question pour creuser. »).
   - `metaphor` : the resolved metaphor body.
4. Render `NarrativeSleeve(slots: ...)` in the overlay body. Total latency budget : ≤ 16ms (next Dart frame).

### W2-T2 — backend NarrativeSleeve schema-only (conditional scope per PLAN.md v4)

Per PLAN.md line 170 W2-T2 conditional-scope clause : under Option A, W2-T2 collapses to ~1h schema-only confirmation :

1. Confirm `services/backend/app/schemas/narrative_sleeve.py` exists with the 4-slot envelope (`hook`, `caption`, `next_step`, `metaphor`).
2. Verify `/coach/chat` returns `narrative_sleeve` field shape for turns 2-3 (non-opener turns where Option B applies).
3. No new endpoint, no LLM-gen on opener — turns 2-3 continue using the existing `coach_chat.py` path with the `narrative_sleeve` populated in the response.

### W2-T3 — ARB FR header label (orthogonal to opener pattern)

D2 fix (header showing raw enum `explain` instead of FR label) — straight ARB sweep 6 langs × 3 intents. No interaction with opener pattern decision.

### W2-T4 — widget test for populated overlay (Option A path)

Mock `source_card` + `metaphors.toml` lookup → assert 4 slots rendered with user's actual numbers. Fast deterministic test (no LLM mock needed since Option A bypasses LLM entirely).

### Free-turn semantics

Opener does NOT count against the 3-turn cap. Counter logic in `MintChatOverlay` increments turn count on `_sendMessage()` (user input), not on `initState()` (auto-populated opener). Existing turn-counter widget shows « 0 / 3 » before user types — semantically correct.

## Migration path to Option B (v2.10 or later)

Option B is NOT a regression of Option A — it's an evolution. The opener pattern can shift to LLM-gen WHEN AND ONLY WHEN all 3 signals are met :

1. **Latency budget** : `coach_chat.first_token` p95 ≤ 1500ms over a 14-day rolling window on staging + production. (Today : p95 = 4100ms — gap : 2600ms.)
2. **Narrator quality gate fall-through rate** : `gate_failure_rate_on_opener < 8%` on synthetic + real traffic over a 14-day window. Today : not measured — telemetry to add in v2.10.
3. **UX research signal** : ≥ 2 user studies (n ≥ 8 each, archetype-stratified) where users prefer Option B's vivid prose despite the latency, AND voice-system drift incidents ≤ 1 per 1000 narrator emissions over the same window.

Concrete v2.10+ trigger : when 3/3 signals green on a 14-day rolling check, the orchestrator may re-open the panel with the v2.10 latency + quality + UX data on the table. Until then, Option A holds.

## Counter-arguments and data gaps

**Counter-arguments :**

- *« Option A's templates are canned and will feel robotic at scale. »* — Refuted in 3 of 4 verdicts (UX narrator, narrator quality, LSFin) : templates populated with user's actual canton + plafond + archetype + life_event are NOT generic. The « robotic » failure mode is template-without-personalisation ; Option A is template-with-personalisation.
- *« A 4-second LLM call with a 0ms skeleton is good UX. »* — Refuted by latency engineer : skeleton is still an information void in a high-intent gesture (verb tap). Doherty's 2s engagement threshold is the load-bearing constraint. Cold-start tail is unbounded.
- *« Option B's ceiling is higher and we should optimise for the best output, not the worst. »* — Refuted by narrator quality : opener turns have `user_input_numbers = ∅` → closed-world gate fall-through is the COMMON case → Option B floor is LOWER than Option A floor in this regime. Optimising for ceiling that triggers only when fall-through doesn't fire is a category error.
- *« 4-expert panel converging 4/4 is suspicious — echo chamber ? »* — Refuted by inspection : each verdict reaches Option A via a DIFFERENT primary axis (LSFin compliance / latency / voice doctrine / gate-fall-through-rate). The convergence is multi-modal, not single-modal.

**Data gaps :**

- Today's `metaphors.toml` 96-entry coverage matrix (8 archetypes × 3 intents × 2 cantons × 2 life_events) has not been audited for actual cell-fill density. `HOOK_FALLBACK` covers gaps but the fall-through rate is unmeasured. **Mitigation** : W3-T4-stripped (Maestro semantic-on-P004 flow) exercises 3 archetype × intent combinations ; if fall-through hits in those 3, the gap is real and W3 receipts must include a `metaphors.toml` density-audit task.
- Sentry `coach_chat.first_token` p95 = 4.1s claimed by latency engineer is the LATEST observable on staging cassette-warm. The cold-start p95 (post-5-min-idle) is harder to measure without explicit synthetic probes — Phase 97 D-22 7-day soak will surface this.
- LSFin officer in-the-loop validation of Option A's template + lookup-table is NOT yet booked (v3 carryover : Julien to schedule within 3 working days of W2-T5 merge, per §J CA-5).
- The 14-day rolling-window migration-trigger thresholds (~1500ms p95, < 8% gate fall-through, 2 user studies) are educated guesses, not measured-baseline-derived. Sub-task for v2.10 milestone authoring : calibrate against production baselines once available.

## Locks downstream

This ADR locks the following Phase 97.5 contracts :

1. **W1-T1 status** : Decided ✓ — Wave 2 unblocked.
2. **W2-T1 implementation path** : Option A template-fill in Dart (no backend endpoint changes for opener turn).
3. **W2-T2 scope** : ~1h schema-only confirmation (per PLAN.md v4 conditional-scope clause).
4. **W2-T4 test posture** : pure widget test, no LLM mock needed for opener turn.
5. **W3-T4-stripped Maestro semantic flow** : 3 archetype × intent combinations exercising Option A's metaphor lookup density.
6. **v2.10 Option B re-evaluation** : conditional on 3/3 telemetry signals (latency p95 / gate fall-through / UX research).

## References

- Phase 97.5 RESEARCH.md §D.1 (opener-pattern design space) + §F.1 (counter-counter on 3-turn cap)
- Phase 97.5 PLAN.md v4 §C (Wave 1 prerequisite expanded) + W1-T1 + W2-T2 conditional-scope clause
- 4 expert verdict artefacts :
  - `.planning/decisions/2026-05-12-p004-opener-pattern-verdict-lsfin.md`
  - `.planning/decisions/2026-05-12-p004-opener-pattern-verdict-latency.md`
  - `.planning/decisions/2026-05-12-p004-opener-pattern-verdict-ux-narrator.md`
  - `.planning/decisions/2026-05-12-p004-opener-pattern-verdict-narrator-quality.md`
- Phase 96 D-13 SerializedCardContext + D-17 metaphors.toml 96-cell asset
- Phase 94 closed-world citation gate (`citation_parser.py`)
- Phase 97 D-30 ship gate (« zero LSFin violation in 7-day soak »)
- Julien-go ADR 2026-05-12T19:50Z (R1-R5 perimeter Q1+Q2+Q3 GO ; Q4+Q5 NO-GO)

---

*Phase : 97.5 — Product Completeness for Ship*
*Wave : 1 (prerequisite — unblocks Wave 2 parallel-6)*
*Task : W1-T1 — OPENER-DECISION*
*Status : **Decided** by orchestrator-full-autonomy + 4-expert convergence 4/4*
*This ADR is consumed mechanically by W2-T1 (Dart auto-fire), W2-T2 (schema-only confirmation), W2-T4 (widget test), W3-T4-stripped (Maestro semantic flow).*
