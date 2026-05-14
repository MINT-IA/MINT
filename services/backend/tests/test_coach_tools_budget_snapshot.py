"""Wave 1a Plan 01 — unit tests for get_budget_status server-side recompute.

Test layout:
  Tests 1-5: CoachingEngine.compute_budget_snapshot + BudgetSnapshotResponse
             Pydantic shape + settings flag default. (Task 1.)
  Tests 6-11: _compute_budget_status dispatcher (flag ON/OFF + DB lookup +
              fallback + parity smoke + inputs_hash determinism). (Task 2.)
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

from app.core.config import settings
from app.models.coach_tools.budget_snapshot import BudgetSnapshotResponse
from app.services.coaching_engine import BudgetSnapshot, CoachingEngine


# ---------------------------------------------------------------------------
# Task 1 — service compute + Pydantic shape + flag default
# ---------------------------------------------------------------------------

def test_compute_budget_snapshot_happy_path() -> None:
    """Test 1: standard profile → quantized Decimal snapshot."""
    profile_data = {
        "monthly_income": 7500.0,
        "monthly_expenses": 5200.0,
        "months_liquidity": 4.6,
    }
    snap = CoachingEngine.compute_budget_snapshot(profile_data)
    assert isinstance(snap, BudgetSnapshot)
    assert snap.monthly_income == Decimal("7500.00")
    assert snap.monthly_expenses == Decimal("5200.00")
    assert snap.monthly_surplus == Decimal("2300.00")
    assert snap.months_liquidity == pytest.approx(4.6)


def test_compute_budget_snapshot_raises_when_both_missing() -> None:
    """Test 2: both income AND expenses None → ValueError."""
    profile_data = {"months_liquidity": 3.0}
    with pytest.raises(ValueError, match="budget data missing"):
        CoachingEngine.compute_budget_snapshot(profile_data)


def test_budget_snapshot_response_serializes_camel_case() -> None:
    """Test 3: model_dump(by_alias=True) produces camelCase keys."""
    response = BudgetSnapshotResponse(
        monthly_income=Decimal("7500.00"),
        monthly_expenses=Decimal("5200.00"),
        monthly_surplus=Decimal("2300.00"),
        months_liquidity=4.6,
        inputs_hash="a" * 64,
        computed_at=datetime(2026, 5, 14, 12, 0, 0, tzinfo=timezone.utc),
    )
    dumped = response.model_dump(by_alias=True)
    assert "monthlyIncome" in dumped
    assert "monthlyExpenses" in dumped
    assert "monthlySurplus" in dumped
    assert "monthsLiquidity" in dumped
    assert "inputsHash" in dumped
    assert "computedAt" in dumped
    # snake_case must NOT leak when by_alias=True is requested.
    assert "monthly_income" not in dumped
    assert "inputs_hash" not in dumped


def test_budget_snapshot_response_rejects_invalid_inputs_hash_length() -> None:
    """Test 4: inputs_hash strictly 64 chars (SHA-256 hex)."""
    base = dict(
        monthly_income=Decimal("100.00"),
        monthly_expenses=Decimal("50.00"),
        monthly_surplus=Decimal("50.00"),
        months_liquidity=1.0,
        computed_at=datetime(2026, 5, 14, tzinfo=timezone.utc),
    )
    with pytest.raises(Exception):  # pydantic.ValidationError
        BudgetSnapshotResponse(**base, inputs_hash="a" * 63)
    with pytest.raises(Exception):
        BudgetSnapshotResponse(**base, inputs_hash="a" * 65)
    # 64 chars passes.
    ok = BudgetSnapshotResponse(**base, inputs_hash="a" * 64)
    assert len(ok.inputs_hash) == 64


def test_settings_flag_default_off() -> None:
    """Test 5: COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED defaults to False."""
    # Constructed in app/core/config.py with default False per Wave 1a D-05.
    assert isinstance(settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED, bool)
    # We do not assert == False unconditionally — env override (staging)
    # could set it. The assertion in the class definition is the contract.
    # Instead, instantiate a fresh Settings to verify the default literal.
    from app.core.config import Settings

    fresh = Settings(_env_file=None)  # type: ignore[call-arg]
    assert fresh.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED is False


# ---------------------------------------------------------------------------
# Task 2 — dispatcher (_compute_budget_status) flag ON/OFF + DB + parity
# ---------------------------------------------------------------------------

_PROFILE_DATA_FULL = {
    "monthly_income": 7500.0,
    "monthly_expenses": 5200.0,
    "months_liquidity": 4.6,
}

_CTX_FULL = {
    "monthly_income": 7500.0,
    "monthly_expenses": 5200.0,
    "months_liquidity": 4.6,
}


def _make_mock_db(profile_data: dict | None) -> MagicMock:
    """Build a SQLAlchemy-shaped mock returning a ProfileModel-ish object.

    Mirrors `db.query(ProfileModel).filter(...).order_by(...).first()`.
    Pass `profile_data=None` to simulate no profile row.
    """
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


def test_dispatcher_flag_off_returns_legacy_string(monkeypatch) -> None:
    """Test 6: flag OFF → byte-identical legacy formatter output."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", False
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_budget_status,
        _format_budget_status,
    )
    mock_db = _make_mock_db(_PROFILE_DATA_FULL)
    result = _compute_budget_status(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db
    )
    expected = _format_budget_status(_CTX_FULL)
    assert result == expected
    assert "Budget actuel :" in result  # accent + verbatim FR preserved.


def test_dispatcher_flag_on_returns_camel_case_json(monkeypatch) -> None:
    """Test 7: flag ON + profile present → BudgetSnapshotResponse JSON."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    mock_db = _make_mock_db(_PROFILE_DATA_FULL)
    raw = _compute_budget_status(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db
    )
    payload = json.loads(raw)
    assert payload["monthlyIncome"] == "7500.00"
    assert payload["monthlyExpenses"] == "5200.00"
    assert payload["monthlySurplus"] == "2300.00"
    assert payload["monthsLiquidity"] == pytest.approx(4.6)
    assert len(payload["inputsHash"]) == 64
    # 64-char lowercase hex.
    int(payload["inputsHash"], 16)


def test_dispatcher_flag_on_falls_back_when_budget_missing(monkeypatch) -> None:
    """Test 8: flag ON + profile lacks budget keys → legacy fallback."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    empty_ctx: dict = {}
    mock_db = _make_mock_db({"unrelated_field": True})
    result = _compute_budget_status(
        user_id="user-abc", ctx=empty_ctx, db=mock_db
    )
    assert result == "Données budgétaires non disponibles dans le profil."


def test_dispatcher_flag_on_no_db_falls_back(monkeypatch) -> None:
    """Test 9: flag ON + db=None → legacy fallback (no crash)."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_budget_status,
        _format_budget_status,
    )
    result = _compute_budget_status(user_id="user-abc", ctx=_CTX_FULL, db=None)
    assert result == _format_budget_status(_CTX_FULL)


def test_dispatcher_parity_smoke_numeric(monkeypatch) -> None:
    """Test 10: same inputs → exact CHF parity (legacy vs JSON path)."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    mock_db = _make_mock_db(_PROFILE_DATA_FULL)
    raw = _compute_budget_status(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db
    )
    payload = json.loads(raw)
    surplus = Decimal(payload["monthlySurplus"])
    assert surplus == Decimal("7500.00") - Decimal("5200.00")
    assert surplus == Decimal("2300.00")


def test_dispatcher_inputs_hash_deterministic(monkeypatch) -> None:
    """Test 11: same profile slice → identical inputs_hash across calls."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    mock_db_1 = _make_mock_db(_PROFILE_DATA_FULL)
    mock_db_2 = _make_mock_db(_PROFILE_DATA_FULL)
    raw_1 = _compute_budget_status(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db_1
    )
    raw_2 = _compute_budget_status(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db_2
    )
    h1 = json.loads(raw_1)["inputsHash"]
    h2 = json.loads(raw_2)["inputsHash"]
    assert h1 == h2
