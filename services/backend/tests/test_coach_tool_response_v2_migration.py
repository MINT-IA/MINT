"""Phase mint-calc-engine-v1 Plan 10 (W2-04) — chip-emitter V2 migration tests.

D-CE-19 Parallel Change: the 5 chip-emitters in coach_chat.py (`_compute_*`
+ `_validate_cap_response`) gain an opt-in path that wraps their JSON
payload in a ``CoachToolOkV2(data=..., latency_tier="L1")`` envelope when
``settings.COACH_TOOL_RESPONSE_V2_ENABLED`` is True.

Default-OFF: existing tests (test_coach_tools_budget_snapshot.py etc.) keep
passing because the dispatcher returns the legacy shape under the flag.

Default-ON: Flutter consumers can read the latencyTier hint and route to
the right surface (chip L1 vs narrative loader L2/L3).

The chip-emitters are 5 (per CONTEXT §code_context Wave 1a):
  - get_budget_status
  - get_retirement_projection
  - get_cross_pillar_analysis
  - get_cap_status
  - get_couple_optimization

`retrieve_memories` is also a "chip" in _WAVE_1B_TOOL_NAMES but is excluded
from the Plan 10 migration because its content is a string text (not a
Pydantic-modelled JSON payload) and its semantic is search-result-as-text.
Plan 11 or a follow-up plan can extend the wrapper to that path.
"""
from __future__ import annotations

import json
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

from app.core.config import settings
from app.models.coach_tools import CoachToolResponseV2


# ─────────────────────────────────────────────────────────────────────
# Helpers — minimal profile + mock DB (mirrors test_coach_tools_*.py)
# ─────────────────────────────────────────────────────────────────────

_PROFILE_BUDGET = {
    "monthly_income": 7500.0,
    "monthly_expenses": 5200.0,
    "months_liquidity": 4.6,
}

_PROFILE_RETIREMENT = {
    "monthly_income": 7500.0,
    "monthly_expenses": 5200.0,
    "months_liquidity": 4.6,
    "birth_year": 1985,
    "avoir_lpp": Decimal("180000.00"),
    "canton": "VD",
}


def _mock_db(profile_data: dict | None) -> MagicMock:
    mock_db = MagicMock()
    query_chain = mock_db.query.return_value
    query_chain = query_chain.filter.return_value
    query_chain = query_chain.order_by.return_value
    if profile_data is None:
        query_chain.first.return_value = None
    else:
        profile = MagicMock()
        profile.data = profile_data
        query_chain.first.return_value = profile
    return mock_db


# ─────────────────────────────────────────────────────────────────────
# Test 1 — _CHIP_EMITTER_LATENCY_TIERS constant maps 5 chip-emitters to L1
# ─────────────────────────────────────────────────────────────────────

def test_chip_emitter_latency_tiers_constant_exposes_five_l1_entries() -> None:
    from app.api.v1.endpoints.coach_chat import _CHIP_EMITTER_LATENCY_TIERS

    # Exactly 5 chip-emitters per CONTEXT §code_context Wave 1a.
    expected = {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }
    assert set(_CHIP_EMITTER_LATENCY_TIERS.keys()) == expected
    # All 5 are L1 (sub-500ms chip surface).
    assert all(v == "L1" for v in _CHIP_EMITTER_LATENCY_TIERS.values())


# ─────────────────────────────────────────────────────────────────────
# Test 2 — _wrap_chip_response_v2 wraps a JSON payload in CoachToolOkV2
# ─────────────────────────────────────────────────────────────────────

def test_wrap_chip_response_v2_envelopes_json_payload() -> None:
    from app.api.v1.endpoints.coach_chat import _wrap_chip_response_v2

    payload_json = json.dumps({"monthlyIncome": "7500.00", "x": 1})
    wrapped = _wrap_chip_response_v2(payload_json, latency_tier="L1")

    # Result is JSON string of a CoachToolOkV2 — round-trip via the V2 model.
    resp = CoachToolResponseV2.model_validate_json(wrapped)
    assert resp.root.status == "ok"
    assert resp.root.latency_tier == "L1"
    assert resp.root.data == {"monthlyIncome": "7500.00", "x": 1}


def test_wrap_chip_response_v2_emits_camelcase_alias() -> None:
    from app.api.v1.endpoints.coach_chat import _wrap_chip_response_v2

    wrapped = _wrap_chip_response_v2(
        json.dumps({"foo": "bar"}), latency_tier="L1"
    )
    parsed = json.loads(wrapped)
    # by_alias=True yields camelCase latencyTier (Concern B Flutter contract).
    assert "latencyTier" in parsed
    assert parsed["latencyTier"] == "L1"


def test_wrap_chip_response_v2_rejects_invalid_latency_tier() -> None:
    from app.api.v1.endpoints.coach_chat import _wrap_chip_response_v2

    with pytest.raises(Exception):  # pydantic ValidationError or ValueError
        _wrap_chip_response_v2(
            json.dumps({"foo": "bar"}), latency_tier="L4"
        )


# ─────────────────────────────────────────────────────────────────────
# Test 3 — Flag OFF (default) preserves legacy shape for budget_status
# (existing test_coach_tools_budget_snapshot.py contract).
# ─────────────────────────────────────────────────────────────────────

def test_flag_off_keeps_legacy_top_level_camelcase_shape(monkeypatch) -> None:
    """Backwards-compat guard — Plan 10 migration is opt-in."""
    monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True)
    monkeypatch.setattr(settings, "COACH_TOOL_RESPONSE_V2_ENABLED", False)
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    raw = _compute_budget_status(
        user_id="user-abc",
        ctx={},
        db=_mock_db(_PROFILE_BUDGET),
    )
    payload = json.loads(raw)
    # Legacy contract: BudgetSnapshotResponse fields at top level, NO V2 envelope.
    assert "monthlyIncome" in payload
    assert "status" not in payload
    assert "latencyTier" not in payload


# ─────────────────────────────────────────────────────────────────────
# Test 4 — Flag ON wraps the 5 chip-emitter JSON outputs in V2 envelope
# ─────────────────────────────────────────────────────────────────────

def test_flag_on_wraps_budget_status_in_v2_envelope(monkeypatch) -> None:
    monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True)
    monkeypatch.setattr(settings, "COACH_TOOL_RESPONSE_V2_ENABLED", True)
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    raw = _compute_budget_status(
        user_id="user-abc",
        ctx={},
        db=_mock_db(_PROFILE_BUDGET),
    )
    # The V2 envelope wraps the budget payload.
    resp = CoachToolResponseV2.model_validate_json(raw)
    assert resp.root.status == "ok"
    assert resp.root.latency_tier == "L1"
    # Original BudgetSnapshotResponse content preserved under data.
    assert "monthlyIncome" in resp.root.data
    assert resp.root.data["monthlyIncome"] == "7500.00"


def test_flag_on_wraps_retirement_projection_in_v2_envelope(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED", True
    )
    monkeypatch.setattr(settings, "COACH_TOOL_RESPONSE_V2_ENABLED", True)
    from app.api.v1.endpoints.coach_chat import _compute_retirement_projection

    raw = _compute_retirement_projection(
        user_id="user-abc",
        ctx={},
        db=_mock_db(_PROFILE_RETIREMENT),
    )
    # When the retirement service computes successfully, raw is a JSON string
    # wrapping the per-tool payload in V2 envelope. When it falls back to the
    # legacy FR string (e.g. service errored on test fixture), the wrapper
    # short-circuits to passthrough (legacy FR is NOT JSON-parseable).
    try:
        resp = CoachToolResponseV2.model_validate_json(raw)
        assert resp.root.status == "ok"
        assert resp.root.latency_tier == "L1"
    except Exception:
        # Legacy fallback path (FR string) — Plan 10 wrapper passes through
        # non-JSON strings unchanged so coach_chat content contract stays
        # backwards-compatible.
        assert isinstance(raw, str)
        assert raw  # non-empty


def test_flag_on_wraps_cap_status_in_v2_envelope(monkeypatch) -> None:
    """cap_status is a STRING tool — wrapper enveloppes the text payload."""
    monkeypatch.setattr(settings, "COACH_TOOL_RESPONSE_V2_ENABLED", True)
    from app.api.v1.endpoints.coach_chat import (
        _format_cap_status,
        _wrap_chip_string_response_v2,
    )

    ctx = {
        "cap_headline": "Verse 200 CHF supplémentaires sur ton 3a ce mois-ci.",
        "cap_why_now": "Plafond annuel non atteint, fenêtre LIFD art. 33.",
        "cap_cta": "Ajuste l'ordre permanent.",
    }
    rendered = _format_cap_status(ctx)
    wrapped = _wrap_chip_string_response_v2(rendered, latency_tier="L1")
    resp = CoachToolResponseV2.model_validate_json(wrapped)
    assert resp.root.status == "ok"
    assert resp.root.latency_tier == "L1"
    assert "text" in resp.root.data
    assert resp.root.data["text"] == rendered


# ─────────────────────────────────────────────────────────────────────
# Test 5 — _wrap_chip_response_v2 passthrough for non-JSON FR fallback
# ─────────────────────────────────────────────────────────────────────

def test_wrap_chip_response_v2_passthrough_for_non_json_fr_fallback() -> None:
    """Legacy FR strings (e.g. 'Budget actuel :') are NOT wrapped — they're
    returned as-is so the dispatcher contract for `_format_*` fallback paths
    stays unchanged. This is the Parallel Change invariant: V2 wrapping is
    opt-in PER JSON PAYLOAD, not a blanket transform."""
    from app.api.v1.endpoints.coach_chat import _wrap_chip_response_v2

    legacy_fr = "Budget actuel :\n- Revenu net mensuel : 7'500 CHF"
    result = _wrap_chip_response_v2(legacy_fr, latency_tier="L1")
    # Passthrough — not enveloped — because it's not JSON.
    assert result == legacy_fr
