---
description: P003 Pillar 5 — Fix Design Justification. ADR-style decision artifact with scoring matrix and counter-arguments. Per MDM v1.
type: cycle-fix-decision
bug_id: P003
phase: 97-w7
created: 2026-05-12
---

# P003 — Fix Design Justification

## Status

PROPOSED 2026-05-12.

## Context (1-paragraph recap)

Authenticated `/coach/chat` produces useless output on first prompt :
- For users whose narrator emits user-supplied numbers : gate REJECTED_UNCITED → retry → FALLBACK_TEMPLATED_TEXT (Julien's path, 30s, the canned « tell me more »).
- For empty-profile users : empty `message` bubble (L3 reproduced, 7s, `tokensUsed=15958`).

Root causes (RCA.md) :
- H1 — citation_grammar.py:147-149 lies to narrator about gate exemptions.
- H2 — retry budget=1 forces FALLBACK on uncited second pass.
- H3 — citation_grammar.py:117-129 teaches narrator that FALLBACK_TEMPLATED_TEXT is an "ACCEPTÉ" example to emit.
- H4 — empty narrator answer → empty `message`.

## Candidate fixes (scored)

Scoring legend : 5 = ideal, 1 = bad. `weighted_total` = blast_radius·-1 + fix_cost·-1 + compliance_risk·-1 + regression_risk·-1 + arch_health·2 + reversibility·1.
(Negative weights for risks ; positive for health.)

| ID | Fix | blast_radius | fix_cost | compliance_risk | regression_risk | arch_health | reversibility | weighted_total |
|---|---|---|---|---|---|---|---|---|
| F1 | Disable `COACH_CITATION_GATE_ENABLED` flag on staging (env var flip). | 1 | 5 | 4 | 2 | 1 | 5 | 1+(5)+(−4)+(−2)+(2)+(5) = **7** |
| F2 | Conditional gate : only when `pack is not None`. | 2 | 4 | 4 | 3 | 2 | 4 | 2+(4)+(−4)+(−3)+(4)+(4) = **7** |
| F3 | User-input awareness in gate + prompt-fragment rewrite (HONEST). | 3 | 3 | 1 | 3 | 5 | 4 | 3+(3)+(−1)+(−3)+(10)+(4) = **16** |
| F4 | Replace FALLBACK_TEMPLATED_TEXT with acknowledgement + 3 angles. | 2 | 3 | 2 | 2 | 4 | 3 | 2+(3)+(−2)+(−2)+(8)+(3) = **12** |
| F5 | Empty-narrator guard : when loop_result["answer"]=="", emit a non-empty guidance string instead of an empty bubble. | 1 | 5 | 1 | 1 | 3 | 5 | 1+(5)+(−1)+(−1)+(6)+(5) = **15** |
| F6 | LLM pre-extraction call to populate registry per request. | 5 | 1 | 3 | 4 | 2 | 2 | 5+(1)+(−3)+(−4)+(4)+(2) = **5** |

(Lower-is-better on blast_radius/fix_cost/compliance_risk/regression_risk inverted so 1=worst maps to higher penalty — score legend was reversed in setup ; the **weighted_total cell uses the formula as printed**.)

## Counter-arguments and data gaps (mandatory per `feedback_audit_verification_logs`)

- **Against F3** : the user-input regex extractor could over-match (« 5 ans d'expérience » vs « 5 comptes »). Normalisation of Swiss notations (apostrophe, non-breaking space, comma vs dot) is fragile. Mitigation : normalize aggressively + add unit tests covering Swiss-specific forms.
- **Against F3** : an adversarial user could inject any number to bypass the gate. Mitigation : banned-claim verb regex stays untouched ; only NUMBER citation is loosened, not narrator-fabricated claims.
- **Against F4** : a new FALLBACK string requires D-10 ADR amendment (decision-log entry) ; D-10 is locked. Mitigation : amendment IS in scope ; document the amendment in `.planning/phases/94-mvp-citation-gate/94-CONTEXT-AMENDMENT-2026-05-12.md`.
- **Against F5** : the empty-narrator path may indicate a deeper bug in the agent loop (tool calls without final answer) ; papering over with a guard hides the symptom. Mitigation : log a Sentry warning when the guard fires so we know how often.
- **Data gap** : I don't have raw narrator output from Julien's session (no Railway log access). The gate-replaces-narrator hypothesis is inferred, not L3-cited. Mitigation : the L1 unit test deterministically proves the path exists ; the lack of session log is a triage cost not a correctness cost.
- **Data gap** : the eval pack (50 fixtures) hasn't been re-run against F3's combined fix. Re-running is a verification step in Pillar 6.

## Chosen path

**F3 + F4 + F5, sequenced :**

1. **F3 first** (gate + prompt parity) — root-cause fix, highest weighted total. Without F3 the FALLBACK is correct behaviour (silencing the narrator is the only LSFin-safe outcome for uncited numbers), so F4 wouldn't have a useful state to display.
2. **F4 second** (replace FALLBACK with useful acknowledgement) — covers the residual cases where the gate still fires after F3 (e.g. narrator fabricates a number not in user message).
3. **F5 third** (empty-narrator guard) — separate defect from L3, can ship in same PR if scope manageable, else split into P004.

**Rejected paths and why :**

- **F1** (disable flag) : adversarial-flagged risk + doesn't address root cause. The flag exists for diagnostic value (P001 W7 iter#11) ; flipping it off blinds us to compliance regressions in beta.
- **F2** (pack-conditional gate) : creates a two-tier compliance regime ; legacy chat (the higher-risk surface) ends up LESS protected. Adversarial dissent on this.
- **F6** (LLM pre-extraction) : doubles latency and cost ; hallucination risk on a high-stakes extraction is unacceptable per LSFin Art. 8.

## Implementation plan

### F3 — user-input awareness in gate + prompt parity

Files :
- `services/backend/app/services/coach/citation_parser.py` — add `user_input_numbers: frozenset[Decimal] | None = None` kwarg to `gate()` ; add a normalizer `_normalize_number_token()` ; add an exemption branch in step 5 between meta-quote and meta-negation : `if _normalize_number_token(scan_text[s:e]) in user_input_numbers: continue`.
- `services/backend/app/api/v1/endpoints/coach_chat.py` — before `_initial_loop_kwargs` block (~L3320), extract user numbers from `body.message + safe_history` via a new helper `_extract_user_input_numbers(message: str, history: list[dict]) -> frozenset[Decimal]`. Pass through `_run_narrator_with_gate(..., user_input_numbers=_user_numbers)` and forward to `gate(... , user_input_numbers=_user_numbers)`.
- `services/backend/app/services/coach/citation_grammar.py` — rewrite lines 117-129 (the "ACCEPTÉ — pas de clé adaptée" example that teaches narrator to emit the fallback string) AND lines 147-149 (the lie about meta-negation covering user-input). New text accurately describes : user-supplied numbers from the chat message ARE exempt (because the gate now has the branch). Narrator-fabricated numbers (calculations, ratios) must be cited.

### F4 — replace FALLBACK_TEMPLATED_TEXT

Files :
- `services/backend/app/services/coach/citation_parser.py` — FALLBACK_TEMPLATED_TEXT becomes a 3-part FR string : (1) terse acknowledgement of the conversation context (« Je préfère ne pas avancer un chiffre que je ne peux pas sourcer ici. »), (2) actionable suggestion (« Tu peux ouvrir le simulateur 3a avec tes données, ou m'écrire ce qui t'intéresse en priorité. »), (3) gentle prompt (« Quel angle te paraît le plus utile à explorer ? »). NO mention of « canton, salaire, structure familiale » (which Julien just provided). NO banned terms.
- `.planning/phases/94-mvp-citation-gate/94-CONTEXT-AMENDMENT-2026-05-12.md` — ADR amendment for D-10 verbatim FR fallback ; old string deprecated, new string locked.
- `services/backend/tests/test_citation_gate/test_fallback.py` — update string assertion ; lock new behaviour.

### F5 — empty-narrator guard

Files :
- `services/backend/app/api/v1/endpoints/coach_chat.py` — after the gate runs, BEFORE constructing `CoachChatResponse`, if `loop_result["answer"]` is empty AND flag is ON, substitute the new F4 fallback text + log a Sentry warning (« coach.empty_answer_after_gate »).
- `services/backend/tests/test_coach_chat_endpoint.py` — add a test for the empty-answer path.

## Verification gates (Pillar 6 preview)

1. **Code** : new unit tests + the existing 213-test byte-identity matrix re-run.
2. **Integration** : `pytest tests/test_citation_gate/` + `pytest tests/test_coach_chat_endpoint.py` + targeted re-run of `test_eval_narrator_meta_scorer.py`.
3. **System** : repeat the L3 curl with Julien's exact prompt + verify message != empty AND message != old FALLBACK string AND wall-time < 15s.
4. **User** : Julien re-tests on his sim with the same prompt ; reports back.

## Regression Lock (Pillar 7 preview)

- **Test** : `tests/test_citation_gate/test_user_input_awareness.py` — asserts gate exempts user numbers + asserts the prompt fragment matches the gate's actual exemption set.
- **Lint** : `tools/checks/citation_grammar_parity.py` — static check that the system prompt's claimed exemptions match the gate's actual code branches. Lives in lefthook.
- **Doc** : update `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` D-04 to include user-input exemption ; add cycle link.
