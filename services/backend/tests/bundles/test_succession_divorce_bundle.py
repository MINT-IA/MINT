"""SuccessionDivorceBundle — Plan 08 W2-02-02 unit tests.

Phase mint-calc-engine-v1 Plan 08 (W2 bundles). Activated when `intents`
contains `family` (CONTEXT D-CE-03). Wraps the already-shipped
`divorce_simulator.py` + `succession_simulator.py` calculators with
citation grammar for CC art. 122-124 / CC art. 462 / CC art. 467-469 /
LAVS art. 29sexies.

Tests mirror the contract precedent from `test_bundle_contract.py` and
the per-bundle invariants from `test_bundle_tax_explainer.py` :

- T-1 frozen + extra=forbid invariants
- T-2 prompt_fragment cites CC art. 122-124 / CC art. 462 /
  CC art. 467-469 / LAVS art. 29sexies + keyword coverage
- T-3 allowed_tools matches plan's tool name list
- T-4 citation_allowlist matches `tool_<name>` convention
- T-5 accent FR clean
- T-6 no banned LSFin terms in the prompt fragment
"""
from __future__ import annotations

import re

import pytest
from pydantic import ValidationError

from app.services.coach.bundles import SuccessionDivorceBundle


# ---------------------------------------------------------------------------
# T-1 Pydantic contract (frozen + extra=forbid)
# ---------------------------------------------------------------------------


def test_succession_divorce_bundle_constructs():
    """Bundle instantiates without raising and exposes the 4 contract fields."""
    bundle = SuccessionDivorceBundle()
    assert bundle.name == "succession-divorce"
    assert isinstance(bundle.prompt_fragment, str)
    assert isinstance(bundle.allowed_tools, list)
    assert isinstance(bundle.citation_allowlist, list)


def test_succession_divorce_bundle_is_frozen():
    """`model_config["frozen"] is True` — attribute assignment raises."""
    bundle = SuccessionDivorceBundle()
    with pytest.raises(ValidationError):
        bundle.allowed_tools = ["evil"]  # type: ignore[misc]


def test_succession_divorce_bundle_forbids_extra():
    """`model_config["extra"] == "forbid"` — unknown fields rejected."""
    bundle = SuccessionDivorceBundle()
    with pytest.raises(ValidationError):
        SuccessionDivorceBundle.model_validate(
            {**bundle.model_dump(), "extra_field": "boom"}
        )


# ---------------------------------------------------------------------------
# T-2 Legal article citations (CC + LAVS — D-CE-03 + swiss-brain.md)
# ---------------------------------------------------------------------------


def test_succession_divorce_bundle_cites_swiss_articles():
    """Prompt fragment must cite CC art. 122-124 + CC art. 462 +
    CC art. 470-471 + LAVS art. 29sexies.

    Les reserves hereditaires sont aux CC art. 470-471, pas 467-469
    (capacite de disposer + vices de volonte). Source dans le depot :
    `succession_simulator.py` docstring + adaptateur coach (meme
    correction, test_anthropic_defer_loading_adapter.py:170). Ce test
    exigeait la citation fausse — un test vert qui gravait un fait faux
    (regle 3 du hand-off 2026-07-27).
    """
    bundle = SuccessionDivorceBundle()
    fragment = bundle.prompt_fragment
    assert "CC art. 122-124" in fragment, "missing CC art. 122-124"
    assert "CC art. 462" in fragment, "missing CC art. 462"
    assert "CC art. 470-471" in fragment, "missing CC art. 470-471"
    assert "467-469" not in fragment, "reserves mal citees (467-469)"
    assert "LAVS art. 29sexies" in fragment, "missing LAVS art. 29sexies"


def test_succession_divorce_bundle_keyword_coverage():
    """Prompt fragment names the user-facing scope keywords."""
    bundle = SuccessionDivorceBundle()
    fragment = bundle.prompt_fragment.lower()
    assert "divorce" in fragment, "missing divorce keyword"
    assert "succession" in fragment, "missing succession keyword"


def test_succession_divorce_bundle_cc_article_count():
    """At least 3 CC article references (122-124 + 462 + 467-469 = 3 ranges)."""
    bundle = SuccessionDivorceBundle()
    matches = re.findall(r"CC art\.", bundle.prompt_fragment)
    assert len(matches) >= 3, (
        f"expected ≥3 CC art. references, got {len(matches)}"
    )


# ---------------------------------------------------------------------------
# T-3 allowed_tools (RESEARCH §Q-F line 922)
# ---------------------------------------------------------------------------


def test_succession_divorce_bundle_allowed_tools():
    """allowed_tools maps to the 3 already-shipped life-event tools."""
    bundle = SuccessionDivorceBundle()
    assert bundle.allowed_tools == [
        "divorce_simulator",
        "succession_simulator",
        "concubinage_succession",
    ]


# ---------------------------------------------------------------------------
# T-4 citation_allowlist convention
# ---------------------------------------------------------------------------


def test_succession_divorce_bundle_citation_allowlist_tool_prefix():
    """Citation keys follow the `tool_<name>` convention."""
    bundle = SuccessionDivorceBundle()
    expected = {
        "tool_divorce_simulator",
        "tool_succession_simulator",
        "tool_concubinage_succession",
    }
    assert set(bundle.citation_allowlist) == expected
    for key in bundle.citation_allowlist:
        assert key.startswith("tool_"), f"citation key {key!r} not tool-prefixed"


# ---------------------------------------------------------------------------
# T-5 Accent FR sanity (CLAUDE.md rule 2)
# ---------------------------------------------------------------------------


def test_succession_divorce_bundle_accent_fr_clean():
    """Prompt fragment uses proper FR accents — no ASCII placeholders."""
    bundle = SuccessionDivorceBundle()
    fragment = bundle.prompt_fragment
    # Positive markers — these accent-bearing words must be present.
    assert "éducatif" in fragment or "éducative" in fragment, "missing éducatif"
    assert "hérédit" in fragment or "héritière" in fragment or "héréd" in fragment
    # Negative markers — common ASCII fallbacks are absent.
    assert not re.search(r"\beducatif\b", fragment), (
        "found ASCII 'educatif' — should be 'éducatif'"
    )
    assert not re.search(r"\bdeces\b", fragment), (
        "found ASCII 'deces' — should be 'décès'"
    )


# ---------------------------------------------------------------------------
# T-6 LSFin banned-terms absence
# ---------------------------------------------------------------------------


def test_succession_divorce_bundle_no_banned_terms():
    """Prompt fragment must NOT contain LSFin banned verbs in narrator voice."""
    bundle = SuccessionDivorceBundle()
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
        f"SuccessionDivorceBundle prompt_fragment contains banned terms : {hits}"
    )
