---
phase: wave-1c-coach-tool-dispatch-rca
wave: A
depends_on: []
autonomous: true
files_modified:
  - services/backend/app/services/coach/citation_grammar.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
wave1c_decisions_addressed: [D-01, D-02, D-03, D-04, D-08, D-09, D-10, D-11, D-12]
branch: feature/wave-1c-smoking-gun
target_branch: dev
must_haves:
  truths:
    - "Narrator system prompt teaches: tool_use FIRST, then citation placeholder."
    - "Runtime gate REJECTS any narrator response containing {{cite:tool_<name>}} without a matching tool_use block."
    - "Every gate REJECT fires a Sentry breadcrumb category coach.citation.tool_use_missing."
    - "Retry-once path re-prompts with the MANDATE + WRONG/RIGHT example; 2nd failure falls through to existing _citation_gate FALLBACK (no crash)."
    - "Wave A PR is the existing feature/wave-1c-smoking-gun branch targeting dev; backend job exits 0 on CI; lint+banned-terms+accent gates exit 0."
  artifacts:
    - path: services/backend/app/services/coach/citation_grammar.py
      provides: "MANDATE paragraph at TOP of get_grammar() output + WRONG/RIGHT example pair, ahead of FORMAT examples"
      contains: "AVANT d'émettre tout placeholder"
    - path: services/backend/app/api/v1/endpoints/coach_chat.py
      provides: "_enforce_tool_use_for_citations(answer_text, tool_calls) -> EnforcementVerdict, wired into _run_narrator_with_gate, Sentry breadcrumb on REJECT"
      exports: ["_enforce_tool_use_for_citations"]
  key_links:
    - from: "services/backend/app/services/coach/citation_grammar.py::_build_citation_grammar_fragment"
      to: "narrator system prompt (header position, before FORMAT examples)"
      pattern: "MANDATE paragraph appears as first non-doctrine header line of get_grammar() output"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py::_run_narrator_with_gate"
      to: "_enforce_tool_use_for_citations"
      pattern: "gate invoked AFTER _citation_gate PASS verdict, BEFORE returning loop_result; REJECT triggers retry with reprompt addendum"
    - from: "_enforce_tool_use_for_citations REJECT path"
      to: "sentry_sdk.add_breadcrumb(category=\"coach.citation.tool_use_missing\")"
      pattern: "breadcrumb fires before re-prompt, payload {placeholder_name, retry_count, narrator_tool_count}"
---

<objective>
Land the doctrine-level fix that makes the coach narrator actually invoke `tool_use` blocks instead of emitting `{{cite:tool_<name>}}` placeholders as bare prose patterns. This is Wave A of 3: it ships (1) the citation-grammar MANDATE rewrite, (2) the new runtime enforcement gate `_enforce_tool_use_for_citations`, (3) the Sentry breadcrumb category `coach.citation.tool_use_missing`, (4) the retry path that inlines the WRONG/RIGHT example, and (5) LSFin + accent lint gates green on the touched file.

Purpose: Wave 1b citation chips currently render NULL on staging because the narrator emits prose `{cite:tool_retirement_projection}` without calling `get_retirement_projection`, then ends its turn. Per CONTEXT D-01 (smoking gun bisect verdict), the grammar fragment teaches FORMAT not INVOCATION. The fix teaches INVOCATION FIRST and adds a runtime tripwire so the bug cannot regress silently.

Output: 1 PR on existing branch `feature/wave-1c-smoking-gun` targeting `dev`, ≤ ~25 lines grammar + ~80 lines gate+wire+breadcrumb. Tests for the new gate ship in Wave B (per D-09 sizing). LSFin/accent/banned-terms exit 0 on every touched file.
</objective>

<execution_context>
This wave is BACKEND-ONLY. No Flutter touch. The PR diff is small but the prompt fragment is user-facing French → LSFin banned-terms scan + accent lint are mandatory pre-push.

Pre-push design panel (per CLAUDE.md §3.5 + memory `feedback_design_panel_before_push`): spawn 4 subagents in parallel before `gh pr create`:
- `security-auditor` — LSFin banned-terms scan on the MANDATE + WRONG/RIGHT FR text
- `qa-expert` — opinion on whether Wave B regression coverage will suffice
- `ai-engineer` — review the MANDATE phrasing for narrator-clarity
- `prompt-engineer` — review the WRONG/RIGHT example pair for prompt-engineering correctness (placement, contrast, token cost)

Apply blocker-level fixes from the panel BEFORE pushing. Soft suggestions can be noted in PR body.
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json
@.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_results.json
@services/backend/app/services/coach/citation_grammar.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/citation_parser.py

<interfaces>
<!-- Extracted from services/backend/app/services/coach/citation_parser.py -->
```python
class GateVerdict(str, Enum):
    """Closed-world citation gate verdict (CONTEXT GATE-01..04)."""
    PASS = "pass"
    REJECTED_UNCITED = "rejected_uncited"
    REJECTED_BANNED_CLAIM = "rejected_banned_claim"
    FALLBACK = "fallback"

@dataclass
class GatedResponse:
    verdict: GateVerdict
    gated_text: str
    reprompt_addendum: Optional[str]
    uncited_numbers_count: int
    banned_claims_found: list[str]
    retry_needed: bool
```

<!-- Existing breadcrumb sibling pattern (coach_chat.py:4203) -->
```python
def _emit_gate_breadcrumb(gated: GatedResponse, retries: int) -> None:
    try:
        import sentry_sdk
        sentry_sdk.add_breadcrumb(
            category="coach.citation_gate",
            message=f"verdict={gated.verdict.value}",
            level=("info" if gated.verdict == GateVerdict.PASS else "warning"),
            data={"verdict": gated.verdict.value, "retries": int(retries), ...},
        )
    except Exception:  # pragma: no cover
        pass
```

<!-- Existing wire site (coach_chat.py:4230-4291) -->
```python
async def _run_narrator_with_gate(pack=None) -> dict:
    loop_result = await asyncio.wait_for(_run_agent_loop(...))
    if not settings.COACH_CITATION_GATE_ENABLED:
        return loop_result
    gated = _citation_gate(response_text=loop_result["answer"], ...)
    _emit_gate_breadcrumb(gated, retries=0)
    if not gated.retry_needed:
        loop_result["answer"] = gated.gated_text
        if gated.verdict == GateVerdict.PASS:
            _emit_citation_chip_breadcrumbs(...)
        return loop_result
    # retry path...
```

<!-- loop_result shape (from _run_agent_loop) -->
loop_result = {
    "answer": str,
    "tool_calls": list[dict],   # each dict has "name", "input", "id", ...
    "citation_chips": list[dict] | None,
    "sources": list,
    "disclaimers": list,
    "tokens_used": int,
    ...
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task A.1 — Rewrite citation_grammar.py header to MANDATE tool_use BEFORE format examples</name>
  <files>services/backend/app/services/coach/citation_grammar.py</files>
  <read_first>
    - services/backend/app/services/coach/citation_grammar.py (full file, especially _build_citation_grammar_fragment lines 61-202 + build_intent_scoped_citation_grammar lines 323-455)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §Specifics (verbatim MANDATE + WRONG + RIGHT text)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md §"Smoking gun discovered in the bisect output"
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json (read the "system" field around the "## DOCTRINE — GRAMMAIRE DE CITATION" section to see what the LLM currently receives)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_results.json (read all 5 layers — observe the LLM citing tool names in prose without invoking)
  </read_first>
  <behavior>
    - Test 1 (Wave B test_tool_use_mandate.py::test_grammar_contains_mandate_paragraph): get_grammar() output contains verbatim "AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta réponse, tu DOIS d'abord invoquer l'outil correspondant via le mécanisme `tool_use`."
    - Test 2 (Wave B test_tool_use_mandate.py::test_mandate_precedes_format_examples): substring index of "AVANT d'émettre tout placeholder" is STRICTLY LESS than substring index of "L'outil `get_budget_status` renvoie" in the output of _build_citation_grammar_fragment().
    - Test 3 (Wave B test_tool_use_mandate.py::test_wrong_right_example_pair_present): output contains BOTH "REJETÉ — placeholder sans tool_use préalable" AND "ACCEPTÉ — tool_use puis citation du résultat".
    - Test 4 (lint): `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - Test 5 (lint): `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - Test 6 (existing byte-identity tests for flag=off do NOT regress): `python3 -m pytest tests/test_citation_gate/ -q` still exits 0 with the existing 212+ passing tests.
  </behavior>
  <action>
    Edit `_build_citation_grammar_fragment()` in `services/backend/app/services/coach/citation_grammar.py`. Insert a new MANDATE section at the TOP of the header block (before the existing header about closed-world placeholders), and add a WRONG/RIGHT example pair to the examples section, placed BEFORE the existing "**ACCEPTÉ — chiffre réglementaire cité**" bullet.

    1. The MANDATE paragraph text (verbatim FR, no banned LSFin terms, 100% accent compliance — copy this EXACTLY):

       ```
       ## DOCTRINE — INVOCATION OBLIGATOIRE D'OUTIL (préalable à toute citation `tool_*`)

       AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta réponse, tu DOIS d'abord invoquer l'outil correspondant via le mécanisme `tool_use`. UNE citation = UN appel `tool_use` préalable. Aucune exception.

       Concrètement : si tu veux écrire `{{cite:tool_retirement_projection}}` après un chiffre, il faut qu'un bloc `tool_use(get_retirement_projection)` ait été émis plus tôt dans ce même tour et que son `tool_result` t'ait été retourné. Sans cet appel préalable, le placeholder est rejeté par la garde et ta réponse bascule sur un fallback templaté.

       Le `{{cite:tool_<name>}}` n'est PAS une formule magique — c'est une référence à un calcul serveur que tu dois avoir déclenché toi-même via `tool_use`.
       ```

    2. The new WRONG/RIGHT example pair (insert in the `examples` block, BEFORE the existing "**ACCEPTÉ — chiffre réglementaire cité**" entry):

       ```
       **REJETÉ — placeholder sans tool_use préalable** :
       « Ta projection de rente AVS sera de {{cite:tool_retirement_projection}} » écrit sans avoir d'abord émis `tool_use(get_retirement_projection)` dans ce tour. La garde détecte l'absence d'invocation et rejette. Pour corriger : appelle `get_retirement_projection` AVANT d'émettre la phrase.

       **ACCEPTÉ — tool_use puis citation du résultat** :
       Émets d'abord le bloc `tool_use(get_retirement_projection)` ; attends le `tool_result` ; écris ensuite « Ta projection de rente AVS pourrait être autour de 24'960 CHF/an {{cite:tool_retirement_projection}} ». La garde reconnaît l'appel préalable et accepte la citation.
       ```

    3. Order in the final composed string (use Python string concatenation order so the test for substring index ordering passes):
       `mandate + header + tool_paragraph + keys_section + examples_with_wrong_right_first + rule_section`

    4. Apply the SAME mandate + WRONG/RIGHT block to `build_intent_scoped_citation_grammar(intents)` (the intent-scoped variant, lines 323-455) so the doctrine is identical regardless of which path is rendered. Do NOT diverge the two variants.

    5. **Doctrine-level LSFin compliance (project-doctrine, NOT lint-enforced)** — `tools/checks/banned_terms_python.py:40-49` lints the WORD-BOUNDARY set `("garanti", "optimal", "meilleur", "certain", "assure", "parfait")` plus the phrase `("sans risque",)`. It does NOT flag « tu dois », « tu devrais », or « il faut ». However, `CLAUDE.md §5 NEVER #5` AND `CLAUDE.md §1` BOTTOM rules forbid « tu devrais », « tu dois », « il faut » as LSFin-imperative voice in user-facing French (use « pourrait », « envisager », « adapté » — or impersonal forms like « il est OBLIGATOIRE de »). The MANDATE text drafted in CONTEXT specifics uses « tu DOIS d'abord invoquer » → REPLACE the rendered string with « il est OBLIGATOIRE d'invoquer d'abord » so the doctrine-level rule is honored. The final MANDATE paragraph becomes:

       « AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta réponse, il est OBLIGATOIRE d'invoquer d'abord l'outil correspondant via le mécanisme `tool_use`. UNE citation = UN appel `tool_use` préalable. Aucune exception. »

       Also rewrite the explanatory paragraph that currently reads « c'est une référence à un calcul serveur que tu dois avoir déclenché toi-même via `tool_use` » → « c'est une référence à un calcul serveur qui doit avoir été déclenché via `tool_use` plus tôt dans ce même tour » (passive voice — keeps the constraint, removes the « tu dois »).

       Verify by grep BEFORE committing:
       ```
       grep -nE "tu [Dd]ois|tu devrais|il faut" services/backend/app/services/coach/citation_grammar.py
       ```
       Expected count = 0. This grep is a pre-push doctrine check, NOT a lint — `banned_terms_python.py` will exit 0 with OR without the substitution.

       **CAVEAT** : the existing file already contains the legacy phrase « N'INVENTE JAMAIS » (uppercase imperative). That is permitted because (a) it's an existing string already shipping on prod, (b) « inventer » is not in the LSFin imperative list, and (c) the equivalent passive « les clés inconnues sont rejetées par la garde » is already expressed later in the same paragraph. Do NOT rewrite legacy strings — surgical changes only (Karpathy #3).
  </action>
  <acceptance_criteria>
    - `grep -c "il est OBLIGATOIRE d'invoquer d'abord l'outil correspondant via le mécanisme \`tool_use\`" services/backend/app/services/coach/citation_grammar.py` returns 2 (one for full fragment, one for intent-scoped variant — or use a shared constant; ≥1 is acceptable if refactored into a constant).
    - `grep -nE "tu [Dd]ois|tu devrais|il faut" services/backend/app/services/coach/citation_grammar.py` returns 0 matches (exit 1 from grep — doctrine-level enforcement per CLAUDE.md §5 NEVER #5; this is a project-doctrine check, NOT a lint requirement — `banned_terms_python.py:40-49` does not scan these phrases).
    - `python3 -c "from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT; assert 'OBLIGATOIRE' in CITATION_GRAMMAR_FRAGMENT and CITATION_GRAMMAR_FRAGMENT.index('OBLIGATOIRE') < CITATION_GRAMMAR_FRAGMENT.index(\"L'outil \`get_budget_status\` renvoie\")"` exits 0 (from services/backend dir).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` exits 0 (existing Phase 94 byte-identity preserved when flag=off; if any byte-identity snapshot test breaks, the snapshot fixture must be regenerated with `pytest --snapshot-update` ONLY IF the COACH_CITATION_GATE_ENABLED=on snapshot test — flag-off byte-identity MUST NOT regress).
    - `git diff --stat services/backend/app/services/coach/citation_grammar.py` shows ≤80 added lines net (mandate ~12 lines + WRONG/RIGHT ~10 lines + duplication in intent-scoped variant ~22 lines, or ~12 lines if refactored to a shared constant).
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_citation_gate/ -q && python3 tools/checks/banned_terms_python.py app/services/coach/citation_grammar.py && python3 tools/checks/accent_lint_fr.py app/services/coach/citation_grammar.py</automated>
  </verify>
  <done>
    MANDATE + WRONG/RIGHT example pair are in `_build_citation_grammar_fragment()` AND `build_intent_scoped_citation_grammar()`, positioned before the FORMAT examples, with substring-order assertion mechanically verifiable. LSFin + accent lints exit 0. Existing test_citation_gate/ suite still exits 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A.2 — Add _enforce_tool_use_for_citations gate + wire into _run_narrator_with_gate + Sentry breadcrumb</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 4200-4291 (existing `_emit_gate_breadcrumb` + `_run_narrator_with_gate`)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 475-552 (existing `_emit_citation_chip_breadcrumbs` — match its style for the new module-level helper)
    - services/backend/app/services/coach/citation_parser.py lines 329-370 (GateVerdict enum + GatedResponse dataclass — match this enum/dataclass style for the new EnforcementVerdict)
    - services/backend/app/services/coach/citation_parser.py lines 132-150 (REPROMPT_ADDENDUM_UNCITED — match this addendum style)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §Decisions D-04 (verbatim spec)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json (verify the 3 advertised tool names: `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`)
  </read_first>
  <behavior>
    - Test 1 (Wave B): _enforce_tool_use_for_citations(answer_text="surplus 1234 CHF {{cite:tool_budget_snapshot}}", tool_calls=[]) returns verdict == REJECTED, reason == "tool_use_missing_for_citation:budget_snapshot".
    - Test 2 (Wave B): _enforce_tool_use_for_citations(answer_text="surplus 1234 CHF {{cite:tool_budget_snapshot}}", tool_calls=[{"name": "get_budget_status", "input": {}}]) returns verdict == PASS (canonical mapping budget_snapshot ↔ get_budget_status).
    - Test 3 (Wave B): _enforce_tool_use_for_citations on PARTIAL case (2 placeholders, only 1 matching tool_use) returns REJECTED with reason naming the missing one.
    - Test 4 (Wave B): _enforce_tool_use_for_citations with answer containing only non-tool citation keys (e.g., {{cite:r3a_plafond_salarie_2026}}) returns PASS regardless of tool_calls (only `tool_*` placeholders are gated).
    - Test 5 (Wave B): _run_narrator_with_gate REJECT path fires sentry breadcrumb with category="coach.citation.tool_use_missing" before re-prompt.
    - Test 6 (Wave B): retry-once exhaustion falls through to existing _citation_gate FALLBACK without crash.
    - Test 7 (regression): `python3 -m pytest tests/test_citation_gate/ -q` still exits 0 (Phase 94 byte-identity preserved; new gate is fail-safe under flag-off — see acceptance below).
  </behavior>
  <action>
    Add code to `services/backend/app/api/v1/endpoints/coach_chat.py`. The new code sits in the same file (do NOT split into a new module — file is 4536 lines; adding ~80 lines stays well under any reasonable LOC cap, and keeping it co-located with the existing `_emit_gate_breadcrumb` + `_run_narrator_with_gate` improves reviewability).

    1. **At module level** (just below the existing `_emit_citation_chip_breadcrumbs` definition around line 552), add a dataclass + enum + helper function. Match the style of `citation_parser.GatedResponse` exactly:

       ```python
       # ---------------------------------------------------------------------------
       # Wave 1c — tool_use mandate enforcement (D-04)
       # Runs AFTER _citation_gate, BEFORE returning loop_result.
       # Per CONTEXT D-04: parse {{cite:tool_<name>}} placeholders from answer_text;
       # for each, require at least one matching tool_use block in tool_calls.
       # Canonical mapping: placeholder `tool_<short>` ↔ tool_use name `get_<short>`
       # for the 3 narrator-relevant tools. Source: captured_staging_payload_hydrated.json
       # tools array.
       # ---------------------------------------------------------------------------

       from enum import Enum
       from dataclasses import dataclass

       class ToolUseEnforcementVerdict(str, Enum):
           PASS = "pass"
           REJECTED = "rejected"

       @dataclass
       class ToolUseEnforcementResult:
           verdict: ToolUseEnforcementVerdict
           missing_placeholder_names: list[str]   # short names, e.g. ["budget_snapshot"]
           structured_reason: Optional[str]        # e.g. "tool_use_missing_for_citation:budget_snapshot"
           narrator_tool_count: int

       # Canonical mapping: placeholder short-name → tool_use canonical name.
       # The 3 narrator tools per captured_staging_payload_hydrated.json + the
       # 3 additional Wave 1b tools whose chips are emitted but whose tools may
       # be added later. Update this when a new tool_* key is added to the
       # CITATION_REGISTRY.
       _PLACEHOLDER_TO_TOOL_NAME: dict[str, str] = {
           "budget_snapshot": "get_budget_status",
           "retirement_projection": "get_retirement_projection",
           "cross_pillar_analysis": "get_cross_pillar_analysis",
           "couple_optimization": "get_couple_optimization",
           "cap_status": "get_cap_status",
           "retrieve_memories": "retrieve_memories",
       }

       _RE_TOOL_CITE_PLACEHOLDER = re.compile(r"\{\{cite:tool_([A-Za-z0-9_]+)\}\}")

       def _enforce_tool_use_for_citations(
           answer_text: str,
           tool_calls: list[dict],
       ) -> ToolUseEnforcementResult:
           """Wave 1c D-04 — assert every {{cite:tool_<name>}} placeholder in
           `answer_text` has a corresponding tool_use block in `tool_calls`.

           Canonical mapping per `_PLACEHOLDER_TO_TOOL_NAME`. Placeholders
           whose short-name is NOT in the mapping are tolerated (PASS) — the
           CITATION_REGISTRY can have tool_* keys whose tools are not narrator-
           dispatchable (e.g. compute-only keys).

           Pure function. No I/O.
           """
           if not answer_text:
               return ToolUseEnforcementResult(
                   verdict=ToolUseEnforcementVerdict.PASS,
                   missing_placeholder_names=[],
                   structured_reason=None,
                   narrator_tool_count=len(tool_calls or []),
               )
           emitted_tool_names = {
               (tc.get("name") or "") for tc in (tool_calls or [])
               if isinstance(tc, dict)
           }
           missing: list[str] = []
           for m in _RE_TOOL_CITE_PLACEHOLDER.finditer(answer_text):
               short = m.group(1)
               canonical = _PLACEHOLDER_TO_TOOL_NAME.get(short)
               if canonical is None:
                   # Unknown tool_* short-name; CITATION_REGISTRY may have
                   # added a new key. Tolerate — Wave B regression suite
                   # will add the mapping when the new key lands.
                   continue
               if canonical not in emitted_tool_names:
                   missing.append(short)
           if missing:
               return ToolUseEnforcementResult(
                   verdict=ToolUseEnforcementVerdict.REJECTED,
                   missing_placeholder_names=missing,
                   structured_reason=f"tool_use_missing_for_citation:{missing[0]}",
                   narrator_tool_count=len(tool_calls or []),
               )
           return ToolUseEnforcementResult(
               verdict=ToolUseEnforcementVerdict.PASS,
               missing_placeholder_names=[],
               structured_reason=None,
               narrator_tool_count=len(tool_calls or []),
           )

       # Verbatim FR reprompt addendum — inlines the WRONG/RIGHT example
       # pair from citation_grammar.py so the narrator sees the doctrine
       # AGAIN at retry-time, not just in the system prompt.
       REPROMPT_ADDENDUM_TOOL_USE_MISSING: str = (
           "\n\n[CORRECTION REQUISE] Tu as écrit un placeholder "
           "`{{cite:tool_<name>}}` SANS avoir d'abord invoqué l'outil "
           "correspondant via `tool_use`. RÈGLE : UNE citation `tool_*` = "
           "UN appel `tool_use` préalable, aucune exception. "
           "Refais ta réponse en émettant d'abord `tool_use(get_<name>)`, "
           "puis cite le résultat. Exemple : `tool_use(get_retirement_projection)` "
           "→ `tool_result` → « ta projection pourrait être autour de "
           "X CHF {{cite:tool_retirement_projection}} »."
       )
       ```

    2. **Sentry breadcrumb helper** (sibling to `_emit_gate_breadcrumb` inside the request-scoped closure at ~line 4203 — copy the style exactly). Inside the `coach_chat` request handler, just below the existing `_emit_gate_breadcrumb` closure (around line 4223), add:

       ```python
       def _emit_tool_use_enforcement_breadcrumb(
           result: ToolUseEnforcementResult,
           retry_count: int,
       ) -> None:
           """D-04 Sentry breadcrumb. Fires on every REJECT.

           Hygiene: counts/labels only, NEVER user message content.
           Payload schema: {placeholder_name, retry_count, narrator_tool_count}
           (per CONTEXT specifics §Sentry breadcrumb payload shape).
           """
           if result.verdict != ToolUseEnforcementVerdict.REJECTED:
               return
           try:
               import sentry_sdk
               sentry_sdk.add_breadcrumb(
                   category="coach.citation.tool_use_missing",
                   message=result.structured_reason or "tool_use_missing_for_citation",
                   level="warning",
                   data={
                       "placeholder_name": (result.missing_placeholder_names[0]
                                            if result.missing_placeholder_names else ""),
                       "retry_count": int(retry_count),
                       "narrator_tool_count": int(result.narrator_tool_count),
                   },
               )
           except Exception:  # pragma: no cover — telemetry is fail-open
               pass
       ```

    3. **Wire into `_run_narrator_with_gate`** at line ~4230. The new gate runs AFTER the existing `_citation_gate` PASS verdict, BEFORE returning `loop_result`. On REJECT, it re-prompts ONCE using the `REPROMPT_ADDENDUM_TOOL_USE_MISSING` text. On 2nd-REJECT exhaustion, fall through to the existing FALLBACK path (do NOT call narrator a 3rd time).

       Modify the body of `_run_narrator_with_gate` (around line 4237-4262) as follows (insert the new enforcement block AFTER the existing `if gated.verdict == GateVerdict.PASS: _emit_citation_chip_breadcrumbs(...)` and BEFORE `return loop_result`):

       ```python
       # ... existing code through _emit_citation_chip_breadcrumbs(...) ...

       # Wave 1c D-04 — tool_use enforcement gate.
       # Only runs on PASS verdict from _citation_gate (because REJECTED_*
       # verdicts already trigger the existing retry path; running this
       # gate on top of those would compound retries and blow the budget).
       enforcement = _enforce_tool_use_for_citations(
           answer_text=gated.gated_text,
           tool_calls=loop_result.get("tool_calls") or [],
       )
       _emit_tool_use_enforcement_breadcrumb(enforcement, retry_count=0)
       if enforcement.verdict == ToolUseEnforcementVerdict.PASS:
           return loop_result

       # REJECT path — retry once with the MANDATE re-prompt addendum
       # inlined. Cap at 1 retry per existing _run_narrator_with_gate
       # budget. Second REJECT collapses to TEXT FALLBACK via the existing
       # _citation_gate FALLBACK machinery on the retry_gated path.
       retry_message_w1c = body.message + REPROMPT_ADDENDUM_TOOL_USE_MISSING
       retry_result_w1c = await asyncio.wait_for(
           _run_agent_loop(question=retry_message_w1c, **_initial_loop_kwargs),
           timeout=AGENT_LOOP_DEADLINE_SECONDS,
       )
       retry_gated_w1c = _citation_gate(
           response_text=retry_result_w1c["answer"],
           ctx=coach_ctx,
           citation_allowlist=_gate_allowlist,
           is_retry=True,
           pack=pack,
           user_input_numbers=_user_input_numbers,
       )
       _emit_gate_breadcrumb(retry_gated_w1c, retries=1)
       retry_result_w1c["answer"] = retry_gated_w1c.gated_text
       retry_enforcement = _enforce_tool_use_for_citations(
           answer_text=retry_gated_w1c.gated_text,
           tool_calls=retry_result_w1c.get("tool_calls") or [],
       )
       _emit_tool_use_enforcement_breadcrumb(retry_enforcement, retry_count=1)
       if retry_enforcement.verdict == ToolUseEnforcementVerdict.REJECTED:
           # 2nd-REJECT exhaustion. The existing _citation_gate on
           # is_retry=True already collapses uncited cases to FALLBACK;
           # for the tool_use-missing case, we need to strip the offending
           # {{cite:tool_*}} placeholders from the text so the user does
           # NOT see them as bare prose. Do NOT crash, do NOT raise.
           retry_result_w1c["answer"] = _RE_TOOL_CITE_PLACEHOLDER.sub(
               "", retry_gated_w1c.gated_text
           ).strip()
       if retry_gated_w1c.verdict == GateVerdict.PASS:
           _emit_citation_chip_breadcrumbs(
               retry_gated_w1c.gated_text,
               retry_result_w1c.get("citation_chips"),
               _user.id if _user else None,
           )
       return retry_result_w1c
       ```

       **Note on flag-conditional behaviour** : The new enforcement gate is wrapped by the same `if not settings.COACH_CITATION_GATE_ENABLED: return loop_result` early-return at line 4237 (existing behaviour). When the Phase 94 gate flag is OFF, this new gate is ALSO off, preserving Phase 94 byte-identity. No new flag is introduced for the Wave 1c gate — it's tied to the same Phase 94 master switch.

    4. **Top-of-file imports** : ensure `re` is imported (it already is — verify with `grep -n "^import re" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1).

    5. **Diff cap** : the entire change should be ≤ ~120 added lines net. If the diff exceeds 150 lines, refactor to a new module `services/backend/app/services/coach/citation_tool_use_gate.py` per CONTEXT D-04 Claude's Discretion clause. Verify with `git diff --stat services/backend/app/api/v1/endpoints/coach_chat.py`.
  </action>
  <acceptance_criteria>
    - `grep -n "_enforce_tool_use_for_citations\|ToolUseEnforcementVerdict\|coach.citation.tool_use_missing\|REPROMPT_ADDENDUM_TOOL_USE_MISSING\|_RE_TOOL_CITE_PLACEHOLDER" services/backend/app/api/v1/endpoints/coach_chat.py | wc -l` returns ≥10 (the symbols appear at definition + at the wire site + at the retry path).
    - `python3 -c "from app.api.v1.endpoints.coach_chat import _enforce_tool_use_for_citations, ToolUseEnforcementVerdict; r = _enforce_tool_use_for_citations('foo {{cite:tool_budget_snapshot}}', []); assert r.verdict == ToolUseEnforcementVerdict.REJECTED; assert r.structured_reason == 'tool_use_missing_for_citation:budget_snapshot'; print('OK')"` (from services/backend) prints "OK".
    - `python3 -c "from app.api.v1.endpoints.coach_chat import _enforce_tool_use_for_citations, ToolUseEnforcementVerdict; r = _enforce_tool_use_for_citations('foo {{cite:tool_budget_snapshot}}', [{'name': 'get_budget_status'}]); assert r.verdict == ToolUseEnforcementVerdict.PASS; print('OK')"` prints "OK".
    - `python3 -c "from app.api.v1.endpoints.coach_chat import _enforce_tool_use_for_citations, ToolUseEnforcementVerdict; r = _enforce_tool_use_for_citations('foo {{cite:r3a_plafond_salarie_2026}}', []); assert r.verdict == ToolUseEnforcementVerdict.PASS; print('OK')"` prints "OK" (non-tool placeholder is ignored).
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/ tests/test_coach_citation/ -q` exits 0 (existing Phase 94 + Wave 1b tests preserved).
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0 (full backend suite ≥ baseline 6898 passing per STATE.md).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `git diff --stat services/backend/app/api/v1/endpoints/coach_chat.py` shows ≤150 added lines (refactor trigger if exceeded).
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/ -q 2>&1 | tail -5 && python3 tools/checks/banned_terms_python.py app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <done>
    `_enforce_tool_use_for_citations` defined at module level; `_emit_tool_use_enforcement_breadcrumb` closure defined inside the request handler; both wired into `_run_narrator_with_gate` after `_citation_gate` PASS verdict; REJECT path retries once with `REPROMPT_ADDENDUM_TOOL_USE_MISSING`; 2nd-REJECT exhaustion strips the offending `{{cite:tool_*}}` placeholders from text and does NOT crash; full backend suite still exits 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A.3 — Design panel pre-push (4 subagents in parallel) + apply blocker fixes</name>
  <files></files>
  <read_first>
    - CLAUDE.md §3.5 (routing rules + design panel pattern)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-11 (panel composition for this wave)
    - Engram memory `feedback_design_panel_before_push` (panel-before-push rule)
    - Engram memory `feedback_critical_pm_mode` (resolve panel findings, don't list 2 options)
    - The two diffs from Task A.1 and Task A.2 (`git diff services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py`)
  </read_first>
  <behavior>
    - Test 1: 4 agent invocations completed in parallel (one Task tool call per agent) — security-auditor + qa-expert + ai-engineer + prompt-engineer.
    - Test 2: Each agent's verdict (PASS / BLOCK / SUGGEST) recorded inline in the task output.
    - Test 3: All BLOCK-level findings resolved by an additional commit on the branch BEFORE Task A.4 runs. SUGGEST findings deferred to PR description.
  </behavior>
  <action>
    Per CONTEXT D-11 and `CLAUDE.md §3.5`, spawn 4 subagents IN PARALLEL (single message, 4 Task tool calls) and feed each the diff from A.1 + A.2 + an explicit verdict ask.

    Agent prompts (one per Task tool call, all 4 fired in the SAME message for parallelism):

    1. **`security-auditor` (wshobson)** — Prompt: « Read services/backend/app/services/coach/citation_grammar.py and services/backend/app/api/v1/endpoints/coach_chat.py (most recent commit on feature/wave-1c-smoking-gun). Scan the diff for LSFin banned terms (« garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait », « conseiller » as a verb, « tu devrais », « tu dois », « il faut » as an imperative). Specifically inspect the new MANDATE paragraph + WRONG/RIGHT example pair in citation_grammar.py and the REPROMPT_ADDENDUM_TOOL_USE_MISSING constant in coach_chat.py. Run `python3 tools/checks/banned_terms_python.py` and `python3 tools/checks/accent_lint_fr.py` on both files. Verdict: PASS, BLOCK (with file:line + replacement suggestion), or SUGGEST. Save findings via `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_a:security_audit` and `prior_finding_refs` to engram obs ids 65, 66, 74, 75. »

    2. **`qa-expert` (VoltAgent)** — Prompt: « Read services/backend/app/services/coach/citation_grammar.py and services/backend/app/api/v1/endpoints/coach_chat.py (most recent commit on feature/wave-1c-smoking-gun) + the 5 regression artifacts spec in `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-05`. Verdict: does the Wave A code change provide enough surface for the Wave B regression test floor (5 artifacts) to cover the failure mode end-to-end? Specifically: can a unit test exercise `_enforce_tool_use_for_citations` without spinning up the full FastAPI client? Can the Maestro flow probe distinguish placeholder-as-prose from placeholder-after-tool_use via the response JSON? Verdict: PASS, BLOCK (with concrete coverage gap + which Wave B test artifact needs adjusting), or SUGGEST. Save findings via `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_a:qa_review` and `prior_finding_refs` to engram obs id 69 + the new wave-1c smoking-gun observation. »

    3. **`ai-engineer` (wshobson)** — Prompt: « Read the new MANDATE paragraph + WRONG/RIGHT example pair in services/backend/app/services/coach/citation_grammar.py (most recent commit on feature/wave-1c-smoking-gun) + the captured staging payload at .planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json (read the existing `system` field around the « DOCTRINE — GRAMMAIRE DE CITATION » section). Verdict on narrator-clarity: when Sonnet 4.5 reads this MANDATE + WRONG/RIGHT pair in the context of the full 44k-char system prompt, will it actually invoke `tool_use` instead of falling back to `end_turn`? Flag any phrasing that competes with the legacy doctrine line in services/backend/app/services/coach/claude_coach_service.py:660 (« Ne cite JAMAIS un chiffre que tu ne peux pas sourcer ») — that line teaches REFUSAL, our MANDATE teaches INVOCATION; surface any contradiction. Verdict: PASS, BLOCK (with concrete phrasing suggestion), or SUGGEST. Save findings via `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_a:ai_eng_review` and `prior_finding_refs` to engram obs id 74. »

    4. **`prompt-engineer` (wshobson)** — Prompt: « Read services/backend/app/services/coach/citation_grammar.py and the new REPROMPT_ADDENDUM_TOOL_USE_MISSING constant in services/backend/app/api/v1/endpoints/coach_chat.py (most recent commit on feature/wave-1c-smoking-gun). Review the WRONG/RIGHT example pair for prompt-engineering correctness: contrast clarity, token cost (target ≤150 added tokens for the addendum, ≤300 for the new MANDATE block in the grammar), placement (MANDATE BEFORE format examples is the explicit hypothesis — verify the substring order with `python3 -c "from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT; print(CITATION_GRAMMAR_FRAGMENT.index('OBLIGATOIRE') < CITATION_GRAMMAR_FRAGMENT.index(\"L'outil\"))"`). Flag any pattern that could teach the LLM to mimic the FORMAT without invoking. Verdict: PASS, BLOCK (with concrete edit), or SUGGEST. Save findings via `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_a:prompt_eng_review` and `prior_finding_refs` to engram obs id 74 + the smoking-gun observation. »

    After ALL 4 agents return verdicts:

    - **If any agent returns BLOCK**: open one additional commit on `feature/wave-1c-smoking-gun` resolving the BLOCKER. Re-run the lint commands. Do NOT proceed to Task A.4 until all 4 agents return PASS (or PASS-after-edit).
    - **If all 4 return PASS or SUGGEST**: record SUGGEST findings in the PR body's "Panel review notes" section. Proceed to Task A.4.

    Record the 4 verdicts inline in this task's output. Cite the file:line of each finding.
  </action>
  <acceptance_criteria>
    - 4 agent verdicts recorded (verbatim) in task output.
    - 0 BLOCK-level findings remaining at task completion (resolved by additional commit if any surfaced).
    - SUGGEST findings (if any) noted for inclusion in PR body.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0 after any panel-driven edits.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0 after any panel-driven edits.
    - 4 `mem_save` calls succeeded with the 4 distinct `topic_key` values above (the response envelopes from each `mem_save` show `judgment_required` resolved per the conflict-surfacing rule).
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py && python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <done>
    4 agents ran in parallel, returned verdicts; any BLOCK fixed by additional commit; SUGGEST findings noted for PR body; lints exit 0; 4 `mem_save` entries persisted with the right `topic_key` + `prior_finding_refs`.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A.4 — Open PR on feature/wave-1c-smoking-gun → dev, monitor CI, merge on green</name>
  <files></files>
  <read_first>
    - CLAUDE.md §9 (0-trust protocol — citation discipline before any « shipped » claim)
    - Engram memory `feedback_pre_push_checklist` (caller-grep + canonical regen + full test before push)
    - The 4 panel verdicts from Task A.3
    - `gh pr list --head feature/wave-1c-smoking-gun --json number,state` (verify no existing open PR)
  </read_first>
  <behavior>
    - Test 1: `cd services/backend && python3 -m pytest tests/ -q` exits 0 BEFORE `git push`.
    - Test 2: `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0 BEFORE `git push`.
    - Test 3: `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0 BEFORE `git push`.
    - Test 4: PR opened with `gh pr create` against base `dev`; `gh pr view <N>` returns state=OPEN.
    - Test 5: `gh pr checks <N>` shows ALL jobs ≠ fail before merge.
    - Test 6: After merge, `gh pr view <N> --json mergedAt` returns non-null timestamp.
  </behavior>
  <action>
    1. **Pre-push sanity** (run from `/Users/julienbattaglia/Desktop/MINT.nosync`):
       ```bash
       cd services/backend && python3 -m pytest tests/ -q | tail -3
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py
       python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py
       git status   # confirm clean working tree apart from intended commits
       git log --oneline origin/dev..HEAD   # confirm the fix commit(s) are present
       ```
       All 3 commands MUST exit 0 before the next step. If any fails, fix it and re-run.

    2. **Push the branch**:
       ```bash
       git push origin feature/wave-1c-smoking-gun
       ```

    3. **Open the PR** (HEREDOC body, public-repo discipline per memory `feedback_public_repo_discipline` — no forensic legal language, no « violates X »):
       ```bash
       gh pr create --base dev --head feature/wave-1c-smoking-gun \
         --title "fix(wave-1c): teach narrator to INVOKE tool_use before emitting {{cite:tool_*}} placeholders" \
         --body "$(cat <<'EOF'
       ## What

       Wave 1c smoking-gun fix (CONTEXT D-01 to D-04).

       Bisection on the staging payload (see `.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_results.json`) showed Sonnet 4.5 emitting `{cite:tool_retirement_projection}` AS PROSE without ever calling `get_retirement_projection`, then `end_turn`. Root cause: the citation grammar fragment in `services/backend/app/services/coach/citation_grammar.py` teaches the LLM the citation FORMAT but never MANDATES that the corresponding tool must have been invoked via `tool_use` first.

       This PR:
       - Rewrites the grammar header so the MANDATE (« invoque l'outil d'abord, cite ensuite ») appears BEFORE any FORMAT example. Adds a WRONG/RIGHT example pair so the doctrine is shown by contrast, not just stated.
       - Adds a runtime gate `_enforce_tool_use_for_citations` in `services/backend/app/api/v1/endpoints/coach_chat.py` that rejects placeholder-without-invocation responses and re-prompts once with the MANDATE inlined. 2nd-REJECT exhaustion strips the offending placeholders from the text (no bare-prose `{cite:tool_*}` reaches the user).
       - Fires a Sentry breadcrumb on every REJECT (`category=coach.citation.tool_use_missing`, payload `{placeholder_name, retry_count, narrator_tool_count}`) — operational tripwire post-deploy.

       Wave 1c is split into 3 PRs per CONTEXT D-09: A (this PR, fix), B (regression test floor — 5 artifacts), C (instrumentation teardown). Wave B merges AFTER this PR is merged + a live staging probe confirms `tool_use` emission.

       ## Files changed

       - `services/backend/app/services/coach/citation_grammar.py` — MANDATE paragraph + WRONG/RIGHT example pair, in both `_build_citation_grammar_fragment()` and `build_intent_scoped_citation_grammar()`.
       - `services/backend/app/api/v1/endpoints/coach_chat.py` — `_enforce_tool_use_for_citations` + `ToolUseEnforcementVerdict` + `ToolUseEnforcementResult` + `_PLACEHOLDER_TO_TOOL_NAME` + `_RE_TOOL_CITE_PLACEHOLDER` + `REPROMPT_ADDENDUM_TOOL_USE_MISSING` (module level); `_emit_tool_use_enforcement_breadcrumb` (closure) + wire into `_run_narrator_with_gate` retry path.

       ## Mechanical gates (pre-push)

       - Backend pytest full suite exits 0 (baseline 6898 preserved).
       - `tools/checks/banned_terms_python.py` exits 0 on both files.
       - `tools/checks/accent_lint_fr.py` exits 0 on both files.

       ## Panel review notes

       4 subagents ran in parallel before push: security-auditor, qa-expert, ai-engineer, prompt-engineer. All returned PASS (or PASS-after-edit). SUGGEST findings: <fill in any non-blocking suggestions from Task A.3 here, or write "none".>

       ## What this PR does NOT do

       - It does NOT add the 5 regression test artifacts (Wave B PR).
       - It does NOT remove the WAVE1C instrumentation in `services/backend/app/services/rag/llm_client.py` or `services/backend/app/services/llm/router.py` (Wave C PR).
       - It does NOT flip Wave 1b status from `PENDING G2 — RUNTIME GAP` to `SHIPPED` — that flip is gated on a live G2 probe after this PR merges + Railway redeploys (CONTEXT D-07).

       ## 0-trust note

       Tests green + lints green = mechanical signals only. Per CLAUDE.md §9.5 and CONTEXT D-10, this PR claims « PR opened » NOT « shipped », « ready », or « works ». Those words become applicable only after the live staging probe returns `citationChips` non-null AND no bare `{cite:tool_*}` strings in the message body.

       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
       EOF
       )"
       ```

    4. **Monitor CI** (use `gh pr checks <N>` polled inline; do NOT use scheduled wakeup per memory `feedback_no_wakeup_active_polling`):
       ```bash
       PR_NUM=$(gh pr list --head feature/wave-1c-smoking-gun --json number --jq '.[0].number')
       echo "PR: $PR_NUM"
       # Poll inline until CI completes
       until gh pr checks $PR_NUM 2>&1 | grep -qE "(^X|pending|in_progress)" || ! gh pr checks $PR_NUM 2>&1 | grep -q pending; do sleep 30; done
       gh pr checks $PR_NUM
       ```
       If any job FAILS:
       - Read the failing job's log: `gh pr checks $PR_NUM | grep fail` then `gh run view <run-id> --log-failed | tail -100`
       - Fix the underlying cause, push a new commit, re-poll.
       - Do NOT use `--no-verify`.

    5. **Merge on green** (squash, delete branch):
       ```bash
       gh pr merge $PR_NUM --squash --delete-branch
       ```
       Capture the squash sha:
       ```bash
       MERGE_SHA=$(gh pr view $PR_NUM --json mergeCommit --jq '.mergeCommit.oid')
       echo "Merged as: $MERGE_SHA"
       ```

    6. **Open dev → staging bundle PR** (downstream consumer — Wave B starts after this lands AND Railway redeploys):
       ```bash
       git fetch origin
       git log --oneline origin/staging..origin/dev | head -5
       gh pr create --base staging --head dev \
         --title "ship: dev → staging — wave-1c tool_use mandate fix" \
         --body "$(cat <<'EOF'
       Ships wave-1c smoking-gun fix (PR #$PR_NUM) to staging.

       After Railway redeploys this commit, run a live probe (curl + JSON parse) against `https://mint-staging.up.railway.app/api/v1/coach/chat` with a seeded retirement question. Expected: `citationChips: [{toolName: "get_retirement_projection", ...}]` non-null AND no bare `{cite:tool_*}` strings in `message`. The probe evidence unblocks Wave B (regression test floor PR).

       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
       EOF
       )"
       ```
       (NOTE: leave this dev→staging PR open for Julien to merge, OR auto-merge it after polling its CI. Do NOT merge into staging without confirming all required staging-gate checks pass.)
  </action>
  <acceptance_criteria>
    - `gh pr view <N> --json state,mergedAt --jq '"state=" + .state + " mergedAt=" + (.mergedAt // "null")'` returns `state=MERGED mergedAt=<non-null timestamp>`.
    - `gh pr checks <N>` shows ALL jobs as `pass` (no `fail`, no `pending` at merge time).
    - `git fetch origin && git log --oneline origin/dev | head -3` includes the squash commit with the title prefix `fix(wave-1c)`.
    - dev→staging bundle PR opened OR auto-merged (URL recorded in output).
  </acceptance_criteria>
  <verify>
    <automated>gh pr view "$(gh pr list --search 'fix(wave-1c) base:dev' --state merged --json number --jq '.[0].number')" --json state,mergedAt 2>&1 | head -5</automated>
  </verify>
  <done>
    Wave A PR is MERGED to `dev` with non-null mergedAt. dev→staging bundle PR opened (and either merged or pending operator action). Squash sha cited in task output. No `--no-verify`, no force-push.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A.5 — Engram mem_save: Wave A close-out finding</name>
  <files></files>
  <read_first>
    - The Task A.4 output (PR number, merge sha, dev→staging PR url)
    - Engram memory `feedback_critical_pm_mode` (engram contract — agent-agnostic topic keys, prior_finding_refs)
    - CLAUDE.md §3.5 (engram contract for wshobson agents)
    - The 4 panel verdicts from Task A.3 (for cross-link refs)
  </read_first>
  <behavior>
    - Test 1: 1 `mem_save` call succeeded with `topic_key: coach:citation:tool_use_mandate:wave_a:shipped` and `prior_finding_refs` listing engram obs ids 65, 66, 69, 74, 75 + the 4 panel topic_keys from Task A.3.
    - Test 2: response envelope shows `judgment_required` resolved per the conflict-surfacing rule.
  </behavior>
  <action>
    Invoke `mem_save` ONCE with the following content (project = mint, autodetected from git remote):

    - `topic_key`: `coach:citation:tool_use_mandate:wave_a:shipped`
    - `observation_type`: `discovery`
    - `prior_finding_refs`: [`65`, `66`, `69`, `74`, `75`, `coach:citation:tool_use_mandate:wave_a:security_audit`, `coach:citation:tool_use_mandate:wave_a:qa_review`, `coach:citation:tool_use_mandate:wave_a:ai_eng_review`, `coach:citation:tool_use_mandate:wave_a:prompt_eng_review`]
    - `supersedes`: obs id 74 (`obs-bcb0b41d70a52ae4` — H2 tool_choice falsification was correct on its own but the actual culprit is doctrine-level FORMAT-teaching; this finding closes the open hypothesis)
    - `content`: « Wave 1c smoking-gun fix shipped to dev. PR #<N> merged at <timestamp>, squash sha <sha>. Two surfaces touched: services/backend/app/services/coach/citation_grammar.py (MANDATE paragraph + WRONG/RIGHT example pair before FORMAT examples, in both _build_citation_grammar_fragment AND build_intent_scoped_citation_grammar) + services/backend/app/api/v1/endpoints/coach_chat.py (_enforce_tool_use_for_citations module-level + ToolUseEnforcementVerdict enum + REPROMPT_ADDENDUM_TOOL_USE_MISSING constant + _emit_tool_use_enforcement_breadcrumb closure wired into _run_narrator_with_gate after _citation_gate PASS verdict). Sentry breadcrumb category=coach.citation.tool_use_missing fires on every REJECT. 2nd-REJECT exhaustion strips offending {{cite:tool_*}} placeholders from text and falls through to existing FALLBACK without crash. Wave B (regression test floor — 5 artifacts) starts after the dev→staging merge lands + a live probe confirms tool_use emission. Wave C (instrumentation teardown) starts after Wave B's regression suite is green + G2 by Julien. 0-trust caveat: PR opened ≠ shipped per CLAUDE.md §9.5; the « works » claim is gated on the live probe evidence, NOT on this PR's tests. »

    Check the `mem_save` response envelope. If `judgment_required: true`, iterate `candidates[]` and call `mem_judge` per the conflict-surfacing rule (confidence ≥0.7 + relation != supersedes/conflicts_with → resolve silently; otherwise raise conversationally in the final output).
  </action>
  <acceptance_criteria>
    - 1 successful `mem_save` call with the exact `topic_key` `coach:citation:tool_use_mandate:wave_a:shipped`.
    - `prior_finding_refs` includes all 4 panel topic_keys from Task A.3 + obs ids 65, 66, 69, 74, 75 (obs 69 = qa-expert regression-test floor mandate per HANDOFF.md).
    - If `judgment_required: true` → `mem_judge` invoked once per candidate; conflicts surfaced conversationally if confidence < 0.7 OR relation is supersedes/conflicts_with on an architecture/policy/decision observation.
  </acceptance_criteria>
  <verify>
    <automated>echo "mem_save invoked via MCP — verification is via the tool response envelope, not via shell"</automated>
  </verify>
  <done>
    Engram observation saved. Conflicts resolved or surfaced conversationally per the rule.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A.6 — Deploy Sentry tripwire alarm rule for `coach.citation.tool_use_missing` (via API)</name>
  <files></files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py (the new `_emit_tool_use_enforcement_breadcrumb` closure from Task A.2 — confirm the breadcrumb `category` value and payload keys)
    - services/backend/app/observability/ (grep for existing Sentry SDK init / DSN configuration; locate the Sentry organization slug + project slug, e.g. via `grep -rn "sentry_sdk.init\|sentry.io\|SENTRY_DSN\|sentry_org\|sentry_project" services/backend/`)
    - Sentry API docs: https://docs.sentry.io/api/alerts/create-an-issue-alert-rule-for-a-project/ (issue-alert-rule create endpoint shape)
    - Wave C `<verification>` line 559-565 (the alarm rule was previously documented as "manual op" — this task supersedes that with autonomous deploy)
  </read_first>
  <behavior>
    - Test 1: Sentry org slug + project slug determined from MINT backend config (NOT hardcoded — discover via grep).
    - Test 2: `curl POST https://sentry.io/api/0/projects/{org}/{proj}/rules/` returns HTTP 201 + a `id` field in the JSON response.
    - Test 3: `curl GET https://sentry.io/api/0/projects/{org}/{proj}/rules/{rule_id}/` returns the rule with `status == "active"` (or equivalent enabled-marker depending on Sentry API version).
    - Test 4: The rule's conditions reference the breadcrumb category `coach.citation.tool_use_missing` (Sentry alert rules filter via `event.breadcrumbs[].category` matcher OR via tags — pick the matcher Sentry supports for breadcrumb categories at issue-alert level).
  </behavior>
  <action>
    1. **Discover Sentry org + project slug** (the values to substitute into the API URL):
       ```bash
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       grep -rn "sentry_sdk.init\|SENTRY_DSN\|sentry.io" services/backend/ | head -20
       # Expected: a `sentry_sdk.init(dsn="https://...@o<org_id>.ingest.sentry.io/<project_id>")` line.
       # The DSN format encodes the org + project IDs. Resolve org_slug + project_slug via:
       curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" https://sentry.io/api/0/organizations/ | python3 -m json.tool | head -50
       # Identify the org_slug (likely "mint" or similar) — record in task output.
       curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" https://sentry.io/api/0/organizations/<org_slug>/projects/ | python3 -m json.tool | head -50
       # Identify the project_slug for the backend (likely "backend" or "mint-backend") — record in task output.
       ```

       **CAVEAT — auth token availability** : `$SENTRY_AUTH_TOKEN` must be set in the local environment OR available via `railway run` against staging. Check with `echo "$SENTRY_AUTH_TOKEN" | wc -c` — output > 1 means the var is set. If unset:
       - Fall back to Option B (defer to Julien manual deploy). Document the fallback in task output. Create the file `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule-manual.md` with the verbatim Sentry-UI steps + the rule JSON for Julien to paste. Skip steps 2-4 below. Do NOT block the rest of Wave A.

    2. **Create the alert rule via POST** (Option A path):
       ```bash
       ORG_SLUG="<resolved_from_step_1>"
       PROJ_SLUG="<resolved_from_step_1>"
       RULE_PAYLOAD='{
         "name": "coach citation tool_use missing — Wave 1c tripwire",
         "actionMatch": "all",
         "filterMatch": "all",
         "frequency": 60,
         "conditions": [
           {
             "id": "sentry.rules.conditions.event_frequency.EventFrequencyCondition",
             "interval": "1h",
             "value": 10
           }
         ],
         "filters": [
           {
             "id": "sentry.rules.filters.tagged_event.TaggedEventFilter",
             "key": "breadcrumb.category",
             "match": "eq",
             "value": "coach.citation.tool_use_missing"
           }
         ],
         "actions": [
           {
             "id": "sentry.rules.actions.notify_email.NotifyEmailAction",
             "targetType": "Member",
             "targetIdentifier": "<resolved_via_sentry_api_users_endpoint — Julien's Sentry member id>"
           }
         ]
       }'
       RESPONSE=$(curl -s -X POST \
         -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
         -H "Content-Type: application/json" \
         -d "$RULE_PAYLOAD" \
         "https://sentry.io/api/0/projects/$ORG_SLUG/$PROJ_SLUG/rules/")
       RULE_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))")
       echo "Created Sentry rule id: $RULE_ID"
       ```

       **CAVEAT — filter shape** : Sentry's issue-alert filter for breadcrumb category may not be `TaggedEventFilter` with `key=breadcrumb.category`. If the POST returns 400 with a filter-validation error, the correct path is to instead use a **metric alert** OR add a `tag` in the breadcrumb itself (which the executor would then add to `_emit_tool_use_enforcement_breadcrumb` in Task A.2 — `sentry_sdk.set_tag("coach_citation_tool_use_missing", "1")` adjacent to the breadcrumb). If that adjustment is needed, do it as a one-line follow-up commit in Wave A's branch BEFORE this task closes. Document the actual filter shape used in task output.

    3. **Verify the rule is live**:
       ```bash
       curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" "https://sentry.io/api/0/projects/$ORG_SLUG/$PROJ_SLUG/rules/$RULE_ID/" | python3 -m json.tool
       # Expected: JSON with the rule's name, conditions, filters, actions, AND a status field indicating active/enabled.
       ```

    4. **Record the rule details** in the verification report artifact:
       Save the rule_id + the URL `https://sentry.io/organizations/$ORG_SLUG/alerts/rules/$PROJ_SLUG/$RULE_ID/` to a new file `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule.md` containing:
       - Rule ID
       - Sentry rule URL (for Julien to verify in UI)
       - The verbatim POST payload
       - The verbatim GET response showing status=active
       - Date/time of deploy
       - The fallback note ("if rule is ever disabled, re-deploy with `curl POST ...` from the verbatim payload above").
  </action>
  <acceptance_criteria>
    - Either (Option A success): file `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule.md` exists AND contains a non-empty rule_id AND the verbatim GET response showing the rule is active.
    - OR (Option B fallback): file `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule-manual.md` exists AND contains the verbatim Sentry-UI steps + JSON payload for Julien to paste, AND the task output documents the fallback rationale (e.g. "SENTRY_AUTH_TOKEN unset in local env, deferred to Julien manual deploy").
    - In EITHER case, the breadcrumb category referenced in the rule (or the manual steps) is verbatim `coach.citation.tool_use_missing` (matches Task A.2 wiring).
    - Task A.6 does NOT block Task A.4 (PR open + merge). If Option A is taken and the rule deploy fails, log the error + fall back to Option B in-task; do NOT block Wave A merge.
  </acceptance_criteria>
  <verify>
    <automated>test -f /Users/julienbattaglia/Desktop/MINT.nosync/.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule.md || test -f /Users/julienbattaglia/Desktop/MINT.nosync/.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule-manual.md</automated>
  </verify>
  <done>
    Sentry tripwire alarm rule deployed via API (Option A) OR manual-deploy artifact provided for Julien (Option B). The breadcrumb category is verbatim `coach.citation.tool_use_missing`. Rule details persisted in `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule{,-manual}.md`.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM output → user-visible narrator response | The narrator may emit placeholder-as-prose; the new gate intercepts and either retries or strips. |
| Sentry breadcrumb payload → telemetry sink | PII hygiene: counts/labels only, NEVER user message content or raw answer text. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wave-1c-A-01 | Information disclosure | Sentry breadcrumb `coach.citation.tool_use_missing` payload | mitigate | Payload includes only `placeholder_name` (registry short-name), `retry_count` (int), `narrator_tool_count` (int). Zero user-message content. Pattern matches existing `_emit_gate_breadcrumb` hygiene. |
| T-wave-1c-A-02 | Denial of service | retry-once path on REJECT | mitigate | Retry cap = 1 per existing `_run_narrator_with_gate` budget. 2nd-REJECT collapses to placeholder strip + fallback. No 3rd narrator call possible. |
| T-wave-1c-A-03 | Tampering | LLM-supplied tool_use name vs `_PLACEHOLDER_TO_TOOL_NAME` canonical map | mitigate | Map is read-only Python dict at module level. Unknown short-names are tolerated (PASS) rather than rejected, so a new CITATION_REGISTRY key cannot bring down the gate. Wave B regression suite adds the mapping when a new key lands. |
| T-wave-1c-A-04 | Repudiation | retry path consumes extra Anthropic tokens | accept | Cost regression is bounded by the existing Phase 94 retry budget (retry-once cap, no new budget added). Sentry breadcrumb rate is the post-deploy monitoring signal. |
| T-wave-1c-A-05 | Elevation of privilege | new MANDATE text in user-facing French | mitigate | LSFin banned-terms scan (`banned_terms_python.py`) + accent lint (`accent_lint_fr.py`) exit 0 in Task A.1 acceptance. Design panel review in Task A.3 includes `security-auditor` for LSFin compliance second-pass. |
| T-wave-1c-A-06 | Spoofing | gate bypass via `COACH_CITATION_GATE_ENABLED=false` | accept | Phase 94 master switch governs both gates. If flag is off, both Phase 94 closed-world gate AND Wave 1c tool_use gate are off → Phase 94 byte-identity preserved (CONTEXT GATE byte-identity invariant). Production flag is on per CONTEXT D-09 / Phase 94 prod-flip path. |
</threat_model>

<verification>
## Wave A close-out checks (run by gsd-verifier subagent on PR merge)

- G1 (Maestro/sim) — DEFERRED to post-merge live probe (Task A.4 §6 dev→staging PR triggers Railway redeploy; probe is the unblock-signal for Wave B).
- G2 (Julien sim) — DEFERRED to Wave C precondition.
- G3 (dev CI green) — `gh pr checks <N>` shows ALL jobs pass. Cite the run ID in the verification report.
- G4 (regression suite) — `cd services/backend && python3 -m pytest tests/ -q` exits 0 with ≥6898 passing. Cite the count.
- G5 (LSFin + accent lint) — `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0. Same for `accent_lint_fr.py`. `validate_arb_parity()` not applicable (backend-only change).

## Live probe (after dev→staging merges + Railway redeploys)

After the dev→staging PR is merged, run this against staging — the OUTPUT is the unblock-signal for Wave B:

```bash
EMAIL="claude-wave1c-probe-$(date +%s)@example.com"
PWD=$(python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(20)))")
REG=$(curl -s -X POST https://mint-staging.up.railway.app/api/v1/auth/register \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PWD\"}")
JWT=$(echo "$REG" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
curl -s -o /dev/null -X PUT https://mint-staging.up.railway.app/api/v1/budget/me \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"income_monthly":7500,"fixed_lines":[{"label":"Loyer","amount":1850,"category":"housing"}],"variable_target_monthly":1100,"savings_target_monthly":1200}'
RESP=$(curl -s -X POST https://mint-staging.up.railway.app/api/v1/coach/chat \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"message":"Quelle sera ma rente AVS et LPP à 65 ans avec mon 3eme pilier actuel ? Donne-moi la projection chiffrée.","language":"fr","cash_level":3,"persistence_consent":false}')
echo "$RESP" | python3 -c "
import sys, json, re
r = json.load(sys.stdin)
chips = r.get('citationChips')
msg = r.get('message', '')
bare = re.findall(r'\{cite:tool_[a-z_]+\}', msg)
print(f'citationChips: {chips!r}')
print(f'bare placeholders in message: {bare!r}')
print('UNBLOCK WAVE B' if (chips and not bare) else 'STILL BROKEN — diagnose before Wave B')
"
```

Cite the verbatim `curl` output as the unblock-signal in Wave B's preconditions.
</verification>

<success_criteria>
- All 5 tasks in Wave A complete: grammar rewrite + runtime gate + design panel + PR merge + engram save.
- Wave A PR is MERGED to `dev` with non-null mergedAt timestamp.
- All 4 design-panel agents returned PASS (or PASS-after-edit).
- Backend pytest suite exits 0 with ≥6898 passing.
- LSFin banned-terms + accent lint exit 0 on both touched files.
- Sentry breadcrumb category `coach.citation.tool_use_missing` defined and wired (mechanically verifiable by grep + import test).
- 1 engram `mem_save` persisted with topic_key `coach:citation:tool_use_mandate:wave_a:shipped`.

**Wave A does NOT claim « shipped » or « works ».** Per CLAUDE.md §9.5, this is « PR opened + dev-merged ». The « works » claim is owned by Wave B's regression suite + the live probe evidence cited in `verification` above.
</success_criteria>

<output>
After Wave A completes, this PLAN.md's status is « MERGED TO DEV — AWAITING LIVE PROBE ». Wave B's preconditions reference the live probe output. Do NOT create a SUMMARY.md for Wave A in isolation — produce a single combined `wave-1c-SUMMARY.md` at phase close-out (after Wave C lands).
</output>
