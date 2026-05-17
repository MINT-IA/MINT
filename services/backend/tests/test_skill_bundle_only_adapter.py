"""Phase mint-calc-engine-v1 Plan 07 Task 3 — SkillBundleOnlyAdapter tests.

D-CE-01 FALLBACK adapter — registers ALL calculators always-on, NO
``defer_loading``, NO Tool Search Tool. Accepts the context-bloat tradeoff
explicitly (Liu 2024 lost-in-the-middle risk acknowledged + documented). Used
when Anthropic deprecates the beta or MINT pivots to a provider without
Tool Search support (Bedrock).
"""
from __future__ import annotations

import pytest


@pytest.fixture
def adapter():
    from app.services.coach.tool_registry.skill_bundle_only_adapter import (
        SkillBundleOnlyAdapter,
    )

    return SkillBundleOnlyAdapter()


def test_register_tools_returns_all_calculators_always_on(adapter) -> None:
    """Plan acceptance Test 1 — all 5 chip-emitters + 63 REGISTRY entries
    surface as always-on tools (intents are IGNORED — fallback mode is
    blanket registration)."""
    tools = adapter.register_tools({"intents": ["retirement"]})
    names = {t.get("name") for t in tools if "name" in t}
    # 5 chip-emitters always present.
    assert {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }.issubset(names)
    # Long-tail must also be present (≥40 from REGISTRY).
    assert len(tools) >= 45  # 5 chip + ≥40 long-tail


def test_no_defer_loading_keys_present(adapter) -> None:
    """Plan acceptance Test 2 — fallback adapter explicitly does NOT set
    ``defer_loading`` (the beta header is not active on this adapter)."""
    tools = adapter.register_tools({})
    for tool in tools:
        assert "defer_loading" not in tool, (
            f"SkillBundleOnlyAdapter must not emit defer_loading ; found on "
            f"{tool.get('name')}"
        )


def test_no_tool_search_tool_entry(adapter) -> None:
    """Plan acceptance Test 3 — no ``tool_search_tool_bm25`` declaration in
    fallback mode (Anthropic-specific primitive)."""
    tools = adapter.register_tools({})
    types = {t.get("type") for t in tools}
    assert "tool_search_tool_bm25_20251119" not in types
    names = {t.get("name") for t in tools}
    assert "tool_search_tool_bm25" not in names


def test_latency_tier_consistent_with_anthropic_adapter(adapter) -> None:
    """Plan acceptance Test 4 — ``latency_tier`` is adapter-agnostic. L1 for
    chip-emitters, L2 default for unknown."""
    assert adapter.latency_tier("get_budget_status") == "L1"
    assert adapter.latency_tier("get_couple_optimization") == "L1"
    assert adapter.latency_tier("unknown_tool_xyz") == "L2"
