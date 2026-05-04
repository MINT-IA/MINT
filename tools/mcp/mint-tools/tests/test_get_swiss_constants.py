"""TOOL-01 unit tests. Proves each of the 5 categories returns non-empty
constants, unknown categories return structured empty, and the version
contract holds.
"""
from __future__ import annotations

import pytest

from tools.constants import TOOL_VERSION, ConstantsResult, get_swiss_constants


CATEGORIES = ["pillar3a", "lpp", "avs", "mortgage", "tax"]


@pytest.mark.parametrize("category", CATEGORIES)
def test_happy_path_each_category_returns_nonempty(category: str) -> None:
    result = get_swiss_constants(category)
    assert isinstance(result, ConstantsResult)
    assert result.category == category
    assert result.jurisdiction == "CH"
    assert len(result.constants) > 0, f"Expected >=1 constant for category {category}"
    # Every entry has a non-empty key and a finite numeric value
    for e in result.constants:
        assert e.key, f"Empty key in {category}: {e}"
        assert isinstance(e.value, float)


def test_unknown_category_returns_empty_not_raise() -> None:
    result = get_swiss_constants("not_a_real_category")
    assert result.category == "not_a_real_category"
    assert result.constants == []
    assert result.version == TOOL_VERSION


def test_version_field_is_phase_number() -> None:
    result = get_swiss_constants("pillar3a")
    assert result.version == "30.7.0"


def test_response_is_stateless_across_calls() -> None:
    """Two back-to-back calls must return byte-equal payloads."""
    a = get_swiss_constants("lpp").model_dump()
    b = get_swiss_constants("lpp").model_dump()
    assert a == b


def test_response_schema_is_pydantic_v2() -> None:
    """Verify we use model_dump (Pydantic v2), not .dict() (deprecated)."""
    result = get_swiss_constants("tax")
    dumped = result.model_dump()
    assert "version" in dumped
    assert "category" in dumped
    assert "jurisdiction" in dumped
    assert "constants" in dumped
    assert isinstance(dumped["constants"], list)


def test_effective_from_is_string_not_date() -> None:
    """Regression guard: RegulatoryParameter.effective_from is a date object;
    the tool must normalize to ISO-format string so the Pydantic schema is
    JSON-serialisable by the Wave 2 MCP envelope."""
    result = get_swiss_constants("pillar3a")
    assert len(result.constants) > 0
    for e in result.constants:
        assert isinstance(e.effective_from, str), (
            f"effective_from must be str, got {type(e.effective_from)} for key={e.key}"
        )
        # ISO-format dates look like YYYY-MM-DD or empty string
        if e.effective_from:
            assert len(e.effective_from) >= 10
            assert e.effective_from[4] == "-"
