"""Wave 1b Plan 03 — narrator grammar fragment."""

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


def test_grammar_fragment_lists_all_tool_keys():
    for key in WAVE_1B_TOOL_KEYS:
        assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT


def test_grammar_fragment_lists_all_24_registry_keys():
    # Wave 1b Plan 03 — registry baseline 18 (Phase 94.1) + 6 tool_call_id keys
    # = 24. Auto-derived from CITATION_REGISTRY.keys() at module-import time.
    assert len(CITATION_REGISTRY) == 24
    for key in CITATION_REGISTRY.keys():
        assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT


def test_intent_scoped_grammar_includes_tools():
    for intent in ("debt", "housing", "family", "career", "retirement", "taxes"):
        frag = build_intent_scoped_citation_grammar((intent,))
        for key in WAVE_1B_TOOL_KEYS:
            assert f"{{{{cite:{key}}}}}" in frag, f"intent={intent} missing key={key}"
