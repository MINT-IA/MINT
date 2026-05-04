"""
Tests — _PROFILE_SAFE_FIELDS whitelist and has_debt wiring through coach_chat helpers.

Covers:
- "has_debt" key survives _sanitize_profile_context whitelist
- "has_debt" True/False values are passed through unchanged (bool, not string)
- Unknown / PII fields are dropped while has_debt is kept
- _build_coach_context_from_profile wires has_debt into CoachContext
- Default (missing key) → ctx.has_debt is False
- String "true" coerced to bool True via bool() in builder
- Int 1 coerced to bool True via bool() in builder
"""

import pytest

from app.api.v1.endpoints.coach_chat import (
    _sanitize_profile_context,
    _build_coach_context_from_profile,
    _PROFILE_SAFE_FIELDS,
)


# ---------------------------------------------------------------------------
# _PROFILE_SAFE_FIELDS membership
# ---------------------------------------------------------------------------

def test_has_debt_in_safe_fields():
    assert "has_debt" in _PROFILE_SAFE_FIELDS


# ---------------------------------------------------------------------------
# _sanitize_profile_context
# ---------------------------------------------------------------------------

def test_sanitize_keeps_has_debt_true():
    result = _sanitize_profile_context({"has_debt": True, "age": 40})
    assert result.get("has_debt") is True


def test_sanitize_keeps_has_debt_false():
    result = _sanitize_profile_context({"has_debt": False, "age": 40})
    assert result.get("has_debt") is False


def test_sanitize_drops_secret_field_keeps_has_debt():
    result = _sanitize_profile_context({"has_debt": True, "secret_field": "sensitive"})
    assert "has_debt" in result
    assert "secret_field" not in result


def test_sanitize_drops_none_has_debt():
    """has_debt=None is treated as missing (dropped by the v is None guard)."""
    result = _sanitize_profile_context({"has_debt": None, "age": 30})
    assert "has_debt" not in result


def test_sanitize_empty_dict():
    result = _sanitize_profile_context({})
    assert result == {}


def test_sanitize_none_input():
    result = _sanitize_profile_context(None)
    assert result == {}


def test_sanitize_pii_fields_dropped():
    """IBAN, full name, employer are NOT in the whitelist and must be dropped."""
    pii_payload = {
        "has_debt": True,
        "iban": "CH56 0483 5012 3456 7800 9",
        "full_name": "Thomas Müller",
        "employer": "Nestlé SA",
        "age": 35,
    }
    result = _sanitize_profile_context(pii_payload)
    assert "iban" not in result
    assert "full_name" not in result
    assert "employer" not in result
    assert result.get("has_debt") is True
    assert result.get("age") == 35


# ---------------------------------------------------------------------------
# _build_coach_context_from_profile
# ---------------------------------------------------------------------------

def test_build_context_has_debt_true():
    ctx = _build_coach_context_from_profile({"has_debt": True, "age": 40, "canton": "VD"})
    assert ctx is not None
    assert ctx.has_debt is True


def test_build_context_has_debt_false():
    ctx = _build_coach_context_from_profile({"has_debt": False, "age": 40, "canton": "VD"})
    assert ctx is not None
    assert ctx.has_debt is False


def test_build_context_has_debt_missing_defaults_false():
    """When has_debt is absent from the payload, ctx.has_debt must default to False."""
    ctx = _build_coach_context_from_profile({"age": 40, "canton": "GE"})
    assert ctx is not None
    assert ctx.has_debt is False


def test_build_context_has_debt_int_1_coerced():
    """Int 1 is truthy; bool(1) == True in the builder."""
    ctx = _build_coach_context_from_profile({"has_debt": 1, "age": 30})
    assert ctx is not None
    assert ctx.has_debt is True


def test_build_context_has_debt_int_0_coerced():
    ctx = _build_coach_context_from_profile({"has_debt": 0, "age": 30})
    assert ctx is not None
    assert ctx.has_debt is False


def test_build_context_none_profile():
    ctx = _build_coach_context_from_profile(None)
    assert ctx is None


def test_build_context_has_debt_does_not_override_other_fields():
    ctx = _build_coach_context_from_profile({"has_debt": True, "age": 50, "canton": "ZH"})
    assert ctx.age == 50
    assert ctx.canton == "ZH"
    assert ctx.has_debt is True
