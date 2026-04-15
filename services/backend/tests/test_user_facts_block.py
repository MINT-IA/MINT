"""Coverage tests for _build_user_facts_block branches added in PR #340.

Targets coach_chat.py lines 626, 629, 632, 638 — the new salary income
fields (gross yearly, net yearly, gross monthly, wealth_estimate)
introduced after Run-005 found the coach couldn't cite incomeGrossYearly
even after scan-confirmation persisted it.
"""
from __future__ import annotations

from app.api.v1.endpoints.coach_chat import _build_user_facts_block


def test_block_includes_income_gross_yearly():
    block = _build_user_facts_block({
        "age": 28,
        "income_gross_yearly": 85000.0,
    })
    assert "<facts_user>" in block
    assert "Salaire brut annuel" in block
    assert "85000" in block


def test_block_includes_income_net_yearly():
    block = _build_user_facts_block({
        "age": 49,
        "income_net_yearly": 70000.0,
    })
    assert "Salaire net annuel" in block
    assert "70000" in block


def test_block_includes_income_gross_monthly():
    block = _build_user_facts_block({
        "age": 35,
        "income_gross_monthly": 9500.0,
    })
    assert "Salaire brut mensuel" in block
    assert "9500" in block


def test_block_includes_wealth_estimate():
    block = _build_user_facts_block({
        "age": 56,
        "wealth_estimate": 250000.0,
    })
    assert "Fortune imposable" in block
    assert "250000" in block


def test_block_combines_all_new_fields():
    """All 4 new fields surface together when present, in stable order."""
    block = _build_user_facts_block({
        "age": 49,
        "canton": "VS",
        "monthly_income": 7600,
        "income_gross_yearly": 122206,
        "income_net_yearly": 91200,
        "income_gross_monthly": 10183,
        "lpp_insured_salary": 95941,
        "wealth_estimate": 75000,
    })
    assert "Salaire net mensuel" in block
    assert "Salaire brut annuel" in block
    assert "Salaire net annuel" in block
    assert "Salaire brut mensuel" in block
    assert "Salaire assure LPP" in block
    assert "Fortune imposable" in block


def test_block_skips_zero_or_none_fields():
    """Zero or None new fields must NOT emit empty lines."""
    block = _build_user_facts_block({
        "age": 28,
        "monthly_income": 5800,
        "income_gross_yearly": None,
        "income_net_yearly": 0,
        "income_gross_monthly": None,
        "wealth_estimate": 0,
    })
    assert "Salaire net mensuel" in block
    assert "Salaire brut annuel" not in block
    assert "Salaire net annuel" not in block
    assert "Fortune imposable" not in block


def test_block_empty_when_only_none_fields():
    """A profile with only the new keys all-None returns empty string
    (no <facts_user> wrapper)."""
    block = _build_user_facts_block({
        "income_gross_yearly": None,
        "income_net_yearly": None,
        "income_gross_monthly": None,
        "wealth_estimate": None,
    })
    assert block == ""
