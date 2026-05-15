---
phase: wave-1c-coach-tool-dispatch-rca
wave: A1
parent_wave: A
depends_on:
  - wave-1c-A-PLAN.md  # merged as PR #634 sha bc020925 at 2026-05-15T17:01:05Z
autonomous: true
files_modified:
  - services/backend/app/services/coach/citation_grammar.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
wave1c_decisions_addressed: [D-03, D-08, D-09, D-10, D-11, D-12]
branch: feature/wave-1c-A1-mandate-position
target_branch: dev
must_haves:
  truths:
    - "Wave A doctrine MANDATE is duplicated at BOTTOM of citation grammar fragment AND injected as a 1-line rappel after `## INTENTION DETECTEE` (system prompt tail, ~99% of prompt) — TOP+BOTTOM mitigation per Liu 2024 lost-in-the-middle."
    - "Both _build_citation_grammar_fragment() AND build_intent_scoped_citation_grammar() apply the SAME duplication, no doctrine drift between paths."
    - "The new tail rappel is appended in coach_chat.py:_build_system_prompt_with_memory AFTER the existing INTENTION DETECTEE block (which ends at ~line 4170) — placed LAST so it sits closest to the user message."
    - "LSFin banned-terms scan + accent lint + project-doctrine grep (`tu dois | tu devrais | il faut`) exit 0 on both touched files."
    - "PR Wave A1 merges to dev only AFTER CI green; dev→staging follows; live probe re-run by orchestrator confirms `tool_use` emission. If still broken, escalation to tool_choice=any is a separate Wave A2 plan, NOT in scope here."
  artifacts:
    - path: services/backend/app/services/coach/citation_grammar.py
      provides: "Wave A constants `_TOOL_USE_MANDATE` and `_TOOL_USE_WRONG_RIGHT_EXAMPLE` are unchanged. _build_citation_grammar_fragment() final composition becomes: `mandate + header + tool_paragraph + keys_section + examples + rule_section + _TOOL_USE_MANDATE_REPEAT` (where the repeat is the mandate text wrapped in a 'RAPPEL' header to avoid byte-identical duplication of the section title). build_intent_scoped_citation_grammar() applies the same."
      contains: "RAPPEL — INVOCATION OBLIGATOIRE"
    - path: services/backend/app/api/v1/endpoints/coach_chat.py
      provides: "_build_system_prompt_with_memory appends a 1-line RAPPEL_MANDATE block AFTER the existing `## INTENTION DETECTEE` block (line 4170 in pre-PR code), BEFORE the function returns system_prompt. Constant defined at module level, sister to REPROMPT_ADDENDUM_TOOL_USE_MISSING."
      exports: ["RAPPEL_MANDATE_TAIL"]
  key_links:
    - from: "services/backend/app/services/coach/citation_grammar.py::_build_citation_grammar_fragment"
      to: "_TOOL_USE_MANDATE_REPEAT (new tail block)"
      pattern: "MANDATE text appears at TWO positions in the fragment: TOP (before legacy header) AND BOTTOM (after rule_section)"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py::_build_system_prompt_with_memory"
      to: "RAPPEL_MANDATE_TAIL"
      pattern: "appended unconditionally as the last block before the function returns; placed AFTER the INTENTION DETECTEE block so it sits closest to the user message in the final API payload"
---

<objective>
Land the prompt-position iteration on Wave A's MANDATE. Wave A correctly composed the doctrine but placed the MANDATE at 51.4% of a 45,879-char system prompt — peak Liu 2024 lost-in-the-middle zone. Sonnet under-attends and chooses the polite-deferral path (« j'ai besoin de récupérer tes données ») instead of invoking `tool_use`. The runtime gate has no leverage because no `{cite:tool_*}` placeholder is emitted.

Fix: apply the same TOP+BOTTOM duplication pattern CLAUDE.md uses for its 6 critical rules, scoped to the citation grammar.

1. Duplicate the MANDATE block at the BOTTOM of `_build_citation_grammar_fragment()` and `build_intent_scoped_citation_grammar(intents)` — same constants, no text duplication in source (reuse `_TOOL_USE_MANDATE`).
2. Inject a 1-line MANDATE rappel at the END of the system prompt (after `## INTENTION DETECTEE`, immediately before the user message in the final API payload).

Output: 1 PR on new branch `feature/wave-1c-A1-mandate-position` targeting `dev`, ~30-40 lines net diff (mostly +1 string concat in 2 functions + 1 new module-level constant + 1 append in `_build_system_prompt_with_memory`). Tests for the new positions ship in this same PR (small scope, byte-stability assertions).
</objective>

<execution_context>
This wave is BACKEND-ONLY. No Flutter touch. The prompt-fragment edit affects user-facing French narrator copy → LSFin banned-terms scan + accent lint are mandatory pre-push.

Pre-push design panel (per CLAUDE.md §3.5 + memory `feedback_design_panel_before_push`): 4 subagents in parallel before `gh pr create` — same composition as Wave A:
- `security-auditor` — LSFin banned-terms scan on RAPPEL_MANDATE_TAIL FR text + the duplicated MANDATE block.
- `qa-expert` — opinion on whether the byte-stability tests adequately lock the new TOP+BOTTOM positions.
- `ai-engineer` — review the rappel phrasing for narrator-clarity at end-of-prompt position; flag any signal-noise interaction with the existing `## INTENTION DETECTEE` heuristic block.
- `prompt-engineer` — review the TOP+BOTTOM duplication pattern (token cost overhead, placement, format-mimicry hazards).

If the executor's environment lacks the `Task` tool (as Wave A's executor did), run the 4 panel verdicts INLINE using the same mechanical lints + close reading. Document explicitly whether each verdict came from a real subagent run or an inline review.

Apply blocker-level fixes BEFORE pushing. Soft suggestions go in PR body's "Panel review notes" section.
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A-PLAN.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/probe-2026-05-15-1958-payload.jsonl
@services/backend/app/services/coach/citation_grammar.py
@services/backend/app/api/v1/endpoints/coach_chat.py

<diagnosis_evidence>
Live probe captured at 2026-05-15T17:58:44 from staging deploy `5e93606d` (post-PR-#635 merge sha `e4f3cc41`):
- system prompt length: 45,879 chars (21 top-level `## ` sections)
- MANDATE position: char 23,761 (51.8% — peak lost-in-the-middle)
- Tools: 3 narrator tools advertised correctly (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`) — full schemas in API payload (instrumentation logs only names)
- tool_choice: `{"type": "auto", "disable_parallel_tool_use": false}` — confirmed not the bug
- Probe response: `citationChips: None`, `toolCalls: None`, message: « Je vais te donner une projection chiffrée, mais j'ai besoin de récupérer d'abord tes données actuelles pour calculer les montants. _Outil éducatif simplifié..._ »
- No bare `{cite:tool_*}` placeholders — narrator stopped before emitting any
- WAVE1C_PAYLOAD logger: `app.services.rag.llm_client` (PR #628 path) — NOT `services/llm/router.py` (PR #631 path). The narrator goes through `rag/llm_client.LLMClient` per the import at `coach_chat.py:153`, contradicting PR #631's premise. Worth correcting in Wave C's CONTEXT D-06.2/D-06.3 routing assumption (out of scope here).

Engram observations: obs id 79 (`obs-41e2b755e6ba13e3` — this diagnosis), supersedes obs id 78 (still-broken finding), cross-link to 77 (Wave A shipped to dev), 74 (H2 falsification), 75 (HANDOFF).
</diagnosis_evidence>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task A1.1 — Duplicate MANDATE at BOTTOM of citation grammar fragment (both variants)</name>
  <files>services/backend/app/services/coach/citation_grammar.py</files>
  <read_first>
    - services/backend/app/services/coach/citation_grammar.py (full file — pay attention to lines 86-122 for the existing MANDATE/WRONG-RIGHT constants, lines 125-285 for `_build_citation_grammar_fragment`, lines 406+ for `build_intent_scoped_citation_grammar`)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/probe-2026-05-15-1958-payload.jsonl (full system prompt — confirm where the MANDATE currently sits)
  </read_first>
  <behavior>
    - Test 1 (new): `_build_citation_grammar_fragment()` output contains the MANDATE text at TWO positions: pos1 < pos2 — the original TOP position AND a new BOTTOM position. Substring `OBLIGATOIRE d'invoquer d'abord l'outil correspondant` appears 2 times via `output.count(...)`.
    - Test 2 (new): same for `build_intent_scoped_citation_grammar()` — MANDATE appears 2 times.
    - Test 3 (new): the BOTTOM repeat sits AFTER the rule_section — i.e. `output.index('Règle de placement') < output.rindex('OBLIGATOIRE d\\'invoquer')`.
    - Test 4 (regression): `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` exits 0 (Phase 94 byte-identity preserved when COACH_CITATION_GATE_ENABLED=false; if any byte-identity snapshot test breaks, the snapshot fixture must be regenerated ONLY for the COACH_CITATION_GATE_ENABLED=on snapshot — flag-off byte-identity MUST NOT regress).
    - Test 5 (lint): `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - Test 6 (lint): `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` exits 0.
  </behavior>
  <action>
    1. **Define the BOTTOM repeat constant** at module level (near `_TOOL_USE_MANDATE` at line 86). The repeat text reuses `_TOOL_USE_MANDATE` content but wraps it in a different section header so the two occurrences are visually distinguishable in the prompt and not byte-identical paragraphs back-to-back at distant positions:

       ```python
       # Wave 1c-A1 (2026-05-15) — MANDATE repeated at BOTTOM of fragment to
       # mitigate Liu 2024 lost-in-the-middle. The TOP occurrence (above the
       # legacy GRAMMAIRE DE CITATION header) sits at ~51% of the staging
       # system prompt; this repeat sits at ~64% (after rule_section). Plus a
       # 3rd injection lives at ~99% (system prompt tail, see coach_chat.py
       # _build_system_prompt_with_memory). 3-position pattern mirrors
       # CLAUDE.md §1 TOP/BOTTOM duplication.
       _TOOL_USE_MANDATE_REPEAT: str = (
           "\n"
           "## RAPPEL — INVOCATION OBLIGATOIRE D'OUTIL "
           "(seconde occurrence, post-règles)\n"
           "\n"
           "AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta "
           "réponse, il est OBLIGATOIRE d'invoquer d'abord l'outil "
           "correspondant via le mécanisme `tool_use`. UNE citation = UN "
           "appel `tool_use` préalable. Aucune exception.\n"
           "\n"
           "Si la question de l'utilisateur appelle un calcul (projection "
           "rente, surplus mensuel, plafond 3a), n'attends pas que "
           "l'utilisateur fournisse les données : INVOQUE l'outil. L'outil "
           "récupère automatiquement le profil et les valeurs côté serveur. "
           "Toute formulation du type « j'ai besoin de récupérer tes "
           "données » indique un manquement à cette doctrine.\n"
       )
       ```

    2. **Modify `_build_citation_grammar_fragment()`** (line 285 currently returns `mandate + header + tool_paragraph + keys_section + examples + rule_section`). Change the return statement to:

       ```python
       return (
           mandate
           + header
           + tool_paragraph
           + keys_section
           + examples
           + rule_section
           + _TOOL_USE_MANDATE_REPEAT
       )
       ```

    3. **Modify `build_intent_scoped_citation_grammar(intents)`** (line 406+) — locate the same final concatenation and append `_TOOL_USE_MANDATE_REPEAT` at the END of the composed string. If the function returns a string, change the return; if it builds via `"".join([...])`, append the constant to the list before the join.

    4. **Add unit tests** in a new file `services/backend/tests/test_coach_citation/test_mandate_top_bottom.py` covering Tests 1-3 above:

       ```python
       """Wave 1c-A1 byte-stability tests for TOP+BOTTOM MANDATE duplication."""
       from app.services.coach.citation_grammar import (
           CITATION_GRAMMAR_FRAGMENT,
           _TOOL_USE_MANDATE,
           build_intent_scoped_citation_grammar,
       )

       _NEEDLE = "OBLIGATOIRE d'invoquer d'abord l'outil correspondant"


       def test_full_fragment_has_mandate_at_top_and_bottom():
           assert CITATION_GRAMMAR_FRAGMENT.count(_NEEDLE) == 2


       def test_intent_scoped_fragment_has_mandate_at_top_and_bottom():
           out = build_intent_scoped_citation_grammar(["retirement"])
           assert out.count(_NEEDLE) == 2


       def test_bottom_mandate_sits_after_rule_section():
           rule_pos = CITATION_GRAMMAR_FRAGMENT.index("Règle de placement")
           last_mandate_pos = CITATION_GRAMMAR_FRAGMENT.rindex(_NEEDLE)
           assert rule_pos < last_mandate_pos, (
               "Wave 1c-A1: BOTTOM MANDATE must sit after the rule section, "
               "not before"
           )


       def test_repeat_constant_includes_no_data_anti_deferral_guidance():
           from app.services.coach.citation_grammar import (
               _TOOL_USE_MANDATE_REPEAT,
           )
           assert "n'attends pas que l'utilisateur fournisse les données" in (
               _TOOL_USE_MANDATE_REPEAT
           )
       ```

    5. **Verify** by grep BEFORE committing:
       ```bash
       cd services/backend && python3 -c "
       from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT
       print(f'mandate count: {CITATION_GRAMMAR_FRAGMENT.count(chr(34) + chr(34) + chr(34))}')
       print(f'mandate count NEEDLE: {CITATION_GRAMMAR_FRAGMENT.count(chr(39))}')"
       grep -c "OBLIGATOIRE d'invoquer d'abord l'outil correspondant" services/backend/app/services/coach/citation_grammar.py
       ```

       The first source-level grep should return ≥3 (one in `_TOOL_USE_MANDATE`, one in `_TOOL_USE_MANDATE_REPEAT`, one anywhere the constants are referenced). The runtime composition test (Tests 1-2) is the source of truth.
  </action>
  <acceptance_criteria>
    - `CITATION_GRAMMAR_FRAGMENT.count("OBLIGATOIRE d'invoquer d'abord l'outil correspondant")` returns exactly 2.
    - `build_intent_scoped_citation_grammar(["retirement"]).count(...)` returns exactly 2.
    - The new test file passes (`cd services/backend && python3 -m pytest tests/test_coach_citation/test_mandate_top_bottom.py -q`).
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` exits 0 (no Phase 94 regression).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - `git diff --stat services/backend/app/services/coach/citation_grammar.py` shows ≤30 added lines net.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_citation/test_mandate_top_bottom.py tests/test_citation_gate/ -q && python3 -c "from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT; assert CITATION_GRAMMAR_FRAGMENT.count('OBLIGATOIRE d\\'invoquer d\\'abord l\\'outil correspondant') == 2"</automated>
  </verify>
  <done>
    MANDATE appears at TOP and BOTTOM of both grammar fragment variants. Tests pass. Lints exit 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A1.2 — Add RAPPEL_MANDATE_TAIL injection in _build_system_prompt_with_memory</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1134-1500 (existing `_build_system_prompt_with_memory` definition + composition)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 4140-4180 (existing `## PROFIL UTILISATEUR` + `## INTENTION DETECTEE` injection blocks at runtime — confirm where these append to system_prompt)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/probe-2026-05-15-1958-payload.jsonl (verify the order in the captured staging prompt: PROFIL @ 98.8%, INTENTION DETECTEE @ 99.3%, end @ 100%)
  </read_first>
  <behavior>
    - Test 1: A new module-level constant `RAPPEL_MANDATE_TAIL` exists in coach_chat.py with FR text that includes "RAPPEL: si la réponse cite un placeholder".
    - Test 2: After the existing INTENTION DETECTEE injection block at coach_chat.py:~4170 in the runtime composition, `system_prompt` is appended with `RAPPEL_MANDATE_TAIL` UNCONDITIONALLY (not gated on intent detection — the rappel must fire even when no intent is classified).
    - Test 3: The injection happens AFTER the PROFIL UTILISATEUR + INTENTION DETECTEE blocks, so RAPPEL_MANDATE_TAIL is the LAST thing in `system_prompt` before the function returns or before the API payload is assembled.
    - Test 4 (regression): `cd services/backend && python3 -m pytest tests/test_citation_gate/ tests/test_coach_chat_tool_use_gate.py -q` exits 0.
    - Test 5 (lint): banned-terms + accent lint exit 0 on coach_chat.py.
  </behavior>
  <action>
    1. **Define module-level constant** in coach_chat.py (sister to `REPROMPT_ADDENDUM_TOOL_USE_MISSING` from Wave A):

       ```python
       # Wave 1c-A1 (2026-05-15) — Liu 2024 lost-in-the-middle mitigation.
       # Wave A's MANDATE sits at 51% of the 45K-char staging system prompt.
       # Wave A1's grammar-fragment BOTTOM repeat puts a 2nd occurrence at
       # ~64%. This 3rd injection sits at ~100% — the very last thing in the
       # system prompt before the user message — so the narrator reads the
       # MANDATE again immediately before generating its answer. Source of
       # the lost-in-the-middle insight: probe-2026-05-15-1958-payload.jsonl
       # showed that the system prompt was 45,879 chars and the existing
       # MANDATE position (51.4%) was insufficient — Sonnet under-attended.
       RAPPEL_MANDATE_TAIL: str = (
           "\n\n## RAPPEL — MANDATE TOOL_USE (placement final)\n"
           "Si la réponse cite un placeholder `{{cite:tool_<name>}}`, le bloc "
           "`tool_use(get_<name>)` doit avoir été émis plus tôt dans ce même "
           "tour. Aucune exception. Si la question appelle un chiffre "
           "(projection, surplus, plafond), INVOQUE l'outil correspondant — "
           "n'attends pas que l'utilisateur fournisse les données, l'outil "
           "récupère le profil côté serveur."
       )
       ```

    2. **Inject at runtime** at the END of the system-prompt composition. Locate the line right AFTER the INTENTION DETECTEE block at coach_chat.py:4170-ish (the `system_prompt = system_prompt + intent_block` line). Add (UNCONDITIONALLY, even when `detected_intents` is empty):

       ```python
       # Wave 1c-A1 — RAPPEL_MANDATE_TAIL is appended AFTER the optional
       # INTENTION DETECTEE block so it sits as the very last directive in
       # the system prompt, immediately above the user message. See
       # RAPPEL_MANDATE_TAIL docstring for rationale.
       system_prompt = system_prompt + RAPPEL_MANDATE_TAIL
       ```

       The injection must run regardless of whether `detected_intents` is non-empty — the RAPPEL is a global rule.

    3. **Add unit test** in `services/backend/tests/test_coach_chat_tool_use_gate.py` (extend the existing file from Wave A):

       ```python
       def test_rappel_mandate_tail_constant_exists_and_is_lsfin_clean():
           from app.api.v1.endpoints.coach_chat import RAPPEL_MANDATE_TAIL
           assert "RAPPEL" in RAPPEL_MANDATE_TAIL
           assert "tool_use" in RAPPEL_MANDATE_TAIL
           # LSFin: no banned imperative phrases
           for forbidden in ("tu dois", "tu devrais", "il faut "):
               assert forbidden not in RAPPEL_MANDATE_TAIL.lower(), (
                   f"LSFin: '{forbidden}' is a banned imperative phrase"
               )
       ```

    4. **Verify the runtime composition** by reading the existing call site at coach_chat.py:~4170 and confirming:
       - The PROFIL UTILISATEUR block is appended first (lines 4140-4154).
       - The INTENTION DETECTEE block is appended next (lines 4160-4178).
       - The new `system_prompt = system_prompt + RAPPEL_MANDATE_TAIL` is appended LAST (after the INTENTION DETECTEE block).
       - No code path in `_build_system_prompt_with_memory` returns BEFORE this line — the rappel must always fire.
  </action>
  <acceptance_criteria>
    - `grep -c "RAPPEL_MANDATE_TAIL" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (one definition + one append).
    - `cd services/backend && python3 -m pytest tests/test_coach_chat_tool_use_gate.py -q` exits 0.
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` exits 0.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `git diff --stat services/backend/app/api/v1/endpoints/coach_chat.py` shows ≤20 added lines net.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_chat_tool_use_gate.py tests/test_citation_gate/ -q && grep -c "RAPPEL_MANDATE_TAIL" app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <done>
    RAPPEL_MANDATE_TAIL constant exists; runtime composition appends it as the LAST block of system_prompt; tests pass; lints clean.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A1.3 — Design panel pre-push (4 reviewers, parallel if Task tool available, inline otherwise)</name>
  <files></files>
  <read_first>
    - CLAUDE.md §3.5 (routing rules + design panel pattern)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-11 (panel composition for this wave)
    - Engram memory `feedback_design_panel_before_push`
    - The two diffs from Task A1.1 + A1.2 (`git diff services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py`)
  </read_first>
  <behavior>
    - Test 1: 4 panel verdicts recorded inline in this task's output. If `Task` tool is available, all 4 fired in parallel as wshobson/VoltAgent subagent calls. If not, 4 inline reviews with the same checklist as Wave A.3.
    - Test 2: All BLOCK-level findings resolved by an additional commit on the branch BEFORE Task A1.4 runs. SUGGEST findings noted for PR body.
  </behavior>
  <action>
    Same panel composition as Wave A.3:
    - `security-auditor` — LSFin banned-terms + accent + project-doctrine grep on `_TOOL_USE_MANDATE_REPEAT` + `RAPPEL_MANDATE_TAIL`.
    - `qa-expert` — verify the byte-stability tests adequately lock the new TOP+BOTTOM positions; flag any test gap.
    - `ai-engineer` — review the rappel phrasing for narrator-clarity at end-of-prompt position; flag any signal-noise interaction with the existing `## INTENTION DETECTEE` heuristic block.
    - `prompt-engineer` — review TOP+BOTTOM duplication pattern (token cost overhead — target ≤200 added tokens for repeat + tail combined; placement justifications; format-mimicry hazards).

    Run via Task() in parallel if available; inline otherwise (document explicitly which mode was used). Apply BLOCK fixes immediately; SUGGEST goes in PR body.

    `mem_save` after each panel finding with `topic_key: coach:citation:tool_use_mandate:wave_a1:<panel_name>` and `prior_finding_refs` to obs id 79 (Wave A1 diagnosis) + obs ids 65, 66, 69, 74, 75, 77.
  </action>
  <acceptance_criteria>
    - 4 verdicts recorded (PASS / BLOCK / SUGGEST + 1-line summary each).
    - 0 BLOCK-level findings remaining at task completion.
    - SUGGEST findings noted for PR body.
    - Lints exit 0 after any panel-driven edits.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py && python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <done>
    4 verdicts captured; BLOCKs fixed by additional commit; SUGGEST noted; lints clean.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A1.4 — Open PR feature/wave-1c-A1-mandate-position → dev, monitor CI, merge on green</name>
  <files></files>
  <read_first>
    - CLAUDE.md §9 (0-trust protocol)
    - Engram memory `feedback_pre_push_checklist`
    - Engram memory `feedback_no_wakeup_active_polling` (poll inline, never schedule wakeup)
    - Engram memory `feedback_public_repo_discipline` (no forensic legal language)
    - The 4 panel verdicts from Task A1.3
  </read_first>
  <behavior>
    - Pre-push: full pytest + both lints exit 0.
    - PR opened on `feature/wave-1c-A1-mandate-position` → `dev`.
    - CI polled inline; merge on green via `gh pr merge --squash --delete-branch`.
    - dev → staging bundle PR opened (or merged) per A.4 step 6 pattern.
    - 0-trust language in PR body: « PR opened » NOT « shipped », « ready », or « works ».
  </behavior>
  <action>
    1. **Branch off origin/dev**:
       ```bash
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       git fetch origin
       git checkout -b feature/wave-1c-A1-mandate-position origin/dev
       # If branch already exists locally from a prior aborted run:
       # git checkout feature/wave-1c-A1-mandate-position
       ```

       Commit the 2 code edits + the new test file + the planning artifacts (wave-1c-A1-PLAN.md + probe evidence directory) atomically.

    2. **Pre-push sanity** (run from `/Users/julienbattaglia/Desktop/MINT.nosync`):
       ```bash
       cd services/backend && python3 -m pytest tests/ -q | tail -3
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py
       python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py
       git status
       git log --oneline origin/dev..HEAD
       ```
       All MUST exit 0 before the next step.

    3. **Push the branch + open PR** (HEREDOC body):
       ```bash
       git push -u origin feature/wave-1c-A1-mandate-position
       gh pr create --base dev --head feature/wave-1c-A1-mandate-position \
         --title "fix(wave-1c-A1): MANDATE TOP+BOTTOM duplication + system-prompt tail rappel" \
         --body "$(cat <<'EOF'
       ## What

       Wave 1c-A1 — prompt-position iteration on Wave A's tool_use MANDATE.

       Wave A (PR #634, merged sha bc020925) shipped the doctrine MANDATE in `services/backend/app/services/coach/citation_grammar.py`. Live probe against staging post-deploy (deploy `5e93606d` SUCCESS at 17:51 UTC; deploy `e8f8ad21` with WAVE1C_INSTRUMENT_ENABLED=true SUCCESS at 17:58 UTC) returned `citationChips: None`, `toolCalls: None`, message: « Je vais te donner une projection chiffrée, mais j'ai besoin de récupérer d'abord tes données actuelles ». No bare `{cite:tool_*}` placeholders — narrator stopped before emitting any.

       Diagnosis (full prompt captured in `.planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/probe-2026-05-15-1958-payload.jsonl`): the MANDATE sits at character 23,761 of a 45,879-char system prompt — exactly 51.4% through, the peak Liu 2024 lost-in-the-middle zone. Tools, tool_choice, and content of the MANDATE are all correct; position is the bug.

       This PR applies the same TOP+BOTTOM pattern CLAUDE.md §1 uses for its 6 critical rules:
       - **Grammar fragment**: `_TOOL_USE_MANDATE_REPEAT` constant added; appended at the END of `_build_citation_grammar_fragment()` and `build_intent_scoped_citation_grammar()`. MANDATE now appears at ~51% AND ~64% of the system prompt.
       - **System prompt tail**: `RAPPEL_MANDATE_TAIL` constant added in `coach_chat.py`; appended UNCONDITIONALLY in `_build_system_prompt_with_memory` AFTER the existing PROFIL UTILISATEUR + INTENTION DETECTEE blocks. MANDATE now also appears at ~100% — immediately above the user message.

       Net diff: ~30-40 LOC. Token cost: ~200 added tokens per request (acceptable per RESEARCH).

       ## Files changed

       - `services/backend/app/services/coach/citation_grammar.py` — `_TOOL_USE_MANDATE_REPEAT` constant + appended in 2 fragment builders.
       - `services/backend/app/api/v1/endpoints/coach_chat.py` — `RAPPEL_MANDATE_TAIL` constant + 1-line append in `_build_system_prompt_with_memory`.
       - `services/backend/tests/test_coach_citation/test_mandate_top_bottom.py` — 4 byte-stability tests.
       - `services/backend/tests/test_coach_chat_tool_use_gate.py` — 1 LSFin-cleanliness test for `RAPPEL_MANDATE_TAIL`.
       - `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A1-PLAN.md` — this plan.
       - `.planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/*` — probe payloads.

       ## Mechanical gates (pre-push)

       - Backend pytest full suite exits 0 (baseline 6921 preserved + N new tests).
       - `tools/checks/banned_terms_python.py` exits 0 on both files.
       - `tools/checks/accent_lint_fr.py` exits 0 on both files.

       ## Panel review notes

       4 reviewers: security-auditor, qa-expert, ai-engineer, prompt-engineer. Verdicts: <fill in PASS/SUGGEST one-liners from Task A1.3>.

       ## What this PR does NOT do

       - It does NOT change Wave A's runtime gate `_enforce_tool_use_for_citations` — the gate stays in place as a tripwire (still useful once narrator starts emitting placeholders).
       - It does NOT add `tool_choice: {"type": "any"}` — that escalation lives in a hypothetical Wave A2 plan, only activated if A1's prompt-position fix is insufficient.
       - It does NOT touch the duplicate `EVENEMENTS DE VIE` / `ARCHETYPES` / `COUPLE DISSYMETRIQUE` sections in the system prompt (separate cleanup ticket).
       - It does NOT correct PR #631's mistaken router.py instrumentation premise (CONTEXT D-06.3 needs a follow-up; tracked in Wave C scope).

       ## 0-trust note

       Tests + lints green = mechanical signals only. Per CLAUDE.md §9.5 + CONTEXT D-10, this PR claims « PR opened » NOT « shipped », « ready », or « works ». The « works » claim is gated on the live staging probe returning `citationChips` non-null AFTER PR #635 successor (A1's dev→staging) merges + Railway redeploys.

       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
       EOF
       )"
       ```

    4. **Monitor CI inline** (no scheduled wakeup):
       ```bash
       PR_NUM=$(gh pr list --head feature/wave-1c-A1-mandate-position --json number --jq '.[0].number')
       until ! gh pr checks $PR_NUM 2>&1 | grep -qE "pending|in_progress"; do sleep 30; done
       gh pr checks $PR_NUM
       ```
       If any job FAILS: read failing log, fix, push, re-poll. Do NOT use `--no-verify`.

    5. **Merge on green** (squash, delete branch):
       ```bash
       gh pr merge $PR_NUM --squash --delete-branch
       MERGE_SHA=$(gh pr view $PR_NUM --json mergeCommit --jq '.mergeCommit.oid')
       echo "Merged as: $MERGE_SHA"
       ```

    6. **Open dev → staging bundle PR** (or update the existing one if PR #635-equivalent is still open):
       ```bash
       git fetch origin
       git log --oneline origin/staging..origin/dev | head -5
       gh pr create --base staging --head dev \
         --title "ship: dev → staging — wave-1c-A1 MANDATE position fix" \
         --body "$(cat <<'EOF'
       Ships wave-1c-A1 prompt-position fix (PR #$PR_NUM) to staging.

       After Railway redeploys this commit, re-run the verbatim probe in `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A-PLAN.md` §verification. Expected: `citationChips: [{toolName: "get_retirement_projection", ...}]` non-null AND no bare `{cite:tool_*}` strings in `message`. The probe evidence unblocks Wave B (regression test floor PR).

       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
       EOF
       )"
       ```
       NOTE: leave for orchestrator (Claude in the calling session) to merge after polling its CI.
  </action>
  <acceptance_criteria>
    - PR Wave A1 MERGED to `dev` with non-null mergedAt.
    - dev→staging bundle PR opened.
    - All CI jobs `pass` at merge.
    - 0-trust language preserved in PR body.
  </acceptance_criteria>
  <verify>
    <automated>echo "verified inline by orchestrator post-merge via gh pr view"</automated>
  </verify>
  <done>
    Wave A1 PR is MERGED to `dev`. dev→staging bundle PR opened (orchestrator handles re-probe). Squash sha cited in task output.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A1.5 — Engram mem_save Wave A1 close-out (executor only if engram MCP available)</name>
  <files></files>
  <read_first>
    - The Task A1.4 output (PR number, merge sha, dev→staging PR url)
  </read_first>
  <behavior>
    - If engram MCP tools available: 1 `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_a1:shipped` + `prior_finding_refs: [77, 78, 79, ... 4 panel topic_keys]`.
    - If engram MCP NOT available: document the intended save in task output so the orchestrator can persist it.
  </behavior>
  <action>
    Same pattern as Wave A's A.5 task. If engram MCP tools are not in the executor's tool list, write the intended observation content to the task output so the orchestrator can run the `mem_save` from its own session.
  </action>
  <acceptance_criteria>
    - mem_save invoked OR intended content documented for orchestrator.
  </acceptance_criteria>
  <verify>
    <automated>echo "engram persistence verified by orchestrator post-task"</automated>
  </verify>
  <done>
    Engram observation saved or content documented for orchestrator handoff.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM output → user-visible narrator response | Same as Wave A. The new MANDATE position is purely a content reorganization; runtime gate is unchanged. |
| System prompt assembly | The unconditional RAPPEL_MANDATE_TAIL injection adds ~120 tokens per request; cost/quota impact bounded. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wave-1c-A1-01 | Information disclosure | RAPPEL_MANDATE_TAIL constant | accept | No PII; static FR text only. |
| T-wave-1c-A1-02 | DoS / cost | +200 tokens per coach_chat request | accept | Token cost bounded; fits within existing Anthropic budget per RESEARCH §3.1. |
| T-wave-1c-A1-03 | Tampering | A1 superseding A's grammar fragment composition | mitigate | Tests T1-T3 lock TOP+BOTTOM positions byte-stably; future grammar refactor must update tests. |
| T-wave-1c-A1-04 | Spoofing | gate bypass via COACH_CITATION_GATE_ENABLED=false | accept | Same as Wave A — Phase 94 master switch governs both. |
</threat_model>

<verification>
## Wave A1 close-out checks (run by orchestrator post-PR merge)

- G1 (live probe via curl per wave-1c-A-PLAN.md §verification) — orchestrator runs after dev→staging merges + Railway redeploys. Expected: `citationChips` non-null + zero bare `{cite:tool_*}` placeholders.
- G3 (dev CI green) — `gh pr checks <N>` shows ALL jobs pass.
- G4 (regression suite) — `cd services/backend && python3 -m pytest tests/ -q` exits 0 with ≥6925 passing (baseline 6921 + 5 new tests, allowing for Phase 94 gate test count drift).
- G5 (LSFin + accent lint) — exit 0 on both touched files.

## Outcome branches

- **If probe returns UNBLOCK signal** → Wave B is unblocked. Orchestrator spawns gsd-executor for Wave B.
- **If probe still BROKEN** → Wave A2 plan (escalation: `tool_choice: {"type": "any"}` scoped to retirement-intent classification, OR system-prompt structural cleanup of duplicate sections, OR a completely different hypothesis from a fresh expert panel). Orchestrator drafts Wave A2 plan with Julien.
</verification>

<success_criteria>
- All 5 tasks A1.1–A1.5 executed in order.
- Each code task committed individually on `feature/wave-1c-A1-mandate-position`.
- Planning artifact (wave-1c-A1-PLAN.md) + probe evidence committed.
- 4 design-panel verdicts captured.
- Backend pytest + LSFin + accent lints exit 0.
- PR opened on `feature/wave-1c-A1-mandate-position` → `dev`, CI polled inline, merged via squash.
- dev → staging bundle PR opened.
- Engram observation saved (or intended content documented for orchestrator).

**Wave A1 does NOT claim « shipped » or « works ».** Per CLAUDE.md §9.5, this is « PR opened + dev-merged ». The « works » claim is owned by the orchestrator's post-deploy live probe re-run.
</success_criteria>

<output>
After Wave A1 completes, this PLAN.md's status is « MERGED TO DEV — AWAITING LIVE PROBE RE-RUN ». The orchestrator handles the dev→staging merge + Railway poll + probe + decision (Wave B fire vs Wave A2 escalation). Do NOT create a SUMMARY.md — the orchestrator will compose the combined wave-1c-SUMMARY.md at phase close-out (after Wave C).
</output>
