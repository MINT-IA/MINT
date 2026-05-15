"""Wave 1b Plan 03 — narrator grammar fragment."""
import pytest

from app.services.coach.citation_grammar import (
    CITATION_GRAMMAR_FRAGMENT,
    build_intent_scoped_citation_grammar,
)
from app.services.coach.citation_registry import CITATION_REGISTRY

WAVE_1B_TOOL_KEYS = (
    "tool_budget_snapshot",
    "tool_retirement_projection",
    "tool_cross_pillar_analysis",
    "tool_couple_optimization",
    "tool_cap_status",
    "tool_retrieve_memories",
)


@pytest.mark.skip(reason="Wave 1b — grammar fragment text lands in Plan 03")
def test_grammar_fragment_lists_all_tool_keys():
    for key in WAVE_1B_TOOL_KEYS:
        assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT


@pytest.mark.skip(reason="Wave 1b — Plan 03 bumps the existing 18-key test to 24")
def test_grammar_fragment_lists_all_24_registry_keys():
    for key in CITATION_REGISTRY.keys():
        assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT


@pytest.mark.skip(reason="Wave 1b — intent-scoped grammar includes tool_* always-on (Plan 03)")
def test_intent_scoped_grammar_includes_tools():
    for intent in ("debt", "housing", "family", "career", "retirement", "taxes"):
        frag = build_intent_scoped_citation_grammar((intent,))
        for key in WAVE_1B_TOOL_KEYS:
            assert f"{{{{cite:{key}}}}}" in frag, f"intent={intent} missing key={key}"
