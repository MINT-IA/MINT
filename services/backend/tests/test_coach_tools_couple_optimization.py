"""Wave 1a Plan 04 — dispatcher tests for `_compute_couple_optimization`.

Tests 1-9 cover the flag-gated wrapper on coach_chat.py (inserted above
`_format_couple_optimization` per CONTEXT D-08):

  Test 1: flag OFF → byte-identical legacy formatter output.
  Test 2: flag ON  + valid profile in DB → CoupleOptimizationResponse JSON
          with camelCase nested keys.
  Test 3: flag ON  + single-status profile → 4 sub-fields None +
          valid inputsHash (64 chars).
  Test 4: flag ON  + user_id=None OR db=None → legacy fallback.
  Test 5: flag ON  + DB returns no ProfileModel → legacy fallback.
  Test 6: flag ON  + CoupleOptimizer.optimize raises → defensive Exception
          fallback (no crash).
  Test 7: flag ON  + same profile across 2 calls → identical inputs_hash.
  Test 8: D-15 5-kwarg breadcrumb contract (tool_name="couple_optimization",
          inputs_hash, profile_id_hashed, elapsed_ms, flag_state="on").
  Test 9: D-15 non-PII — profile_id_hashed is 16 chars, NOT raw user_id.
"""

from __future__ import annotations

import json
from typing import Any, Dict, Optional
from unittest.mock import MagicMock


from app.core.config import settings


_PROFILE_JULIEN: Dict[str, Any] = {
    "salaireBrutMensuel": 15_000.0,
    "nombreDeMois": 13,
    "etatCivil": "marie",
    "canton": "ZH",
    "nombreEnfants": 2,
    "birthYear": 1985,
    "gender": "M",
    "prevoyance": {"rachatMaximum": 50_000.0, "rachatEffectue": 0.0},
    "desiredRetirementAge": 65,
    "conjoint": {
        "salaireBrutMensuel": 4_000.0,
        "nombreDeMois": 12,
        "canContribute3a": True,
        "birthYear": 1988,
        "gender": "F",
        "prevoyance": {"rachatMaximum": 10_000.0, "rachatEffectue": 0.0},
        "targetRetirementAge": 65,
    },
}

# Legacy ctx (Flutter-injected today). Used to assert byte-identical fallback.
_CTX_LEGACY: Dict[str, Any] = {
    "civil_status": "marie",
    "couple_optimization": {
        "lpp_buyback": {
            "winner": "main_user",
            "saving_delta": 499.88,
            "reason": "Taux marginal plus élevé → économie fiscale supérieure par CHF racheté.",
            "trade_off": "Le rachat LPP est bloqué 3 ans avant le retrait (LPP art. 79b al. 3). Le timing dépend aussi de l'âge de chaque personne.",
        },
        "pillar_3a": {
            "winner": "main_user",
            "reason": "Revenu imposable plus élevé → déduction 3a plus avantageuse.",
            "trade_off": "Le plafond 3a est individuel (CHF 7258/an). Les deux partenaires peuvent verser chacun le maximum.",
        },
        "avs_cap": {
            "cap_applied": True,
            "monthly_reduction": 605.16,
        },
        "marriage_penalty": {
            "has_penalty": False,
            "annual_delta": -6813.9,
        },
    },
}


def _make_mock_db(profile_data: Optional[Dict[str, Any]]) -> MagicMock:
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


# ---------------------------------------------------------------------------
# Test 1 — flag OFF byte-identity
# ---------------------------------------------------------------------------


def test_dispatcher_flag_off_returns_legacy_string(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", False
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_couple_optimization,
        _format_couple_optimization,
    )

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    result = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    expected = _format_couple_optimization(_CTX_LEGACY)
    assert result == expected
    # FR text preserved verbatim (accents + LSFin-clean).
    assert "Optimisation couple :" in result


# ---------------------------------------------------------------------------
# Test 2 — flag ON returns Pydantic JSON in camelCase
# ---------------------------------------------------------------------------


def test_dispatcher_flag_on_returns_camel_case_json(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    raw = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    payload = json.loads(raw)
    # Top-level camelCase nested keys.
    assert "lppBuyback" in payload
    # pillar_3a maps to "pillar3A" via to_camel; tolerate both spellings.
    p3a_key = "pillar3A" if "pillar3A" in payload else "pillar3a"
    assert p3a_key in payload
    assert "avsCap" in payload
    assert "marriagePenalty" in payload
    assert "inputsHash" in payload
    assert "computedAt" in payload
    # Sub-field camelCase under lppBuyback.
    assert payload["lppBuyback"]["savingDelta"]
    assert "tradeOff" in payload["lppBuyback"]
    # 64-char lowercase hex hash.
    assert len(payload["inputsHash"]) == 64
    int(payload["inputsHash"], 16)


# ---------------------------------------------------------------------------
# Test 3 — flag ON + single profile → all None sub-fields + valid hash
# ---------------------------------------------------------------------------


def test_dispatcher_flag_on_single_profile_returns_empty_subfields(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    single_profile = {
        "salaireBrutMensuel": 8_000.0,
        "nombreDeMois": 12,
        "etatCivil": "celibataire",
        "canton": "VD",
        "nombreEnfants": 0,
        "birthYear": 1990,
        "conjoint": None,
    }
    mock_db = _make_mock_db(single_profile)
    raw = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    payload = json.loads(raw)
    assert payload.get("lppBuyback") is None
    p3a_key = "pillar3A" if "pillar3A" in payload else "pillar3a"
    assert payload.get(p3a_key) is None
    assert payload.get("avsCap") is None
    assert payload.get("marriagePenalty") is None
    assert len(payload["inputsHash"]) == 64


# ---------------------------------------------------------------------------
# Test 4 — user_id None / db None → legacy fallback
# ---------------------------------------------------------------------------


def test_dispatcher_no_user_id_or_no_db_falls_back(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_couple_optimization,
        _format_couple_optimization,
    )

    expected = _format_couple_optimization(_CTX_LEGACY)
    # db=None
    assert (
        _compute_couple_optimization(
            user_id="user-abc", ctx=_CTX_LEGACY, db=None
        )
        == expected
    )
    # user_id=None
    mock_db = _make_mock_db(_PROFILE_JULIEN)
    assert (
        _compute_couple_optimization(user_id=None, ctx=_CTX_LEGACY, db=mock_db)
        == expected
    )


# ---------------------------------------------------------------------------
# Test 5 — DB lookup returns None → legacy fallback
# ---------------------------------------------------------------------------


def test_dispatcher_db_no_profile_falls_back(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_couple_optimization,
        _format_couple_optimization,
    )

    mock_db = _make_mock_db(None)  # no profile row.
    result = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    assert result == _format_couple_optimization(_CTX_LEGACY)


# ---------------------------------------------------------------------------
# Test 6 — CoupleOptimizer.optimize raises → defensive fallback
# ---------------------------------------------------------------------------


def test_dispatcher_optimize_raises_falls_back(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    # Patch CoupleOptimizer.optimize at its source module so the lazy
    # import inside _compute_couple_optimization resolves to the stub.
    import app.services.couple_optimizer.couple_optimizer as port_mod

    def _raise(*_args, **_kwargs):
        raise ValueError("boom — synthetic failure")

    monkeypatch.setattr(port_mod.CoupleOptimizer, "optimize", staticmethod(_raise))

    from app.api.v1.endpoints.coach_chat import (
        _compute_couple_optimization,
        _format_couple_optimization,
    )

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    result = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    assert result == _format_couple_optimization(_CTX_LEGACY)


# ---------------------------------------------------------------------------
# Test 7 — inputs_hash deterministic across 2 calls
# ---------------------------------------------------------------------------


def test_dispatcher_inputs_hash_deterministic(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    mock_db_1 = _make_mock_db(_PROFILE_JULIEN)
    mock_db_2 = _make_mock_db(_PROFILE_JULIEN)
    raw_1 = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db_1
    )
    raw_2 = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db_2
    )
    h1 = json.loads(raw_1)["inputsHash"]
    h2 = json.loads(raw_2)["inputsHash"]
    assert h1 == h2


# ---------------------------------------------------------------------------
# Test 8 — D-15 5-kwarg breadcrumb contract
# ---------------------------------------------------------------------------


def test_dispatcher_breadcrumb_d15_contract(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    captured: Dict[str, Any] = {}

    def _capture_breadcrumb(**kwargs: Any) -> None:
        captured.update(kwargs)

    # Patch at the source module — _compute_couple_optimization imports lazily.
    import app.observability.coach_breadcrumbs as bc_mod
    monkeypatch.setattr(bc_mod, "emit_coach_tool_breadcrumb", _capture_breadcrumb)

    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    _ = _compute_couple_optimization(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    # D-15 exact 5-kwarg contract.
    assert set(captured.keys()) == {
        "tool_name",
        "inputs_hash",
        "profile_id_hashed",
        "elapsed_ms",
        "flag_state",
    }
    assert captured["tool_name"] == "couple_optimization"
    assert len(captured["inputs_hash"]) == 64
    assert captured["flag_state"] == "on"
    assert isinstance(captured["elapsed_ms"], int)
    assert isinstance(captured["profile_id_hashed"], str)


# ---------------------------------------------------------------------------
# Test 9 — D-15 non-PII: profile_id_hashed is 16 chars, NOT raw user_id
# ---------------------------------------------------------------------------


def test_dispatcher_breadcrumb_profile_id_hashed_is_not_raw(monkeypatch) -> None:
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True
    )
    captured: Dict[str, Any] = {}

    def _capture_breadcrumb(**kwargs: Any) -> None:
        captured.update(kwargs)

    import app.observability.coach_breadcrumbs as bc_mod
    monkeypatch.setattr(bc_mod, "emit_coach_tool_breadcrumb", _capture_breadcrumb)

    from app.api.v1.endpoints.coach_chat import _compute_couple_optimization

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    _ = _compute_couple_optimization(
        user_id="user-abc-secret-pii-marker", ctx=_CTX_LEGACY, db=mock_db
    )
    assert captured["profile_id_hashed"] != "user-abc-secret-pii-marker"
    # 16-char hex prefix per app.utils.hashing.hash_profile_id contract.
    assert len(captured["profile_id_hashed"]) == 16
    int(captured["profile_id_hashed"], 16)  # valid hex.


# ---------------------------------------------------------------------------
# WS-A (plan 03 Task 2) — get_couple_optimization tool description must be
# education-strict (scenarios side-by-side, explicit assumptions) with ZERO
# residual ranked-ish/ordering language. The « sans ranking » framing already
# present (plan-check correction) must be preserved.
# ---------------------------------------------------------------------------


def _couple_tool_description() -> str:
    """Fetch the get_couple_optimization tool description from COACH_TOOLS."""
    from app.services.coach.coach_tools import COACH_TOOLS

    entry = next(
        t for t in COACH_TOOLS if t["name"] == "get_couple_optimization"
    )
    return entry["description"]


def test_couple_tool_description_has_no_residual_ranked_ordering_language() -> None:
    desc = _couple_tool_description()
    # Residual ranked-ish/ordering fragments must be gone (small-diff target).
    assert "l'ordre de rachat" not in desc, (
        "residual inter-spouse ordering claim « l'ordre de rachat … » must "
        "be removed (WS-A education-strict)"
    )
    assert "l'ordre de" not in desc, "no ordering language « l'ordre de … »"
    assert "la meilleure répartition" not in desc
    assert "tu devrais" not in desc
    # No LSFin banned ranking adjectives.
    for banned in ("optimal", "meilleur", "garanti"):
        assert banned not in desc.lower(), f"banned ranked term « {banned} »"


def test_couple_tool_description_preserves_education_comparison_framing() -> None:
    desc = _couple_tool_description()
    # « sans ranking » framing is preserved (plan-check: already present).
    assert "sans ranking" in desc
    # Still a comparison of scenarios (side-by-side, no personalised arbitrage).
    assert "scénarios" in desc.lower() or "compar" in desc.lower()
