"""Direct unit tests for _extract_wave_1b_citation_chip().

Plan 04 code-reviewer P0-1: the original implementation used
`tool_name.replace("get_", "")` which strips ALL occurrences and corrupted
`get_budget_status` to `budstatus`. This file pins the exact dispatcher
tool_name → registry short-name mapping so the bug cannot regress.
"""

import json
from typing import Any

import pytest

from app.api.v1.endpoints.coach_chat import _extract_wave_1b_citation_chip


# ─────────────────────────────────────────────────────────────────────────
# P0-1 regression: short-name mapping is explicit, not a string-replace.
# ─────────────────────────────────────────────────────────────────────────


def _pydantic_dump(short_name: str) -> str:
    """Build a fake Wave 1a Pydantic JSON dump with inputsHash + computedAt."""
    return json.dumps(
        {
            "inputsHash": f"hash-{short_name}",
            "computedAt": "2026-05-15T00:00:00+00:00",
            "data": {"placeholder": True},
        }
    )


@pytest.mark.parametrize(
    "tool_name,expected_short",
    [
        ("get_budget_status", "budget_snapshot"),
        ("get_retirement_projection", "retirement_projection"),
        ("get_cross_pillar_analysis", "cross_pillar_analysis"),
        ("get_couple_optimization", "couple_optimization"),
    ],
)
def test_pydantic_tool_short_name_pinned(
    tool_name: str, expected_short: str
) -> None:
    """4 Pydantic-result tools — short_name MUST match registry tool_<short> key."""
    chip = _extract_wave_1b_citation_chip(
        tool_name, _pydantic_dump(expected_short)
    )
    assert chip is not None, f"expected chip for {tool_name}"
    assert chip["toolName"] == expected_short, (
        f"{tool_name} → {chip['toolName']!r}, expected {expected_short!r} "
        f"(registry key: tool_{expected_short})"
    )


@pytest.mark.parametrize(
    "tool_name,expected_short",
    [
        ("get_cap_status", "cap_status"),
        ("retrieve_memories", "retrieve_memories"),
    ],
)
def test_string_tool_short_name_pinned(
    tool_name: str, expected_short: str
) -> None:
    """2 string-result tools — synthetic hash, short_name MUST match registry."""
    chip = _extract_wave_1b_citation_chip(tool_name, "some FR text result")
    assert chip is not None
    assert chip["toolName"] == expected_short


def test_unknown_tool_returns_none() -> None:
    """Non-Wave-1b tools must not produce a chip."""
    assert _extract_wave_1b_citation_chip("save_fact", "{}") is None
    assert _extract_wave_1b_citation_chip("route_to_screen", "{}") is None
    # The literal string `get_budget_status_v2` would have been mapped by the
    # broken replace() variant; explicit dict rejects it.
    assert _extract_wave_1b_citation_chip("get_budget_status_v2", "{}") is None


# ─────────────────────────────────────────────────────────────────────────
# P0-1 regression: empirical guard against str.replace("get_", "").
# ─────────────────────────────────────────────────────────────────────────


def test_budget_short_name_is_not_corrupted() -> None:
    """The exact bug — `get_budget_status` MUST NOT yield `budstatus`."""
    chip = _extract_wave_1b_citation_chip(
        "get_budget_status", _pydantic_dump("budget_snapshot")
    )
    assert chip is not None
    assert chip["toolName"] != "budstatus", (
        "P0-1 regression — tool_name.replace('get_', '') would have stripped "
        "the inner 'get_' inside 'budget' and produced 'budstatus'."
    )
    assert chip["toolName"] == "budget_snapshot"


# ─────────────────────────────────────────────────────────────────────────
# Pydantic / string paths produce the same chip shape.
# ─────────────────────────────────────────────────────────────────────────


def test_pydantic_chip_carries_inputs_hash_and_computed_at_from_payload() -> None:
    chip = _extract_wave_1b_citation_chip(
        "get_retirement_projection", _pydantic_dump("retirement_projection")
    )
    assert chip is not None
    assert chip["inputsHash"] == "hash-retirement_projection"
    assert chip["computedAt"] == "2026-05-15T00:00:00+00:00"
    assert chip["rawResponse"]["data"]["placeholder"] is True


def test_string_chip_synthesises_inputs_hash() -> None:
    """Q9_DECISION — string-result tools synthesise a hash over the text."""
    chip = _extract_wave_1b_citation_chip("get_cap_status", "1 234.56 CHF")
    assert chip is not None
    assert chip["inputsHash"]
    assert len(chip["inputsHash"]) == 64  # sha256 hex
    assert chip["rawResponse"]["text"] == "1 234.56 CHF"


def test_pydantic_chip_skipped_on_legacy_string_result() -> None:
    """Flag-OFF path returns the legacy formatter string; chip must be skipped."""
    chip = _extract_wave_1b_citation_chip(
        "get_budget_status", "Budget: 1234 CHF (legacy formatter)"
    )
    assert chip is None


def test_pydantic_chip_skipped_when_payload_parses_to_non_dict() -> None:
    """JSON parses to a list/scalar (not an object) → skip the chip."""
    assert _extract_wave_1b_citation_chip("get_budget_status", "[1, 2, 3]") is None
    assert _extract_wave_1b_citation_chip("get_budget_status", '"plain"') is None
    assert _extract_wave_1b_citation_chip("get_budget_status", "42") is None


def test_pydantic_chip_skipped_when_missing_hash_or_computed_at() -> None:
    """Valid dict missing inputsHash or computedAt → skip the chip."""
    # Missing inputsHash
    assert (
        _extract_wave_1b_citation_chip(
            "get_budget_status",
            json.dumps({"computedAt": "2026-05-15T00:00:00+00:00"}),
        )
        is None
    )
    # Missing computedAt
    assert (
        _extract_wave_1b_citation_chip(
            "get_budget_status", json.dumps({"inputsHash": "abc"})
        )
        is None
    )
    # Both missing
    assert (
        _extract_wave_1b_citation_chip("get_budget_status", json.dumps({}))
        is None
    )
