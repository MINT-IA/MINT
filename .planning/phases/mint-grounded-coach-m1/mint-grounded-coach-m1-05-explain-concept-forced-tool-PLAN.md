---
phase: mint-grounded-coach-m1
plan: 05
type: execute
wave: 4
depends_on:
  - mint-grounded-coach-m1-04-concept-registry-claim-checker
files_modified:
  - services/backend/app/services/coach/coach_tools.py
  - services/backend/app/services/rag/llm_client.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/app/services/coach/claude_coach_service.py
  - services/backend/tests/test_explain_concept_tool.py
  - services/backend/tests/test_coach_chat_intent_force.py
autonomous: true
requirements: [WS-B]
must_haves:
  truths:
    - "An explain_concept tool returns the curated registry page for a concept (no LLM paraphrase)"
    - "A definition-intent question forces tool_choice to explain_concept on the AUTHENTICATED surface — first LLM call of the turn only"
    - "show_fact_card content/source are validated against the concept registry before render"
  artifacts:
    - path: "services/backend/app/services/coach/coach_tools.py"
      provides: "explain_concept tool definition + registry-backed handler"
      contains: "explain_concept"
  key_links:
    - from: "coach_chat.py intent classifier"
      to: "tool_choice explain_concept"
      via: "forced tool on definition intent (first call only)"
      pattern: "explain_concept"
    - from: "show_fact_card handler"
      to: "concept_registry"
      via: "content/source validation"
      pattern: "concept_registry|CONCEPT_REGISTRY"
---

<objective>
Force grounded retrieval for definitions on the authenticated surface and gate show_fact_card
against the registry (CONTEXT WS-B, audit 04 §3.b). Today tool_choice is hardcoded "auto"
(llm_client.py:227) so the LLM defines concepts from its weights; the anonymous surface
already has intent-forced tool_choice (anonymous_chat.py:204) — generalise that pattern to
the authenticated path, force explain_concept on definition intent, and validate
show_fact_card content/source against the curated registry so a fact card can't ship an
inverted definition with a fabricated source.

Purpose: forced retrieval + registry-gated cards turn the claim-checker (Plan 04) from a
post-hoc catch into a prevention. The pattern exists; this generalises it.
Output: explain_concept tool + forced tool_choice + gated fact card; backend suite green.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-etat-des-lieux-20260612/04-coach-orchestrator.md
@./CLAUDE.md

<interfaces>
Exact anchors (read in context — do NOT re-explore):
- anonymous_chat.py:204-208 — the pattern to generalise:
    tool_choice = {"type":"tool","name":"get_regulatory_constant"} if force_tool else {"type":"auto"}
  driven by a finance-keyword regex at :183-187. Generalise to intent-forcing explain_concept.
  NOTE the loop shape of that pattern: the FORCE applies to the FIRST LLM call only; the
  follow-up call (with the tool_result) runs unforced so the model can produce the final
  text answer ("force turn 1, answer turn 2").
- llm_client.py:227 — authenticated path hardcodes tool_choice {"type":"auto", ...}. This is
  where the forced-tool decision must be threadable (pass tool_choice through, defaulting to
  auto, so coach_chat can force explain_concept on definition intent).
- coach_chat.py:1868 _classify_user_intent(message) -> set[str] — existing intent classifier
  on the authenticated surface. Add/derive a "definition_request" intent (concept definiendum
  from CONCEPT_REGISTRY present + interrogative pattern "c'est quoi", "qu'est-ce que",
  "explique"). When detected, force tool_choice explain_concept for that turn's FIRST call.
- coach_chat.py:4699 detected_intents = _classify_user_intent(...) — where intents are
  already consumed; thread the forced tool_choice from here.
- FIRST-CALL-ONLY CONSTRAINT (plan-check blocker fix): the forced
  {"type":"tool","name":"explain_concept"} tool_choice applies ONLY to the FIRST LLM call of
  the turn. Subsequent agent-loop iterations (the loop is capped by
  MAX_AGENT_LOOP_ITERATIONS=4) MUST revert to {"type":"auto"} — otherwise every iteration is
  forced to call the tool again and the loop can never emit the final text answer. This
  mirrors the anonymous_chat.py shape exactly (force turn 1, answer turn 2).
- coach_tools.py COACH_TOOLS list (starts :126) — add the explain_concept tool definition
  (input: concept_key enum over the registry keys). Handler returns the registry page
  (canonical_fr + source) — backend-handled, fed back as tool_result (like get_regulatory_constant).
- coach_tools.py show_fact_card schema :130-161 — content/source/highlight_value are 100%
  LLM-generated today (audit 04 §1.3 P1). Add a validation step: when a show_fact_card is
  emitted for a registry concept, its content must not contradict the page (run claim_checker
  on the card content) and source must be the page's source (reject/repair off-registry source).
- claude_coach_service.py:740-748 — the free-text CONNAISSANCES SUISSES block. Tighten the
  directive so definitions of registry concepts go through explain_concept, not prose recall.
  Do NOT delete the prose (it remains conversational scaffolding) — change the instruction to
  "pour DÉFINIR un concept réglementé, invoque explain_concept ; ne définis jamais de mémoire".
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: explain_concept tool + registry-backed handler</name>
  <files>services/backend/app/services/coach/coach_tools.py, services/backend/tests/test_explain_concept_tool.py</files>
  <behavior>
    - COACH_TOOLS contains an explain_concept tool: input_schema requires concept_key
      (enum/string over CONCEPT_REGISTRY keys); description forces its use for any conceptual
      definition of a regulated Swiss concept.
    - The backend handler resolves concept_key → ConceptPage and returns canonical_fr +
      source as the tool_result (no LLM paraphrase of the definition itself).
    - An unknown concept_key returns a structured "not in registry" result (never invents).
  </behavior>
  <action>Add the explain_concept tool definition to COACH_TOOLS and a handler that calls concept_registry.resolve(). Register it as backend-handled (mirror get_regulatory_constant / retrieve_memories handling — fed back into the loop, may be forwarded to mobile as a fact card payload in Plan-later, but for now returns the page text as tool_result). Write test_explain_concept_tool.py: tool present in get_llm_tools(), handler returns rachat_lpp canonical_fr, unknown key returns not-found shape, no banned term in returned text.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_explain_concept_tool.py -q 2>&1 | tail -10</automated>
  </verify>
  <done>explain_concept tool defined + registry-backed handler returns canonical pages; test green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Force explain_concept on definition intent (authenticated surface, first call only)</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py, services/backend/app/services/rag/llm_client.py, services/backend/app/services/coach/claude_coach_service.py, services/backend/tests/test_coach_chat_intent_force.py</files>
  <behavior>
    - A "c'est quoi un rachat" style message (registry definiendum + interrogative) causes
      the authenticated path to set tool_choice {"type":"tool","name":"explain_concept"} for
      the FIRST LLM call of that turn (generalising the anonymous_chat.py:204 pattern).
    - FIRST-CALL-ONLY: subsequent agent-loop iterations (MAX_AGENT_LOOP_ITERATIONS=4) revert
      to {"type":"auto"} — mirroring the anonymous pattern (force turn 1, answer turn 2) —
      so the loop terminates with a final text answer after the explain_concept tool_result.
    - A non-definition message leaves tool_choice at auto on every call (no regression to
      save_fact / route_to_screen flows).
    - The CONNAISSANCES SUISSES directive (claude_coach_service.py:740) instructs the LLM to
      DEFINE regulated concepts only via explain_concept, never from memory.
  </behavior>
  <action>Thread a tool_choice override through llm_client.generate (replace the hardcoded :227 with a parameter defaulting to auto). In coach_chat.py, extend _classify_user_intent (:1868) to detect a definition_request intent (registry definiendum + "c'est quoi/qu'est-ce que/explique"); where intents are consumed (:4699 region) compute the forced tool_choice and pass it to the FIRST LLM call ONLY — the agent loop's follow-up iterations after the tool_result revert to auto. Tighten the claude_coach_service.py:740 directive prose (neutral language, correct accents, no banned terms). Write test_coach_chat_intent_force.py: definition message → first call forced explain_concept AND second/loop calls auto AND the loop TERMINATES with a text answer after the tool_result; chitchat → auto on all calls; existing save_fact path unaffected (assert tool_choice stays auto for a fact-declaration message).</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_chat_intent_force.py -q 2>&1 | tail -12</automated>
  </verify>
  <done>Definition intent forces explain_concept on the FIRST call only; loop iterations revert to auto and terminate with a text answer after the tool_result; non-definition stays auto; directive tightened; test green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Gate show_fact_card content/source against the registry</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py, services/backend/tests/test_coach_chat_intent_force.py</files>
  <behavior>
    - When a show_fact_card is emitted whose title/content concerns a registry concept, the
      content is run through claim_checker; a definitional inversion in the card is blocked
      (card rejected → fallback text), and an off-registry source for a known concept is
      repaired to the page source or rejected.
    - A correct fact card (content consistent with the page, registry source) renders.
  </behavior>
  <action>In the show_fact_card emit path (coach_chat flutter_tool_calls assembly, INTERNAL/external split region ~4314-4362), add validation: if the card maps to a registry concept, run claim_checker.check_claims on content; on violation, drop the card and emit the templated fallback; for source, if the concept resolves, force the page source. Extend the test to cover: inverted-content card blocked, correct card passes, fabricated-source card repaired.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_chat_intent_force.py -q -k "fact_card or source or card" 2>&1 | tail -10</automated>
  </verify>
  <done>Inverted/fabricated fact cards blocked or repaired against the registry; correct cards render; test green.</done>
</task>

<task type="auto">
  <name>Task 4: Full backend suite — no regression</name>
  <files>services/backend</files>
  <action>Run the full backend suite. Threading tool_choice + the fact-card gate can affect coach_chat tool-loop tests; update only the ones encoding the old auto-everywhere behaviour, justify in SUMMARY. The prose change must not introduce a banned term — run the banned-terms check on the edited prompt block.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -8</automated>
  </verify>
  <done>Full backend suite green; prompt prose banned-term-clean; updated tests justified.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM definition output → user | Definitions sourced from weights instead of the curated registry |
| show_fact_card payload → mobile render | LLM-authored content/source crossing to a rendered card |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-05-01 | Information disclosure | tool_choice=auto on definitions | mitigate | Force explain_concept on definition intent (authenticated surface, first call of the turn) |
| T-m1-05-02 | Spoofing | show_fact_card fabricated source | mitigate | Validate card content via claim_checker; force registry source |
| T-m1-05-03 | Denial of service (loop never answers) | forced tool_choice on every loop iteration | mitigate | First-call-only force; iterations 2..MAX_AGENT_LOOP_ITERATIONS revert to auto; termination test |
| T-m1-05-SC | Tampering | pip installs | accept | No new packages; existing SDK + pytest |
</threat_model>

<verification>
- `grep -n "explain_concept" services/backend/app/services/coach/coach_tools.py` shows the tool definition.
- `grep -n "explain_concept" services/backend/app/api/v1/endpoints/coach_chat.py` shows the forced-tool wiring (first call only).
- `grep -c "auto" services/backend/app/services/rag/llm_client.py` confirms tool_choice is now parameterised (not hardcoded auto-only).
- The intent-force test asserts loop termination with a text answer after the tool_result.
- `cd services/backend && python3 -m pytest tests/ -q` exits 0.
</verification>

<success_criteria>
explain_concept returns curated registry pages, definition-intent questions force that tool
on the FIRST LLM call of the turn (loop iterations revert to auto and terminate with a text
answer), show_fact_card content/source are validated/repaired against the registry, the
CONNAISSANCES directive routes definitions through the tool, and the full backend suite is green.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-05-SUMMARY.md` when done.
</output>
