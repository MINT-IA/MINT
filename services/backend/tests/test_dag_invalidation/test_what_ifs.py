"""Phase 95 — D-11 uni-variate +/-10% sensitivity 5-entry contract."""
from __future__ import annotations

from decimal import Decimal

import pytest

from app.services.coach.grounding_pack import GroundingPackEntry
from app.services.coach.sensitivity import compute_what_ifs


def _linear_retirement_income(inputs: dict) -> dict:
    """Synthetic compute_fn : income_brut x 5 + lpp x 0.04 + 3a x 0.04 + (target - current) x 1000."""
    return {
        "retirement_income": (
            inputs["income_brut_annual"] * 5
            + inputs["current_lpp_balance"] * 0.04
            + inputs["current_3a_balance"] * 0.04
            + (inputs["target_retirement_age"] - inputs["current_age"]) * 1000
        )
    }


@pytest.fixture
def base_inputs():
    return {
        "income_brut_annual":     80000.0,
        "current_lpp_balance":    350000.0,
        "current_age":            35,
        "target_retirement_age":  65,
        "current_3a_balance":     20000.0,
    }


def test_returns_exactly_5_entries(base_inputs):
    result = compute_what_ifs(base_inputs, _linear_retirement_income)
    assert len(result) == 5
    assert all(isinstance(e, GroundingPackEntry) for e in result.values())


def test_canonical_perturb_keys(base_inputs):
    result = compute_what_ifs(base_inputs, _linear_retirement_income)
    expected_keys = {
        "sensitivity_income_brut_annual",
        "sensitivity_current_lpp_balance",
        "sensitivity_current_age",
        "sensitivity_target_retirement_age",
        "sensitivity_current_3a_balance",
    }
    assert set(result.keys()) == expected_keys


def test_raw_audit_trail(base_inputs):
    result = compute_what_ifs(base_inputs, _linear_retirement_income)
    for key, entry in result.items():
        assert "baseline" in entry.raw
        assert "plus10" in entry.raw
        assert "minus10" in entry.raw


def test_income_brut_delta_matches_synthetic(base_inputs):
    """+10% of income_brut_annual (80000 -> 88000) x 5 => +40000 CHF retirement income."""
    result = compute_what_ifs(base_inputs, _linear_retirement_income)
    entry = result["sensitivity_income_brut_annual"]
    # plus10 delta = (88000-80000) * 5 = 40000.00
    assert entry.value == Decimal("40000.00"), f"Got {entry.value}, expected 40000.00"


def test_credible_bounds_low_below_high(base_inputs):
    result = compute_what_ifs(base_inputs, _linear_retirement_income)
    for entry in result.values():
        assert entry.credible_low is not None
        assert entry.credible_high is not None
        # In a monotone-positive system, credible_low (-10%) <= credible_high (+10%)
        assert entry.credible_low <= entry.credible_high


def test_source_ref_per_input(base_inputs):
    result = compute_what_ifs(base_inputs, _linear_retirement_income)
    for key, entry in result.items():
        input_name = key[len("sensitivity_"):]
        assert input_name in entry.source_ref
