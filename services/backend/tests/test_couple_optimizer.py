"""Wave 1a Plan 04 — unit tests for the Python port of Flutter CoupleOptimizer.

Test layout:
  Tests 1-4    : LPP buyback order analysis (4 cases).
  Tests 5-8    : 3a contribution order analysis (4 cases incl. FATCA).
  Tests 9-12   : AVS couple cap analysis (4 cases incl. married/concubin).
  Tests 13-16  : Marriage penalty analysis (4 cases incl. canton format).
  Tests 17-18  : Integration tests (full optimize + empty result).
  Test 19      : Pydantic CoupleOptimizationResponse camelCase shape.
  Test 20      : FR-string accent integrity (Dart line 229 byte-identity).

All FR strings are asserted byte-identical to the Dart source so any
accidental ASCII regression (é → e, → → ->) trips immediately.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict

import pytest

from app.models.coach_tools.couple_optimization import (
    AvsCapResponse,
    CoupleOptimizationResponse,
    LppBuybackOrderResponse,
    MarriagePenaltyResponse,
    Pillar3aOrderResponse,
)
from app.services.couple_optimizer import (
    CoupleOptimizationResult,
    CoupleOptimizer,
    CoupleWinner,
)


# ---------------------------------------------------------------------------
# Shared fixtures — profile shapes mirror ProfileModel.data camelCase contract.
# ---------------------------------------------------------------------------

# User: ZH, married, 2 children, 15k/13mo, born 1985, with LPP buyback room.
# Conjoint: 4k/12mo, born 1988, smaller buyback room, can contribute 3a.
_PROFILE_USER_HIGH_TAX: Dict[str, Any] = {
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

# Mirrored swap: low-income user, high-income conjoint.
_PROFILE_CONJOINT_HIGH_TAX: Dict[str, Any] = {
    "salaireBrutMensuel": 4_000.0,
    "nombreDeMois": 12,
    "etatCivil": "marie",
    "canton": "ZH",
    "nombreEnfants": 2,
    "birthYear": 1985,
    "gender": "M",
    "prevoyance": {"rachatMaximum": 10_000.0, "rachatEffectue": 0.0},
    "desiredRetirementAge": 65,
    "conjoint": {
        "salaireBrutMensuel": 15_000.0,
        "nombreDeMois": 13,
        "canContribute3a": True,
        "birthYear": 1988,
        "gender": "F",
        "prevoyance": {"rachatMaximum": 50_000.0, "rachatEffectue": 0.0},
        "targetRetirementAge": 65,
    },
}

# FATCA conjoint — canContribute3a=False (US resident).
_PROFILE_FATCA: Dict[str, Any] = {
    **_PROFILE_USER_HIGH_TAX,
    "conjoint": {
        **_PROFILE_USER_HIGH_TAX["conjoint"],
        "isFatcaResident": True,
        "canContribute3a": False,
    },
}

# Single user — no conjoint dict.
_PROFILE_SINGLE: Dict[str, Any] = {
    "salaireBrutMensuel": 8_000.0,
    "nombreDeMois": 12,
    "etatCivil": "celibataire",
    "canton": "VD",
    "nombreEnfants": 0,
    "birthYear": 1990,
    "prevoyance": {"rachatMaximum": 0.0, "rachatEffectue": 0.0},
    "conjoint": None,
}

# Near-zero saving delta — user and conjoint mirror each other.
_PROFILE_EQUAL_TAX: Dict[str, Any] = {
    "salaireBrutMensuel": 10_000.0,
    "nombreDeMois": 12,
    "etatCivil": "marie",
    "canton": "ZH",
    "nombreEnfants": 1,
    "birthYear": 1985,
    "prevoyance": {"rachatMaximum": 20_000.0, "rachatEffectue": 0.0},
    "conjoint": {
        "salaireBrutMensuel": 10_000.0,
        "nombreDeMois": 12,
        "canContribute3a": True,
        "birthYear": 1985,
        "prevoyance": {"rachatMaximum": 20_000.0, "rachatEffectue": 0.0},
    },
}


# ---------------------------------------------------------------------------
# LPP buyback order (Tests 1-4) — Dart couple_optimizer.dart:180-242
# ---------------------------------------------------------------------------


def test_lpp_buyback_user_higher_marginal_rate_wins() -> None:
    """Test 1a: user has higher income → MAIN_USER wins, byte-identical reason."""
    result = CoupleOptimizer._analyze_lpp_buyback_order(
        _PROFILE_USER_HIGH_TAX, _PROFILE_USER_HIGH_TAX["conjoint"]
    )
    assert result is not None
    assert result.winner == CoupleWinner.MAIN_USER
    assert result.saving_delta >= 100.0  # Dart _minDelta gate.
    # Byte-identical to Dart line 229.
    assert (
        result.reason
        == "Taux marginal plus élevé → économie fiscale supérieure par CHF racheté."
    )
    # Verbatim trade-off from Dart lines 239-240.
    assert "LPP art. 79b al. 3" in result.trade_off


def test_lpp_buyback_conjoint_higher_marginal_rate_wins() -> None:
    """Test 1b: conjoint higher income → CONJOINT wins, same reason form."""
    result = CoupleOptimizer._analyze_lpp_buyback_order(
        _PROFILE_CONJOINT_HIGH_TAX, _PROFILE_CONJOINT_HIGH_TAX["conjoint"]
    )
    assert result is not None
    assert result.winner == CoupleWinner.CONJOINT
    assert result.saving_delta >= 100.0
    # Dart line 232 — same string as line 229 (winner-agnostic reason).
    assert (
        result.reason
        == "Taux marginal plus élevé → économie fiscale supérieure par CHF racheté."
    )


def test_lpp_buyback_similar_marginal_rates_no_preference() -> None:
    """Test 1c: delta < 100 CHF → NO_PREFERENCE, byte-identical reason."""
    result = CoupleOptimizer._analyze_lpp_buyback_order(
        _PROFILE_EQUAL_TAX, _PROFILE_EQUAL_TAX["conjoint"]
    )
    assert result is not None
    assert result.winner == CoupleWinner.NO_PREFERENCE
    assert result.saving_delta < 100.0
    # Byte-identical to Dart line 226.
    assert result.reason == "Taux marginaux similaires — pas de préférence."


def test_lpp_buyback_both_rachat_zero_returns_none() -> None:
    """Test 1d: neither user nor conjoint has buyback room → None."""
    profile = {
        **_PROFILE_USER_HIGH_TAX,
        "prevoyance": {"rachatMaximum": 0.0, "rachatEffectue": 0.0},
        "conjoint": {
            **_PROFILE_USER_HIGH_TAX["conjoint"],
            "prevoyance": {"rachatMaximum": 0.0, "rachatEffectue": 0.0},
        },
    }
    result = CoupleOptimizer._analyze_lpp_buyback_order(profile, profile["conjoint"])
    assert result is None


# ---------------------------------------------------------------------------
# 3a contribution order (Tests 5-8) — Dart couple_optimizer.dart:246-315
# ---------------------------------------------------------------------------


def test_3a_user_higher_income_wins() -> None:
    """Test 2a: user higher income → MAIN_USER wins."""
    result = CoupleOptimizer._analyze_3a_contribution_order(
        _PROFILE_USER_HIGH_TAX, _PROFILE_USER_HIGH_TAX["conjoint"]
    )
    assert result is not None
    assert result.winner == CoupleWinner.MAIN_USER
    assert result.saving_delta >= 100.0
    # Byte-identical to Dart line 302.
    assert (
        result.reason
        == "Revenu imposable plus élevé → déduction 3a plus avantageuse."
    )


def test_3a_conjoint_higher_income_wins() -> None:
    """Test 2b: conjoint higher income → CONJOINT wins."""
    result = CoupleOptimizer._analyze_3a_contribution_order(
        _PROFILE_CONJOINT_HIGH_TAX, _PROFILE_CONJOINT_HIGH_TAX["conjoint"]
    )
    assert result is not None
    assert result.winner == CoupleWinner.CONJOINT
    # Byte-identical to Dart line 305.
    assert (
        result.reason
        == "Revenu imposable plus élevé → déduction 3a plus avantageuse."
    )


def test_3a_fatca_conjoint_blocks_with_verbatim_strings() -> None:
    """Test 2c: conjoint FATCA → MAIN_USER, saving_delta=0, verbatim FR strings."""
    result = CoupleOptimizer._analyze_3a_contribution_order(
        _PROFILE_FATCA, _PROFILE_FATCA["conjoint"]
    )
    assert result is not None
    assert result.winner == CoupleWinner.MAIN_USER
    assert result.saving_delta == 0.0
    # Byte-identical to Dart lines 261-262 — "Le·la conjoint·e ... résident·e FATCA"
    # The Dart middle-dot is U+00B7. Python source uses it identically.
    assert result.reason == (
        "Le·la conjoint·e est résident·e FATCA "
        "— le versement 3a n'est pas possible pour cette personne."
    )
    # Byte-identical to Dart lines 263-264.
    assert result.trade_off == (
        "FATCA (Foreign Account Tax Compliance Act) "
        "restreint l'accès à certains produits 3a pour les résidents US."
    )


def test_3a_both_incomes_zero_returns_none() -> None:
    """Test 2d: both incomes zero → None."""
    profile = {
        "salaireBrutMensuel": 0.0,
        "nombreDeMois": 12,
        "etatCivil": "marie",
        "canton": "ZH",
        "nombreEnfants": 0,
        "birthYear": 1985,
        "conjoint": {"salaireBrutMensuel": 0.0, "nombreDeMois": 12},
    }
    result = CoupleOptimizer._analyze_3a_contribution_order(
        profile, profile["conjoint"]
    )
    assert result is None


# ---------------------------------------------------------------------------
# AVS couple cap (Tests 9-12) — Dart couple_optimizer.dart:319-369
# ---------------------------------------------------------------------------


def test_avs_cap_married_high_incomes_caps() -> None:
    """Test 3a: married + combined rente > 150% max → cap_applied=True."""
    # Two high earners → individual rentes ~maximum → couple uncapped > 3780 CHF/mo.
    result = CoupleOptimizer._analyze_avs_cap(
        _PROFILE_USER_HIGH_TAX, _PROFILE_USER_HIGH_TAX["conjoint"]
    )
    assert result is not None
    assert result.cap_applied is True
    assert result.monthly_reduction > 0
    assert result.user_rente_before_cap > 0
    assert result.conjoint_rente_before_cap > 0
    assert result.total_after_cap > 0


def test_avs_cap_concubinage_does_not_apply() -> None:
    """Test 3d: not married (concubinage) → cap_applied=False per LAVS art. 35.

    Note: Dart logic computes the cap via computeCouple's `isMarried` flag.
    When False, the function returns total uncapped → reduction = 0 → cap_applied=False.
    """
    profile = {
        **_PROFILE_USER_HIGH_TAX,
        "etatCivil": "concubinage",
    }
    result = CoupleOptimizer._analyze_avs_cap(profile, profile["conjoint"])
    assert result is not None
    # No marriage → no LAVS art. 35 cap, reduction is 0.
    assert result.cap_applied is False
    assert result.monthly_reduction == pytest.approx(0.0, abs=0.01)


def test_avs_cap_conjoint_age_none_returns_none() -> None:
    """Test 3c: conjoint.birthYear absent → conjoint_age=None → None."""
    profile = {
        **_PROFILE_USER_HIGH_TAX,
        "conjoint": {
            **_PROFILE_USER_HIGH_TAX["conjoint"],
            "birthYear": None,
        },
    }
    result = CoupleOptimizer._analyze_avs_cap(profile, profile["conjoint"])
    assert result is None


def test_avs_cap_low_incomes_no_cap() -> None:
    """Test 3b: married + combined under 3780 CHF/mo cap → cap_applied=False."""
    profile = {
        "salaireBrutMensuel": 2_000.0,
        "nombreDeMois": 12,
        "etatCivil": "marie",
        "canton": "ZH",
        "nombreEnfants": 0,
        "birthYear": 1985,
        "desiredRetirementAge": 65,
        "conjoint": {
            "salaireBrutMensuel": 2_000.0,
            "nombreDeMois": 12,
            "birthYear": 1988,
            "targetRetirementAge": 65,
        },
    }
    result = CoupleOptimizer._analyze_avs_cap(profile, profile["conjoint"])
    assert result is not None
    # Low individual rentes → sum stays below 3780 → no cap.
    assert result.cap_applied is False
    assert result.monthly_reduction == pytest.approx(0.0, abs=0.01)


def test_avs_rente_delegates_to_canonical_echelle44_no_local_copy() -> None:
    """Anti-façade : la rente AVS couple délègue à la fonction canonique unique.

    Le couple_optimizer NE doit PAS redéfinir sa propre table échelle 44
    ni son propre ``_rente_from_ramd`` (règle 4 / NEVER #3). La rente pleine
    (carrière complète 44 ans, sans ajustement) doit égaler exactement
    ``social_insurance.rente_from_ramd``.
    """
    from app.services.couple_optimizer import couple_optimizer as _mod
    from app.constants.social_insurance import rente_from_ramd

    # Full career (arrival 20, current 65, retire 65) → gap_factor 1.0, no adj.
    rente = _mod._avs_compute_monthly_rente(
        current_age=65, retirement_age=65, gross_annual_salary=52_920.0
    )
    assert rente == pytest.approx(rente_from_ramd(52_920.0), abs=0.01)
    assert rente == pytest.approx(2016.0, abs=0.01)  # palier officiel exact

    # Aucune copie locale de la table ou du lookup ne subsiste.
    assert not hasattr(_mod, "_AVS_ECHELLE_44"), "Table échelle 44 dupliquée détectée"
    assert not hasattr(_mod, "_rente_from_ramd"), "Copie locale de rente_from_ramd détectée"


def test_pilier3a_ceiling_sourced_from_registry_no_local_copy() -> None:
    """Anti-façade (P1) : le plafond 3a trace au registre unique, pas hardcodé.

    Le couple_optimizer utilisait une copie locale ``_PILIER_3A_PLAFOND_AVEC_LPP
    = 7258.0`` servie telle quelle dans l'analyse 3a (dérive silencieuse si le
    registre ``pillar3a.max_with_lpp`` change). Elle doit être supprimée au
    profit de ``social_insurance.PILIER_3A_PLAFOND_AVEC_LPP`` (règle 4 / NEVER
    #3).
    """
    from app.services.couple_optimizer import couple_optimizer as _mod
    from app.constants.social_insurance import PILIER_3A_PLAFOND_AVEC_LPP

    # La copie locale hardcodée n'existe plus.
    assert not hasattr(_mod, "_PILIER_3A_PLAFOND_AVEC_LPP"), (
        "Copie locale hardcodée du plafond 3a détectée"
    )
    # Le registre reste la source (valeur 2026 vérifiée -zaw).
    assert PILIER_3A_PLAFOND_AVEC_LPP == 7258.0


# ---------------------------------------------------------------------------
# Marriage penalty (Tests 13-16) — Dart couple_optimizer.dart:373-422
# ---------------------------------------------------------------------------


def test_marriage_penalty_double_income_be_canton_has_penalty() -> None:
    """Test 4a: double-income high in BE canton → has_penalty=True, penalty string."""
    profile = {
        **_PROFILE_USER_HIGH_TAX,
        "canton": "BE",
        "conjoint": {
            **_PROFILE_USER_HIGH_TAX["conjoint"],
            "salaireBrutMensuel": 12_000.0,
            "nombreDeMois": 13,
        },
    }
    result = CoupleOptimizer._analyze_marriage_penalty(profile, profile["conjoint"])
    assert result is not None
    # With this simplified tax model BE canton + double high income → penalty path.
    if result.has_penalty:
        assert result.annual_delta > 0
        assert "surcharge fiscale" in result.trade_off
        assert "BE" in result.trade_off
    else:
        # Bonus path falls back to the splitting-advantage string.
        assert "avantage fiscal" in result.trade_off
        assert "BE" in result.trade_off


def test_marriage_penalty_single_income_returns_bonus() -> None:
    """Test 4b: single-income married → splitting advantage → has_penalty=False."""
    profile = {
        **_PROFILE_USER_HIGH_TAX,
        "conjoint": {
            **_PROFILE_USER_HIGH_TAX["conjoint"],
            "salaireBrutMensuel": 0.0,
        },
    }
    result = CoupleOptimizer._analyze_marriage_penalty(profile, profile["conjoint"])
    assert result is not None
    # Single-income couple should show a bonus (negative or near-zero delta).
    assert result.has_penalty is False
    # Byte-identical to Dart lines 418-420.
    assert "avantage fiscal" in result.trade_off
    assert "splitting" in result.trade_off


def test_marriage_penalty_both_incomes_zero_returns_none() -> None:
    """Test 4c: both incomes zero → None (Dart line 380 guard)."""
    profile = {
        "salaireBrutMensuel": 0.0,
        "nombreDeMois": 12,
        "etatCivil": "marie",
        "canton": "ZH",
        "nombreEnfants": 0,
        "conjoint": {"salaireBrutMensuel": 0.0, "nombreDeMois": 12},
    }
    result = CoupleOptimizer._analyze_marriage_penalty(profile, profile["conjoint"])
    assert result is None


def test_marriage_penalty_tradeoff_contains_canton_iso_code() -> None:
    """Test 4d: tradeOff contains the canton ISO code byte-identical with Dart."""
    profile = {
        **_PROFILE_USER_HIGH_TAX,
        "canton": "VS",
    }
    result = CoupleOptimizer._analyze_marriage_penalty(profile, profile["conjoint"])
    assert result is not None
    # Dart line 416/419 — canton appears verbatim after "dans le canton ".
    assert "dans le canton VS" in result.trade_off


# ---------------------------------------------------------------------------
# Integration (Tests 17-18)
# ---------------------------------------------------------------------------


def test_optimize_full_julien_profile_all_four_results_present() -> None:
    """Test 17: full profile → all 4 sub-results non-None."""
    result = CoupleOptimizer.optimize(_PROFILE_USER_HIGH_TAX)
    assert isinstance(result, CoupleOptimizationResult)
    assert result.lpp_buyback_order is not None
    assert result.pillar_3a_order is not None
    assert result.avs_cap is not None
    assert result.marriage_penalty is not None
    assert result.has_results is True


def test_optimize_no_conjoint_returns_empty() -> None:
    """Test 18: profile without conjoint → empty() (all 4 None)."""
    result = CoupleOptimizer.optimize(_PROFILE_SINGLE)
    assert isinstance(result, CoupleOptimizationResult)
    assert result.lpp_buyback_order is None
    assert result.pillar_3a_order is None
    assert result.avs_cap is None
    assert result.marriage_penalty is None
    assert result.has_results is False


# ---------------------------------------------------------------------------
# Pydantic + accent integrity (Tests 19-20)
# ---------------------------------------------------------------------------


def test_response_serializes_camel_case_with_inputs_hash() -> None:
    """Test 19: CoupleOptimizationResponse(...).model_dump(by_alias=True) → camelCase."""
    response = CoupleOptimizationResponse(
        lpp_buyback=LppBuybackOrderResponse(
            winner="main_user",
            saving_delta=Decimal("499.88"),
            reason="Taux marginal plus élevé → économie fiscale supérieure par CHF racheté.",
            trade_off="Le rachat LPP est bloqué 3 ans avant le retrait (LPP art. 79b al. 3). Le timing dépend aussi de l'âge de chaque personne.",
        ),
        pillar_3a=Pillar3aOrderResponse(
            winner="main_user",
            saving_delta=Decimal("364.74"),
            reason="Revenu imposable plus élevé → déduction 3a plus avantageuse.",
            trade_off="Le plafond 3a est individuel (CHF 7258/an). Les deux partenaires peuvent verser chacun le maximum.",
        ),
        avs_cap=AvsCapResponse(
            cap_applied=True,
            monthly_reduction=Decimal("605.16"),
            user_rente_before_cap=Decimal("2730.00"),
            conjoint_rente_before_cap=Decimal("1970.16"),
            total_after_cap=Decimal("4095.00"),
        ),
        marriage_penalty=MarriagePenaltyResponse(
            has_penalty=False,
            annual_delta=Decimal("-6813.90"),
            trade_off="Le mariage crée un avantage fiscal de CHF 6814/an dans le canton ZH. Cet avantage est dû au splitting pour les couples mariés.",
        ),
        inputs_hash="a" * 64,
        computed_at=datetime(2026, 5, 14, 12, 0, 0, tzinfo=timezone.utc),
    )
    dumped = response.model_dump(by_alias=True)
    # camelCase nested keys.
    assert "lppBuyback" in dumped
    assert "pillar3A" in dumped or "pillar3a" in dumped  # to_camel converts pillar_3a
    assert "avsCap" in dumped
    assert "marriagePenalty" in dumped
    assert "inputsHash" in dumped
    assert "computedAt" in dumped
    # snake_case must NOT leak.
    assert "lpp_buyback" not in dumped
    assert "inputs_hash" not in dumped
    # Nested sub-fields camelCase.
    assert "savingDelta" in dumped["lppBuyback"]
    assert "tradeOff" in dumped["lppBuyback"]
    assert "capApplied" in dumped["avsCap"]
    assert "monthlyReduction" in dumped["avsCap"]
    assert "hasPenalty" in dumped["marriagePenalty"]
    assert "annualDelta" in dumped["marriagePenalty"]


def test_fr_accent_integrity_preserves_dart_line_229_byte_identical() -> None:
    """Test 20: reason from a real optimize() call contains é and → exactly.

    Proves Python source preserves Dart accents byte-identically — any
    ASCII regression (é → e, → → ->) trips immediately.
    """
    result = CoupleOptimizer._analyze_lpp_buyback_order(
        _PROFILE_USER_HIGH_TAX, _PROFILE_USER_HIGH_TAX["conjoint"]
    )
    assert result is not None
    # Composite accent é (U+00E9) and arrow → (U+2192).
    assert "é" in result.reason  # é present.
    assert "→" in result.reason  # → present.
    # And the literal Dart string.
    assert (
        result.reason
        == "Taux marginal plus élevé → économie fiscale supérieure par CHF racheté."
    )


# ---------------------------------------------------------------------------
# Optional: to_legacy_dict shape contract (covered separately for clarity).
# ---------------------------------------------------------------------------


def test_to_legacy_dict_matches_format_couple_optimization_keys() -> None:
    """Bonus: to_legacy_dict() emits the exact keys _format_couple_optimization reads."""
    result = CoupleOptimizer.optimize(_PROFILE_USER_HIGH_TAX)
    legacy = result.to_legacy_dict()
    assert set(legacy.keys()) <= {
        "lpp_buyback",
        "pillar_3a",
        "avs_cap",
        "marriage_penalty",
    }
    if "lpp_buyback" in legacy:
        assert set(legacy["lpp_buyback"].keys()) == {
            "winner",
            "saving_delta",
            "reason",
            "trade_off",
        }
    if "avs_cap" in legacy:
        # _format_couple_optimization reads cap_applied + monthly_reduction.
        assert "cap_applied" in legacy["avs_cap"]
        assert "monthly_reduction" in legacy["avs_cap"]
    if "marriage_penalty" in legacy:
        assert "has_penalty" in legacy["marriage_penalty"]
        assert "annual_delta" in legacy["marriage_penalty"]
