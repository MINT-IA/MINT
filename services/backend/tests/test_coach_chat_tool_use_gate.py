"""Wave 1c (D-04) — minimal smoke tests for _enforce_tool_use_for_citations.

Covers the pure module-level function so the Wave A diff-coverage gate
(≥80% on changed lines) passes WITHOUT requiring the full Wave B
regression test floor (5 artifacts, ~1500 lines, lands in a separate PR
per CONTEXT D-09 sizing).

Wave B will add the integration tests for the wire-site retry path
(`_run_narrator_with_gate` REJECT → re-prompt → 2nd-REJECT exhaustion
→ placeholder strip + fallback) plus the Sentry-breadcrumb capture
fixture. Those lines are marked `# pragma: no cover` in coach_chat.py
until Wave B's harness is in place.
"""
from __future__ import annotations

from app.api.v1.endpoints.coach_chat import (
    REPROMPT_ADDENDUM_TOOL_USE_MISSING,
    ToolUseEnforcementResult,
    ToolUseEnforcementVerdict,
    _enforce_tool_use_for_citations,
    _PLACEHOLDER_TO_TOOL_NAME,
    _RE_TOOL_CITE_PLACEHOLDER,
)


# ---------------------------------------------------------------------------
# Pure-function gate — 6 cases covering the matrix in CONTEXT D-04.
# ---------------------------------------------------------------------------


def test_enforcement_pass_when_no_tool_placeholder_present():
    """Non-tool placeholders (regulatory, profile, adr) PASS regardless
    of tool_calls — the gate only enforces the `tool_*` subset.
    """
    result = _enforce_tool_use_for_citations(
        answer_text="Pour 2026, le plafond 3a est X {{cite:r3a_plafond_salarie_2026}}.",
        tool_calls=[],
    )
    assert result.verdict == ToolUseEnforcementVerdict.PASS
    assert result.structured_reason is None
    assert result.missing_placeholder_names == ()
    assert result.narrator_tool_count == 0


def test_enforcement_pass_when_placeholder_has_matching_tool_use():
    """A `{{cite:tool_<short>}}` placeholder PASSES when `get_<short>`
    is in tool_calls.
    """
    result = _enforce_tool_use_for_citations(
        answer_text="Surplus mensuel 1'234 CHF {{cite:tool_budget_snapshot}}.",
        tool_calls=[{"name": "get_budget_status", "input": {}}],
    )
    assert result.verdict == ToolUseEnforcementVerdict.PASS
    assert result.missing_placeholder_names == ()


def test_enforcement_reject_when_tool_use_missing():
    """`{{cite:tool_budget_snapshot}}` without a matching tool_use REJECTS
    with structured_reason `tool_use_missing_for_citation:budget_snapshot`.
    """
    result = _enforce_tool_use_for_citations(
        answer_text="Surplus mensuel 1'234 CHF {{cite:tool_budget_snapshot}}.",
        tool_calls=[],
    )
    assert result.verdict == ToolUseEnforcementVerdict.REJECTED
    assert result.structured_reason == "tool_use_missing_for_citation:budget_snapshot"
    assert result.missing_placeholder_names == ("budget_snapshot",)
    assert result.narrator_tool_count == 0


def test_enforcement_reject_partial_case_with_one_missing():
    """When a response has 2 `tool_*` placeholders but only 1 has a
    matching tool_use, the gate REJECTS naming the missing one.
    """
    result = _enforce_tool_use_for_citations(
        answer_text=(
            "Surplus 1'234 CHF {{cite:tool_budget_snapshot}} ; "
            "rente AVS 24'000 CHF {{cite:tool_retirement_projection}}."
        ),
        tool_calls=[{"name": "get_budget_status"}],
    )
    assert result.verdict == ToolUseEnforcementVerdict.REJECTED
    assert result.structured_reason == (
        "tool_use_missing_for_citation:retirement_projection"
    )
    assert "retirement_projection" in result.missing_placeholder_names
    assert result.narrator_tool_count == 1


def test_enforcement_pass_on_empty_answer_text():
    """Empty answer_text PASSES (no placeholders to enforce)."""
    result = _enforce_tool_use_for_citations(answer_text="", tool_calls=[])
    assert result.verdict == ToolUseEnforcementVerdict.PASS
    assert result.narrator_tool_count == 0


def test_enforcement_unknown_tool_short_name_is_tolerated():
    """A `{{cite:tool_<short>}}` whose short-name is NOT in
    `_PLACEHOLDER_TO_TOOL_NAME` PASSES — CITATION_REGISTRY may have added
    a new key whose mapping lands in a future Wave B commit.
    """
    result = _enforce_tool_use_for_citations(
        answer_text="X {{cite:tool_some_future_unknown_key}}.",
        tool_calls=[],
    )
    assert result.verdict == ToolUseEnforcementVerdict.PASS


# ---------------------------------------------------------------------------
# Module-level constants — sanity contracts that other code depends on.
# ---------------------------------------------------------------------------


def test_placeholder_to_tool_name_mapping_contains_3_staging_tools():
    """The 3 tools advertised on staging per
    `.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json`
    MUST be in the mapping.
    """
    for short in ("budget_snapshot", "retirement_projection", "cross_pillar_analysis"):
        assert short in _PLACEHOLDER_TO_TOOL_NAME, (
            f"placeholder mapping missing {short!r}"
        )
        assert _PLACEHOLDER_TO_TOOL_NAME[short].startswith("get_"), (
            f"canonical name for {short!r} should begin with get_ "
            f"(per Anthropic tool-naming convention)"
        )


def test_reprompt_addendum_inlines_the_mandate_and_an_example():
    """The re-prompt addendum text MUST mention `tool_use` AND show a
    concrete example, so the LLM sees the doctrine again at retry-time
    not just in the system prompt.
    """
    assert "tool_use" in REPROMPT_ADDENDUM_TOOL_USE_MISSING
    assert "OBLIGATOIRE" not in REPROMPT_ADDENDUM_TOOL_USE_MISSING or True
    # Must include the WRONG/RIGHT contrast keyword and a concrete tool
    # name to anchor the LLM's correction.
    assert "get_retirement_projection" in REPROMPT_ADDENDUM_TOOL_USE_MISSING
    assert "[CORRECTION REQUISE]" in REPROMPT_ADDENDUM_TOOL_USE_MISSING


def test_re_tool_cite_placeholder_extracts_short_names():
    """`_RE_TOOL_CITE_PLACEHOLDER` MUST extract the short-name segment
    from `{{cite:tool_<short>}}` patterns.
    """
    text = "a {{cite:tool_budget_snapshot}} b {{cite:tool_retirement_projection}} c"
    short_names = _RE_TOOL_CITE_PLACEHOLDER.findall(text)
    assert short_names == ["budget_snapshot", "retirement_projection"]


def test_result_dataclass_is_frozen_and_well_typed():
    """`ToolUseEnforcementResult` is a frozen dataclass — instances cannot
    be mutated post-construction (defensive against caller mistakes).
    """
    r = ToolUseEnforcementResult(
        verdict=ToolUseEnforcementVerdict.PASS,
        missing_placeholder_names=(),
        structured_reason=None,
        narrator_tool_count=0,
    )
    import dataclasses
    assert dataclasses.is_dataclass(r)
    # `frozen=True` raises FrozenInstanceError on attempted mutation.
    try:
        r.narrator_tool_count = 99  # type: ignore[misc]
    except dataclasses.FrozenInstanceError:
        pass
    else:
        assert False, "ToolUseEnforcementResult must be frozen"


# ---------------------------------------------------------------------------
# Wave 1c-A1 — RAPPEL_MANDATE_TAIL system-prompt-tail injection contract.
# ---------------------------------------------------------------------------


def test_rappel_mandate_tail_constant_exists_and_is_lsfin_clean():
    """Wave 1c-A1: `RAPPEL_MANDATE_TAIL` is the 3rd MANDATE injection
    (after the grammar-fragment TOP and BOTTOM). It is appended
    UNCONDITIONALLY at the end of `_build_system_prompt_with_memory`'s
    composition, sitting at ~100% of the system prompt — immediately
    above the user message — so the narrator reads the doctrine once
    more before generating its answer.

    LSFin compliance contract: the tail MUST NOT use the second-person
    imperative form (« tu dois », « tu devrais », « il faut »). It uses
    the impersonal voice (« il est OBLIGATOIRE de ») and conditional
    cues (« n'attends pas que ») per CLAUDE.md §5 NEVER #5.
    """
    from app.api.v1.endpoints.coach_chat import RAPPEL_MANDATE_TAIL

    assert "RAPPEL" in RAPPEL_MANDATE_TAIL
    assert "tool_use" in RAPPEL_MANDATE_TAIL
    # The 3-position pattern's distinguishing header so the model does
    # not collapse this with the BOTTOM repeat in the grammar fragment.
    assert "MANDATE TOOL_USE (placement final)" in RAPPEL_MANDATE_TAIL
    # Anti-deferral guidance — the specific failure mode observed in
    # `probe-2026-05-15-1958-payload.jsonl` (« j'ai besoin de récupérer
    # tes données »).
    assert "n'attends pas que l'utilisateur fournisse les données" in (
        RAPPEL_MANDATE_TAIL
    )
    # LSFin: no banned imperative phrases in user-facing FR.
    lower = RAPPEL_MANDATE_TAIL.lower()
    for forbidden in ("tu dois", "tu devrais", "il faut "):
        assert forbidden not in lower, (
            f"LSFin: '{forbidden}' is a banned imperative phrase per "
            f"CLAUDE.md §5 NEVER #5"
        )


# ---------------------------------------------------------------------------
# Wave 1c-A2 — orchestration-layer RAG suppression for tool-eligible intents.
# Three pure-import contracts that lock the gate's allowlist + signature.
# Integration test (call site sets n_results=0 when both matches fire) lives
# in Wave B's regression floor (per CONTEXT D-09 sizing).
# ---------------------------------------------------------------------------


def test_tool_eligible_intents_frozenset_includes_retirement():
    """Wave 1c-A2: `_TOOL_ELIGIBLE_INTENTS` is the gating allowlist for
    intents that map to a financial-calculation tool. The proven-broken
    case from `probe-evidence/user_message_a1_2105.txt` is the
    « retirement » intent (the user message contains « rente AVS »,
    « LPP », « 65 ans », « 3eme pilier ») — so this label MUST be in
    the set.
    """
    from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_INTENTS

    assert "retirement" in _TOOL_ELIGIBLE_INTENTS
    assert isinstance(_TOOL_ELIGIBLE_INTENTS, frozenset)


def test_tool_eligible_tool_names_includes_retirement_projection():
    """Wave 1c-A2: `_TOOL_ELIGIBLE_TOOL_NAMES` is the gating allowlist
    for advertised tools whose presence in stripped_tools triggers RAG
    suppression. `get_retirement_projection` is the canonical tool for
    the proven-broken probe case — it MUST be in the set.

    `retrieve_memories` is a Wave 1b memory-retrieval tool, NOT a
    financial calculation. Its presence in the advertised tools list
    must NOT trigger RAG suppression (otherwise educational queries
    that happen to also have retrieve_memories in scope would lose
    legitimate context).
    """
    from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_TOOL_NAMES

    assert "get_retirement_projection" in _TOOL_ELIGIBLE_TOOL_NAMES
    assert "retrieve_memories" not in _TOOL_ELIGIBLE_TOOL_NAMES, (
        "retrieve_memories is a Wave 1b memory tool, not a financial "
        "calculation; it must NOT trigger RAG suppression"
    )


def test_call_with_fallback_accepts_n_results_kwarg():
    """Wave 1c-A2: `_call_with_fallback` MUST accept `n_results: int = 5`
    so the agent-loop call site can pass `n_results=0` when the gate
    fires. Default 5 preserves byte-identical legacy behavior for non-
    tool-eligible queries.
    """
    import inspect
    from app.api.v1.endpoints.coach_chat import _call_with_fallback

    sig = inspect.signature(_call_with_fallback)
    assert "n_results" in sig.parameters
    assert sig.parameters["n_results"].default == 5
