---
name: MVP-B14-B15-DEBT-CONTEXT-RAG — perimeter STUB
description: Device finding 2026-05-08 (TestFlight v2.12.2+4) — user typed « j'ai des dettes » to coach, response talked about « amortissement direct vs indirect » (B14) and showed generic suggest_actions chips ignoring the just-given context (B15). Root cause = RAG retrieval has no intent/life-event gate ; suggest_actions reads cold profile, ignores in-flight tool calls. Effort ~1 j.
type: decision
date: 2026-05-09
status: STUB (à ouvrir post G2 device confirm sur PR #534 B13 fix)
related:
  - .planning/decisions/2026-05-08-perimeter-b8-doctrine-runtime-wire/STUB.md
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md
  - PR #532 (B6 retractation + B8 STUB)
  - PR #534 (B13 anonymous routing leak)
sources:
  - Device finding by Julien (2026-05-08, TestFlight v2.12.2+4) sur flow « j'ai des dettes »
  - Code trace `services/backend/app/services/rag/orchestrator.py:82-100` (no intent gate)
  - Code trace `services/backend/app/api/v1/endpoints/coach_chat.py:883-960` (_compute_suggested_actions reads cold profile)
  - Code trace `services/backend/app/services/rag/faq_service.py:1033-1075` (FaqService.search keyword-only)
---

# MVP-B14-B15-DEBT-CONTEXT-RAG — STUB

## Goal

**Gate the coach response generation on detected user intent / life event** so a debt-conso scenario doesn't pull mortgage-amortissement education content + adjust suggest_actions chips to skip generic profile-gap questions when the just-given message provided concrete data.

This perimeter exists because the device walk on 2026-05-08 revealed that typing « j'ai des dettes » to the coach surfaced the « Amortissement direct vs indirect » education insert as the response framing — completely off-topic for a debt-consolidation scenario. The root cause is structural : the RAG pipeline has no awareness of the user's current intent or life event when retrieving knowledge chunks.

## B14 root cause (verified)

User input « j'ai des dettes » → RAG vector retrieval pulls the `immobilier_amortissement_direct_indirect.md` insert because :

1. **Vector semantic match** — the markdown insert body contains « tu gardes une dette élevée », « rembourser ta dette petit à petit ». Embedding similarity to « j'ai des dettes » is high.
2. **FAQ keyword fallback** — `services/backend/app/services/rag/faq_service.py:1033` `search()` matches « dette » against `faq_mortgage_amortissement.answer` (« tu gardes une dette élevée »). When vector store returns < 2 results, this kicks in.
3. **Zero context gate** — neither path filters by user's current life event (`debtCrisis` vs `housing`) nor archetype-aware intent.

The retrieved chunks become part of the LLM prompt context. The LLM, given « amortissement direct vs indirect » as the most relevant context, naturally synthesizes its response around it.

## B15 root cause (verified)

`_compute_suggested_actions(user_id, db)` at `coach_chat.py:883` reads only **cold profile state** from the DB. It ignores :

- The user's current message text (no parsing of « j'ai des dettes »).
- In-flight `save_fact` tool calls in the current agent loop turn (e.g. `hasDebt=true` just persisted).
- The conversation history's last 2-3 turns of context.

Result : a user who just shared concrete data still gets generic « Quel âge as-tu ? » / « D'où vient ton argent ? » chips because the cold profile fields are still empty.

## Truth-in-claim retractation (per CLAUDE.md §9.1)

The PR #532 audit synthesis claimed B14 was « contained to mortgage trigger keyword ». **That claim is overstated.** The actual scope is broader :

- ✅ Mortgage trigger keyword in `education/inserts/concepts/immobilier_amortissement_direct_indirect.md` is too greedy on « amortissement »
- ❌ But the structural issue is the **absence of any intent classifier** in the RAG pipeline. Even if we tighten this one trigger, the same bypass happens on every other insert that mentions « dette / dépense / argent » in its body.

So **B14 is symptomatic, not causal**. The fix at trigger level (option C below) ships value but leaves the structural debt open.

## Fix options

| Option | Description | Effort | Coverage | Pick |
|---|---|---|---|---|
| **A. Tag-based intent metadata + retrieval filter** | Add `life_events: [housing, debt, ...]` to insert frontmatter ; pre-classify user message into one of 18 life events via keyword heuristic OR small SLM ; filter retrieval to overlapping life events | 1.5 j | High — extends to all 84 inserts | ⏳ defer |
| **B. Inject detected intent into system prompt** | Detect user intent (debt/housing/family/...) via keyword pre-scan ; append « Current user intent: debt_consolidation. Do NOT discuss mortgage amortization unless user is property owner » to system prompt | 0.4 j | Medium — depends on LLM compliance | ✅ ship now |
| **C. Tighten trigger keywords** | Edit `immobilier_amortissement_direct_indirect.md` frontmatter trigger to require co-occurrence of « hypothèque » or « propriétaire » | 0.1 j | Low — patch one insert, structural debt remains | ✅ ship now |
| **D. Drop FAQ keyword fallback** | Remove `FaqService.search(question)` block at `orchestrator.py:92-97` ; rely on vector-only retrieval + empty-context handling | 0.3 j | Low — orthogonal to B14 root cause but reduces noise | 🟡 evaluate |

**Recommendation : ship B + C now (~0.5 j), defer A behind a measurement gate.**

Reasonably : B + C together close the immediate user-facing bug. We measure whether the same pattern recurs on other intent×insert combos in walker logs ; if yes, escalate to A.

## B15 fix

Single targeted change in `_compute_suggested_actions` :

1. Accept new param `last_user_message: str` from the agent loop.
2. Pre-scan for concrete-data signals : numbers + currency markers (`\d+(['\s]?\d+)*\s*(CHF|chf|francs?)`) , percentages (`\d+\s*%`), date markers (`\d{4}|janvier|février|...`), known fact keywords (« dette de », « salaire de », « j'ai un 3a », ...).
3. If `last_user_message` contains ≥2 concrete-data signals AND a `save_fact` ran in the current turn → suppress generic « ask basic profile » chips ; instead emit forward-progress chips (« Compare ta dette aux taux du marché », « Calcule ta capacité de remboursement », « Lance le simulateur de désendettement »).
4. If user said « j'ai des dettes » bare (no numbers), keep existing flow but add « Quel est le montant total ? » as the first chip (more aligned than « D'où vient ton argent ? »).

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — `flow_debt_crisis_response.yaml` : type « j'ai des dettes » → assert response does NOT contain « amortissement direct » | Maestro flow exit 0 |
| G2 | device by Julien — confirm on TestFlight v2.12.2+5 sur expat_eu seed account | TestFlight |
| G3 | dev CI green — flutter analyze + pytest backend (incl. new debt-context tests) | run green |
| G4 | regression tests — new test asserts intent-classifier filters mortgage chunks when user_intent=debt_consolidation | new test exit 0 |
| G5 | LSFin/accent/ARB lint — no banned-term regression introduced | banned_terms_arb exit 0 |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| B14.1 | Add `_classify_user_intent(message: str) -> str` heuristic in `coach_chat.py` returning one of `{debt, housing, family, career, retirement, taxes, other}` based on keyword match (« dette/endetté/surendetté » → debt ; « hypothèque/maison/appart » → housing ; ...) | 0.15 j | None |
| B14.2 | In `coach_chat.py` agent loop, call `_classify_user_intent(user_message)` once per turn ; pass into `RAGOrchestrator.query` via new optional param `user_intent` | 0.1 j | B14.1 |
| B14.3 | In `orchestrator.py:query`, pass `user_intent` to `retriever.retrieve` ; in retriever, filter retrieved chunks where `metadata.life_events` (when present) does NOT include `user_intent` | 0.2 j | B14.2 |
| B14.4 | In ingester, parse new optional `life_events` frontmatter field from markdown ; persist to vector store metadata | 0.1 j | None |
| B14.5 | Update `immobilier_amortissement_direct_indirect.md` frontmatter to add `life_events: [housing]` ; tighten trigger keywords | 0.05 j | B14.4 |
| B14.6 | Add system-prompt augmentation in `coach_chat.py` build_system_prompt : « Current user intent (heuristic): {intent}. Avoid off-topic education content. » | 0.1 j | B14.1 |
| B14.7 | Backend test `test_coach_debt_intent_filters_mortgage.py` : POST « j'ai des dettes » to `/api/v1/coach/chat`, assert response context does NOT include `immobilier_amortissement_*` chunks | 0.2 j | B14.1-B14.6 |
| B15.1 | Refactor `_compute_suggested_actions` to accept `last_user_message: Optional[str] = None` and `recent_save_fact_keys: list[str] = []` | 0.1 j | None |
| B15.2 | Add `_has_concrete_facts(message: str) -> bool` regex scan for numbers/CHF/% | 0.05 j | None |
| B15.3 | When `_has_concrete_facts(last_user_message)` AND any save_fact ran this turn → suppress generic profile-gap chips ; emit forward-progress chips for the detected intent | 0.15 j | B15.1 + B15.2 + B14.1 |
| B15.4 | In agent loop, pass `last_user_message` + tool_call_history to suggest_actions handler | 0.1 j | B15.1 |
| B15.5 | Backend test `test_suggest_actions_skips_generic_when_facts_given.py` : tool call with concrete-fact context → no « D'où vient ton argent » chip | 0.15 j | B15.1-B15.4 |

**Total estimé** : ~1.4 j (incl. tests).

## Counter-arguments and data gaps

- **Risk 1** : Heuristic intent classifier (option B) misses nuance — « j'ai 50k de dettes mais je veux acheter » should activate BOTH debt and housing intents. Mitigation : multi-label intent detection + take union when filtering. Or accept single-label miss for v1, escalate to ML classifier in B14-v2.
- **Risk 2** : Filtering retrieval results too aggressively can starve the LLM of relevant context, causing the « Sortie vide » fallback. Mitigation : guard — if filter would reduce results to 0, fall back to unfiltered retrieval + log warning ; observability metric : `intent_filter_starvation_rate`.
- **Risk 3** : `life_events` frontmatter on 84 existing inserts is a manual migration burden. Mitigation : default to all-life-events (`[*]`) for un-tagged inserts ; only tag inserts that are clearly scoped (mortgage / divorce / ELP / FATCA). Migrate opportunistically.
- **Risk 4** : The system prompt augmentation (option B) burns tokens on every turn. ~50 tokens × 30k turns/day = 1.5M tokens/day ≈ $4.5/day on Sonnet 4.6. Acceptable cost vs. user-trust value.
- **Risk 5** : B15 forward-progress chips need a chip catalog per intent. Building a complete catalog is scope creep ; ship with 3-4 chips per intent for the 4 highest-frequency (debt / housing / retirement / taxes) and leave others on the existing flow.
- **Data gap** : No telemetry yet on intent×retrieval mismatch frequency. We can't measure baseline « how often does B14 fire today ? » without instrumenting the existing flow first. Mitigation : ship B14.1 + B14.2 (intent classifier) WITHOUT the filter on day 1, log every retrieval that would be filtered, observe 48h, then enable the filter on day 3.
- **Risk 6** : User may legitimately want to discuss mortgage amortization in a debt-conso framing (e.g. « j'ai des dettes, dois-je amortir mon hypothèque plus vite ? »). Multi-label intent detection covers this ; single-label misses it. Need user-message-LSBM (longest-substring-best-match) to detect both « dettes » AND « hypothèque » triggers.
- **Truth-in-claim** : This perimeter does NOT close the broader « no intent classifier in the entire app » structural gap. It contains the bleed at the coach surface. Other surfaces (reminders, education feed, financial plan card) remain context-blind. Filed as MVP-INTENT-GLOBAL future perimeter.

## Approval gate

À ouvrir comme PR séparée post-Julien G2 device confirm sur TestFlight v2.12.2+5 (the next bump that includes B13 PR #534 fix). **Pas avant.**

Reasonably : G2 confirm = the user-facing B13 anonymous routing fix lands cleanly. THEN we open B14+B15 to fix the structural debt-context gap.

## Order of fixes (within this perimeter)

1. **B14.1 + B14.6** (intent classifier + system-prompt augmentation) — ship first, lowest risk, fast feedback loop.
2. **B14.5** (tighten amortissement trigger) — surgical patch, no new code surface.
3. **B14.4 + B14.3** (ingester + retriever filter, with starvation guard).
4. **B15.1 → B15.4** (suggest_actions has-facts gate).
5. **B14.7 + B15.5** (regression tests).
6. **B14.2** wires it all together at the coach_chat agent loop call site.

Each fix is an atomic commit. PR opens only after all 6 commits + sim walker G1 + flutter analyze + pytest local green.
