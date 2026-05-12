---
description: P003 Pillar 1 CAP output — context manifest assembled before any fix. Reading log + verified facts about the authenticated coach citation-gate fallback failure mode that surfaced on Julien's first prompt 2026-05-12T08:13Z. Per MDM v1 Pillar 1.
type: cycle-context
bug_id: P003
phase: 97-w7
created: 2026-05-12
authority: julien-screenshot-2026-05-12T08:13Z + julien-directive-2026-05-12T08:20Z
---

# P003 — Context Acquisition Protocol (CAP) output

## Bug summary (1 sentence)

Authenticated `/coach/chat` returns the canned `Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) et je peux t'orienter vers ce qui s'applique chez toi.` fallback ~30s after a logged-in user submits a complete first prompt with all financial profile data inline (« j'ai 49 ans, je vis en Valais, je suis marié, je gagne 7600 CHF net par mois, j'ai 300 000 CHF de rachat potentiel dans mon 2e pilier, et j'ai 5 comptes 3e pilier, qu'est-ce que je dois faire ? »).

Surface evidence : Julien sim screenshot 2026-05-12T08:13Z (`Coach` tab selected, 4-tab BottomNav visible, message bubble carries the user prompt, response bubble carries the canned text + an empty Sources block + an « Outil éducatif » disclaimer).

## Reading log

CAP step | What | Verified facts
---|---|---
1 | `CLAUDE.md` (auto-loaded) | TOP §9 0-trust (banned phrases without deterministic citation), §1 LSFin (banned terms), §5 NEVER #5 banned terms incl. « garanti / optimal / parfait ». NEVER #8 « no promise of return » → projections must use « pourrait », « envisager ».
2 | `MEMORY.md` index (auto-loaded) | `feedback_anthropic_key_on_railway.md` (key IS on Railway, not a suspect); `feedback_app_targets_staging_always.md` (mobile hits Railway staging `mint-staging.up.railway.app`); `feedback_zero_trust_protocol.md` (tests passing ≠ feature working).
3 | `.planning/phases/97-mvp-parfait-maestro-full-power-maestro-driven-on-device-grou/97-BUGS-REGISTRY.md` rows P001 + P001b-e | P001 status IN_PROGRESS. W7 iter#11 H1 (intent-driven keys) MARGINAL lift (Sonnet 16→18%, Haiku 18→22% vs 95%/90% targets). Notes : « *No prod flag flip — staging stays ON for diagnostic value.* » Critical fact : THE GATE IS ON IN STAGING.
4 | `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` (D-01..D-13) | D-01 placeholder grammar `{{cite:<key>}}` only. D-04#4 strip placeholders from scan input. D-08 retry budget hard-capped at 1 ; second-pass rejection forces FALLBACK. D-10 verbatim FR templated fallback (str constant, no template vars). D-19 default flag OFF for byte-identity invariant. D-20 byte-identical bypass when flag OFF.
5 | `.planning/phases/96-mvp-chat-as-verb/96-CONTEXT.md` | D-13 source_card structured snapshot. Chat-as-verb path passes a `ProjectionGroundingPack` to the gate. Phase 95 W2 plumbing (the wrapper accepts `pack: ProjectionGroundingPack \| None`).
6 | `services/backend/app/services/coach/citation_parser.py:1-150` | 5 number-family regexes (CHF/EUR currency, %, legal article, duration, regulatory constant). Adjacency check via `_CITATION_ADJACENCY_CHARS`. Exempted only on `is_meta_quoted` OR `is_meta_negation` OR legal-article overlap.
7 | `services/backend/app/services/coach/citation_parser.py:450-580` | **Verbatim gate logic on `is_retry=True`** : ANY uncited number → `verdict=GateVerdict.FALLBACK, gated_text=FALLBACK_TEMPLATED_TEXT`, retry_needed=False. Same for banned-claim regex hit.
8 | `services/backend/app/services/coach/citation_grammar.py:1-150` | **System prompt fragment** appended to narrator. Line 147-149 (verbatim) : « *Si le chiffre vient d'un calcul utilisateur (revenus, patrimoine saisi en chat), tu peux l'écrire sans clé — la garde reconnaît les négations et les méta-citations.* » **This is a lie the prompt tells the narrator** : the gate has NO user-input awareness — only meta-quote + meta-negation + legal-article. User-supplied numbers without a registry key fail the gate.
9 | `services/backend/app/api/v1/endpoints/coach_chat.py:3300-3410` | `_run_narrator_with_gate` wrapper. Behaviour : (a) call `_run_agent_loop` once. (b) If `settings.COACH_CITATION_GATE_ENABLED=False` → return loop_result unchanged (byte-identity bypass). (c) If True → run gate ; on `retry_needed=True`, second `_run_agent_loop` call with `body.message + reprompt_addendum` ; second gate with `is_retry=True` ; rejection on retry → `retry_result["answer"] = retry_gated.gated_text` (FALLBACK string).
10 | `services/backend/app/services/coach/citation_registry.py` keys (inferred via earlier session memory) | 18 keys, all regulatory/legal constants (max_3a_2026, lpp_coordination_amount, etc.). **No key represents a user-input value** (user's salary, age, canton, household_type).
11 | `BUGS-REGISTRY.md` P001 row 414 `iter11_h1_verdict: REJECTED_ON_HEADLINE_WITH_PROCESS_LIFT` | H2-H5 hypotheses filed as P001b/c/d/e. None deployed. Architectural root cause per P001 notes « *the dominant failure mode is NOT key-list noise — it's deeper (model attention to the placeholder syntax itself, retry-once collapse semantics, or genuine instruction-tuned-LLM resistance to the « cite or don't emit » directive).* »

## Verified facts (deterministic citations only, no opinions)

| Fact ID | Statement | Citation |
|---|---|---|
| F1 | The fallback string seen by Julien is `citation_parser.FALLBACK_TEMPLATED_TEXT` (line 147-151). | `services/backend/app/services/coach/citation_parser.py:147` |
| F2 | `gated_text=FALLBACK_TEMPLATED_TEXT` is assigned when uncited numbers detected AND `is_retry=True`. | `citation_parser.py:566` |
| F3 | Same string assigned when banned-claim verb regex matches AND `is_retry=True`. | `citation_parser.py:513` |
| F4 | The flag `settings.COACH_CITATION_GATE_ENABLED` short-circuits the gate when False : `loop_result` returned unchanged. | `coach_chat.py:3375-3377` |
| F5 | P001 W7 iter#11 notes say staging keeps the flag ON for diagnostic value (no prod flip). | `97-BUGS-REGISTRY.md` P001 notes |
| F6 | The citation gate exempts numbers only on : meta-quote, meta-negation, legal-article overlap, OR adjacent `{{cite:<key>}}` placeholder with key in allowlist. | `citation_parser.py:541-559` |
| F7 | The narrator system prompt fragment tells the LLM that user-input numbers can be emitted without `{{cite:}}`. | `citation_grammar.py:147-149` verbatim |
| F8 | The gate code path has NO user-input awareness — there is no path that recognises a number as user-supplied vs narrator-fabricated. | `citation_parser.py:498-580` (grep `user_input`, `user_message`, `body.message` returns 0 hits in citation_parser.py) |
| F9 | The citation_registry contains regulatory/legal constants only (max_3a_2026, lpp_coordination_amount, etc.). | Phase 94 CONTEXT D-08 + memory of registry shape |
| F10 | First-pass rejection causes a second narrator call with the same `system_prompt + reprompt_addendum`. The 30-second wall-time observed by Julien is the cumulative cost of 2 LLM round-trips + 2 gate passes. | `coach_chat.py:3396-3409` (two `await asyncio.wait_for(_run_agent_loop(...), timeout=AGENT_LOOP_DEADLINE_SECONDS)` calls in the retry path) |

## Open questions (to be resolved by Pillar 2 panel or Pillar 3 repro)

1. **Is the flag actually ON on Railway staging right now ?** F5 is from the P001 notes (W7 iter#11, dated 2026-05-11T21:30Z). The flag is environment-controlled (`os.getenv("COACH_CITATION_GATE_ENABLED", "").lower() == "true"` per `claude_coach_service.py:1055`). Need L3 verification via Railway env var check OR a `/health` or `/admin/feature-flags` endpoint that surfaces the runtime value.
2. **Does the gate also apply on the LEGACY `/coach/chat` path with NO source_card, or only when source_card is present ?** F2/F3 don't distinguish ; `_run_narrator_with_gate` is the wrapper but `_run_narrator_with_gate_and_cap` (the chat-as-verb path) wraps it. Need to read the chat handler to see which wrapper the request enters.
3. **Did the narrator actually emit user-message numbers (7600, 49, 300000, 5) in its first-pass output ?** Or did it return the fallback string itself (« je n'ai pas cette donnée ») — which then trips the gate's banned-claim regex or its empty-response branch ? Need L3 staging log access to see the raw `loop_result["answer"]`.
4. **Is there a separate fallback in `apps/mobile/lib/services/api_service.dart` that returns the same string on 5xx ?** Need an L0 grep.

## Memory keys to consult before Pillar 5 fix decision

- `feedback_zero_trust_protocol.md` — never claim « shipped / works » without 4-GREEN cube.
- `feedback_pre_push_checklist.md` — schema/config changes need OpenAPI regen + full pytest.
- `feedback_expert_panel_pattern.md` — strategic decisions go through ≥3 expert subagents with verdict synthesis.
- `project_testflight_ship_path.md` — staging deploy fires testflight.yml ; backend changes go through dev → staging merge.
- `feedback_app_targets_staging_always.md` — mobile/sim always hits Railway staging (no local backend for E2E).

## Phase artifacts to consult during Pillar 2 / 5

- `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` (D-01..D-13 locked decisions)
- `.planning/phases/94-mvp-citation-gate/94-03-EVAL-RESULTS.md` (root cause analysis of 60-80% fallback rate)
- `.planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md` (the production deferral rationale)
- `.planning/phases/94.1-wave-4-narrator-prompt-fattening-citation-registry-cite-key-/94.1-EVAL-DELTA.md` (H1 hypothesis + 5 follow-up hypotheses H2-H5)
- `.planning/phases/97-.../eval-runs/P001-iter11-*.json` (4 eval runs : Sonnet/Haiku × baseline/H1)
- `.planning/phases/97-.../97-BUGS-REGISTRY.md` P001 + P001b/c/d/e rows

## Surface model (architectural snapshot, not opinions)

```
mobile (Flutter)                     backend (FastAPI)
─────────────────────────────────────────────────────────────────────
[Coach tab UI] ── POST /api/v1/coach/chat ──> coach_chat.handle_chat
                                                  │
                                                  ├─ build_narrator_system_prompt
                                                  │    └─ + CITATION_GRAMMAR_FRAGMENT
                                                  │       (when flag ON)
                                                  │
                                                  ├─ _run_narrator_with_gate
                                                  │    │
                                                  │    ├─ _run_agent_loop (LLM)
                                                  │    │
                                                  │    ├─ if flag OFF → return as-is
                                                  │    │
                                                  │    ├─ _citation_gate(text, pack=None)
                                                  │    │    │
                                                  │    │    └─ 5 regex passes
                                                  │    │       → REJECTED_UNCITED ?
                                                  │    │
                                                  │    ├─ if retry_needed → 2nd LLM call
                                                  │    │    + REPROMPT_ADDENDUM_UNCITED
                                                  │    │
                                                  │    └─ if is_retry=True + uncited
                                                  │       → gated_text=FALLBACK_TEMPLATED_TEXT
                                                  │
                                                  └─ JSON response
                                                       answer: <fallback or gated>
[Coach chat bubble] <─────────────────────────────  empty Sources block
                                                    « Outil éducatif » disclaimer
```

## Cycle entry conditions met (per MDM)

- [x] Bug has single atomic title (« coach returns fallback on first auth prompt »)
- [x] Bug is in registry (P003 row to be added next step)
- [x] Severity computed : P0 (first-contact UX broken on canonical flow) × all-archetype (4) / medium fix-cost (4) = 8. But severity weighting upgraded to P0=8 → 8 × 4 / 4 = **8**, escalated by user-visible impact.

## Next steps per MDM

- Pillar 2 — spawn 5 expert sub-agents in parallel with the 8.b briefing preamble, each with role-specific scope. Collect verdicts. Write `.planning/cycles/P003/PANEL.md`.
- Pillar 3 — climb Repro Ladder L0 → L1 → L2 → L3 → L4. L0 partly done in this CAP (gate code path read). L1 next : run the gate against a synthetic narrator output mentioning Julien's 4 user numbers without citations and verify FALLBACK is what comes out. L3 critical : curl staging with Julien's exact prompt + capture pre-gate narrator output via Railway log.
- Pillar 4 RCA → enumerate every hypothesis with verification command and RED/GREEN result.
- Pillar 5 Fix Design → 3-5 alternatives scored by the matrix in MDM Pillar 5.
