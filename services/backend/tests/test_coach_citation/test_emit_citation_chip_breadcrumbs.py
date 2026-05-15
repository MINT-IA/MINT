"""Direct unit tests for _emit_citation_chip_breadcrumbs().

Wave 1b Plan 08 — extracted from `_run_narrator_with_gate` closure to
module-level so diff-coverage gate (≥80% on changed lines) is satisfied
without exercising the full coach_chat endpoint.

Covers:
  - empty/None gated_text or citation_chips → no emission
  - chip without inputsHash → skipped
  - placeholder not starting with `tool_` → skipped
  - duplicate placeholders → dedup (1 emit per tool short-name)
  - non-tool placeholders mixed with tool_* → only tool_* emit
  - exception inside emit → swallowed (telemetry fail-open)
  - user_id None / present → hashed correctly
"""

from typing import Any
from unittest.mock import patch

from app.api.v1.endpoints.coach_chat import _emit_citation_chip_breadcrumbs


def _make_chip(tool_name: str, inputs_hash: str = "a" * 64) -> dict[str, Any]:
    return {
        "toolName": tool_name,
        "inputsHash": inputs_hash,
        "computedAt": "2026-05-15T00:00:00+00:00",
        "rawResponse": {"placeholder": True},
    }


# ─────────────────────────────────────────────────────────────────────────
# Empty-input guards.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_empty_gated_text_no_emission(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "", [_make_chip("budget_snapshot")], user_id="u1"
    )
    mock_emit.assert_not_called()


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_none_chips_no_emission(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "Hello {{cite:tool_budget_snapshot}}", None, user_id="u1"
    )
    mock_emit.assert_not_called()


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_empty_chips_list_no_emission(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "Hello {{cite:tool_budget_snapshot}}", [], user_id="u1"
    )
    mock_emit.assert_not_called()


# ─────────────────────────────────────────────────────────────────────────
# Happy path — one chip, one placeholder, one emission.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_one_tool_placeholder_emits_once(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "Hello {{cite:tool_budget_snapshot}} world.",
        [_make_chip("budget_snapshot", inputs_hash="b" * 64)],
        user_id="user-42",
    )
    assert mock_emit.call_count == 1
    kwargs = mock_emit.call_args.kwargs
    assert kwargs["tool_name"] == "budget_snapshot"
    assert kwargs["inputs_hash"] == "b" * 64
    assert kwargs["elapsed_ms"] == 0
    assert kwargs["flag_state"] == "on"
    # profile_id_hashed is hashed before emit — opaque to test; just non-empty.
    assert isinstance(kwargs["profile_id_hashed"], str)
    assert kwargs["profile_id_hashed"]


# ─────────────────────────────────────────────────────────────────────────
# Dedup — same tool placeholder twice → 1 emission.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_duplicate_tool_placeholder_emits_once(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "A {{cite:tool_budget_snapshot}} and again "
        "{{cite:tool_budget_snapshot}}.",
        [_make_chip("budget_snapshot")],
        user_id="u",
    )
    assert mock_emit.call_count == 1


# ─────────────────────────────────────────────────────────────────────────
# Non-tool placeholders → skipped silently.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_non_tool_placeholders_skipped(mock_emit: Any) -> None:
    text = (
        "Some {{cite:spec_lpp_buyback}} and "
        "{{cite:adr_calc_first}} and "
        "{{cite:profile_canton_vd}} and "
        "{{cite:reasoning_age_60}}."
    )
    _emit_citation_chip_breadcrumbs(
        text, [_make_chip("budget_snapshot")], user_id="u"
    )
    mock_emit.assert_not_called()


# ─────────────────────────────────────────────────────────────────────────
# Mixed tool + non-tool placeholders → only tools emit.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_mixed_placeholders_only_tools_emit(mock_emit: Any) -> None:
    text = (
        "{{cite:spec_lpp_buyback}} and "
        "{{cite:tool_budget_snapshot}} and "
        "{{cite:tool_retirement_projection}}."
    )
    chips = [
        _make_chip("budget_snapshot", "h1" + "a" * 62),
        _make_chip("retirement_projection", "h2" + "b" * 62),
    ]
    _emit_citation_chip_breadcrumbs(text, chips, user_id="u")
    assert mock_emit.call_count == 2
    emitted_names = {c.kwargs["tool_name"] for c in mock_emit.call_args_list}
    assert emitted_names == {"budget_snapshot", "retirement_projection"}


# ─────────────────────────────────────────────────────────────────────────
# Missing inputsHash → skipped (defensive).
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_chip_missing_inputs_hash_skipped(mock_emit: Any) -> None:
    chip = {"toolName": "budget_snapshot", "computedAt": "2026-05-15"}
    _emit_citation_chip_breadcrumbs(
        "X {{cite:tool_budget_snapshot}}.", [chip], user_id="u"
    )
    mock_emit.assert_not_called()


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_chip_with_empty_inputs_hash_skipped(mock_emit: Any) -> None:
    chip = _make_chip("budget_snapshot", inputs_hash="")
    _emit_citation_chip_breadcrumbs(
        "X {{cite:tool_budget_snapshot}}.", [chip], user_id="u"
    )
    mock_emit.assert_not_called()


# ─────────────────────────────────────────────────────────────────────────
# Tool placeholder with no matching chip → skipped.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_placeholder_without_matching_chip_skipped(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "X {{cite:tool_couple_optimization}}.",
        [_make_chip("budget_snapshot")],
        user_id="u",
    )
    mock_emit.assert_not_called()


# ─────────────────────────────────────────────────────────────────────────
# Non-dict chip entries → silently skipped during chips_by_short build.
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_non_dict_chip_entries_skipped(mock_emit: Any) -> None:
    chips: list[Any] = ["just a string", 42, None]
    _emit_citation_chip_breadcrumbs(
        "X {{cite:tool_budget_snapshot}}.", chips, user_id="u"
    )
    mock_emit.assert_not_called()


# ─────────────────────────────────────────────────────────────────────────
# user_id=None → anonymous path (hash still computed, no crash).
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_user_id_none_uses_anonymous(mock_emit: Any) -> None:
    _emit_citation_chip_breadcrumbs(
        "X {{cite:tool_budget_snapshot}}.",
        [_make_chip("budget_snapshot")],
        user_id=None,
    )
    assert mock_emit.call_count == 1
    assert mock_emit.call_args.kwargs["profile_id_hashed"]


# ─────────────────────────────────────────────────────────────────────────
# Exception inside emit → swallowed (telemetry fail-open).
# ─────────────────────────────────────────────────────────────────────────


@patch("app.observability.coach_breadcrumbs.emit_coach_citation_breadcrumb")
def test_emit_exception_swallowed(mock_emit: Any) -> None:
    mock_emit.side_effect = RuntimeError("Sentry transport down")
    # MUST NOT raise.
    _emit_citation_chip_breadcrumbs(
        "X {{cite:tool_budget_snapshot}}.",
        [_make_chip("budget_snapshot")],
        user_id="u",
    )
    assert mock_emit.call_count == 1  # invoked once, exception swallowed
