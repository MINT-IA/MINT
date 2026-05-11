"""Phase 95 — D-10 3-point scalarisation determinism + winner-per-weight-set."""
from __future__ import annotations

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.services.coach.pareto import PARETO_WEIGHT_SETS, compute_pareto_points
from app.services.coach.grounding_pack import ParetoPoint


@pytest.fixture
def synthetic_trajectoires():
    """3 trajectoires each dominant on one objective.

    NOTE — values are unit-normalized so that each trajectoire wins under
    its dedicated weight set against the simple linear scalarisation in
    compute_pareto_points. The plan's original fixture had a math error :
    real-world tax_saving_chf (1000s) vastly dominates real-world
    liquidity_score (0-1) under 50/50 weights, so the "liquidity winner"
    would never win. Phase 96 W2 will wire real arbitrage_engine outputs
    AND consume a normalisation step ; this test guards the determinism
    of the scoring loop, not the realism of inputs.
    """
    return [
        {  # winner under fiscal_pure
            "id": "3a",
            "tax_saving_chf": 2400.0,
            "liquidity_score": 0.0,
            "ruin_prob_reduction": 0.0,
            "allocation": {"3a": 7056.0, "rachat_lpp": 0.0, "amort_indirect": 0.0},
        },
        {  # winner under liquidity_prioritized (0.5 × 1000 + 0.5 × 5000 = 3000)
            "id": "rachat_lpp",
            "tax_saving_chf": 1000.0,
            "liquidity_score": 5000.0,
            "ruin_prob_reduction": 0.0,
            "allocation": {"3a": 0.0, "rachat_lpp": 20000.0, "amort_indirect": 0.0},
        },
        {  # winner under ruin_reduction_prioritized (0.4 × 0 + 0.6 × 8000 = 4800)
            "id": "amort_indirect",
            "tax_saving_chf": 0.0,
            "liquidity_score": 0.0,
            "ruin_prob_reduction": 8000.0,
            "allocation": {"3a": 0.0, "rachat_lpp": 0.0, "amort_indirect": 50000.0},
        },
    ]


def test_returns_exactly_3_points(synthetic_trajectoires):
    pts = compute_pareto_points({}, synthetic_trajectoires)
    assert len(pts) == 3
    assert all(isinstance(p, ParetoPoint) for p in pts)


def test_labels_in_canonical_order(synthetic_trajectoires):
    pts = compute_pareto_points({}, synthetic_trajectoires)
    assert [p.label for p in pts] == [
        "fiscal_pure",
        "liquidity_prioritized",
        "ruin_reduction_prioritized",
    ]


def test_winner_per_weight_set(synthetic_trajectoires):
    pts = compute_pareto_points({}, synthetic_trajectoires)
    # fiscal_pure picks 3a (highest tax_saving_chf)
    assert pts[0].allocation == {"3a": Decimal("7056.0"), "rachat_lpp": Decimal("0.0"), "amort_indirect": Decimal("0.0")}
    # liquidity_prioritized picks rachat_lpp (highest weighted sum at 0.5 tax + 0.5 liq)
    assert pts[1].allocation == {"3a": Decimal("0.0"), "rachat_lpp": Decimal("20000.0"), "amort_indirect": Decimal("0.0")}
    # ruin_reduction_prioritized picks amort_indirect (highest weighted sum at 0.4 tax + 0.6 ruin)
    assert pts[2].allocation == {"3a": Decimal("0.0"), "rachat_lpp": Decimal("0.0"), "amort_indirect": Decimal("50000.0")}


def test_weight_sums_equal_one():
    for spec in PARETO_WEIGHT_SETS:
        s = sum(spec["weights"].values())
        assert s == Decimal("1.00"), f"{spec['label']} weights sum to {s}, expected 1.00"


def test_pareto_point_is_frozen(synthetic_trajectoires):
    pts = compute_pareto_points({}, synthetic_trajectoires)
    with pytest.raises(ValidationError):
        pts[0].label = "mutated"  # type: ignore[misc]


def test_deterministic_across_calls(synthetic_trajectoires):
    pts_a = compute_pareto_points({}, synthetic_trajectoires)
    pts_b = compute_pareto_points({}, synthetic_trajectoires)
    assert [p.model_dump() for p in pts_a] == [p.model_dump() for p in pts_b]
