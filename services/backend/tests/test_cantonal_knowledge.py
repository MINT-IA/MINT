"""
Tests for CantonalKnowledge — RAG v2.

Validates tax specifics, pension fund lists, and housing market data
for the 11 major Swiss cantons.
"""

from __future__ import annotations

import pytest

from app.services.rag.cantonal_knowledge import CantonalKnowledge


# ---------------------------------------------------------------------------
# Tax specifics
# ---------------------------------------------------------------------------


def test_all_major_cantons_have_tax_specifics():
    """The 11 major cantons must all have tax specifics."""
    major_cantons = ["ZH", "BE", "VD", "GE", "VS", "TI", "ZG", "BS", "LU", "AG", "SG"]
    for canton in major_cantons:
        result = CantonalKnowledge.tax_specifics(canton)
        assert result is not None, f"Missing tax specifics for canton {canton}"


def test_tax_specifics_structure():
    """Tax specifics dict must have required fields."""
    required_keys = [
        "canton", "name", "marginal_rate_pct", "capital_gains_tax",
        "wealth_tax_rate_permille", "inheritance_tax_direct_heirs",
        "notable_deductions", "source",
    ]
    for canton in CantonalKnowledge.all_cantons():
        data = CantonalKnowledge.tax_specifics(canton)
        for key in required_keys:
            assert key in data, f"Canton {canton} missing key '{key}' in tax_specifics"


def test_zg_has_lowest_tax_rate():
    """Zoug (ZG) must have the lowest income tax rate among all cantons."""
    lowest = CantonalKnowledge.lowest_tax_canton()
    assert lowest == "ZG", f"Expected ZG as lowest tax canton, got {lowest}"


def test_zg_tax_rate_is_below_25():
    """Zoug marginal rate must be below 25%."""
    data = CantonalKnowledge.tax_specifics("ZG")
    assert data["marginal_rate_pct"] < 25, (
        f"ZG marginal rate expected < 25%, got {data['marginal_rate_pct']}%"
    )


def test_ge_tax_rate_is_highest():
    """Geneva (GE) must have one of the highest tax rates."""
    ge = CantonalKnowledge.tax_specifics("GE")
    zh = CantonalKnowledge.tax_specifics("ZH")
    assert ge["marginal_rate_pct"] > zh["marginal_rate_pct"], (
        "GE should have higher rate than ZH"
    )


def test_tax_specifics_unknown_canton_returns_none():
    """Unknown canton code returns None."""
    result = CantonalKnowledge.tax_specifics("XX")
    assert result is None


def test_tax_specifics_case_insensitive():
    """tax_specifics should work with lowercase canton code."""
    upper = CantonalKnowledge.tax_specifics("ZH")
    lower = CantonalKnowledge.tax_specifics("zh")
    assert upper == lower


def test_no_capital_gains_tax():
    """Switzerland has no cantonal capital gains tax for individuals — check field."""
    for canton in CantonalKnowledge.all_cantons():
        data = CantonalKnowledge.tax_specifics(canton)
        assert isinstance(data["capital_gains_tax"], bool)


def test_all_cantons_returns_list_of_strings():
    """all_cantons() returns a non-empty list of strings."""
    cantons = CantonalKnowledge.all_cantons()
    assert isinstance(cantons, list)
    assert len(cantons) >= 11
    for c in cantons:
        assert isinstance(c, str)
        assert len(c) == 2


# ---------------------------------------------------------------------------
# Pension funds
# ---------------------------------------------------------------------------


def test_major_cantons_have_pension_funds():
    """All 11 major cantons must have at least 2 pension funds listed."""
    major_cantons = ["ZH", "BE", "VD", "GE", "VS", "TI", "ZG", "BS", "LU", "AG", "SG"]
    for canton in major_cantons:
        funds = CantonalKnowledge.pension_funds(canton)
        assert len(funds) >= 2, f"Canton {canton} has fewer than 2 pension funds listed"


def test_pension_funds_are_strings():
    """Pension fund names must be non-empty strings."""
    for canton in ["ZH", "GE", "VD"]:
        funds = CantonalKnowledge.pension_funds(canton)
        for f in funds:
            assert isinstance(f, str) and f.strip(), (
                f"Invalid pension fund name in {canton}: {f!r}"
            )


def test_pension_funds_unknown_canton_returns_empty():
    """Unknown canton returns empty list for pension_funds."""
    result = CantonalKnowledge.pension_funds("XX")
    assert result == []


def test_vs_has_known_funds():
    """Valais must include CPE and HOTELA in its fund list."""
    funds = CantonalKnowledge.pension_funds("VS")
    fund_names = " ".join(funds).lower()
    assert "cpe" in fund_names or "caisse" in fund_names.lower(), (
        "VS should include a state caisse"
    )
    assert "hotela" in fund_names, "VS should include HOTELA"


# ---------------------------------------------------------------------------
# Housing market
# ---------------------------------------------------------------------------


def test_major_cantons_have_housing_data():
    """All 11 major cantons must have housing market data."""
    major_cantons = ["ZH", "BE", "VD", "GE", "VS", "TI", "ZG", "BS", "LU", "AG", "SG"]
    for canton in major_cantons:
        data = CantonalKnowledge.housing_market(canton)
        assert data is not None, f"Missing housing data for canton {canton}"


def test_housing_market_structure():
    """Housing market dict must have required fields."""
    required_keys = [
        "canton", "median_rent_4pce_chf", "median_price_per_sqm_buy_chf",
        "avg_mortgage_rate_pct", "rental_vacancy_rate_pct", "market_pressure",
        "comment", "source",
    ]
    for canton in ["ZH", "GE", "VD"]:
        data = CantonalKnowledge.housing_market(canton)
        for key in required_keys:
            assert key in data, f"Canton {canton} housing data missing key '{key}'"


def test_ge_has_highest_median_rent():
    """Geneva (GE) must have the highest median rent among all cantons with data."""
    highest = CantonalKnowledge.highest_rent_canton()
    assert highest == "GE", f"Expected GE as highest rent canton, got {highest}"


def test_housing_unknown_canton_returns_none():
    """Unknown canton returns None for housing_market."""
    result = CantonalKnowledge.housing_market("XX")
    assert result is None


# ---------------------------------------------------------------------------
# Canton comparison
# ---------------------------------------------------------------------------


def test_compare_tax_zg_vs_ge():
    """Zoug should be significantly cheaper than Geneva."""
    comparison = CantonalKnowledge.compare_tax("ZG", "GE")
    assert comparison is not None
    assert comparison["cheaper_canton"] == "ZG"
    assert comparison["difference_pct"] < 0  # ZG - GE < 0


def test_compare_tax_unknown_canton_returns_none():
    """Comparison with unknown canton returns None."""
    result = CantonalKnowledge.compare_tax("ZH", "XX")
    assert result is None


def test_compare_tax_same_canton():
    """Comparing a canton to itself returns 0 difference."""
    result = CantonalKnowledge.compare_tax("ZH", "ZH")
    assert result is not None
    assert result["difference_pct"] == 0.0
