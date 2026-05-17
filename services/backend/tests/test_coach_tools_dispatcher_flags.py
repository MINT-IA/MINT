"""Wave 1a plan-08 Task 1 (WAVE1A-10).

Safety-net suite confirming the 6 rollback flags shipped during Wave 1a
gate the dispatcher correctly:

  - 5 server-side per-tool flags (default False):
      COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED              (plan-01)
      COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED (plan-02)
      COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED        (plan-03)
      COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED (plan-04)
      COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED   (plan-05)
  - 1 cap CHF garde flag (default True):
      COACH_CAP_CHF_GARDE_ENABLED                        (plan-06)

Strategy:
  * Flag OFF: monkeypatch the corresponding legacy formatter / handler to
    a sentinel; assert the dispatcher returns the sentinel; assert no
    server-side traversal happened (e.g. db.query not called).
  * Flag ON: monkeypatch the inner service entry point (db.query for the
    4 ProfileModel-backed tools; bm25 for retrieve_memories; the cite
    regex for cap garde) to be observable; assert the server-side path
    was attempted (.called) regardless of downstream outcome.

This file is intentionally *light* — each tool's dedicated test file
(test_coach_tools_<tool>.py) already exhaustively exercises the
success / fallback paths. The contract here is only "flag routing works
at the dispatcher entry point".

13 tests total: 6 tools × 2 (OFF/ON) + 1 defaults audit.
"""
from __future__ import annotations

from unittest.mock import MagicMock

from app.core.config import Settings, settings


# ──────────────────────────────────────────────────────────────────────────
# Flag default values (production-shipped contract)
# ──────────────────────────────────────────────────────────────────────────


def test_all_six_flags_exist_with_correct_defaults() -> None:
    fresh = Settings(_env_file=None)
    assert fresh.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED is False
    assert fresh.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED is False
    assert fresh.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False
    assert fresh.COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED is False
    assert fresh.COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED is False
    assert fresh.COACH_CAP_CHF_GARDE_ENABLED is True


# ──────────────────────────────────────────────────────────────────────────
# get_budget_status flag routing
# ──────────────────────────────────────────────────────────────────────────


def test_budget_status_flag_off_routes_to_legacy_format(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", False
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_budget_status",
        lambda ctx: "LEGACY_BUDGET_OFF",
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    mock_db = MagicMock()
    assert _compute_budget_status(user_id="u", ctx={}, db=mock_db) == "LEGACY_BUDGET_OFF"
    assert not mock_db.query.called


def test_budget_status_flag_on_attempts_server_side(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_budget_status",
        lambda ctx: "LEGACY_BUDGET_ON_FALLBACK",
    )
    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    mock_db = MagicMock()
    mock_db.query.side_effect = RuntimeError("forced — server-side reached")
    _compute_budget_status(user_id="u", ctx={}, db=mock_db)
    assert mock_db.query.called


# ──────────────────────────────────────────────────────────────────────────
# get_retirement_projection flag routing
# ──────────────────────────────────────────────────────────────────────────


def test_retirement_projection_flag_off_routes_to_legacy_format(
    monkeypatch,
) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED", False
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_retirement_projection",
        lambda ctx: "LEGACY_RETIREMENT_OFF",
    )
    from app.api.v1.endpoints.coach_chat import _compute_retirement_projection

    mock_db = MagicMock()
    assert (
        _compute_retirement_projection(user_id="u", ctx={}, db=mock_db)
        == "LEGACY_RETIREMENT_OFF"
    )
    assert not mock_db.query.called


def test_retirement_projection_flag_on_attempts_server_side(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED", True
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_retirement_projection",
        lambda ctx: "LEGACY_RETIREMENT_ON_FALLBACK",
    )
    from app.api.v1.endpoints.coach_chat import _compute_retirement_projection

    mock_db = MagicMock()
    mock_db.query.side_effect = RuntimeError("forced — server-side reached")
    _compute_retirement_projection(user_id="u", ctx={}, db=mock_db)
    assert mock_db.query.called


# ──────────────────────────────────────────────────────────────────────────
# get_cross_pillar_analysis flag routing
# ──────────────────────────────────────────────────────────────────────────


def test_cross_pillar_flag_off_routes_to_legacy_format(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", False
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_cross_pillar_analysis",
        lambda ctx: "LEGACY_CROSS_PILLAR_OFF",
    )
    from app.api.v1.endpoints.coach_chat import _compute_cross_pillar_analysis

    mock_db = MagicMock()
    assert (
        _compute_cross_pillar_analysis(user_id="u", ctx={}, db=mock_db)
        == "LEGACY_CROSS_PILLAR_OFF"
    )
    assert not mock_db.query.called


def test_cross_pillar_flag_on_attempts_server_side(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_cross_pillar_analysis",
        lambda ctx: "LEGACY_CROSS_PILLAR_ON_FALLBACK",
    )
    from app.api.v1.endpoints.coach_chat import _compute_cross_pillar_analysis

    mock_db = MagicMock()
    mock_db.query.side_effect = RuntimeError("forced — server-side reached")
    _compute_cross_pillar_analysis(user_id="u", ctx={}, db=mock_db)
    assert mock_db.query.called


# ──────────────────────────────────────────────────────────────────────────
# get_couple_optimization flag routing
# ──────────────────────────────────────────────────────────────────────────


def test_couple_optimization_flag_off_routes_to_legacy_format(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", False
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_couple_optimization",
        lambda ctx: "LEGACY_COUPLE_OFF",
    )
    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    mock_db = MagicMock()
    assert (
        _compute_couple_optimization(user_id="u", ctx={}, db=mock_db)
        == "LEGACY_COUPLE_OFF"
    )
    assert not mock_db.query.called


def test_couple_optimization_flag_on_attempts_server_side(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._format_couple_optimization",
        lambda ctx: "LEGACY_COUPLE_ON_FALLBACK",
    )
    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    mock_db = MagicMock()
    mock_db.query.side_effect = RuntimeError("forced — server-side reached")
    _compute_couple_optimization(user_id="u", ctx={}, db=mock_db)
    assert mock_db.query.called


# ──────────────────────────────────────────────────────────────────────────
# retrieve_memories flag routing (legacy = _handle_retrieve_memories)
# ──────────────────────────────────────────────────────────────────────────


def test_retrieve_memories_flag_off_routes_to_legacy_handler(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", False
    )
    called = {"legacy": False}

    def _legacy_sentinel(topic, memory_block, max_results, user_id, db):
        called["legacy"] = True
        return "LEGACY_MEMORIES_OFF"

    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._handle_retrieve_memories",
        _legacy_sentinel,
    )
    from app.api.v1.endpoints.coach_chat import _compute_retrieve_memories

    result = _compute_retrieve_memories(
        topic="3a",
        user_id="u",
        db=MagicMock(),
        max_results=3,
        memory_block=None,
    )
    assert result == "LEGACY_MEMORIES_OFF"
    assert called["legacy"]


def test_retrieve_memories_flag_on_invokes_bm25(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )
    bm25_called = {"yes": False}

    def _bm25_sentinel(topic, user_id, db, k):
        bm25_called["yes"] = True
        return []  # empty hits → fallback to legacy handler

    monkeypatch.setattr(
        "app.services.memory.bm25.retrieve", _bm25_sentinel
    )
    monkeypatch.setattr(
        "app.api.v1.endpoints.coach_chat._handle_retrieve_memories",
        lambda **_: "LEGACY_MEMORIES_FALLBACK",
    )
    from app.api.v1.endpoints.coach_chat import _compute_retrieve_memories

    _compute_retrieve_memories(
        topic="3a",
        user_id="u",
        db=MagicMock(),
        max_results=3,
        memory_block=None,
    )
    assert bm25_called["yes"]


# ──────────────────────────────────────────────────────────────────────────
# get_cap_status CHF garde flag routing (gate = _validate_cap_response)
# ──────────────────────────────────────────────────────────────────────────


def test_cap_garde_flag_off_passes_through(monkeypatch) -> None:
    monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", False)
    from app.api.v1.endpoints.coach_chat import _validate_cap_response

    raw = "Cap : retire 3'000 CHF du compte courant."
    assert _validate_cap_response(raw) == raw


def test_cap_garde_flag_on_strips_uncited_chf(monkeypatch) -> None:
    monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", True)
    from app.api.v1.endpoints.coach_chat import _validate_cap_response

    raw = "Cap : retire 3'000 CHF du compte courant."
    sanitized = _validate_cap_response(raw)
    assert "[montant indisponible]" in sanitized
    assert "3'000 CHF" not in sanitized
