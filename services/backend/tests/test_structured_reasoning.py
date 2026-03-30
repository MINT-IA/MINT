"""
Tests for StructuredReasoningService — reasoning/humanization split.

Sprint S52+ (Cleo 3.0 inspired architecture).

18 tests across 7 groups:
    - TestEmptyProfile (2): null output when profile is empty or None
    - TestDeficit (3): monthly deficit and low liquidity detection
    - TestDecember3aDeadline (3): year-end 3a deadline detection
    - TestGapWarning (3): replacement rate gap warning
    - TestRachatOpportunity (2): LPP buyback opportunity detection
    - TestPriorityOrdering (3): first-match priority ordering
    - TestOutputContract (2): confidence bounds, supporting data always present

Run: cd services/backend && python3 -m pytest tests/test_structured_reasoning.py -v
"""

from __future__ import annotations

import datetime
from unittest.mock import patch

import pytest

from app.services.coach.structured_reasoning import (
    ReasoningOutput,
    StructuredReasoningService,
    _3A_CEILING_SALARIED,
    _REPLACEMENT_RATE_GAP_THRESHOLD,
)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────


def _reason(profile: dict | None, message: str = "test") -> ReasoningOutput:
    """Shorthand to call StructuredReasoningService.reason()."""
    return StructuredReasoningService.reason(
        user_message=message,
        profile_context=profile,
        memory_block=None,
    )


# A date in July (not December) — avoids triggering the 3a deadline detector
_JULY_DATE = datetime.date(2025, 7, 15)

# A date in late December — triggers the 3a deadline detector
_DECEMBER_DATE = datetime.date(2025, 12, 15)


# ─────────────────────────────────────────────────────────────────────────────
# Group 1: Empty profile → null output
# ─────────────────────────────────────────────────────────────────────────────


class TestEmptyProfile:
    """When the profile is absent or empty, no fact should be produced."""

    def test_none_profile_returns_null(self):
        output = _reason(None)
        assert output.fact_tag is None

    def test_empty_dict_returns_null(self):
        output = _reason({})
        assert output.fact_tag is None

    def test_null_output_confidence_is_zero(self):
        output = _reason(None)
        assert output.confidence == 0.0

    def test_null_output_prompt_block_is_empty(self):
        output = _reason(None)
        assert output.as_system_prompt_block() == ""


# ─────────────────────────────────────────────────────────────────────────────
# Group 2: Deficit detection
# ─────────────────────────────────────────────────────────────────────────────


class TestDeficit:
    """Deficit is detected from income/expense pair or low liquidity proxy."""

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_income_expense_deficit_detected(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        output = _reason({"monthly_income": 4000, "monthly_expenses": 5000})
        assert output.fact_tag == "deficit"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_deficit_supporting_data_has_chf_amounts(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        output = _reason({"monthly_income": 4000, "monthly_expenses": 5000})
        assert "deficit_CHF" in output.supporting_data
        assert output.supporting_data["deficit_CHF"] == 1000.0

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_low_liquidity_triggers_deficit(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        output = _reason({"months_liquidity": 1.5})
        assert output.fact_tag == "deficit"
        assert "mois_liquidites" in output.supporting_data

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_sufficient_liquidity_no_deficit(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"months_liquidity": 5.0})
        assert output.fact_tag != "deficit"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_balanced_budget_no_deficit(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"monthly_income": 5000, "monthly_expenses": 4500})
        assert output.fact_tag != "deficit"


# ─────────────────────────────────────────────────────────────────────────────
# Group 3: December 3a deadline
# ─────────────────────────────────────────────────────────────────────────────


class TestDecember3aDeadline:
    """3a deadline fires in December when 3a contribution is below ceiling."""

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_december_3a_not_maxed_fires(self, mock_dt):
        mock_dt.date.today.return_value = _DECEMBER_DATE
        mock_dt.date.return_value = _DECEMBER_DATE
        # Patch year_end construction inside the module
        with patch(
            "app.services.coach.structured_reasoning.datetime",
        ) as mock_datetime:
            mock_datetime.date.today.return_value = _DECEMBER_DATE
            mock_datetime.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
            output = _reason({"annual_3a_contribution": 0.0})
        assert output.fact_tag == "3a_deadline"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_3a_deadline_supporting_data_has_plafond(self, mock_dt):
        with patch(
            "app.services.coach.structured_reasoning.datetime",
        ) as mock_datetime:
            mock_datetime.date.today.return_value = _DECEMBER_DATE
            mock_datetime.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
            output = _reason({"annual_3a_contribution": 0.0})
        assert "plafond_3a_CHF" in output.supporting_data
        assert output.supporting_data["plafond_3a_CHF"] == _3A_CEILING_SALARIED
        assert "jours_restants" in output.supporting_data

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_july_no_3a_deadline(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"annual_3a_contribution": 0.0})
        assert output.fact_tag != "3a_deadline"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_december_3a_already_maxed_no_deadline(self, mock_dt):
        with patch(
            "app.services.coach.structured_reasoning.datetime",
        ) as mock_datetime:
            mock_datetime.date.today.return_value = _DECEMBER_DATE
            mock_datetime.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
            output = _reason({"annual_3a_contribution": _3A_CEILING_SALARIED})
        # If 3a already maxed, deadline should not fire
        assert output.fact_tag != "3a_deadline"


# ─────────────────────────────────────────────────────────────────────────────
# Group 4: Gap warning (replacement rate)
# ─────────────────────────────────────────────────────────────────────────────


class TestGapWarning:
    """Gap warning fires when replacement_ratio < 60%."""

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_low_replacement_rate_fires_gap_warning(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": 0.45})
        assert output.fact_tag == "gap_warning"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_gap_warning_supporting_data_has_rate(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": 0.45, "monthly_income": 8000})
        assert "taux_remplacement_pct" in output.supporting_data
        assert output.supporting_data["taux_remplacement_pct"] == pytest.approx(45.0, abs=0.1)
        assert "ecart_mensuel_CHF" in output.supporting_data

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_adequate_replacement_rate_no_gap_warning(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": 0.75})
        assert output.fact_tag != "gap_warning"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_gap_warning_at_threshold_boundary(self, mock_dt):
        """Replacement rate exactly at threshold — no warning."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": _REPLACEMENT_RATE_GAP_THRESHOLD})
        assert output.fact_tag != "gap_warning"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_gap_warning_just_below_threshold(self, mock_dt):
        """Replacement rate just below threshold — warning fires."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": _REPLACEMENT_RATE_GAP_THRESHOLD - 0.01})
        assert output.fact_tag == "gap_warning"


# ─────────────────────────────────────────────────────────────────────────────
# Group 5: Rachat opportunity
# ─────────────────────────────────────────────────────────────────────────────


class TestRachatOpportunity:
    """Rachat fires when lpp_buyback_max >= 10'000 CHF and no higher fact."""

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_rachat_fires_when_buyback_significant(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"lpp_buyback_max": 50_000.0, "replacement_ratio": 0.70})
        assert output.fact_tag == "rachat_opportunity"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_rachat_supporting_data_has_chf_amounts(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({
            "lpp_buyback_max": 50_000.0,
            "replacement_ratio": 0.70,
            "lpp_capital": 70_000.0,
        })
        assert "rachat_max_CHF" in output.supporting_data
        assert output.supporting_data["rachat_max_CHF"] == 50_000.0
        assert "economie_fiscale_estimee_CHF" in output.supporting_data
        assert "avoir_lpp_actuel_CHF" in output.supporting_data

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_rachat_below_minimum_no_fact(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"lpp_buyback_max": 5_000.0, "replacement_ratio": 0.70})
        assert output.fact_tag != "rachat_opportunity"


# ─────────────────────────────────────────────────────────────────────────────
# Group 6: Priority ordering
# ─────────────────────────────────────────────────────────────────────────────


class TestPriorityOrdering:
    """Deficit takes priority over all other facts; ordering is deterministic."""

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_deficit_beats_gap_warning(self, mock_dt):
        """Even with a low replacement rate, deficit fires first."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({
            "monthly_income": 3000,
            "monthly_expenses": 4000,
            "replacement_ratio": 0.40,
        })
        assert output.fact_tag == "deficit"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_deficit_beats_rachat_opportunity(self, mock_dt):
        """Even with a large rachat potential, deficit fires first."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({
            "monthly_income": 3000,
            "monthly_expenses": 4500,
            "lpp_buyback_max": 100_000.0,
            "replacement_ratio": 0.70,
        })
        assert output.fact_tag == "deficit"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_gap_warning_beats_rachat(self, mock_dt):
        """Gap warning fires before rachat when no deficit."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({
            "months_liquidity": 5.0,
            "replacement_ratio": 0.45,
            "lpp_buyback_max": 50_000.0,
        })
        assert output.fact_tag == "gap_warning"

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_multiple_facts_highest_priority_returned(self, mock_dt):
        """When all facts are present, the highest-priority one is returned."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({
            "monthly_income": 2000,
            "monthly_expenses": 3000,   # deficit
            "replacement_ratio": 0.40,   # gap_warning
            "lpp_buyback_max": 80_000,   # rachat
            "tax_saving_potential": 2000,
            "annual_3a_contribution": 0,
        })
        assert output.fact_tag == "deficit"


# ─────────────────────────────────────────────────────────────────────────────
# Group 7: Output contract
# ─────────────────────────────────────────────────────────────────────────────


class TestOutputContract:
    """ReasoningOutput must always respect its contract regardless of input."""

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_confidence_always_valid_range(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        profiles = [
            None,
            {},
            {"monthly_income": 4000, "monthly_expenses": 5000},
            {"replacement_ratio": 0.40},
            {"lpp_buyback_max": 50_000, "replacement_ratio": 0.80},
            {"tax_saving_potential": 2000, "annual_3a_contribution": 1000},
        ]
        for profile in profiles:
            output = _reason(profile)
            assert 0.0 <= output.confidence <= 1.0, (
                f"confidence={output.confidence} out of range for profile={profile}"
            )

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_supporting_data_always_dict(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"monthly_income": 4000, "monthly_expenses": 5000})
        assert isinstance(output.supporting_data, dict)

    def test_invalid_confidence_raises_value_error(self):
        """ReasoningOutput raises ValueError if confidence is out of bounds."""
        with pytest.raises(ValueError, match="confidence"):
            ReasoningOutput(
                fact_tag="deficit",
                fact_label="test",
                confidence=1.5,   # invalid
                suggested_action="test",
                intent_tag=None,
                reasoning_trace="test",
                supporting_data={},
            )

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_fact_output_prompt_block_not_empty(self, mock_dt):
        """When a fact is detected, as_system_prompt_block() is non-empty."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": 0.45})
        block = output.as_system_prompt_block()
        assert len(block) > 0
        assert "ANALYSE PRÉALABLE" in block

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_prompt_block_contains_supporting_data(self, mock_dt):
        """as_system_prompt_block() includes supporting data amounts."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"monthly_income": 4000, "monthly_expenses": 5000})
        block = output.as_system_prompt_block()
        assert "Données" in block

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_disclaimer_always_present(self, mock_dt):
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": 0.45})
        assert output.disclaimer
        assert "LSFin" in output.disclaimer

    @patch("app.services.coach.structured_reasoning.datetime")
    def test_gap_warning_has_sources(self, mock_dt):
        """Gap warning references Swiss legal sources."""
        mock_dt.date.today.return_value = _JULY_DATE
        mock_dt.date.side_effect = lambda *a, **kw: datetime.date(*a, **kw)
        output = _reason({"replacement_ratio": 0.45})
        assert len(output.sources) > 0
        sources_str = " ".join(output.sources)
        assert "LAVS" in sources_str or "LPP" in sources_str
