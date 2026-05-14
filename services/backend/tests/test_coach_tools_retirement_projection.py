"""Wave 1a Plan 02 — unit tests for get_retirement_projection server-side recompute.

Test layout:
  Tests 1-6: RetirementProjectionService.compute orchestrator + Pydantic shape
             + flag default + chained-service contract (mock). (Task 1.)
  Tests 7-12: _compute_retirement_projection dispatcher (flag ON/OFF + DB
              lookup + fallback + parity smoke + breadcrumb). (Task 2.)

Real chained-service signatures (verified by pre-execution panel
obs-54a6659a6008b907 + obs-a5f5f19baeb3119b):

  AvsEstimationService().estimate(current_age, retirement_age=65,
        is_couple=False, annees_lacunes=0, life_expectancy=87,
        gross_salary=0.0) -> AvsEstimation
  LppConversionService().compare(capital_lpp, canton="ZH",
        retirement_age=65, life_expectancy=87, taux_marginal_revenu=0.25)
        -> LppConversionResult
  RetirementBudgetService().reconcile(avs_mensuel, lpp_mensuel,
        capital_3a_net, autres_revenus, depenses_mensuelles,
        revenu_pre_retraite, is_couple=False) -> RetirementBudget
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from unittest.mock import MagicMock

import pytest

from app.core.config import settings
from app.models.coach_tools.retirement_projection import (
    RetirementProjectionResponse,
)
from app.services.retirement.retirement_projection_service import (
    RetirementProjection,
    RetirementProjectionService,
)


# ---------------------------------------------------------------------------
# Task 1 — service compute + Pydantic shape + flag default + chain proof
# ---------------------------------------------------------------------------

# camelCase profile (Flutter <-> backend contract). Julien-shaped fixture:
# 40 yo, single, ZH, ~10k CHF/month, 120k LPP avoir, 85k insured salary,
# 30k pillar3a, retire at 65, expenses 7000/mo.
_PROFILE_JULIEN = {
    "birthYear": 1986,
    "householdType": "single",
    "canton": "ZH",
    "avsContributionYears": 22,
    "avoirLpp": 120_000.0,
    "lppInsuredSalary": 85_000.0,
    "pillar3aBalance": 30_000.0,
    "monthlyIncome": 10_000.0,
    "monthlyExpenses": 7_000.0,
    "desiredRetirementAge": 65,
}


def test_compute_retirement_projection_happy_path() -> None:
    """Test 1: full Julien profile -> typed dataclass with quantized Decimals."""
    proj = RetirementProjectionService.compute(_PROFILE_JULIEN)
    assert isinstance(proj, RetirementProjection)
    # Replacement ratio is a 0.0-1.0 RATIO, not a 0-100 percent.
    # Panel obs-a5f5f19baeb3119b C4: critical unit fix.
    assert 0.0 <= proj.replacement_ratio <= 1.0
    # AVS rente is monthly CHF, quantized Decimal.
    assert isinstance(proj.avs_rente, Decimal)
    assert proj.avs_rente > Decimal("0.00")
    # LPP capital should be non-None and quantized when avoirLpp > 0.
    assert isinstance(proj.lpp_capital, Decimal)
    assert proj.lpp_capital > Decimal("0.00")
    # Monthly retirement income is positive CHF.
    assert proj.monthly_retirement_income > Decimal("0.00")
    # current_monthly_income mirrors profile.monthlyIncome.
    assert proj.current_monthly_income == Decimal("10000.00")
    # gap = current - retirement_income (can be positive or negative).
    assert proj.monthly_gap == (
        proj.current_monthly_income - proj.monthly_retirement_income
    )


def test_compute_retirement_projection_raises_when_inputs_missing() -> None:
    """Test 2: missing birthYear AND no monthlyIncome -> ValueError."""
    # No birthYear -> current_age=None -> raises.
    bad_profile: dict = {"householdType": "single"}
    with pytest.raises(ValueError, match="retirement projection inputs missing"):
        RetirementProjectionService.compute(bad_profile)
    # Has birthYear but no avoirLpp AND no monthlyIncome -> raises.
    bad_profile_2 = {"birthYear": 1986}
    with pytest.raises(ValueError, match="retirement projection inputs missing"):
        RetirementProjectionService.compute(bad_profile_2)


def test_retirement_projection_response_serializes_camel_case() -> None:
    """Test 3: model_dump(by_alias=True) produces camelCase keys."""
    response = RetirementProjectionResponse(
        replacement_ratio=0.42,
        avs_rente=Decimal("1900.00"),
        lpp_capital=Decimal("250000.00"),
        monthly_retirement_income=Decimal("4200.00"),
        monthly_gap=Decimal("5800.00"),
        current_monthly_income=Decimal("10000.00"),
        inputs_hash="a" * 64,
        computed_at=datetime(2026, 5, 14, 12, 0, 0, tzinfo=timezone.utc),
    )
    dumped = response.model_dump(by_alias=True)
    assert "replacementRatio" in dumped
    assert "avsRente" in dumped
    assert "lppCapital" in dumped
    assert "monthlyRetirementIncome" in dumped
    assert "monthlyGap" in dumped
    assert "currentMonthlyIncome" in dumped
    assert "inputsHash" in dumped
    assert "computedAt" in dumped
    # snake_case must NOT leak when by_alias=True is requested.
    assert "replacement_ratio" not in dumped
    assert "avs_rente" not in dumped
    assert "inputs_hash" not in dumped


def test_retirement_projection_response_rejects_invalid_hash_length() -> None:
    """Test 4: inputs_hash strictly 64 chars (SHA-256 hex)."""
    base = dict(
        replacement_ratio=0.5,
        avs_rente=Decimal("1000.00"),
        lpp_capital=Decimal("200000.00"),
        monthly_retirement_income=Decimal("3500.00"),
        monthly_gap=Decimal("6500.00"),
        current_monthly_income=Decimal("10000.00"),
        computed_at=datetime(2026, 5, 14, tzinfo=timezone.utc),
    )
    with pytest.raises(Exception):  # pydantic.ValidationError
        RetirementProjectionResponse(**base, inputs_hash="a" * 63)
    with pytest.raises(Exception):
        RetirementProjectionResponse(**base, inputs_hash="a" * 65)
    # 64 chars passes.
    ok = RetirementProjectionResponse(**base, inputs_hash="a" * 64)
    assert len(ok.inputs_hash) == 64
    # lpp_capital is Optional[Decimal] — None must validate too (panel H3).
    base_no_lpp = {**base, "lpp_capital": None}
    ok2 = RetirementProjectionResponse(**base_no_lpp, inputs_hash="a" * 64)
    assert ok2.lpp_capital is None


def test_settings_flag_default_off() -> None:
    """Test 5: COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED defaults False."""
    assert isinstance(
        settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED, bool
    )
    from app.core.config import Settings

    fresh = Settings(_env_file=None)  # type: ignore[call-arg]
    assert fresh.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED is False


def test_chain_calls_all_three_retirement_services(monkeypatch) -> None:
    """Test 6: compute() invokes AvsEstimationService + LppConversionService
    + RetirementBudgetService at least once each (panel obs-54a6659a6008b907
    requirement — no calculation re-implementation, only orchestration)."""
    import app.services.retirement.retirement_projection_service as svc_mod

    avs_called = {"n": 0}
    lpp_called = {"n": 0}
    budget_called = {"n": 0}

    # Stub returns — minimal duck-typed objects with the fields the
    # orchestrator reads. We do NOT rely on the real services' math here;
    # this test ONLY proves the chain wiring (panel SC #6).
    class _StubAvs:
        rente_mensuelle = 1800.0
        rente_annuelle = 23400.0

    class _StubLpp:
        option_capital_net = 240_000.0
        option_rente_nette_mensuelle = 1100.0
        capital_total = 290_000.0

    class _StubBudget:
        total_revenus_mensuels = 3050.0
        solde_mensuel = -3950.0
        taux_remplacement = 30.5  # PERCENT (0-100)

    def _fake_avs_estimate(self, **kwargs):
        avs_called["n"] += 1
        return _StubAvs()

    def _fake_lpp_compare(self, **kwargs):
        lpp_called["n"] += 1
        return _StubLpp()

    def _fake_budget_reconcile(self, **kwargs):
        budget_called["n"] += 1
        return _StubBudget()

    monkeypatch.setattr(
        svc_mod.AvsEstimationService, "estimate", _fake_avs_estimate
    )
    monkeypatch.setattr(
        svc_mod.LppConversionService, "compare", _fake_lpp_compare
    )
    monkeypatch.setattr(
        svc_mod.RetirementBudgetService, "reconcile", _fake_budget_reconcile
    )

    proj = RetirementProjectionService.compute(_PROFILE_JULIEN)
    assert avs_called["n"] >= 1
    assert lpp_called["n"] >= 1
    assert budget_called["n"] >= 1
    # Replacement ratio is 30.5/100 = 0.305 (RATIO, not PERCENT).
    assert proj.replacement_ratio == pytest.approx(0.305)
    assert proj.avs_rente == Decimal("1800.00")
    # LPP capital uses option_capital_net.
    assert proj.lpp_capital == Decimal("240000.00")
    assert proj.monthly_retirement_income == Decimal("3050.00")


# ---------------------------------------------------------------------------
# Task 2 — dispatcher (_compute_retirement_projection) flag ON/OFF + DB + parity
# ---------------------------------------------------------------------------

# Legacy ctx (Flutter-injected today). Used to assert byte-identical fallback.
_CTX_LEGACY = {
    "replacement_ratio": 0.42,
    "monthly_income": 10_000.0,
    "monthly_retirement_income": 4_200.0,
    "lpp_capital": 250_000.0,
    "avs_rente": 22_800.0,
}


def _make_mock_db(profile_data: Optional[dict]) -> MagicMock:
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
    """Test 7: flag OFF -> byte-identical legacy formatter output."""
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        False,
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_retirement_projection,
        _format_retirement_projection,
    )

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    result = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    expected = _format_retirement_projection(_CTX_LEGACY)
    assert result == expected
    # FR text preserved verbatim (accents + LSFin-clean).
    assert "Projection retraite :" in result


def test_dispatcher_flag_on_returns_camel_case_json(monkeypatch) -> None:
    """Test 8: flag ON + profile present -> RetirementProjectionResponse JSON."""
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        True,
    )
    from app.api.v1.endpoints.coach_chat import _compute_retirement_projection

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    raw = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    payload = json.loads(raw)
    assert "replacementRatio" in payload
    assert "avsRente" in payload
    assert "lppCapital" in payload
    assert "monthlyRetirementIncome" in payload
    assert "monthlyGap" in payload
    assert "currentMonthlyIncome" in payload
    assert "inputsHash" in payload
    assert "computedAt" in payload
    # RATIO bounds (0.0-1.0). Critical unit-fix assertion (panel C4 +
    # success_criteria: replacement_ratio MUST NOT exceed 1.0).
    assert 0.0 <= float(payload["replacementRatio"]) <= 1.0
    # 64-char lowercase hex.
    assert len(payload["inputsHash"]) == 64
    int(payload["inputsHash"], 16)


def test_dispatcher_flag_on_falls_back_when_compute_raises(monkeypatch) -> None:
    """Test 9: flag ON + RetirementProjectionService.compute raises ValueError
    -> legacy formatter fallback (no crash, defensive)."""
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        True,
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_retirement_projection,
        _format_retirement_projection,
    )

    # Empty profile_data triggers the ValueError("retirement projection inputs missing")
    # path in compute(). Dispatcher must catch it and fall back.
    mock_db = _make_mock_db({"unrelated": True})
    result = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    # Falls back to legacy formatter.
    assert result == _format_retirement_projection(_CTX_LEGACY)


def test_dispatcher_flag_on_no_db_falls_back(monkeypatch) -> None:
    """Test 10: flag ON + db=None -> legacy fallback (no crash)."""
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        True,
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_retirement_projection,
        _format_retirement_projection,
    )
    result = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=None
    )
    assert result == _format_retirement_projection(_CTX_LEGACY)


def test_dispatcher_inputs_hash_deterministic(monkeypatch) -> None:
    """Test 11: same profile slice -> identical inputs_hash across calls."""
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        True,
    )
    from app.api.v1.endpoints.coach_chat import _compute_retirement_projection

    mock_db_1 = _make_mock_db(_PROFILE_JULIEN)
    mock_db_2 = _make_mock_db(_PROFILE_JULIEN)
    raw_1 = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db_1
    )
    raw_2 = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db_2
    )
    h1 = json.loads(raw_1)["inputsHash"]
    h2 = json.loads(raw_2)["inputsHash"]
    assert h1 == h2


def test_dispatcher_breadcrumb_fires_on_success(monkeypatch) -> None:
    """Test 12: flag ON + success path -> emit_coach_tool_breadcrumb fires
    with tool_name='retirement_projection' (D-15 telemetry contract)."""
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        True,
    )
    captured: dict = {}

    def _capture_breadcrumb(**kwargs):
        captured.update(kwargs)

    # Patch the symbol AT the call site (coach_chat module imports it
    # locally inside the function — we patch the source module so the
    # late-bound import picks up the stub).
    import app.observability.coach_breadcrumbs as bc_mod
    monkeypatch.setattr(
        bc_mod, "emit_coach_tool_breadcrumb", _capture_breadcrumb
    )

    from app.api.v1.endpoints.coach_chat import _compute_retirement_projection

    mock_db = _make_mock_db(_PROFILE_JULIEN)
    _ = _compute_retirement_projection(
        user_id="user-abc", ctx=_CTX_LEGACY, db=mock_db
    )
    assert captured.get("tool_name") == "retirement_projection"
    assert len(captured.get("inputs_hash", "")) == 64
    assert captured.get("flag_state") == "on"
    assert isinstance(captured.get("elapsed_ms"), int)
    assert isinstance(captured.get("profile_id_hashed"), str)
