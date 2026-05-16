"""IndependentTaxBundle — Plan 08 W2-02-01 unit tests.

Phase mint-calc-engine-v1 Plan 08 (W2 bundles). Activated when `intents`
contains `taxes` or `career` (CONTEXT D-CE-03). Covers matrix domain 8
(Sàrl-vs-RI + dividende-vs-salaire — scaffolds coaching register even
though the underlying calculators are not yet implemented).

Tests mirror the contract precedent from `test_bundle_contract.py` and
the per-bundle Wave 0 + Wave 2 invariants from `test_bundle_tax_explainer.py` :

- T-1 frozen + extra=forbid invariants
- T-2 prompt_fragment cites LAVS art. 8 + LPP art. 4 + LIFD art. 33
- T-3 allowed_tools matches plan's tool name list
- T-4 citation_allowlist matches `tool_<name>` convention
- T-5 accent FR clean — verifies « éducatif », « équivalent », « indépendant »
- T-6 no banned LSFin terms in the prompt fragment
"""
from __future__ import annotations

import re

import pytest
from pydantic import ValidationError

from app.services.coach.bundles import IndependentTaxBundle


# ---------------------------------------------------------------------------
# T-1 Pydantic contract (frozen + extra=forbid)
# ---------------------------------------------------------------------------


def test_independent_tax_bundle_constructs():
    """Bundle instantiates without raising and exposes the 4 contract fields."""
    bundle = IndependentTaxBundle()
    assert bundle.name == "independent-tax"
    assert isinstance(bundle.prompt_fragment, str)
    assert isinstance(bundle.allowed_tools, list)
    assert isinstance(bundle.citation_allowlist, list)


def test_independent_tax_bundle_is_frozen():
    """`model_config["frozen"] is True` — attribute assignment raises."""
    bundle = IndependentTaxBundle()
    with pytest.raises(ValidationError):
        bundle.allowed_tools = ["evil"]  # type: ignore[misc]


def test_independent_tax_bundle_forbids_extra():
    """`model_config["extra"] == "forbid"` — unknown fields rejected."""
    bundle = IndependentTaxBundle()
    with pytest.raises(ValidationError):
        IndependentTaxBundle.model_validate(
            {**bundle.model_dump(), "extra_field": "boom"}
        )


# ---------------------------------------------------------------------------
# T-2 Legal article citations
# ---------------------------------------------------------------------------


def test_independent_tax_bundle_cites_swiss_articles():
    """Prompt fragment must cite LAVS art. 8 + LPP art. 4 + LIFD art. 33."""
    bundle = IndependentTaxBundle()
    fragment = bundle.prompt_fragment
    assert "LAVS art. 8" in fragment, "missing LAVS art. 8 citation"
    assert "LPP art. 4" in fragment, "missing LPP art. 4 citation"
    assert "LIFD art. 33" in fragment, "missing LIFD art. 33 citation"


def test_independent_tax_bundle_keyword_coverage():
    """Prompt fragment names the user-facing scope keywords."""
    bundle = IndependentTaxBundle()
    fragment = bundle.prompt_fragment.lower()
    assert "indépendant" in fragment, "missing indépendant keyword"
    assert "sàrl" in fragment, "missing Sàrl keyword"


# ---------------------------------------------------------------------------
# T-3 allowed_tools per RESEARCH §Q-F line 900-905
# ---------------------------------------------------------------------------


def test_independent_tax_bundle_allowed_tools():
    """allowed_tools matches RESEARCH §Q-F mapping (4 tools)."""
    bundle = IndependentTaxBundle()
    assert bundle.allowed_tools == [
        "avs_cotisations_independants",
        "pillar_3a_indep",
        "lpp_volontaire",
        "ijm_service",
    ]


# ---------------------------------------------------------------------------
# T-4 citation_allowlist convention
# ---------------------------------------------------------------------------


def test_independent_tax_bundle_citation_allowlist_tool_prefix():
    """Citation keys follow the `tool_<name>` convention."""
    bundle = IndependentTaxBundle()
    expected = {
        "tool_avs_cotisations_independants",
        "tool_pillar_3a_indep",
        "tool_lpp_volontaire",
        "tool_ijm_service",
    }
    assert set(bundle.citation_allowlist) == expected
    for key in bundle.citation_allowlist:
        assert key.startswith("tool_"), f"citation key {key!r} not tool-prefixed"


# ---------------------------------------------------------------------------
# T-5 Accent FR sanity (CLAUDE.md rule 2)
# ---------------------------------------------------------------------------


def test_independent_tax_bundle_accent_fr_clean():
    """Prompt fragment uses proper FR accents — no ASCII placeholders for é."""
    bundle = IndependentTaxBundle()
    fragment = bundle.prompt_fragment
    # Positive markers — these accent-bearing words must be present.
    assert "indépendant" in fragment or "Indépendant" in fragment
    assert "éducatif" in fragment
    # Negative markers — common ASCII fallbacks for é are absent in tokens
    # that should carry accents.
    assert not re.search(r"\beducatif\b", fragment), (
        "found ASCII 'educatif' — should be 'éducatif'"
    )
    assert not re.search(r"\bindependant\b", fragment), (
        "found ASCII 'independant' — should be 'indépendant'"
    )


# ---------------------------------------------------------------------------
# T-6 LSFin banned-terms absence
# ---------------------------------------------------------------------------


def test_independent_tax_bundle_no_banned_terms():
    """Prompt fragment must NOT contain LSFin banned verbs in narrator voice.

    The 7 cardinal banned terms (CLAUDE.md TOP rule #1): « garanti »,
    « optimal », « meilleur », « certain », « assuré », « sans risque »,
    « parfait » + paraphrase variants from D-CE-16 (« recommandé »,
    « tu devrais »).
    """
    bundle = IndependentTaxBundle()
    fragment = bundle.prompt_fragment.lower()
    banned = [
        "garanti",
        "optimal",
        "meilleur",
        "sans risque",
        "parfait",
        "tu devrais",
        "recommandé",
    ]
    hits = [term for term in banned if term in fragment]
    assert not hits, (
        f"IndependentTaxBundle prompt_fragment contains banned terms : {hits}"
    )
