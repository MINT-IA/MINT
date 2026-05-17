"""Phase 96 D-12 — SerializedCardContext schema tests.

Per 96-02-PLAN.md Task 1 <behavior> Tests 1-10. Validates :
- 7-field instantiation (Test 1)
- minimal 2-required-field instantiation (Test 2)
- frozen=True (Test 3)
- extra="forbid" (Test 4)
- computed_facts scalar-only validator (Tests 5-7)
- field length bounds (Tests 8-9)
- camelCase JSON aliases (Test 10)
"""
from __future__ import annotations

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.schemas.card_context import SerializedCardContext


# ---------------------------------------------------------------------------
# Test 1 — full instantiation
# ---------------------------------------------------------------------------


def test_full_instantiation(serialized_card_context_full):
    """All 7 fields populated → no validation error."""
    ctx = serialized_card_context_full
    assert ctx.card_id == "mon_3a_2026"
    assert ctx.card_type == "pillar_3a"
    assert ctx.computed_facts["annual_contribution_chf"] == Decimal("7056.00")
    assert ctx.computed_facts["years_until_retirement"] == 22
    assert ctx.computed_facts["frequency_note"] == "annual"
    assert ctx.grounding_keys == ["pillar_3a.max_contribution_2026"]
    assert ctx.life_event == "retirement"
    assert ctx.canton == "VD"
    assert ctx.archetype == "swiss_native"


# ---------------------------------------------------------------------------
# Test 2 — minimal instantiation (2 required fields only)
# ---------------------------------------------------------------------------


def test_minimal_instantiation_defaults(serialized_card_context_minimal):
    """Only card_id + card_type required ; the rest defaults."""
    ctx = serialized_card_context_minimal
    assert ctx.card_id == "x"
    assert ctx.card_type == "y"
    assert ctx.computed_facts == {}
    assert ctx.grounding_keys == []
    assert ctx.life_event is None
    assert ctx.canton is None
    assert ctx.archetype is None


# ---------------------------------------------------------------------------
# Test 3 — frozen=True
# ---------------------------------------------------------------------------


def test_frozen_blocks_attribute_assignment(serialized_card_context_minimal):
    """frozen=True → attribute mutation raises ValidationError."""
    with pytest.raises(ValidationError):
        serialized_card_context_minimal.card_id = "new"  # type: ignore[misc]


# ---------------------------------------------------------------------------
# Test 4 — extra="forbid"
# ---------------------------------------------------------------------------


def test_extra_fields_rejected():
    """Unknown fields raise ValidationError (PII smuggling defense)."""
    with pytest.raises(ValidationError) as exc_info:
        SerializedCardContext(
            card_id="x",
            card_type="y",
            email="leak@example.com",  # type: ignore[call-arg]
        )
    assert "extra" in str(exc_info.value).lower() or "forbidden" in str(
        exc_info.value
    ).lower()


# ---------------------------------------------------------------------------
# Tests 5-7 — computed_facts scalar-only validator
# ---------------------------------------------------------------------------


def test_computed_facts_accepts_scalar_types():
    """Decimal | int | str values pass the validator."""
    ctx = SerializedCardContext(
        card_id="x",
        card_type="y",
        computed_facts={
            "monthly": Decimal("1500.00"),
            "count": 12,
            "note": "hi",
        },
    )
    assert ctx.computed_facts["monthly"] == Decimal("1500.00")
    assert ctx.computed_facts["count"] == 12
    assert ctx.computed_facts["note"] == "hi"


def test_computed_facts_rejects_nested_dict():
    """Dict values raise ValidationError (forces flat key:value pairs)."""
    with pytest.raises(ValidationError):
        SerializedCardContext(
            card_id="x",
            card_type="y",
            computed_facts={"nested": {"a": 1}},  # type: ignore[dict-item]
        )


def test_computed_facts_rejects_list():
    """List values raise ValidationError."""
    with pytest.raises(ValidationError):
        SerializedCardContext(
            card_id="x",
            card_type="y",
            computed_facts={"list": [1, 2, 3]},  # type: ignore[dict-item]
        )


def test_computed_facts_rejects_bool():
    """bool is a subclass of int — must be explicitly rejected."""
    with pytest.raises(ValidationError):
        SerializedCardContext(
            card_id="x",
            card_type="y",
            computed_facts={"flag": True},  # type: ignore[dict-item]
        )


def test_computed_facts_rejects_none():
    """None values forbidden (would coerce to empty string)."""
    with pytest.raises(ValidationError):
        SerializedCardContext(
            card_id="x",
            card_type="y",
            computed_facts={"missing": None},  # type: ignore[dict-item]
        )


# ---------------------------------------------------------------------------
# Tests 8-9 — field length bounds
# ---------------------------------------------------------------------------


def test_card_id_min_length_rejects_empty():
    """Empty card_id raises ValidationError (min_length=1)."""
    with pytest.raises(ValidationError):
        SerializedCardContext(card_id="", card_type="y")


def test_canton_max_length_rejects_long():
    """canton bounded at 2 chars (Swiss canton code, e.g. VD/GE/ZH)."""
    with pytest.raises(ValidationError):
        SerializedCardContext(card_id="x", card_type="y", canton="VAUD")


# ---------------------------------------------------------------------------
# Test 10 — camelCase JSON aliases
# ---------------------------------------------------------------------------


def test_camel_case_serialization(serialized_card_context_full):
    """model_dump(by_alias=True) emits cardId, cardType, computedFacts, …"""
    payload = serialized_card_context_full.model_dump(by_alias=True)
    assert "cardId" in payload
    assert "cardType" in payload
    assert "computedFacts" in payload
    assert "groundingKeys" in payload
    assert "lifeEvent" in payload
    # canton + archetype keep their literal names (single-word) but verify
    # nothing got mangled either.
    assert "canton" in payload
    assert "archetype" in payload
    # Round-trip via populate_by_name=True accepting camelCase input :
    rehydrated = SerializedCardContext.model_validate(payload)
    assert rehydrated.card_id == serialized_card_context_full.card_id
    assert rehydrated.life_event == serialized_card_context_full.life_event
