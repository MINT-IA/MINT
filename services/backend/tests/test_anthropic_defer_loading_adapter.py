"""Phase mint-calc-engine-v1 Plan 07 Task 2 — AnthropicDeferLoadingAdapter tests.

The default adapter wires :
- 5 chip-emitters always-on (no ``defer_loading`` key → Anthropic default False).
- 63 long-tail calculators from ``app.calculators.REGISTRY`` with
  ``defer_loading: True``.
- 1 ``tool_search_tool_bm25_20251119`` declaration so Sonnet 4.5 can BM25-search
  the deferred tools (Anthropic beta ``tool-search-tool-2025-10-19``).
"""
from __future__ import annotations

import re

import pytest


@pytest.fixture
def adapter():
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import (
        AnthropicDeferLoadingAdapter,
    )

    return AnthropicDeferLoadingAdapter()


def test_register_tools_returns_chip_emitters_and_long_tail_and_tool_search(adapter) -> None:
    """Plan acceptance Test 1 — list contains ≥6 entries (5 chip + ≥1 long-tail
    + tool_search declaration)."""
    tools = adapter.register_tools({})
    assert len(tools) >= 6
    names = {t.get("name") for t in tools if "name" in t}
    # 5 chip-emitters must be present.
    assert {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }.issubset(names)


def test_chip_emitters_are_not_deferred(adapter) -> None:
    """Plan acceptance Test 2 — 5 chip-emitters have ``defer_loading`` either
    absent or False (Anthropic default = False, both equivalent)."""
    always_on = {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }
    tools = adapter.register_tools({})
    for tool in tools:
        if tool.get("name") in always_on:
            assert tool.get("defer_loading", False) is False, (
                f"Chip-emitter {tool['name']} must NOT be deferred — it lives "
                f"in the sub-500 ms L1 latency budget per CONTEXT D-CE-01."
            )


def test_long_tail_calculators_are_deferred(adapter) -> None:
    """Plan acceptance Test 3 — every non-chip-emitter calculator tool carries
    ``defer_loading=True`` (cache-preserving per Anthropic spec)."""
    always_on = {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }
    tools = adapter.register_tools({})
    long_tail = [
        t
        for t in tools
        if t.get("name") not in always_on and "type" not in t
    ]
    # Plan 05's REGISTRY has 63 calculators — they all land here.
    assert len(long_tail) >= 40, (
        f"Expected ≥40 deferred long-tail tools, got {len(long_tail)}"
    )
    for tool in long_tail:
        assert tool.get("defer_loading") is True, (
            f"Long-tail tool {tool.get('name')} must carry defer_loading=True."
        )


def test_tool_search_declaration_present_exactly_once(adapter) -> None:
    """Plan acceptance Test 4 — exactly one ``tool_search_tool_bm25_20251119``
    declaration. Anthropic injects the BM25 server-side ; MINT only declares it."""
    tools = adapter.register_tools({})
    declarations = [t for t in tools if t.get("type") == "tool_search_tool_bm25_20251119"]
    assert len(declarations) == 1
    assert declarations[0]["name"] == "tool_search_tool_bm25"


def test_latency_tier_classifies_chip_long_tail_and_unknown(adapter) -> None:
    """Plan acceptance Test 5 — L1 for chip-emitters, L2 default for long-tail
    + unknown tools."""
    assert adapter.latency_tier("get_budget_status") == "L1"
    assert adapter.latency_tier("get_retirement_projection") == "L1"
    # Long-tail registry entry — defaults to L2 (no magic-comment lucidity tier
    # populated yet ; Plan 09 retrofit will populate L2/L3).
    assert adapter.latency_tier(
        "affordability_service__AffordabilityService_calculate_affordability"
    ) == "L1"  # output_type is "L1" in REGISTRY (Plan 05 baseline)
    # Unknown name → L2 default.
    assert adapter.latency_tier("unknown_tool_name_xyz") == "L2"


def test_beta_header_property_is_canonical_anthropic_string(adapter) -> None:
    """The beta header is the canonical 2025-10-19 string (CONTEXT D-CE-01)."""
    assert adapter.beta_header == "tool-search-tool-2025-10-19"


# ===========================================================================
# Surface coach — la description est ce que le modele lit pour CHOISIR
# ===========================================================================
#
# Le service a cesse de produire un montant et un taux d'impot successoral.
# Tant que la description annonce « Produit l'impôt CHF + la part nette », la
# promesse survit au correctif : c'est ce texte que le modele consulte.
#
# Option B (decidee) : l'outil RESTE selectionnable — s'il disparaissait, un
# «combien paierait mon concubin ?» ferait repondre le modele depuis ses
# poids, qui inventerait un taux cantonal. Il reste donc joignable, mais il
# retourne de la prose et sa description doit le dire.

_CONCUBINAGE_SUCCESSION_TOOL = (
    "concubinage_service__ConcubinageService_compare_succession_concubin_vs_conjoint"
)


@pytest.fixture
def descriptions():
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import (
        _TOOL_DESCRIPTIONS_FR,
    )

    return _TOOL_DESCRIPTIONS_FR


def test_ancien_nom_outil_succession_concubinage_absent(descriptions) -> None:
    """Le nom qui promettait une estimation chiffree ne doit plus exister."""
    assert (
        "concubinage_service__ConcubinageService_estimate_inheritance_tax"
        not in descriptions
    )


def test_outil_succession_concubinage_reste_joignable(descriptions) -> None:
    """Option B : l'outil demeure, sinon le modele repond de memoire."""
    assert _CONCUBINAGE_SUCCESSION_TOOL in descriptions


def test_description_succession_concubinage_ne_promet_aucun_chiffre(descriptions) -> None:
    """Ni montant CHF, ni pourcentage, ni « part nette » dans la promesse."""
    desc = descriptions[_CONCUBINAGE_SUCCESSION_TOOL]
    assert "CHF" not in desc, desc
    assert not re.search(r"\d\s*%", desc), desc
    assert "part nette" not in desc.lower(), desc


def test_description_succession_concubinage_n_impute_rien_au_cc_462(descriptions) -> None:
    """CC art. 462 regle une part successorale CIVILE, pas la fiscalite."""
    desc = descriptions[_CONCUBINAGE_SUCCESSION_TOOL]
    assert "462" not in desc, desc


def test_description_succession_simulator_cite_les_bons_articles(descriptions) -> None:
    """Les reserves hereditaires sont aux CC art. 470-471, pas 467-469.

    Source dans le depot meme : `succession_simulator.py` docstring —
    « CC art. 470-471 (reserves hereditaires, reforme 2023) » et
    « CC art. 467-469 (capacite de disposer, testament) ». La description
    coach inversait les deux.
    """
    desc = descriptions["succession_simulator__SuccessionSimulator_simulate"]
    assert "470-471" in desc, desc
    assert "467-469" not in desc, desc
