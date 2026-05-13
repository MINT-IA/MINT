---
type: expert-verdict
role: lsfin-compliance
status: Decided
decided_at: 2026-05-12
panel_question: opener-pattern-option-a-vs-b
---

# P004 Opener Pattern — LSFin Compliance Officer Verdict

**Verdict : OPTION A**

**Score : 9 / 10**

## Rationale

LSFin Art 8 (« ability to demonstrate compliance ») is the load-bearing constraint here, and Option A satisfies it mechanically while Option B satisfies it only probabilistically.

Option A's opener is a pure function of typed inputs : `source_card` (already audited at CapDuJourBanner population time), `metaphors.toml` (96-entry lookup table, version-pinned, banned-terms-prescanned at PR time by `tools/checks/banned_terms_*`), and the envelope template. Every rendered opener is reproducible from a row in the analytics log : given `(archetype, intent, canton, life_event)`, the output is determined. That is the literal definition of « auditable » in Art 8 (« preuve a posteriori de la conformité »). The FALLBACK_TEMPLATED_TEXT path in `narrator.py` is precedent : we already use templated text whenever LLM output fails lint. Option A simply makes the safe path the default for the opener turn — the highest-volume, lowest-personalisation turn in the funnel.

Option B fires a TRANSFER_US_ANTHROPIC event on every overlay open. With v2.9 ConsentService in `log_only` mode, this means nLPD Art 6 al. 6 granular consent is NOT enforced at runtime — we are accumulating a consent-debt that will surface at v2.10 hard_block promotion. More damning : every opener becomes a free-form generation that must pass LSFin Art 7-10 (« no promise, no banned term, no « optimal » / « garanti » »). The FALLBACK_TEMPLATED_TEXT path exists precisely because we have already observed LLM output failing this lint. Making opener LLM-gen multiplies the failure surface by the verb-chip tap rate (estimated ~3-7 taps per session).

Phase 97 D-30 ship gate (« zero LSFin violation in 7-day staging soak ») is approximately unreachable with Option B at staging traffic volume. Option A is reachable by construction : if the lookup table passes PR-time lint, runtime cannot violate.

The « lucidité » counter (Option B personalisation) is real but addressable inside Option A : the 96-entry table is segmented on the four axes that matter (archetype, intent, canton, life_event). Personalisation is granular, just pre-computed.

## Counter-arguments and data gaps

- **Where I could be wrong** : if `metaphors.toml` coverage gaps force HOOK_FALLBACK to fire >15% of the time, perceived personalisation collapses and lucidité suffers — Option B's marginal LSFin risk might be worth the UX gain. I do not have current HOOK_FALLBACK hit-rate telemetry.
- **Data that would change my mind** : (1) staging soak showing Option A HOOK_FALLBACK rate <5% AND user-reported « ça ne me parle pas » <10% → Option A is settled ; (2) any signal that LSFin examiner accepts runtime LLM-gen with deterministic post-filter as Art 8-compliant (no current FINMA precedent known) → Option B becomes viable.
- **Asymmetry** : nLPD Art 6 hard_block at v2.10 is calendar-fixed ; lucidité regret is reversible by table expansion. Compliance regret is not reversible.

## Migration path (Option A → Option B in v2.10+)

1. v2.9 ships Option A. Telemetry logs `(source_card_hash, opener_rendered, hook_fallback_fired, user_typed_followup)` per overlay.
2. v2.10 promotes ConsentService to `hard_block` + ships TRANSFER_US_ANTHROPIC granular consent UI.
3. v2.11 introduces Option B **only on the second turn onward** (user has already engaged), with `FALLBACK_TEMPLATED_TEXT` as runtime safety-net and the Option A opener preserved as the cold-start frame.
4. Opener turn stays templated permanently. LLM-gen earns its way in by user pull, not push.
