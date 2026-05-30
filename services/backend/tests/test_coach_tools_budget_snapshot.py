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


def test_compute_budget_snapshot_reads_budget_read_model_first() -> None:
    """Backend budget CRUD data must win over stale legacy flat fields."""
    profile_data = {
        "incomeNetMonthly": 5379.0,
        "monthly_income": 999_999.0,
        "monthly_expenses": 888_888.0,
        "budget": {
            "fixed_lines": [
                {"id": "rent", "label": "Loyer", "amount": 2200.0},
                {"id": "lamal", "label": "LAMal", "amount": 420.0},
            ],
            "variable_target_monthly": 520.0,
            "savings_target_monthly": 0.0,
        },
    }

    snap = CoachingEngine.compute_budget_snapshot(profile_data)

    assert snap.monthly_income == Decimal("5379.00")
    assert snap.monthly_expenses == Decimal("3140.00")
    assert snap.monthly_surplus == Decimal("2239.00")


def test_compute_budget_snapshot_accepts_numeric_strings_in_budget_model() -> None:
    """Budget data serialized as strings must not silently drop amounts."""
    profile_data = {
        "incomeNetMonthly": "5'379",
        "budget": {
            "fixed_lines": [
                {"id": "rent", "label": "Loyer", "amount": "2'200"},
                {"id": "lamal", "label": "LAMal", "amount": "420"},
                {"id": "bad", "label": "Ignore", "amount": "n/a"},
            ],
            "variable_target_monthly": "520",
            "savings_target_monthly": "0",
        },
    }

    snap = CoachingEngine.compute_budget_snapshot(profile_data)

    assert snap.monthly_income == Decimal("5379.00")
    assert snap.monthly_expenses == Decimal("3140.00")
    assert snap.monthly_surplus == Decimal("2239.00")


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


def test_legacy_formatter_prefers_coach_context_packet_budget_facts() -> None:
    """Packet values are the trust-aware mobile spine and win over legacy ctx."""
    from app.api.v1.endpoints.coach_chat import _format_budget_status

    result = _format_budget_status(
        {
            "monthly_income": 999_999,
            "monthly_expenses": 888_888,
            "months_liquidity": 12,
            "coach_context_packet": {
                "facts": [
                    {
                        "id": "budget.monthly_net",
                        "domain": "budget",
                        "field_path": "budget.present.monthlyNet",
                        "value": 5379.0,
                    },
                    {
                        "id": "budget.monthly_charges",
                        "domain": "budget",
                        "field_path": "budget.present.monthlyCharges",
                        "value": 3140.0,
                    },
                    {
                        "id": "budget.monthly_free",
                        "domain": "budget",
                        "field_path": "budget.present.monthlyFree",
                        "value": 2239.0,
                    },
                ],
                "missing_fields": [
                    {
                        "field_path": "situation.monthlyHousingCost",
                        "domain": "budget",
                        "reason": "missing_fact",
                    }
                ],
            },
        }
    )

    assert "Revenu net mensuel : CHF 5'379" in result
    assert "Charges mensuelles : CHF 3'140" in result
    assert "Marge libre : CHF 2'239" in result
    assert "Données budget à confirmer : situation.monthlyHousingCost" in result
    assert "999'999" not in result
    assert "888'888" not in result


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


def test_dispatcher_flag_on_prefers_packet_over_stale_db(monkeypatch) -> None:
    """Packet budget facts win over stale DB values even when flag is ON."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    stale_db = _make_mock_db(
        {
            "monthly_income": 999_999.0,
            "monthly_expenses": 888_888.0,
            "months_liquidity": 12.0,
        }
    )
    ctx = {
        "coach_context_packet": {
            "facts": [
                {
                    "id": "budget.monthly_net",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyNet",
                    "value": 5379.0,
                },
                {
                    "id": "budget.monthly_charges",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyCharges",
                    "value": 3140.0,
                },
                {
                    "id": "budget.monthly_free",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyFree",
                    "value": 2239.0,
                },
            ]
        }
    }

    result = _compute_budget_status(user_id="user-abc", ctx=ctx, db=stale_db)

    assert "Revenu net mensuel : CHF 5'379" in result
    assert "Charges mensuelles : CHF 3'140" in result
    assert "Marge libre : CHF 2'239" in result
    assert "999'999" not in result
    assert "888'888" not in result
    stale_db.query.assert_not_called()


def test_dispatcher_flag_on_reads_budget_read_model_when_packet_absent(
    monkeypatch,
) -> None:
    """Without a packet, DB fallback must align with /budget/me shape."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    db = _make_mock_db(
        {
            "incomeNetMonthly": 5379.0,
            "monthly_income": 999_999.0,
            "monthly_expenses": 888_888.0,
            "budget": {
                "fixed_lines": [
                    {"id": "rent", "label": "Loyer", "amount": 2200.0},
                    {"id": "lamal", "label": "LAMal", "amount": 420.0},
                ],
                "variable_target_monthly": 520.0,
                "savings_target_monthly": 0.0,
            },
        }
    )

    raw = _compute_budget_status(user_id="user-abc", ctx={}, db=db)
    payload = json.loads(raw)

    assert payload["monthlyIncome"] == "5379.00"
    assert payload["monthlyExpenses"] == "3140.00"
    assert payload["monthlySurplus"] == "2239.00"
    assert "999999" not in raw
    assert "888888" not in raw


def test_dispatcher_flag_on_preserves_liquidity_with_partial_packet(monkeypatch) -> None:
    """Partial packet facts still win without dropping safe legacy context."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    stale_db = _make_mock_db(
        {
            "monthly_income": 999_999.0,
            "monthly_expenses": 888_888.0,
            "months_liquidity": 99.0,
        }
    )
    ctx = {
        "months_liquidity": 4.6,
        "coach_context_packet": {
            "facts": [
                {
                    "id": "budget.monthly_free",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyFree",
                    "value": 2239.0,
                },
            ]
        },
    }

    result = _compute_budget_status(user_id="user-abc", ctx=ctx, db=stale_db)

    assert "Marge libre : CHF 2'239" in result
    assert "Réserve de liquidités : 4.6 mois" in result
    assert "999'999" not in result
    assert "888'888" not in result
    stale_db.query.assert_not_called()


def test_dispatcher_flag_on_ignores_non_finite_packet_budget_values(monkeypatch) -> None:
    """NaN/inf packet values must not bypass a valid DB budget snapshot."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    db = _make_mock_db(_PROFILE_DATA_FULL)
    ctx = {
        "coach_context_packet": {
            "facts": [
                {
                    "id": "budget.monthly_net",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyNet",
                    "value": float("nan"),
                },
                {
                    "id": "budget.monthly_charges",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyCharges",
                    "value": float("inf"),
                },
            ]
        }
    }

    raw = _compute_budget_status(user_id="user-abc", ctx=ctx, db=db)
    payload = json.loads(raw)

    assert payload["monthlyIncome"] == "7500.00"
    assert payload["monthlyExpenses"] == "5200.00"
    assert "nan" not in raw.lower()
    assert "inf" not in raw.lower()
    db.query.assert_called_once()


def test_dispatcher_flag_on_ignores_stale_or_missing_packet_budget(monkeypatch) -> None:
    """Stale/missing packet facts are not trusted over a valid DB snapshot."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    db = _make_mock_db(_PROFILE_DATA_FULL)
    ctx = {
        "coach_context_packet": {
            "facts": [
                {
                    "id": "budget.monthly_net",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyNet",
                    "value": 999_999.0,
                    "freshness": "stale",
                },
                {
                    "id": "budget.monthly_charges",
                    "domain": "budget",
                    "field_path": "budget.present.monthlyCharges",
                    "value": 888_888.0,
                    "state": "missing",
                },
            ]
        }
    }

    raw = _compute_budget_status(user_id="user-abc", ctx=ctx, db=db)
    payload = json.loads(raw)

    assert payload["monthlyIncome"] == "7500.00"
    assert payload["monthlyExpenses"] == "5200.00"
    assert "999999" not in raw
    assert "888888" not in raw
    db.query.assert_called_once()


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
