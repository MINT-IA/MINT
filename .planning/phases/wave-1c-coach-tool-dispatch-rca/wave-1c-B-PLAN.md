---
phase: wave-1c-coach-tool-dispatch-rca
wave: B
depends_on:
  - wave-1c-A-PLAN.md
  - human_checkpoint_live_probe   # Wave A merged + dev→staging merged + Railway redeployed + 1 live probe confirmed tool_use emission
autonomous: false
files_modified:
  - services/backend/tests/test_coach_citation/test_tool_use_mandate.py
  - services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py
  - services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py
  - services/backend/tests/bundles/test_compile_yields_chip_emitter.py
  - tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml
wave1c_decisions_addressed: [D-05, D-08, D-09, D-10, D-12]
branch: feature/wave-1c-regression-tests
target_branch: dev
must_haves:
  truths:
    - "5 regression test artifacts exist and pass (4 pytest files + 1 Maestro flow)."
    - "Mock-Anthropic unit tests cover the 4 cases: stop_reason==tool_use, gate REJECT on placeholder-without-tool_use, retry restores correct behavior, 2-retry exhaustion → FALLBACK without crash."
    - "Bundle compiler test parameterized on 3 messages, asserts compile_bundles(intents).allowed_tools ∩ CHIP_EMITTERS is non-empty."
    - "8-archetype × 6-tool matrix test reuses the Wave 1a parity fixture rig."
    - "Maestro flow asserts chips for ALL 6 tools (get_budget_status, get_retirement_projection, get_cross_pillar_analysis, get_3a_cap, get_avs_age_reference, get_couple_optimization). Precondition: runFlow: auth/login.yaml."
    - "Wave B PR merges to dev only AFTER a live staging probe confirms tool_use emission (human checkpoint blocks Wave B start)."
  artifacts:
    - path: services/backend/tests/test_coach_citation/test_tool_use_mandate.py
      provides: "Unit tests for _enforce_tool_use_for_citations + _run_narrator_with_gate retry path"
      exports: ["test_grammar_contains_mandate_paragraph", "test_mandate_precedes_format_examples", "test_wrong_right_example_pair_present", "test_gate_rejects_placeholder_without_tool_use", "test_gate_passes_when_tool_use_present", "test_partial_case_rejects_naming_missing", "test_retry_restores_correct_behavior", "test_two_retry_exhaustion_falls_through_to_fallback", "test_non_tool_placeholder_is_ignored"]
    - path: services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py
      provides: "6 force-keyword fixtures + mock Anthropic + assert stop_reason==tool_use"
    - path: services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py
      provides: "8 archetypes × 6 tools parametrized test"
    - path: services/backend/tests/bundles/test_compile_yields_chip_emitter.py
      provides: "3-message parametrized test, asserts compile_bundles ∩ CHIP_EMITTERS non-empty"
    - path: tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml
      provides: "Maestro flow asserting all 6 tool chips visible after a retirement-question prompt"
  key_links:
    - from: "test_tool_use_mandate.py"
      to: "app.api.v1.endpoints.coach_chat._enforce_tool_use_for_citations"
      pattern: "direct unit test import; no FastAPI TestClient needed (pure function)"
    - from: "test_narrator_emits_tool_use_for_intent.py"
      to: "AnthropicClient mock at services/backend/app/services/llm/router.py"
      pattern: "monkeypatch the Anthropic SDK call to return a canned tool_use block"
    - from: "coach_tool_dispatch_all_6_smoke.yaml"
      to: "Maestro app on iPhone-17-Pro sim against staging backend"
      pattern: "extendedWaitUntil pattern + assertVisible for each of the 6 chip widgets"
---

<objective>
Land the regression test floor that makes the Wave A fix mechanically permanent. 5 artifacts per CONTEXT D-05: 4 pytest files + 1 Maestro flow. Wave B PR merges AFTER Wave A is merged AND a live staging probe confirms tool_use emission (the human checkpoint at the top of this plan).

Purpose: Wave A landed the doctrine + the runtime gate. Wave B is the safety net that prevents the bug from re-emerging. Without these tests, a future grammar refactor could silently reintroduce the FORMAT-without-INVOCATION pattern and the runtime gate could be bypassed.

Output: 1 PR on new branch `feature/wave-1c-regression-tests` targeting `dev`, ~500 lines of test code total + 1 Maestro flow YAML. All tests exit 0 on backend baseline + Maestro flow PASSes on iPhone-17-Pro sim against staging.
</objective>

<execution_context>
**Human checkpoint at task B.0** (blocker — must resolve before any test artifact is created): Verify that Wave A has merged AND a live staging probe returned `citationChips` non-null + no bare `{cite:tool_*}` strings. If this evidence is not in chat OR cannot be produced by Claude itself with the curl block in Wave A's `<verification>` section, PAUSE and ask Julien for the probe evidence.

Backend-only PR + 1 Maestro YAML. No Flutter touch.
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A-PLAN.md
@services/backend/app/services/coach/citation_grammar.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/citation_parser.py
@services/backend/tests/test_coach_citation/test_breadcrumb_contract.py
@services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py
@tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml
@tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml

<interfaces>
<!-- From wave-1c-A-PLAN.md merged commit — these are the symbols Wave B tests against -->
```python
# Module level in services/backend/app/api/v1/endpoints/coach_chat.py
class ToolUseEnforcementVerdict(str, Enum):
    PASS = "pass"
    REJECTED = "rejected"

@dataclass
class ToolUseEnforcementResult:
    verdict: ToolUseEnforcementVerdict
    missing_placeholder_names: list[str]
    structured_reason: Optional[str]   # e.g. "tool_use_missing_for_citation:budget_snapshot"
    narrator_tool_count: int

def _enforce_tool_use_for_citations(answer_text: str, tool_calls: list[dict]) -> ToolUseEnforcementResult: ...

_PLACEHOLDER_TO_TOOL_NAME: dict[str, str] = {
    "budget_snapshot": "get_budget_status",
    "retirement_projection": "get_retirement_projection",
    "cross_pillar_analysis": "get_cross_pillar_analysis",
    "couple_optimization": "get_couple_optimization",
    "cap_status": "get_cap_status",
    "retrieve_memories": "retrieve_memories",
}

REPROMPT_ADDENDUM_TOOL_USE_MISSING: str = "...verbatim FR text..."
```

<!-- Existing fixture rig (Wave 1a parity) — REUSE -->
```python
# services/backend/tests/conftest.py
def archetype_fixture(name): ...   # 8 archetypes: swiss_native, expat_eu, expat_us, cross_border, independent_no_lpp, retiree, young_professional, expat_high_income

# services/backend/tests/bundles/conftest.py
CHIP_EMITTERS: set[str] = {"get_budget_status", "get_retirement_projection", "get_cross_pillar_analysis", "get_couple_optimization", "get_cap_status", "retrieve_memories"}
```

<!-- Maestro flow style (extracted from wave_1b_citation_chip_smoke.yaml) -->
```yaml
appId: ch.mint.app
env:
  STAGING_URL: https://mint-staging.up.railway.app
---
- runFlow: auth/login.yaml
- tapOn: <chat input>
- inputText: "Quelle sera ma rente AVS et LPP à 65 ans..."
- tapOn: <send button>
- extendedWaitUntil:
    visible: { id: "ToolCallCitationChip:get_retirement_projection" }
    timeout: 15000
- assertVisible: { id: "ToolCallCitationChip:get_budget_status" }
- assertVisible: { id: "ToolCallCitationChip:get_retirement_projection" }
# ...etc for the other 4 chips
```
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task B.0 — HUMAN CHECKPOINT: confirm live staging probe shows tool_use emission</name>
  <what-built>
    Wave A landed on dev. dev→staging PR opened (and either merged or pending). Railway should have redeployed. We need a live probe confirming the fix works on staging before opening any regression test PR.
  </what-built>
  <how-to-verify>
    Two paths — EITHER works as the unblock signal:

    Path 1 — Claude runs the probe itself (preferred when Railway is available):
    Run the verbatim `curl` block from `wave-1c-A-PLAN.md <verification>` section against `https://mint-staging.up.railway.app`. The Python parse at the end MUST print:
    ```
    citationChips: [{...non-empty...}]
    bare placeholders in message: []
    UNBLOCK WAVE B
    ```
    Paste the verbatim curl response JSON into the task output. If the parse prints `STILL BROKEN — diagnose before Wave B`, do NOT proceed; diagnose (likely Wave A's dev→staging PR has not merged yet, OR Railway has not redeployed, OR the fix has a regression).

    Path 2 — Julien posts the evidence in chat:
    Operator says « probe OK » in chat AND posts either (a) a screenshot of citation chips rendering in the iOS sim against staging, OR (b) the curl JSON output showing citationChips non-null + no bare placeholders.

    On EITHER path, record the evidence verbatim in this task's output (the curl JSON OR the screenshot path OR the chat quote) before proceeding.
  </how-to-verify>
  <resume-signal>
    Paste the curl JSON OR Julien's confirmation quote OR « probe failed — diagnose ». Only « probe OK » with cited evidence unblocks B.1+.
  </resume-signal>
</task>

<task type="auto" tdd="true">
  <name>Task B.1 — Create test_tool_use_mandate.py (NEW, 9 test cases)</name>
  <files>services/backend/tests/test_coach_citation/test_tool_use_mandate.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py (search for `_enforce_tool_use_for_citations`, `ToolUseEnforcementVerdict`, `ToolUseEnforcementResult`, `REPROMPT_ADDENDUM_TOOL_USE_MISSING`, `_PLACEHOLDER_TO_TOOL_NAME` — read the full definitions + the wire site in `_run_narrator_with_gate`)
    - services/backend/app/services/coach/citation_grammar.py (`_build_citation_grammar_fragment` + `build_intent_scoped_citation_grammar`)
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py (style reference — match this file's import + parametrize patterns exactly)
    - services/backend/tests/test_citation_gate/conftest.py (look for existing FastAPI app fixture + Anthropic mock pattern)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-05.4 (NEW test_tool_use_mandate.py spec — verbatim 4 fixture cases)
  </read_first>
  <behavior>
    9 test cases in `test_tool_use_mandate.py` (3 grammar + 6 gate):
    - test_grammar_contains_mandate_paragraph — assert "OBLIGATOIRE" substring appears in `CITATION_GRAMMAR_FRAGMENT` AND in `build_intent_scoped_citation_grammar({"retirement"})`.
    - test_mandate_precedes_format_examples — assert `CITATION_GRAMMAR_FRAGMENT.index("OBLIGATOIRE") < CITATION_GRAMMAR_FRAGMENT.index("L'outil \`get_budget_status\` renvoie")`.
    - test_wrong_right_example_pair_present — assert BOTH "REJETÉ — placeholder sans tool_use préalable" AND "ACCEPTÉ — tool_use puis citation du résultat" substrings appear in `CITATION_GRAMMAR_FRAGMENT`.
    - test_gate_rejects_placeholder_without_tool_use — assert `_enforce_tool_use_for_citations("foo {{cite:tool_budget_snapshot}}", [])` returns verdict==REJECTED, structured_reason=="tool_use_missing_for_citation:budget_snapshot", missing_placeholder_names==["budget_snapshot"].
    - test_gate_passes_when_tool_use_present — assert `_enforce_tool_use_for_citations("foo {{cite:tool_budget_snapshot}}", [{"name": "get_budget_status"}])` returns verdict==PASS, narrator_tool_count==1.
    - test_partial_case_rejects_naming_missing — answer with 2 tool placeholders, only 1 matching tool_use → REJECTED, structured_reason names the missing one.
    - test_non_tool_placeholder_is_ignored — answer with `{{cite:r3a_plafond_salarie_2026}}` + empty tool_calls → PASS (only `tool_*` placeholders are gated).
    - test_retry_restores_correct_behavior — mock `_run_agent_loop` to return placeholder-without-tool_use on first call, then tool_use+placeholder on retry; assert the request handler returns the retry's answer + 0 bare `{{cite:tool_*}}` placeholders in the final response.
    - test_two_retry_exhaustion_falls_through_to_fallback — mock `_run_agent_loop` to ALWAYS return placeholder-without-tool_use; assert the request handler returns response with 0 bare `{{cite:tool_*}}` placeholders (stripped per Wave A's 2nd-REJECT path) AND does NOT raise.

    All 9 tests must exit 0 on `pytest tests/test_coach_citation/test_tool_use_mandate.py -q`.
  </behavior>
  <action>
    Create `services/backend/tests/test_coach_citation/test_tool_use_mandate.py`. Match the style of `services/backend/tests/test_coach_citation/test_breadcrumb_contract.py` (import + pytest fixture pattern).

    Test scaffolding template:

    ```python
    """Wave 1c Plan B — regression test floor for the tool_use mandate.

    CONTEXT D-05.4 — 4 mandatory fixture cases + 5 grammar/gate sanity tests.

    The 4 mandatory fixtures (per CONTEXT verbatim) :
    - fixture: prompt with `{{cite:tool_X}}` produces `tool_use:X` in response stack
    - fixture: gate REJECTS when LLM emits placeholder without prior `tool_use`
    - fixture: re-prompt restores correct behavior on retry
    - fixture: 2-retry exhaustion falls through to TEXT FALLBACK without crash

    The 5 sanity tests guard the prompt-fragment side (citation_grammar.py)
    and the pure-function side (_enforce_tool_use_for_citations), so future
    refactors cannot silently revert the doctrine.
    """
    from __future__ import annotations

    import re
    from unittest.mock import patch, AsyncMock

    import pytest

    from app.api.v1.endpoints.coach_chat import (
        _enforce_tool_use_for_citations,
        ToolUseEnforcementVerdict,
        REPROMPT_ADDENDUM_TOOL_USE_MISSING,
        _RE_TOOL_CITE_PLACEHOLDER,
    )
    from app.services.coach.citation_grammar import (
        CITATION_GRAMMAR_FRAGMENT,
        build_intent_scoped_citation_grammar,
    )


    # ---------------------------------------------------------------------------
    # Grammar fragment sanity (3 tests)
    # ---------------------------------------------------------------------------

    def test_grammar_contains_mandate_paragraph():
        """D-03 — MANDATE substring appears in both grammar variants."""
        assert "OBLIGATOIRE" in CITATION_GRAMMAR_FRAGMENT
        scoped = build_intent_scoped_citation_grammar(["retirement"])
        assert "OBLIGATOIRE" in scoped, "Intent-scoped grammar must inherit the MANDATE"

    def test_mandate_precedes_format_examples():
        """D-03 — MANDATE must appear BEFORE any FORMAT example.

        Reorder protection : if a future refactor moves the MANDATE below
        the FORMAT examples, this test catches it. The bug was: the LLM
        mimics the FORMAT pattern before reading the MANDATE.
        """
        mandate_idx = CITATION_GRAMMAR_FRAGMENT.index("OBLIGATOIRE")
        format_idx = CITATION_GRAMMAR_FRAGMENT.index("L'outil `get_budget_status` renvoie")
        assert mandate_idx < format_idx, (
            f"MANDATE position ({mandate_idx}) must be before FORMAT example "
            f"position ({format_idx}) — see HANDOFF.md smoking-gun section."
        )

    def test_wrong_right_example_pair_present():
        """D-03 — explicit WRONG vs RIGHT example pair shown by contrast."""
        assert "REJETÉ — placeholder sans tool_use préalable" in CITATION_GRAMMAR_FRAGMENT
        assert "ACCEPTÉ — tool_use puis citation du résultat" in CITATION_GRAMMAR_FRAGMENT


    # ---------------------------------------------------------------------------
    # _enforce_tool_use_for_citations pure-function gate (4 tests)
    # ---------------------------------------------------------------------------

    def test_gate_rejects_placeholder_without_tool_use():
        result = _enforce_tool_use_for_citations(
            answer_text="foo {{cite:tool_budget_snapshot}}",
            tool_calls=[],
        )
        assert result.verdict == ToolUseEnforcementVerdict.REJECTED
        assert result.structured_reason == "tool_use_missing_for_citation:budget_snapshot"
        assert result.missing_placeholder_names == ["budget_snapshot"]
        assert result.narrator_tool_count == 0

    def test_gate_passes_when_tool_use_present():
        result = _enforce_tool_use_for_citations(
            answer_text="foo {{cite:tool_budget_snapshot}}",
            tool_calls=[{"name": "get_budget_status", "input": {}}],
        )
        assert result.verdict == ToolUseEnforcementVerdict.PASS
        assert result.missing_placeholder_names == []
        assert result.structured_reason is None
        assert result.narrator_tool_count == 1

    def test_partial_case_rejects_naming_missing():
        """D-04 Claude's Discretion §4 — PARTIAL case."""
        result = _enforce_tool_use_for_citations(
            answer_text=(
                "surplus 1234 CHF {{cite:tool_budget_snapshot}} "
                "et projection {{cite:tool_retirement_projection}}"
            ),
            tool_calls=[{"name": "get_budget_status"}],
        )
        assert result.verdict == ToolUseEnforcementVerdict.REJECTED
        # Only the missing one is named; the matched one is absent from missing_placeholder_names.
        assert "retirement_projection" in result.missing_placeholder_names
        assert "budget_snapshot" not in result.missing_placeholder_names
        assert result.structured_reason == "tool_use_missing_for_citation:retirement_projection"

    def test_non_tool_placeholder_is_ignored():
        """Only tool_* placeholders are gated; non-tool keys (regulatory) PASS."""
        result = _enforce_tool_use_for_citations(
            answer_text="le plafond est X {{cite:r3a_plafond_salarie_2026}}",
            tool_calls=[],
        )
        assert result.verdict == ToolUseEnforcementVerdict.PASS


    # ---------------------------------------------------------------------------
    # End-to-end retry path (2 tests) — mocked _run_agent_loop
    # ---------------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_retry_restores_correct_behavior(monkeypatch):
        """D-04 — re-prompt with MANDATE inlined → narrator emits tool_use on retry."""
        from app.api.v1.endpoints import coach_chat as endpoint

        responses = iter([
            # 1st call: placeholder without tool_use
            {"answer": "rente {{cite:tool_retirement_projection}}", "tool_calls": [], "citation_chips": [],
             "sources": [], "disclaimers": [], "tokens_used": 50, "degraded": False, "model_used": "test"},
            # 2nd call: tool_use + placeholder
            {"answer": "rente 24960 CHF {{cite:tool_retirement_projection}}",
             "tool_calls": [{"name": "get_retirement_projection", "input": {}}],
             "citation_chips": [{"toolName": "retirement_projection", "inputsHash": "abc123"}],
             "sources": [], "disclaimers": [], "tokens_used": 50, "degraded": False, "model_used": "test"},
        ])

        async def fake_agent_loop(*args, **kwargs):
            return next(responses)

        # ...full setup: TestClient, auth fixture, mock _citation_gate to PASS the second call...
        # (See test_breadcrumb_contract.py for the FastAPI TestClient + override-deps pattern)
        # ASSERT:
        # - final response contains no bare {{cite:tool_*}} placeholders
        # - final response has tool_calls with get_retirement_projection
        # - assert sentry breadcrumb category="coach.citation.tool_use_missing" fired exactly once (on the 1st-call REJECT)
        # ...
        pytest.skip("Full FastAPI TestClient setup — adapt from test_breadcrumb_contract.py")

    @pytest.mark.asyncio
    async def test_two_retry_exhaustion_falls_through_to_fallback(monkeypatch):
        """D-04 — 2-retry exhaustion: placeholder stripped from text, no crash."""
        from app.api.v1.endpoints import coach_chat as endpoint

        # Both calls return placeholder-without-tool_use
        bad_response = {
            "answer": "rente {{cite:tool_retirement_projection}}", "tool_calls": [],
            "citation_chips": [], "sources": [], "disclaimers": [],
            "tokens_used": 50, "degraded": False, "model_used": "test"
        }

        async def fake_agent_loop(*args, **kwargs):
            return bad_response

        # ASSERT after handler call:
        # - response status == 200 (no crash, no 5xx)
        # - response body's "message" field has 0 occurrences of {{cite:tool_*}} (stripped per Wave A's 2nd-REJECT path)
        # - sentry breadcrumb category="coach.citation.tool_use_missing" fired exactly twice
        pytest.skip("Full FastAPI TestClient setup — adapt from test_breadcrumb_contract.py")
    ```

    Replace the two `pytest.skip()` calls with the FULL FastAPI TestClient setup pattern from `test_breadcrumb_contract.py`. The skip is a placeholder for the executor — they MUST implement the full path before marking the task done.

    **Diff cap** : target ≤200 lines of test code (the 7 non-skipped tests are short; the 2 retry-path tests are the heaviest, each ~50 lines including fixtures).
  </action>
  <acceptance_criteria>
    - File `services/backend/tests/test_coach_citation/test_tool_use_mandate.py` exists.
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_use_mandate.py -q` exits 0 with 9 passing tests, 0 skipped (no `pytest.skip` in final).
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0 with count ≥ 6907 passing (baseline 6898 + 9 new).
    - `python3 tools/checks/accent_lint_fr.py services/backend/tests/test_coach_citation/test_tool_use_mandate.py` exits 0 (FR substrings in tests are accent-clean).
    - The 4 verbatim CONTEXT D-05.4 fixtures (mandate present, gate rejects, retry restores, exhaustion fallback) are implemented (not skipped).
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_citation/test_tool_use_mandate.py -v 2>&1 | tail -15</automated>
  </verify>
  <done>
    9 tests pass, none skipped. Full backend suite passes. Accent lint exits 0.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task B.2 — Create test_narrator_emits_tool_use_for_intent.py (6 force-keyword fixtures, mock Anthropic)</name>
  <files>services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py</files>
  <read_first>
    - services/backend/app/services/llm/router.py (`_call_anthropic` — what to mock)
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py (mock pattern)
    - services/backend/app/api/v1/endpoints/coach_chat.py (`_run_agent_loop` — the call site)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-05.1 (verbatim spec: 6 force-keyword fixtures)
  </read_first>
  <behavior>
    6 parametrized fixtures, one per narrator-relevant tool:
    - "Quelle sera ma rente AVS à 65 ans ?" → tool_use:get_retirement_projection
    - "Combien il me reste à dépenser ce mois ?" → tool_use:get_budget_status
    - "Comment optimiser entre mon 3a, mon LPP et mes impôts ?" → tool_use:get_cross_pillar_analysis
    - "Mon plafond 3a annuel autorisé ?" → tool_use:get_cap_status
    - "À quel âge pourrais-je prendre l'AVS ?" → tool_use:get_avs_age_reference (OR get_retirement_projection — accept either)
    - "Comment optimiser fiscalement en couple ?" → tool_use:get_couple_optimization

    Each test mocks the Anthropic SDK call to return a canned `tool_use` block + `stop_reason==tool_use`. Assert (a) `stop_reason == "tool_use"`, (b) the emitted `tool_use.name` matches the expected canonical name, (c) `_enforce_tool_use_for_citations(response.message, response.toolCalls).verdict == PASS`.

    All 6 fixtures must exit 0 on `pytest tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py -q`.
  </behavior>
  <action>
    Create `services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py`. Use the FastAPI TestClient + Anthropic mock pattern from `test_breadcrumb_contract.py`.

    Skeleton:

    ```python
    """Wave 1c Plan B — narrator emits tool_use per force-keyword intent.

    CONTEXT D-05.1 — 6 force-keyword fixtures, mock Anthropic, assert
    stop_reason == "tool_use" + the correct tool name.
    """
    from __future__ import annotations
    import pytest
    from unittest.mock import patch, AsyncMock, MagicMock

    FORCE_KEYWORD_FIXTURES = [
        ("Quelle sera ma rente AVS à 65 ans ?", "get_retirement_projection"),
        ("Combien il me reste à dépenser ce mois ?", "get_budget_status"),
        ("Comment optimiser entre mon 3a, mon LPP et mes impôts ?", "get_cross_pillar_analysis"),
        ("Mon plafond 3a annuel autorisé ?", "get_cap_status"),
        ("À quel âge pourrais-je prendre l'AVS ?", "get_retirement_projection"),  # canonical fallback
        ("Comment optimiser fiscalement en couple ?", "get_couple_optimization"),
    ]

    @pytest.mark.parametrize("user_message,expected_tool_name", FORCE_KEYWORD_FIXTURES)
    def test_narrator_emits_tool_use_for_intent(user_message, expected_tool_name, ...):
        # Mock Anthropic SDK at services/backend/app/services/llm/router.py:_call_anthropic
        # to return: { stop_reason: "tool_use", content: [{type: "tool_use", name: expected_tool_name, input: {}}] }
        # ...
        # Call POST /api/v1/coach/chat with user_message + auth + seeded budget
        # ...
        # Assert: response.toolCalls has at least one element with name == expected_tool_name
        # Assert: stop_reason in the trace == "tool_use"
        # Assert: _enforce_tool_use_for_citations(response.message, response.toolCalls).verdict == PASS
        pass
    ```

    Implement the full body using the conftest patterns from `tests/test_coach_citation/conftest.py` (FastAPI client + auth fixture + Anthropic-SDK monkeypatch).

    **Diff cap** : ≤150 lines.
  </action>
  <acceptance_criteria>
    - File `services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py` exists.
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py -v` exits 0 with 6 passing.
    - The 6 force-keyword fixtures cover the 6 narrator-relevant tools listed in `_PLACEHOLDER_TO_TOOL_NAME` (verify mechanically: assert set of expected_tool_name in fixtures == set of values in `_PLACEHOLDER_TO_TOOL_NAME` minus the special-case `retrieve_memories`).
    - Backend suite exit 0 on full run.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py -v 2>&1 | tail -10</automated>
  </verify>
  <done>
    6 tests pass. Full backend suite exits 0.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task B.3 — Create test_g2_archetype_matrix.py (8 archetypes × 6 tools) + test_compile_yields_chip_emitter.py (bundle compiler)</name>
  <files>services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py, services/backend/tests/bundles/test_compile_yields_chip_emitter.py</files>
  <read_first>
    - services/backend/tests/conftest.py (archetype fixture rig used by Wave 1a parity tests)
    - services/backend/tests/bundles/ (existing bundle compiler tests — match style)
    - services/backend/app/services/coach/bundle_compiler.py (`compile_bundles` signature)
    - services/backend/app/services/coach/bundles/life_event_router.py (`LifeEventRouterBundle.allowed_tools`)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-05.2 + D-05.3
  </read_first>
  <behavior>
    Two test files in this task:

    **A) test_g2_archetype_matrix.py** — 48-case parametrized test (8 archetypes × 6 tools). For each (archetype, tool_name) pair: build a profile with the archetype, send a force-keyword message that should trigger that tool, mock Anthropic to return the expected tool_use, assert:
    - `_enforce_tool_use_for_citations(response.message, response.toolCalls).verdict == PASS`
    - The emitted tool name matches `_PLACEHOLDER_TO_TOOL_NAME[<short>]`.
    - The chip in `response.citationChips` has `toolName == <short>`.

    **B) test_compile_yields_chip_emitter.py** — 3-message parametrized test. For each of (`budget_message`, `retirement_message`, `cross_pillar_message`): call `compile_bundles(intents=[<inferred>])` and assert `len(allowed_tools ∩ CHIP_EMITTERS) >= 1`.
  </behavior>
  <action>
    File A: `services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py`. Use `pytest.mark.parametrize` with the cross product of `ARCHETYPES = ["swiss_native", "expat_eu", "expat_us", "cross_border", "independent_no_lpp", "retiree", "young_professional", "expat_high_income"]` × `TOOLS = list(_PLACEHOLDER_TO_TOOL_NAME.values())`. Reuse the Wave 1a archetype fixture rig (`archetype_fixture(name)` in conftest.py — if it doesn't exist by that exact name, find the equivalent and reuse it; do not duplicate).

    Skeleton:
    ```python
    """Wave 1c Plan B — 8-archetype × 6-tool matrix.

    CONTEXT D-05.3 — assert each archetype reaches the chip-emit code path
    for each narrator-relevant tool, with the Wave 1c tool_use gate PASSING
    at every cell of the matrix.
    """
    import pytest
    from app.api.v1.endpoints.coach_chat import (
        _PLACEHOLDER_TO_TOOL_NAME,
        _enforce_tool_use_for_citations,
        ToolUseEnforcementVerdict,
    )

    ARCHETYPES = [
        "swiss_native", "expat_eu", "expat_us", "cross_border",
        "independent_no_lpp", "retiree", "young_professional", "expat_high_income",
    ]
    TOOLS = list(_PLACEHOLDER_TO_TOOL_NAME.values())

    @pytest.mark.parametrize("archetype", ARCHETYPES)
    @pytest.mark.parametrize("tool_name", TOOLS)
    def test_archetype_tool_pair_passes_tool_use_gate(archetype, tool_name, ...):
        # Build profile with archetype (reuse Wave 1a fixture)
        # Send force-keyword message for tool_name
        # Mock Anthropic to return tool_use:{tool_name}
        # Assert: _enforce_tool_use_for_citations(message, toolCalls).verdict == PASS
        # Assert: chip in citationChips has toolName matching the registry short-name
        pass
    ```

    File B: `services/backend/tests/bundles/test_compile_yields_chip_emitter.py`. Parametrize 3 messages, classify intent, call `compile_bundles`, assert intersection with CHIP_EMITTERS is non-empty.

    Skeleton:
    ```python
    """Wave 1c Plan B — bundle compiler returns at least one chip emitter.

    CONTEXT D-05.2 — assert compile_bundles(intents).allowed_tools ∩ CHIP_EMITTERS
    is non-empty for each of 3 archetypal user messages.
    """
    import pytest
    from app.services.coach.bundle_compiler import compile_bundles
    from app.api.v1.endpoints.coach_chat import _classify_user_intent

    CHIP_EMITTERS = {
        "get_budget_status", "get_retirement_projection", "get_cross_pillar_analysis",
        "get_couple_optimization", "get_cap_status", "retrieve_memories",
    }

    MESSAGES = [
        "Quelle sera ma rente AVS à 65 ans avec mon 3eme pilier actuel ?",
        "Combien il me reste à dépenser ce mois ?",
        "Comment optimiser entre 3a et LPP cette année ?",
    ]

    @pytest.mark.parametrize("message", MESSAGES)
    def test_compile_yields_chip_emitter(message):
        intents = _classify_user_intent(message)  # exact import path may differ — find via grep
        compiled = compile_bundles(intents)
        allowed = set(compiled.allowed_tools)
        intersection = allowed & CHIP_EMITTERS
        assert len(intersection) >= 1, (
            f"compile_bundles({intents}) returned allowed_tools {allowed} "
            f"which has empty intersection with CHIP_EMITTERS {CHIP_EMITTERS}. "
            f"This is the precondition the smoking-gun bisect chased — see HANDOFF.md."
        )
    ```

    Implement the full bodies. **Diff cap** : ≤120 lines for File A, ≤60 lines for File B.
  </action>
  <acceptance_criteria>
    - File `services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py` exists.
    - File `services/backend/tests/bundles/test_compile_yields_chip_emitter.py` exists.
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_g2_archetype_matrix.py tests/bundles/test_compile_yields_chip_emitter.py -v` exits 0 with 48 + 3 = 51 passing tests.
    - Full backend suite exits 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_citation/test_g2_archetype_matrix.py tests/bundles/test_compile_yields_chip_emitter.py -v 2>&1 | tail -15</automated>
  </verify>
  <done>
    51 tests pass (48 archetype-matrix + 3 bundle-compiler). Backend full suite exits 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task B.4 — Create coach_tool_dispatch_all_6_smoke.yaml Maestro flow (all 6 tool chips)</name>
  <files>tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml</files>
  <read_first>
    - tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml (existing wave-1b flow — verify the chip widget ID pattern + auth flow)
    - tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml (Phase 94 reference)
    - tools/simulator/flows/auth/login.yaml (the runFlow precondition)
    - apps/mobile/lib/widgets/coach/ — grep for the chip widget Key pattern (e.g., `Key('ToolCallCitationChip:get_retirement_projection')`)
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md §D-05.5 (verbatim spec)
    - Engram memory `feedback_maestro_for_sim_tests` + `reference_maestro_setup`
  </read_first>
  <behavior>
    Maestro flow that, against staging backend on iPhone-17-Pro sim:
    1. Auth in (runFlow: auth/login.yaml).
    2. Seed a budget + profile that triggers all 6 narrator-relevant tools.
    3. Send a single multi-intent message: « Quelle sera ma rente AVS à 65 ans avec mon 3eme pilier actuel ? Combien il me reste à dépenser ce mois ? Comment optimiser entre 3a, LPP et impôts en couple ? »
    4. extendedWaitUntil the first chip appears (timeout: 30000).
    5. assertVisible on ALL 6 chip widgets by their Key('ToolCallCitationChip:<canonical_tool_name>') OR the closest matching pattern in apps/mobile/lib/widgets/coach/.
    6. takeScreenshot (for the verification report).

    Flow PASSes on `~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml`.
  </behavior>
  <action>
    **Step 0 (BLOCKING — run BEFORE writing the YAML)** — Resolve the actual widget Key values via grep. Do NOT proceed to YAML authorship with hardcoded guesses.

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT.nosync
    grep -rn "Key.*ToolCallCitationChip\|Key.*CoachChatInput\|Key.*CoachChatSendButton\|Key.*ChatTabButton" apps/mobile/lib/widgets/coach/ apps/mobile/lib/screens/ | tee /tmp/wave1c_b4_keys.txt
    ```

    Inspect `/tmp/wave1c_b4_keys.txt`. For EACH of the 4 widget-key identifiers (`ChatTabButton`, `CoachChatInput`, `CoachChatSendButton`, `ToolCallCitationChip`):
    - If the identifier appears verbatim in the grep output → use that exact key in the YAML.
    - If the identifier is NOT present verbatim → run a wider grep to find the actual key:
      ```bash
      # Examples of follow-up greps when an expected key is absent:
      grep -rn "chatTabButton\|ChatTab\|chat_tab" apps/mobile/lib/widgets/ apps/mobile/lib/screens/ | tee -a /tmp/wave1c_b4_keys.txt
      grep -rn "ValueKey.*'coach\|ValueKey.*"coach" apps/mobile/lib/widgets/coach/ | tee -a /tmp/wave1c_b4_keys.txt
      grep -rn "Key.*'chip\|Key.*"chip" apps/mobile/lib/widgets/coach/ | tee -a /tmp/wave1c_b4_keys.txt
      ```
      Record the discovered key + its `file:line` in `/tmp/wave1c_b4_keys.txt`.
    - When the YAML is written, document the discovered key inline in a comment line in the YAML header: `# Widget key for <expected_identifier> verified at <file:line> as <actual_key_value>`.

    The YAML's `assertVisible: { id: "..." }` values MUST match the verbatim keys recorded in `/tmp/wave1c_b4_keys.txt`. If the grep finds no matching key for one of the 4 identifiers, the executor MUST search apps/mobile/lib/ widely before resorting to a hardcoded guess; if no key exists at all, surface the gap as a deviation note in the task output AND mark the YAML assertion `# DEFERRED — no Flutter Key for <identifier> found at plan-execute time; add Key in a follow-up Flutter PR and re-enable this assertion`.

    **Step 1 (write the YAML)** — Create `tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml`. Match the style of `wave_1b_citation_chip_smoke.yaml` exactly.

    YAML skeleton (adjust `Key('...')` ids based on the actual chip widget keys in `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart`):

    ```yaml
    appId: ch.mint.app
    name: coach_tool_dispatch_all_6_smoke
    env:
      STAGING_URL: https://mint-staging.up.railway.app
    tags:
      - wave-1c
      - regression
      - tool-dispatch
    ---
    # Wave 1c CONTEXT D-05.5 — assert chips for ALL 6 narrator tools
    # render after a multi-intent prompt. Precondition: runFlow auth/login.yaml.
    # The user message intentionally covers 3 distinct intent clusters
    # (retirement + budget + cross-pillar-couple) to maximize narrator
    # dispatch coverage.

    - runFlow: auth/login.yaml

    - tapOn: { id: "ChatTabButton" }   # or whatever the entry-point key is
    - extendedWaitUntil:
        visible: { id: "CoachChatInput" }
        timeout: 10000

    - tapOn: { id: "CoachChatInput" }
    - inputText: "Quelle sera ma rente AVS à 65 ans avec mon 3eme pilier actuel ? Combien il me reste à dépenser ce mois ? Comment optimiser entre 3a, LPP et impôts en couple ?"
    - tapOn: { id: "CoachChatSendButton" }

    # First chip appears within 30s (narrator + tool_use round-trip on staging)
    - extendedWaitUntil:
        visible: { id: "ToolCallCitationChip:retirement_projection" }
        timeout: 30000

    # All 6 narrator tools must have a chip rendered
    - assertVisible: { id: "ToolCallCitationChip:retirement_projection" }
    - assertVisible: { id: "ToolCallCitationChip:budget_snapshot" }
    - assertVisible: { id: "ToolCallCitationChip:cross_pillar_analysis" }
    - assertVisible: { id: "ToolCallCitationChip:cap_status" }
    - assertVisible: { id: "ToolCallCitationChip:couple_optimization" }
    # The 6th (retrieve_memories) is conditionally rendered only on referenced
    # past discussions; for this smoke we accept either retrieve_memories OR
    # one additional regulatory chip ; document the exception inline:
    # - assertVisible: { id: "ToolCallCitationChip:retrieve_memories" }

    - takeScreenshot: wave-1c-tool-dispatch-all-6-PASS
    ```

    **Note — chip key naming subtlety** : the actual widget key may be `'ToolCallCitationChip:retirement_projection'` (registry short-name) or `'ToolCallCitationChip:get_retirement_projection'` (canonical tool name). The blocking grep at Step 0 above resolves the ambiguity mechanically — do NOT rely on this paragraph alone. If Step 0 found the registry short-name (which matches the Wave 1b wiring at `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart`), keep the short-name in the YAML.

    **6th chip exception** : `retrieve_memories` only fires when the user references a past discussion. For this smoke test, do NOT assert its chip — instead, assert that a 5th non-tool_* chip (regulatory, e.g. `r3a_plafond_salarie_2026`) is also visible, or simply document the 5-chip floor in the YAML header. Mark the 6th chip assertion as "see commented line — conditionally rendered".

    Validate the YAML locally:
    ```bash
    # Syntax validation only (no sim run yet):
    python3 -c "import yaml; yaml.safe_load(open('tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml'))"
    ```

    Local run against booted sim (if Julien has the iPhone-17-Pro sim booted with the staging build installed, OR if Claude can build + install per the standard MINT walker.sh pattern):
    ```bash
    # Mitigate sim crash recurrence per memory feedback_sim_crash_mitigation
    xcrun simctl shutdown booted 2>/dev/null
    xcrun simctl boot "iPhone 17 Pro"
    sleep 5
    ~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml
    ```

    If the local run FAILs, diagnose:
    - sim crash → reboot + retry (per memory feedback_sim_crash_mitigation)
    - chip key mismatch → grep apps/mobile/lib/widgets/coach/ for the actual Key
    - tool not dispatched → re-verify the Wave A fix is on staging (rerun the live probe)
    - sim auth flow broken → fix auth/login.yaml or seed via API
  </action>
  <acceptance_criteria>
    - File `tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` exists.
    - YAML is syntactically valid (`python3 -c "import yaml; yaml.safe_load(open('...'))"` exits 0).
    - `/tmp/wave1c_b4_keys.txt` exists AND contains evidence for each of the 4 widget keys (`ChatTabButton`, `CoachChatInput`, `CoachChatSendButton`, `ToolCallCitationChip`) — EITHER the identifier appears verbatim in the grep output (with `file:line`), OR the YAML header comment cites a different actual key value with `file:line` discovered via follow-up grep, OR the YAML carries a `# DEFERRED — no Flutter Key for <id>` marker for that identifier (with a deviation note in the task output explaining why no Key exists).
    - The flow asserts at least 5 of the 6 narrator-relevant tool chips (retrieve_memories conditionally exempt and documented inline).
    - The flow uses `runFlow: auth/login.yaml` as precondition.
    - The flow uses `extendedWaitUntil` (NOT bare `timeout` — per memory `feedback_pre_push_checklist` and the wave_1b_citation_chip_smoke.yaml fix history).
    - Local maestro run against booted iPhone-17-Pro sim with staging build PASSes (cite the maestro stdout `Flow Passed` line in task output) — OR document the blocker (sim not booted, build not installed) and defer the sim run to Julien's G2.
  </acceptance_criteria>
  <verify>
    <automated>python3 -c "import yaml; yaml.safe_load(open('/Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml'))" && grep -cE "assertVisible|extendedWaitUntil" /Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml</automated>
  </verify>
  <done>
    Flow YAML exists, is syntactically valid, asserts ≥5 chip widgets, uses extendedWaitUntil + runFlow auth precondition. Local maestro run PASSes OR blocker documented for G2 deferral.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task B.5 — Pre-push checklist + PR open + merge on green</name>
  <files></files>
  <read_first>
    - CLAUDE.md §9 (0-trust)
    - Engram memory `feedback_pre_push_checklist`
    - Engram memory `feedback_public_repo_discipline`
    - The 4 test files + 1 Maestro flow from B.1-B.4
  </read_first>
  <behavior>
    - Pre-push sanity passes: full pytest, banned-terms, accent-lint, YAML valid.
    - PR opened on `feature/wave-1c-regression-tests` → dev.
    - CI green; PR merged with squash.
  </behavior>
  <action>
    1. **Create the test branch** (assumes B.1-B.4 were committed on a freshly cut branch from origin/dev post-Wave-A merge):
       ```bash
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       git fetch origin
       git checkout -b feature/wave-1c-regression-tests origin/dev   # if not already on the branch
       # ...stage + commit the 5 files from B.1-B.4 in atomic commits:
       git add services/backend/tests/test_coach_citation/test_tool_use_mandate.py
       git commit -m "test(wave-1c): add test_tool_use_mandate.py (9 cases)"
       git add services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py
       git commit -m "test(wave-1c): add narrator-emits-tool-use force-keyword fixtures"
       git add services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py services/backend/tests/bundles/test_compile_yields_chip_emitter.py
       git commit -m "test(wave-1c): add 8-archetype matrix + bundle-compiler chip-emitter test"
       git add tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml
       git commit -m "test(wave-1c): add Maestro flow asserting all 6 tool-dispatch chips"
       ```

    2. **Pre-push checklist** (run all from project root):
       ```bash
       cd services/backend && python3 -m pytest tests/ -q | tail -5  # full backend suite exits 0
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       python3 tools/checks/banned_terms_python.py services/backend/tests/test_coach_citation/test_tool_use_mandate.py services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py services/backend/tests/bundles/test_compile_yields_chip_emitter.py
       python3 tools/checks/accent_lint_fr.py services/backend/tests/test_coach_citation/test_tool_use_mandate.py services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py services/backend/tests/bundles/test_compile_yields_chip_emitter.py
       python3 -c "import yaml; yaml.safe_load(open('tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml'))"
       ```
       All 4 commands MUST exit 0 before push.

    3. **Push + open PR** (public-repo discipline language):
       ```bash
       git push -u origin feature/wave-1c-regression-tests
       gh pr create --base dev --head feature/wave-1c-regression-tests \
         --title "test(wave-1c): regression test floor — tool_use mandate + 8-archetype matrix + Maestro" \
         --body "$(cat <<'EOF'
       ## What

       Regression test floor for the Wave 1c tool_use mandate fix (Wave A merged in #<wave-A-PR-num>).

       5 artifacts per CONTEXT D-05:
       1. `tests/test_coach_citation/test_tool_use_mandate.py` — 9 unit tests covering grammar substring order, _enforce_tool_use_for_citations pure-function gate, retry path, 2-retry exhaustion fallback.
       2. `tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py` — 6 force-keyword fixtures × mock Anthropic.
       3. `tests/test_coach_citation/test_g2_archetype_matrix.py` — 8 archetypes × 6 tools parametrized matrix.
       4. `tests/bundles/test_compile_yields_chip_emitter.py` — 3 messages × compile_bundles intersection assertion.
       5. `tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` — Maestro flow asserting ≥5 of 6 tool chips render after a multi-intent prompt on staging.

       ## Why now

       Wave A is merged + a live staging probe confirms `tool_use` emission (see chat history of session 2026-05-16). This PR is the safety net.

       ## Mechanical gates (pre-push)

       - Full backend pytest exits 0 with ≥6957 passing (baseline 6898 + 51 archetype-matrix + 3 bundle-compiler + 6 force-keyword + 9 tool-use-mandate = baseline + 69).
       - LSFin banned-terms + accent lint exit 0 on all 4 test files.
       - Maestro YAML syntax-valid.

       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
       EOF
       )"
       ```

    4. **Monitor CI inline** (no scheduled wakeup per memory `feedback_no_wakeup_active_polling`):
       ```bash
       PR_NUM=$(gh pr list --head feature/wave-1c-regression-tests --json number --jq '.[0].number')
       until ! gh pr checks $PR_NUM 2>&1 | grep -q pending; do sleep 30; done
       gh pr checks $PR_NUM
       ```

    5. **Merge on green** (squash, delete branch):
       ```bash
       gh pr merge $PR_NUM --squash --delete-branch
       MERGE_SHA=$(gh pr view $PR_NUM --json mergeCommit --jq '.mergeCommit.oid')
       ```

    6. **Open dev→staging bundle PR** (Wave C precondition is « Wave B merged + Julien G2 sim screenshot »):
       ```bash
       gh pr create --base staging --head dev \
         --title "ship: dev → staging — wave-1c regression test floor" \
         --body "Bundles Wave B regression tests (PR #$PR_NUM) into staging. After this merges + Railway redeploys, Julien runs the Maestro flow on his iPhone-17-Pro sim to capture the G2 evidence that unblocks Wave C (instrumentation teardown).
       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
       ```
  </action>
  <acceptance_criteria>
    - PR opened on `feature/wave-1c-regression-tests` → `dev`, state OPEN at creation.
    - `gh pr checks <N>` shows ALL jobs pass.
    - PR merged with squash, branch deleted.
    - dev→staging bundle PR opened.
    - `git log --oneline origin/dev | head -5` shows the squash commit with title prefix `test(wave-1c)`.
  </acceptance_criteria>
  <verify>
    <automated>gh pr list --state merged --search 'test(wave-1c) base:dev' --json number,mergedAt --jq '.[0]' 2>&1 | head -5</automated>
  </verify>
  <done>
    Wave B PR merged to dev with non-null mergedAt. dev→staging bundle PR opened. No --no-verify, no force-push.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task B.6 — Engram mem_save: Wave B close-out finding</name>
  <files></files>
  <read_first>
    - Task B.5 output (PR number, merge sha, dev→staging PR url)
    - Wave A's engram observation (topic_key coach:citation:tool_use_mandate:wave_a:shipped)
    - The Task B.0 live probe evidence
  </read_first>
  <behavior>
    - 1 successful `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_b:regression_floor_landed` + `prior_finding_refs` to Wave A's topic_key + obs ids 65, 66, 69, 74, 75.
  </behavior>
  <action>
    Invoke `mem_save` ONCE:
    - `topic_key`: `coach:citation:tool_use_mandate:wave_b:regression_floor_landed`
    - `observation_type`: `discovery`
    - `prior_finding_refs`: [`coach:citation:tool_use_mandate:wave_a:shipped`, `65`, `66`, `69`, `74`, `75`]
    - `content`: « Wave 1c Wave B regression test floor merged to dev (PR #<N>, squash sha <sha>). 5 artifacts: 4 pytest files (test_tool_use_mandate.py, test_narrator_emits_tool_use_for_intent.py, test_g2_archetype_matrix.py, test_compile_yields_chip_emitter.py) + 1 Maestro YAML (coach_tool_dispatch_all_6_smoke.yaml). Backend pytest count grew from baseline 6898 to <new_count>. The 4 mandatory CONTEXT D-05.4 fixtures (mandate present, gate rejects, retry restores, exhaustion fallback) are implemented and pass. The Maestro flow on iPhone-17-Pro sim against staging shows <n>/6 chips PASS (where n is documented in the PR body if <6). dev→staging bundle PR opened. Wave C (instrumentation teardown) precondition: Wave B's dev→staging merged + Julien G2 sim screenshot cited. 0-trust caveat per CLAUDE.md §9.5: Wave B PR merged ≠ feature works on production — only the live probe evidence + Maestro PASS demonstrate the user-visible flow. »

    Handle `judgment_required` per the conflict-surfacing rule.
  </action>
  <acceptance_criteria>
    - 1 `mem_save` call with the exact `topic_key`.
    - `prior_finding_refs` includes Wave A's topic_key + the 5 obs ids.
  </acceptance_criteria>
  <verify>
    <automated>echo "mem_save verification is via tool response envelope"</automated>
  </verify>
  <done>
    Engram observation saved.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test fixtures → backend behavior | Tests assert the gate's structural behaviour; do not test against real Anthropic API (cost + flakiness). |
| Maestro flow → staging backend | Read-only probes; the test users created by the flow are flagged with `claude-wave1c-` prefix for cleanup in Wave C. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wave-1c-B-01 | Tampering | test_tool_use_mandate.py assertions are brittle if `_PLACEHOLDER_TO_TOOL_NAME` changes | accept | When a new tool_* key lands in CITATION_REGISTRY, the test maintenance burden is a single dict update; the matrix test is the canary. |
| T-wave-1c-B-02 | Denial of service | full 51-case archetype matrix may slow CI | accept | Parametrized tests share fixtures; estimated ~10s added to backend CI time. Acceptable. |
| T-wave-1c-B-03 | Information disclosure | Maestro test users (`claude-wave1c-bisect-*@example.com`) remain on staging DB | mitigate | Wave C teardown deletes them. Maestro YAML uses unique-suffix emails so cleanup is grep-clean. |
| T-wave-1c-B-04 | Spoofing | Maestro flow could PASS against a stub backend | accept | Flow runs against `mint-staging.up.railway.app` (env var STAGING_URL pins the prod backend); local stub bypass requires explicit user action. |
</threat_model>

<verification>
- G1 (Maestro/sim) — `~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` exits 0 against staging build on iPhone-17-Pro. Cite the « Flow Passed » line.
- G2 (Julien) — DEFERRED to Wave C precondition.
- G3 (dev CI green) — `gh pr checks <N>` ALL pass.
- G4 (regression suite) — full pytest exits 0 with count = baseline + 69.
- G5 (LSFin + accent lint) — both lints exit 0 on all 4 test files.
</verification>

<success_criteria>
- B.0 checkpoint resolved (live probe evidence cited).
- 5 artifacts created + tests pass (9 + 6 + 51 + Maestro flow valid).
- Wave B PR merged to dev with non-null mergedAt.
- 1 engram `mem_save` persisted with topic_key `coach:citation:tool_use_mandate:wave_b:regression_floor_landed`.
</success_criteria>

<output>
After Wave B completes, this PLAN.md's status is « MERGED TO DEV — AWAITING G2 SIM ». Wave C's preconditions reference Julien's G2 screenshot.
</output>
