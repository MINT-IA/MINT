"""Phase mint-calc-engine-v1 Plan 07 Task 4 — ManualSubsetAdapter tests.

D-CE-01 BACKUP adapter — extends Wave 1c-A2's ``_TOOL_ELIGIBLE_INTENTS``
heritage to a per-intent tool-array filter. Cheapest of the 3 adapters,
least flexible. Used when both Anthropic Tool Search Tool AND skill-bundle
fallback are unavailable, OR when operators want explicit per-intent
allowlists for compliance audit.

Selection via ``TOOL_REGISTRY_ADAPTER=manual_subset`` env var.
"""
from __future__ import annotations

import pytest


@pytest.fixture
def adapter():
    from app.services.coach.tool_registry.manual_subset_adapter import (
        ManualSubsetAdapter,
    )

    return ManualSubsetAdapter()


def test_intent_retirement_includes_chip_emitters_and_retirement_calcs(adapter) -> None:
    """Plan acceptance Test 1 — ``user_intents=['retirement']`` returns the 5
    chip-emitters PLUS the registry entries served by ``retirement`` life event.
    """
    tools = adapter.register_tools({"user_intents": ["retirement"]})
    names = {t["name"] for t in tools}
    # 5 chip-emitters always included.
    assert {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }.issubset(names)
    # At least one retirement-domain calculator present (REGISTRY has 9
    # retirement-tagged entries per Plan 05).
    retirement_present = any(
        "avs_estimation" in n or "rachat_echelonne" in n or "retirement" in n.lower()
        for n in names
    )
    assert retirement_present


def test_empty_intents_returns_only_chip_emitters(adapter) -> None:
    """Plan acceptance Test 2 — ``user_intents=[]`` returns ONLY the 5
    chip-emitters (defaults / always-on baseline)."""
    tools = adapter.register_tools({"user_intents": []})
    names = {t["name"] for t in tools}
    assert names == {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }


def test_latency_tier_consistent_with_other_adapters(adapter) -> None:
    """Plan acceptance Test 3 — ``latency_tier`` is adapter-agnostic."""
    assert adapter.latency_tier("get_budget_status") == "L1"
    assert adapter.latency_tier("unknown_tool_xyz") == "L2"


def test_intent_housing_returns_housing_calcs(adapter) -> None:
    """Bonus regression : ``user_intents=['housing']`` returns at least
    one housing-tagged registry entry."""
    tools = adapter.register_tools({"user_intents": ["housing"]})
    names = {t["name"] for t in tools}
    housing_present = any(
        "affordability" in n or "epl" in n or "mortgage" in n or "amortization" in n
        for n in names
    )
    assert housing_present, f"Expected housing calc in {names}"
