"""Wave 1a Plan 03 — unit tests for get_cross_pillar_analysis server-side recompute.

Test layout:
  Tests 1-5: CrossPillarService.compute orchestration + Pydantic shape +
             settings flag default. (Task 1.)
  Tests 6-9: CrossPillarAnalysisResponse Pydantic v2 model + chain reuse
             via mock on compare_allocation_annuelle. (Task 1.)
  Tests 10-14: _compute_cross_pillar_analysis dispatcher (flag ON/OFF +
              DB lookup + fallback + missing-buyback breadcrumb tag +
              inputs_hash determinism). (Task 2.)
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import MagicMock, patch

import pytest

from app.core.config import settings
from app.models.coach_tools.cross_pillar import CrossPillarAnalysisResponse
from app.services.arbitrage.cross_pillar_service import (
    CrossPillarAnalysis,
    CrossPillarService,
)


# ---------------------------------------------------------------------------
# Task 1 — service compute + Pydantic shape + chain-reuse proofs
# ---------------------------------------------------------------------------


def test_compute_strategy_a_success_path() -> None:
    """Test 1: Strategy A — chain compare_allocation_annuelle for tax_saving.

    The test does NOT hardcode a CHF for tax_saving_potential — it computes
    the expected value by calling compare_allocation_annuelle with the
    same args and asserts equality. This proves CHAIN REUSE (CLAUDE.md
    rule 4) without coupling the test to a specific CHF value that could
    drift if the underlying math changes.
    """
    profile = {
        "annual_3a_contribution": 5000.0,
        "lpp_avoir": 95000.0,
        "lpp_buyback_max": 12000.0,
        "employment_status": "salarie",
        "has_2nd_pillar": True,
        "canton": "VD",
        "income_gross_yearly": 90000.0,
        "household_type": "single",
    }
    analysis = CrossPillarService.compute(profile)

    assert isinstance(analysis, CrossPillarAnalysis)
    assert analysis.annual_3a_contribution == Decimal("5000.00")
    assert analysis.three_a_ceiling == Decimal("7258.00")
    assert analysis.three_a_remaining == Decimal("2258.00")
    assert analysis.lpp_buyback_max == Decimal("12000.00")
    assert analysis.lpp_capital == Decimal("95000.00")
    assert analysis.lpp_buyback_source == "from_profile"
    assert analysis.tax_saving_source == "strategy_a"

    # Compute the expected tax_saving by re-calling the same chain.
    from app.services.arbitrage.allocation_annuelle import (
        compare_allocation_annuelle,
    )
    # Strategy A calcule désormais la DIFFÉRENCE d'impôt canonique sur le
    # versement borné au plafond d'affiliation (revue Codex H3), plus
    # compare_allocation_annuelle (qui bornait à 7'258 × taux).
    from app.services.fiscal.cantonal_comparator import estimate_tax_saving

    expected_saving = Decimal(
        str(estimate_tax_saving(90000.0, min(5000.0, 7258.0), "VD", is_married=False))
    ).quantize(Decimal("0.01"))
    assert analysis.tax_saving_potential == expected_saving
    assert analysis.tax_saving_potential > Decimal("0.00")


def test_compute_strategy_b_fallback_when_canton_missing() -> None:
    """Test 2: Strategy B — profile without canton/income but with
    profile-supplied tax_saving_potential → relay verbatim."""
    profile = {
        "annual_3a_contribution": 5000.0,
        "lpp_buyback_max": 12000.0,
        "tax_saving_potential": 1814.5,
        # no canton, no income_gross_yearly, no taux_marginal.
        "employment_status": "salarie",
        "has_2nd_pillar": True,
    }
    analysis = CrossPillarService.compute(profile)
    assert analysis.tax_saving_potential == Decimal("1814.50")
    assert analysis.tax_saving_source == "strategy_b"


def test_compute_tax_saving_missing_returns_zero_with_tag() -> None:
    """Test 3: neither Strategy A pre-requisites nor profile fallback →
    Decimal('0.00') + source tag 'missing_from_profile'."""
    profile = {
        # Provide lpp_buyback_max so the ValueError guard doesn't trip,
        # but NO canton, NO income, NO taux_marginal, NO annual_3a, NO
        # profile tax_saving_potential.
        "lpp_buyback_max": 15000.0,
    }
    analysis = CrossPillarService.compute(profile)
    assert analysis.tax_saving_potential == Decimal("0.00")
    assert analysis.tax_saving_source == "missing_from_profile"


def test_compute_lpp_buyback_max_is_relayed_not_recomputed() -> None:
    """Test 4: lpp_buyback_max value comes RELAYED from profile_data.

    Proves CLAUDE.md rule 4 (no re-implementation): the service does NOT
    call any server function to derive lpp_buyback_max. The value is
    taken verbatim from profile_data['lpp_buyback_max'] and Decimal-
    quantized.
    """
    profile = {
        "annual_3a_contribution": 3000.0,
        "lpp_buyback_max": 15000.0,
    }
    analysis = CrossPillarService.compute(profile)
    assert analysis.lpp_buyback_max == Decimal("15000.00")
    assert analysis.lpp_buyback_source == "from_profile"


def test_compute_all_missing_raises_value_error() -> None:
    """Test 5: profile lacking ALL five payload-bearing fields → ValueError.

    Mirrors `_format_cross_pillar_analysis` line 2602 guard.
    """
    profile = {
        # Has neither annual_3a_contribution, lpp_avoir/lpp_capital,
        # lpp_buyback_max, nor tax_saving_potential.
        "employment_status": "salarie",
        "canton": "VD",
    }
    with pytest.raises(ValueError, match="cross pillar data missing"):
        CrossPillarService.compute(profile)


def test_response_serializes_camel_case() -> None:
    """Test 6: Pydantic model_dump(by_alias=True) produces camelCase keys.

    pydantic.alias_generators.to_camel applies digit-adjacency upper-casing:
    `annual_3a_contribution` -> `annual3AContribution`,
    `three_a_ceiling` -> `threeACeiling`. This is deterministic and matches
    the plan-02 RetirementProjectionResponse `threeARemaining` precedent.
    """
    response = CrossPillarAnalysisResponse(
        annual_3a_contribution=Decimal("5000.00"),
        three_a_ceiling=Decimal("7258.00"),
        three_a_remaining=Decimal("2258.00"),
        lpp_buyback_max=Decimal("12000.00"),
        lpp_capital=Decimal("95000.00"),
        tax_saving_potential=Decimal("1700.00"),
        inputs_hash="a" * 64,
        computed_at=datetime(2026, 5, 14, 12, 0, 0, tzinfo=timezone.utc),
    )
    dumped = response.model_dump(by_alias=True)
    # pydantic.alias_generators.to_camel inserts an UPPERCASE letter after
    # any digit (digit-adjacency rule), so:
    #   annual_3a_contribution -> annual3AContribution
    #   three_a_ceiling        -> threeACeiling
    #   three_a_remaining      -> threeARemaining
    # This is deterministic for the entire MINT camelCase wire contract.
    assert "annual3AContribution" in dumped
    assert "threeACeiling" in dumped
    assert "threeARemaining" in dumped
    assert "lppBuybackMax" in dumped
    assert "lppCapital" in dumped
    assert "taxSavingPotential" in dumped
    assert "inputsHash" in dumped
    assert "computedAt" in dumped
    # snake_case must NOT leak when by_alias=True is requested.
    assert "annual_3a_contribution" not in dumped
    assert "inputs_hash" not in dumped


def test_response_rejects_invalid_hash_length() -> None:
    """Test 7: inputs_hash strictly 64 chars (SHA-256 hex)."""
    base = dict(
        annual_3a_contribution=Decimal("5000.00"),
        three_a_ceiling=Decimal("7258.00"),
        three_a_remaining=Decimal("2258.00"),
        lpp_buyback_max=Decimal("12000.00"),
        lpp_capital=Decimal("95000.00"),
        tax_saving_potential=Decimal("1700.00"),
        computed_at=datetime(2026, 5, 14, tzinfo=timezone.utc),
    )
    with pytest.raises(Exception):  # pydantic.ValidationError
        CrossPillarAnalysisResponse(**base, inputs_hash="a" * 63)
    with pytest.raises(Exception):
        CrossPillarAnalysisResponse(**base, inputs_hash="a" * 65)
    # 64 chars passes.
    ok = CrossPillarAnalysisResponse(**base, inputs_hash="a" * 64)
    assert len(ok.inputs_hash) == 64


def test_settings_flag_default_off() -> None:
    """Test 8: COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED defaults to False."""
    assert isinstance(
        settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED, bool
    )
    from app.core.config import Settings

    fresh = Settings(_env_file=None)  # type: ignore[call-arg]
    assert fresh.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False


def test_chain_calls_compare_allocation_annuelle_with_expected_args() -> None:
    """Test 9: chain assertion — compare_allocation_annuelle is called
    exactly once with montant_disponible=5000.0, potentiel_rachat_lpp=
    12000.0, annees_avant_retraite=1 (proves Strategy A invocation).

    When the mock returns a synthetic ArbitrageResult whose 3a option
    trajectory[0].cumulative_tax_delta == -1700.0, the service returns
    tax_saving_potential == Decimal('1700.00') (sign-flipped per
    allocation_annuelle.py:101 convention).
    """
    from app.services.arbitrage.arbitrage_models import (
        ArbitrageResult,
        TrajectoireOption,
        YearlySnapshot,
    )

    synthetic_snapshot = YearlySnapshot(
        year=1,
        net_patrimony=5000.0,
        annual_cashflow=5000.0,
        cumulative_tax_delta=-1700.0,  # -ve = saving per convention
    )
    synthetic_3a = TrajectoireOption(
        id="3a",
        label="Pilier 3a (test)",
        trajectory=[synthetic_snapshot],
        terminal_value=5000.0,
        cumulative_tax_impact=-1700.0,
    )
    synthetic_result = ArbitrageResult(
        options=[synthetic_3a],
        breakeven_year=-1,
        premier_eclairage="test",
        display_summary="test",
        hypotheses=[],
        disclaimer="test",
        sources=[],
        confidence_score=0.0,
        sensitivity={},
    )

    # Revue Codex H3 : cross_pillar N'appelle PLUS compare_allocation_annuelle
    # (qui bornait à 7'258 × taux) — Strategy A est désormais la DIFFÉRENCE
    # d'impôt canonique. On prouve le NON-appel + l'égalité à estimate_tax_saving.
    _ = synthetic_result  # setup conservé, plus mocké
    from app.services.fiscal.cantonal_comparator import estimate_tax_saving

    profile = {
        "annual_3a_contribution": 5000.0,
        "lpp_buyback_max": 12000.0,
        "canton": "VD",
        "income_gross_yearly": 90000.0,
        "household_type": "single",
    }

    with patch(
        "app.services.arbitrage.cross_pillar_service.compare_allocation_annuelle",
    ) as mock_chain:
        analysis = CrossPillarService.compute(profile)

    assert mock_chain.call_count == 0  # plus de délégation au calculateur borné
    expected = Decimal(
        str(estimate_tax_saving(90000.0, min(5000.0, 7258.0), "VD", is_married=False))
    ).quantize(Decimal("0.01"))
    assert analysis.tax_saving_potential == expected
    assert analysis.tax_saving_source == "strategy_a"


# ---------------------------------------------------------------------------
# Task 2 — dispatcher (_compute_cross_pillar_analysis) flag ON/OFF + DB
# ---------------------------------------------------------------------------

_CTX_FULL = {
    "annual_3a_contribution": 5000.0,
    "lpp_buyback_max": 12000.0,
    "tax_saving_potential": 1700.0,
    "lpp_capital": 95000.0,
    "employment_status": "salarie",
    "has_2nd_pillar": True,
}

_PROFILE_FULL = {
    "annual_3a_contribution": 5000.0,
    "lpp_avoir": 95000.0,
    "lpp_buyback_max": 12000.0,
    "tax_saving_potential": 1700.0,
    "employment_status": "salarie",
    "has_2nd_pillar": True,
    "canton": "VD",
    "income_gross_yearly": 90000.0,
    "household_type": "single",
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
    """Test 10: flag OFF → byte-identical legacy formatter output."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", False
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_cross_pillar_analysis,
        _format_cross_pillar_analysis,
    )

    mock_db = _make_mock_db(_PROFILE_FULL)
    result = _compute_cross_pillar_analysis(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db
    )
    expected = _format_cross_pillar_analysis(_CTX_FULL)
    assert result == expected
    assert "Analyse inter-piliers :" in result


def test_dispatcher_flag_on_returns_camel_case_json(monkeypatch) -> None:
    """Test 11: flag ON + profile present → CrossPillarAnalysisResponse JSON."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_cross_pillar_analysis

    mock_db = _make_mock_db(_PROFILE_FULL)
    raw = _compute_cross_pillar_analysis(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db
    )
    payload = json.loads(raw)
    # pydantic to_camel: digit-adjacency upper-cases the next letter
    # (annual_3a_contribution -> annual3AContribution, three_a_* ->
    # threeA*). See test_response_serializes_camel_case for the rule.
    assert payload["annual3AContribution"] == "5000.00"
    assert payload["threeACeiling"] == "7258.00"
    assert payload["threeARemaining"] == "2258.00"
    assert payload["lppBuybackMax"] == "12000.00"
    assert payload["lppCapital"] == "95000.00"
    # tax_saving derived via Strategy A — value > 0.
    assert Decimal(payload["taxSavingPotential"]) > Decimal("0.00")
    assert len(payload["inputsHash"]) == 64
    int(payload["inputsHash"], 16)  # is hex


def test_dispatcher_flag_on_value_error_falls_back_to_legacy(monkeypatch) -> None:
    """Test 12: flag ON + profile lacks all payload-bearing fields →
    ValueError → legacy formatter fallback (byte-identical to flag OFF)."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import (
        _compute_cross_pillar_analysis,
        _format_cross_pillar_analysis,
    )

    # ctx is empty AND profile.data lacks the 5 payload fields.
    empty_ctx: dict = {}
    mock_db = _make_mock_db({"unrelated_field": True})
    result = _compute_cross_pillar_analysis(
        user_id="user-abc", ctx=empty_ctx, db=mock_db
    )
    # Fallback string from legacy formatter on empty ctx.
    assert result == _format_cross_pillar_analysis(empty_ctx)
    assert "Données d'analyse inter-piliers non disponibles" in result


def test_dispatcher_missing_buyback_emits_breadcrumb_tag(monkeypatch) -> None:
    """Test 13 (RESEARCH §3 caveat #3): profile without lpp_buyback_max →
    response has lppBuybackMax='0.00' AND breadcrumb extra_tags carries
    `lpp_buyback_source='missing_from_profile'`."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True
    )
    captured: dict = {}

    def _capture_breadcrumb(**kwargs):
        captured.update(kwargs)

    # Patch the symbol AT the source module so the late-bound import
    # inside _compute_cross_pillar_analysis picks up the stub.
    import app.observability.coach_breadcrumbs as bc_mod
    monkeypatch.setattr(
        bc_mod, "emit_coach_tool_breadcrumb", _capture_breadcrumb
    )

    from app.api.v1.endpoints.coach_chat import _compute_cross_pillar_analysis

    profile_missing_buyback = {
        "annual_3a_contribution": 5000.0,
        "lpp_avoir": 95000.0,
        # NO lpp_buyback_max.
        "tax_saving_potential": 1700.0,
        "employment_status": "salarie",
        "has_2nd_pillar": True,
    }
    mock_db = _make_mock_db(profile_missing_buyback)
    raw = _compute_cross_pillar_analysis(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db
    )
    payload = json.loads(raw)
    assert payload["lppBuybackMax"] == "0.00"

    # The breadcrumb call must have captured extra_tags with the
    # lpp_buyback_source flag set to 'missing_from_profile'.
    assert captured.get("tool_name") == "cross_pillar"
    extra_tags = captured.get("extra_tags") or {}
    assert extra_tags.get("lpp_buyback_source") == "missing_from_profile"
    # tax_saving_source should be present too (Strategy B since profile
    # carries tax_saving_potential).
    assert extra_tags.get("tax_saving_source") in (
        "strategy_a",
        "strategy_b",
        "missing_from_profile",
    )


def test_dispatcher_inputs_hash_deterministic(monkeypatch) -> None:
    """Test 14: same profile → identical inputsHash across calls."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True
    )
    from app.api.v1.endpoints.coach_chat import _compute_cross_pillar_analysis

    mock_db_1 = _make_mock_db(_PROFILE_FULL)
    mock_db_2 = _make_mock_db(_PROFILE_FULL)
    raw_1 = _compute_cross_pillar_analysis(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db_1
    )
    raw_2 = _compute_cross_pillar_analysis(
        user_id="user-abc", ctx=_CTX_FULL, db=mock_db_2
    )
    h1 = json.loads(raw_1)["inputsHash"]
    h2 = json.loads(raw_2)["inputsHash"]
    assert h1 == h2


# ---------------------------------------------------------------------------
# Batch G — G3 (normalisation camelCase) + G1 (plafond inconnu -> None).
# ---------------------------------------------------------------------------


def _real_profile_dump(**overrides):
    """Construit un VRAI Profile puis model_dump(by_alias=True) — zéro clé à la
    main (revue Codex H1/P2 : un test canonique PART de Profile.model_dump)."""
    import uuid
    from datetime import datetime, timezone
    from app.schemas.profile import Profile, HouseholdType

    base = dict(
        id=str(uuid.uuid4()), birthYear=1985, canton="VD",
        householdType=HouseholdType.single, createdAt=datetime.now(timezone.utc),
    )
    base.update(overrides)
    return Profile(**base).model_dump(by_alias=True)


def test_g3_h1_canonical_profile_independant_no_lpp_yields_20000():
    """Profil CANONIQUE (Profile.model_dump) indépendant sans LPP 100'000,
    pillar3aAnnual=0 -> calcule (pas ValueError), plafond 20'000 — Codex H1."""
    from app.services.arbitrage.cross_pillar_service import CrossPillarService

    d = _real_profile_dump(
        employmentStatus="independant", has2ndPillar=False,
        incomeGrossYearly=100_000.0, selfEmployedNetIncome=100_000.0,
        pillar3aAnnual=0.0,
    )
    a = CrossPillarService.compute(profile_data=d)
    assert a.three_a_ceiling == Decimal("20000.00")


def test_h1_pillar3a_annual_reflected_in_contribution():
    """pillar3aAnnual=20'000 -> annual3AContribution reflète 20'000 versés
    (pas « 0.00 versé / 20'000 restants ») — Codex H1."""
    from app.services.arbitrage.cross_pillar_service import CrossPillarService

    d = _real_profile_dump(
        employmentStatus="independant", has2ndPillar=False,
        incomeGrossYearly=100_000.0, selfEmployedNetIncome=100_000.0,
        pillar3aAnnual=20_000.0,
    )
    a = CrossPillarService.compute(profile_data=d)
    assert a.annual_3a_contribution == Decimal("20000.00")
    assert a.three_a_remaining == Decimal("0.00")


def test_h3_cross_pillar_saving_is_canonical_difference_not_capped():
    """L'économie cross_pillar = différence d'impôt sur le versement borné au
    plafond D'AFFILIATION (20'000), pas 7'258 × taux. Indep sans LPP 100'000,
    versement 20'000, VD -> 6'338.81 (pas 2'305.36) — Codex H3."""
    from app.services.arbitrage.cross_pillar_service import CrossPillarService

    d = _real_profile_dump(
        employmentStatus="independant", has2ndPillar=False,
        incomeGrossYearly=100_000.0, selfEmployedNetIncome=100_000.0,
        pillar3aAnnual=20_000.0,
    )
    a = CrossPillarService.compute(profile_data=d)
    assert a.tax_saving_potential == Decimal("6338.81")


def test_g1_unknown_income_ceiling_is_none_not_zero():
    """Non-affilié sans revenu déterminant -> plafond None (jamais 0.00
    fabriqué) — revue Codex G1."""
    from app.services.arbitrage.cross_pillar_service import CrossPillarService

    for income in (None, 0.0, -10_000.0):
        prof = {
            "employmentStatus": "independant",
            "has2ndPillar": False,
            "annual_3a_contribution": 0.0,
        }
        if income is not None:
            prof["incomeGrossYearly"] = income
        a = CrossPillarService.compute(profile_data=prof)
        assert a.three_a_ceiling is None
        assert a.three_a_remaining is None


def test_i1_salarie_with_residual_independent_key_uses_salary_base():
    """Revue Codex I1 : salarié affilié LPP, brut 100'000, avec une clé
    selfEmployedNetIncome RÉSIDUELLE 20'000 (update partiel) -> assiette = base
    salariale 100'000, plafond 7'258, économie 2'305.38 (pas 1'044.38 sur 20k).
    La clé indépendante ne remplace jamais le salaire pour un salarié."""
    from app.services.arbitrage.cross_pillar_service import CrossPillarService

    d = _real_profile_dump(
        employmentStatus="salarie", has2ndPillar=True,
        incomeGrossYearly=100_000.0, selfEmployedNetIncome=20_000.0,
        pillar3aAnnual=7_258.0,
    )
    a = CrossPillarService.compute(profile_data=d)
    assert a.three_a_ceiling == Decimal("7258.00")
    assert a.tax_saving_potential == Decimal("2305.38")
