"""Phase 95 — D-07/D-08 ProjectionGroundingPack Pydantic v2 invariants."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.services.coach.grounding_pack import (
    GroundingPackEntry,
    ParetoPoint,
    ProjectionGroundingPack,
)


def _entry(value="1.00", credible_low=None, credible_high=None):
    return GroundingPackEntry(
        value=Decimal(value),
        raw={"trace": "test"},
        source_ref="test.source",
        credible_low=Decimal(credible_low) if credible_low else None,
        credible_high=Decimal(credible_high) if credible_high else None,
        staleness_iso=datetime.now(timezone.utc).isoformat(),
    )


def _pareto(label="fiscal_pure"):
    return ParetoPoint(
        label=label,
        weights={"tax_saving": Decimal("1.00"), "liquidity": Decimal("0.00"), "ruin_red": Decimal("0.00")},
        allocation={"3a": Decimal("7056.00"), "rachat_lpp": Decimal("0.00"), "amort_indirect": Decimal("0.00")},
        projected_outcomes={"tax_saving_chf": Decimal("2400.00"), "liquidity_score": Decimal("0.00"), "ruin_prob_red": Decimal("0.00")},
    )


def _valid_pack(**overrides):
    defaults = dict(
        inputs_hash="a" * 64,
        entries={"r3a_plafond_salarie_2026": _entry()},
        pareto_points=[_pareto("fiscal_pure"), _pareto("liquidity_prioritized"), _pareto("ruin_reduction_prioritized")],
        what_ifs={f"sensitivity_input_{i}": _entry() for i in range(5)},
        legal_constraints=["OPP3 art. 7"],
        superseded_by=None,
    )
    defaults.update(overrides)
    return ProjectionGroundingPack(**defaults)


def test_frozen_raises_on_mutation():
    p = _valid_pack()
    with pytest.raises(ValidationError):
        p.inputs_hash = "b" * 64  # type: ignore[misc]


def test_extra_forbid_rejects_unknown_field():
    with pytest.raises(ValidationError):
        ProjectionGroundingPack(
            inputs_hash="a" * 64,
            entries={},
            pareto_points=[_pareto(), _pareto(), _pareto()],
            what_ifs={f"s{i}": _entry() for i in range(5)},
            legal_constraints=[],
            superseded_by=None,
            bogus_field="oops",  # type: ignore[call-arg]
        )


def test_inputs_hash_length_64_required():
    with pytest.raises(ValidationError):
        _valid_pack(inputs_hash="a" * 63)
    with pytest.raises(ValidationError):
        _valid_pack(inputs_hash="a" * 65)


def test_pareto_points_exactly_3():
    with pytest.raises(ValidationError):
        _valid_pack(pareto_points=[_pareto(), _pareto()])
    with pytest.raises(ValidationError):
        _valid_pack(pareto_points=[_pareto()] * 4)


def test_what_ifs_exactly_5():
    with pytest.raises(ValidationError):
        _valid_pack(what_ifs={f"s{i}": _entry() for i in range(4)})
    with pytest.raises(ValidationError):
        _valid_pack(what_ifs={f"s{i}": _entry() for i in range(6)})


def test_superseded_by_none_or_36_chars():
    _valid_pack(superseded_by=None)
    _valid_pack(superseded_by="018f63d6-9ce0-7a3b-8000-123456789012")
    with pytest.raises(ValidationError):
        _valid_pack(superseded_by="not-a-uuid")


def test_decimal_serializes_as_string():
    p = _valid_pack()
    dumped = p.model_dump_json()
    data = json.loads(dumped)
    first_key = next(iter(data["entries"]))
    assert isinstance(data["entries"][first_key]["value"], str)
    assert data["entries"][first_key]["value"] == "1.00"


def test_grounding_pack_entry_credible_intervals_optional():
    _entry(credible_low=None, credible_high=None)
    _entry(credible_low="0.50", credible_high="1.50")
    _entry(credible_low="0.50", credible_high=None)
