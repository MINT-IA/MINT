"""
Tests for Scenario Narration + Annual Refresh — Sprint S37.

Covers:
    - ScenarioNarratorService: narration (12 tests)
    - AnnualRefreshService: refresh detection + questions (8 tests)
    - Compliance: banned terms, disclaimer, sources (5 tests)
    - API endpoints: integration (3 tests)

Run: cd services/backend && python3 -m pytest tests/test_scenario_narration.py -v
"""

import pytest
import re
from datetime import date

from fastapi.testclient import TestClient

from app.services.scenario.scenario_models import (
    AnnualRefreshResult,
    NarratedScenario,
    RefreshQuestion,
    ScenarioInput,
    ScenarioNarrationResult,
)
from app.services.scenario.scenario_narrator_service import (
    BANNED_TERMS,
    STANDARD_DISCLAIMER,
    STANDARD_SOURCES,
    ScenarioNarratorService,
    _format_chf,
)
from app.services.scenario.annual_refresh_service import (
    AnnualRefreshService,
    REFRESH_THRESHOLD_MONTHS,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def narrator():
    return ScenarioNarratorService()


@pytest.fixture
def refresh_svc():
    return AnnualRefreshService()


@pytest.fixture
def three_scenarios():
    """Standard 3 scenarios: prudent / base / optimiste."""
    return [
        ScenarioInput(
            label="prudent",
            annual_return=0.01,
            capital_final=350000,
            monthly_income=2100,
            replacement_ratio=0.42,
        ),
        ScenarioInput(
            label="base",
            annual_return=0.045,
            capital_final=520000,
            monthly_income=3200,
            replacement_ratio=0.64,
        ),
        ScenarioInput(
            label="optimiste",
            annual_return=0.07,
            capital_final=780000,
            monthly_income=4800,
            replacement_ratio=0.96,
        ),
    ]


@pytest.fixture
def client():
    """FastAPI test client."""
    from app.main import app

    return TestClient(app)


# ===========================================================================
# SCENARIO NARRATION — 12 tests
# ===========================================================================


class TestScenarioNarrator:
    """Tests for ScenarioNarratorService."""

    def test_narrate_three_scenarios_returns_three(self, narrator, three_scenarios):
        """3 input scenarios produce 3 narrated scenarios."""
        result = narrator.narrate_scenarios(three_scenarios)
        assert isinstance(result, ScenarioNarrationResult)
        assert len(result.scenarios) == 3

    def test_narrate_labels_match_input(self, narrator, three_scenarios):
        """Output labels match input labels."""
        result = narrator.narrate_scenarios(three_scenarios)
        labels = [s.label for s in result.scenarios]
        assert labels == ["prudent", "base", "optimiste"]

    def test_narrate_mentions_return_pct(self, narrator, three_scenarios):
        """Each narrative mentions the return percentage."""
        result = narrator.narrate_scenarios(three_scenarios)
        for ns in result.scenarios:
            pct_str = str(ns.annual_return_pct)
            assert pct_str in ns.narrative, (
                f"Narrative for {ns.label} must mention {pct_str}%"
            )

    def test_narrate_mentions_uncertainty(self, narrator, three_scenarios):
        """Each narrative mentions uncertainty (incertitude, depend, estimat, etc.)."""
        uncertainty_words = [
            "incertitude",
            "evoluer",
            "dependront",
            "estimations",
            "facteurs",
            "conditions",
        ]
        result = narrator.narrate_scenarios(three_scenarios)
        for ns in result.scenarios:
            lower = ns.narrative.lower()
            found = any(w in lower for w in uncertainty_words)
            assert found, (
                f"Narrative for {ns.label} must mention uncertainty. "
                f"Text: {ns.narrative}"
            )

    def test_narrate_capital_matches_input(self, narrator, three_scenarios):
        """Capital values in narratives match inputs (via CHF formatting)."""
        result = narrator.narrate_scenarios(three_scenarios)
        for ns, inp in zip(result.scenarios, three_scenarios):
            assert ns.capital_final == inp.capital_final
            chf_str = _format_chf(inp.capital_final)
            assert chf_str in ns.narrative, (
                f"Narrative for {ns.label} must contain CHF {chf_str}"
            )

    def test_narrate_monthly_matches_input(self, narrator, three_scenarios):
        """Monthly income values in narratives match inputs."""
        result = narrator.narrate_scenarios(three_scenarios)
        for ns, inp in zip(result.scenarios, three_scenarios):
            assert ns.monthly_income == inp.monthly_income
            chf_str = _format_chf(inp.monthly_income)
            assert chf_str in ns.narrative, (
                f"Narrative for {ns.label} must contain CHF {chf_str}"
            )

    def test_narrate_max_150_words(self, narrator, three_scenarios):
        """Each narrative is at most 150 words."""
        result = narrator.narrate_scenarios(three_scenarios)
        for ns in result.scenarios:
            word_count = len(ns.narrative.split())
            assert word_count <= 150, (
                f"Narrative for {ns.label} has {word_count} words (max 150)"
            )

    def test_narrate_annual_return_pct_conversion(self, narrator, three_scenarios):
        """annual_return_pct is correctly converted from decimal to percentage."""
        result = narrator.narrate_scenarios(three_scenarios)
        assert result.scenarios[0].annual_return_pct == 1.0  # 0.01 -> 1.0%
        assert result.scenarios[1].annual_return_pct == 4.5  # 0.045 -> 4.5%
        assert result.scenarios[2].annual_return_pct == 7.0  # 0.07 -> 7.0%

    def test_narrate_single_scenario(self, narrator):
        """Narration works with a single scenario."""
        single = [
            ScenarioInput(
                label="base",
                annual_return=0.03,
                capital_final=400000,
                monthly_income=2500,
            )
        ]
        result = narrator.narrate_scenarios(single)
        assert len(result.scenarios) == 1
        assert result.scenarios[0].label == "base"

    def test_narrate_unknown_label_uses_fallback(self, narrator):
        """Unknown scenario label uses fallback template."""
        custom = [
            ScenarioInput(
                label="custom_scenario",
                annual_return=0.05,
                capital_final=600000,
                monthly_income=3500,
            )
        ]
        result = narrator.narrate_scenarios(custom)
        assert len(result.scenarios) == 1
        assert "custom_scenario" in result.scenarios[0].narrative

    def test_narrate_zero_values(self, narrator):
        """Narration handles zero capital and income gracefully."""
        zero = [
            ScenarioInput(
                label="prudent",
                annual_return=0.0,
                capital_final=0,
                monthly_income=0,
            )
        ]
        result = narrator.narrate_scenarios(zero)
        assert len(result.scenarios) == 1
        # Should not crash; narrative should still be present
        assert len(result.scenarios[0].narrative) > 0

    def test_narrate_large_amounts_formatted(self, narrator):
        """Large CHF amounts are formatted with Swiss apostrophes."""
        large = [
            ScenarioInput(
                label="base",
                annual_return=0.05,
                capital_final=1234567,
                monthly_income=7890,
            )
        ]
        result = narrator.narrate_scenarios(large)
        assert "1'234'567" in result.scenarios[0].narrative
        assert "7'890" in result.scenarios[0].narrative


# ===========================================================================
# CHF FORMATTING — 3 tests
# ===========================================================================


class TestChfFormatting:
    """Tests for Swiss CHF formatting."""

    def test_format_small_amount(self):
        assert _format_chf(500) == "500"

    def test_format_thousands(self):
        assert _format_chf(12345) == "12'345"

    def test_format_millions(self):
        assert _format_chf(1234567.89) == "1'234'568"


# ===========================================================================
# ANNUAL REFRESH — 8 tests
# ===========================================================================


class TestAnnualRefresh:
    """Tests for AnnualRefreshService."""

    def test_refresh_needed_after_12_months(self, refresh_svc):
        """Refresh needed when last update was 12 months ago."""
        last_update = date(2025, 1, 1)
        today = date(2026, 1, 2)
        assert refresh_svc.check_refresh_needed(last_update, today) is True

    def test_refresh_not_needed_within_11_months(self, refresh_svc):
        """Refresh NOT needed when last update was 6 months ago."""
        last_update = date(2025, 8, 1)
        today = date(2026, 1, 1)
        assert refresh_svc.check_refresh_needed(last_update, today) is False

    def test_refresh_boundary_exactly_11_months(self, refresh_svc):
        """Refresh NOT needed at exactly 11 months (threshold is > 11)."""
        last_update = date(2025, 2, 1)
        today = date(2026, 1, 1)  # 11 months exactly
        assert refresh_svc.check_refresh_needed(last_update, today) is False

    def test_refresh_boundary_12_months(self, refresh_svc):
        """Refresh IS needed at 12 months (> 11)."""
        last_update = date(2025, 1, 1)
        today = date(2026, 1, 1)  # 12 months
        assert refresh_svc.check_refresh_needed(last_update, today) is True

    def test_generate_7_questions(self, refresh_svc):
        """Generate exactly 7 refresh questions."""
        result = refresh_svc.generate_refresh_questions(
            current_salary=85000,
            current_lpp=120000,
            current_3a=45000,
            risk_profile="modere",
            last_major_update=date(2025, 1, 1),
            today=date(2026, 2, 1),
        )
        assert isinstance(result, AnnualRefreshResult)
        assert len(result.questions) == 7

    def test_prefilled_salary(self, refresh_svc):
        """Salary question is pre-filled with formatted value."""
        result = refresh_svc.generate_refresh_questions(
            current_salary=95000,
            last_major_update=date(2025, 6, 1),
            today=date(2026, 2, 1),
        )
        salary_q = next(q for q in result.questions if q.key == "salary_changed")
        assert salary_q.current_value == "95'000"
        assert salary_q.question_type == "slider"

    def test_prefilled_lpp_and_3a(self, refresh_svc):
        """LPP and 3a questions are pre-filled."""
        result = refresh_svc.generate_refresh_questions(
            current_lpp=200000,
            current_3a=50000,
            last_major_update=date(2025, 1, 1),
            today=date(2026, 2, 1),
        )
        lpp_q = next(q for q in result.questions if q.key == "lpp_balance")
        assert lpp_q.current_value == "200'000"
        three_a_q = next(q for q in result.questions if q.key == "three_a_balance")
        assert three_a_q.current_value == "50'000"

    def test_risk_appetite_options(self, refresh_svc):
        """Risk appetite question has correct options."""
        result = refresh_svc.generate_refresh_questions(risk_profile="dynamique")
        risk_q = next(q for q in result.questions if q.key == "risk_appetite")
        assert risk_q.question_type == "select"
        assert risk_q.options == ["conservateur", "modere", "dynamique"]
        assert risk_q.current_value == "dynamique"

    def test_family_change_options(self, refresh_svc):
        """Family change question has correct options."""
        result = refresh_svc.generate_refresh_questions()
        family_q = next(q for q in result.questions if q.key == "family_change")
        assert family_q.question_type == "select"
        assert "mariage" in family_q.options
        assert "naissance" in family_q.options
        assert "divorce" in family_q.options
        assert "aucun" in family_q.options

    def test_months_since_update_calculated(self, refresh_svc):
        """months_since_update is correctly calculated."""
        result = refresh_svc.generate_refresh_questions(
            last_major_update=date(2025, 6, 1),
            today=date(2026, 2, 1),
        )
        assert result.months_since_update == 8
        assert result.refresh_needed is False

    def test_refresh_needed_flag_in_result(self, refresh_svc):
        """refresh_needed flag is True when stale."""
        result = refresh_svc.generate_refresh_questions(
            last_major_update=date(2024, 12, 1),
            today=date(2026, 2, 1),
        )
        assert result.months_since_update == 14
        assert result.refresh_needed is True


# ===========================================================================
# COMPLIANCE — 5 tests
# ===========================================================================


class TestCompliance:
    """Compliance tests: banned terms, disclaimer, sources."""

    def test_no_banned_terms_in_narratives(self, narrator, three_scenarios):
        """No banned terms appear in any narrative."""
        result = narrator.narrate_scenarios(three_scenarios)
        for ns in result.scenarios:
            lower = ns.narrative.lower()
            for term in BANNED_TERMS:
                assert term not in lower, (
                    f"Banned term '{term}' found in {ns.label} narrative: "
                    f"{ns.narrative}"
                )

    def test_no_prescriptive_language(self, narrator, three_scenarios):
        """No prescriptive language (tu devrais, tu dois, il faut)."""
        prescriptive = ["tu devrais", "tu dois", "il faut que tu"]
        result = narrator.narrate_scenarios(three_scenarios)
        for ns in result.scenarios:
            lower = ns.narrative.lower()
            for phrase in prescriptive:
                assert phrase not in lower, (
                    f"Prescriptive phrase '{phrase}' found in {ns.label}"
                )

    def test_disclaimer_present_narration(self, narrator, three_scenarios):
        """Disclaimer is present in narration result."""
        result = narrator.narrate_scenarios(three_scenarios)
        assert result.disclaimer
        assert "educatif" in result.disclaimer.lower() or "LSFin" in result.disclaimer

    def test_sources_present_narration(self, narrator, three_scenarios):
        """Sources are present in narration result."""
        result = narrator.narrate_scenarios(three_scenarios)
        assert len(result.sources) >= 1
        sources_text = " ".join(result.sources).lower()
        assert "lsfin" in sources_text or "lpp" in sources_text

    def test_disclaimer_present_refresh(self, refresh_svc):
        """Disclaimer and sources are present in refresh result."""
        result = refresh_svc.generate_refresh_questions()
        assert result.disclaimer
        assert "educatif" in result.disclaimer.lower() or "LSFin" in result.disclaimer
        assert len(result.sources) >= 1


# ===========================================================================
# API ENDPOINT INTEGRATION — 3 tests
# ===========================================================================


class TestScenarioAPI:
    """Integration tests for the /scenario endpoints."""

    def test_narrate_endpoint(self, client):
        """POST /api/v1/scenario/narrate returns 200 with narratives."""
        payload = {
            "scenarios": [
                {
                    "label": "prudent",
                    "annualReturn": 0.01,
                    "capitalFinal": 350000,
                    "monthlyIncome": 2100,
                    "replacementRatio": 0.42,
                },
                {
                    "label": "base",
                    "annualReturn": 0.045,
                    "capitalFinal": 520000,
                    "monthlyIncome": 3200,
                    "replacementRatio": 0.64,
                },
                {
                    "label": "optimiste",
                    "annualReturn": 0.07,
                    "capitalFinal": 780000,
                    "monthlyIncome": 4800,
                    "replacementRatio": 0.96,
                },
            ],
            "firstName": "Sophie",
            "age": 35,
        }
        resp = client.post("/api/v1/scenario/narrate", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["scenarios"]) == 3
        assert data["disclaimer"]
        assert data["uncertaintyMentioned"] is True
        # Check camelCase aliases
        assert "annualReturnPct" in data["scenarios"][0]
        assert "capitalFinal" in data["scenarios"][0]

    def test_refresh_check_endpoint_stale(self, client):
        """POST /api/v1/scenario/refresh-check returns refreshNeeded=true for stale profile."""
        payload = {
            "lastMajorUpdate": "2024-12-01",
            "currentSalary": 95000,
            "currentLpp": 120000,
            "current3a": 45000,
            "riskProfile": "modere",
        }
        resp = client.post("/api/v1/scenario/refresh-check", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["refreshNeeded"] is True
        assert data["monthsSinceUpdate"] > 11
        assert len(data["questions"]) == 7

    def test_refresh_check_endpoint_fresh(self, client):
        """POST /api/v1/scenario/refresh-check returns refreshNeeded=false for fresh profile."""
        payload = {
            "lastMajorUpdate": "2026-01-01",
            "currentSalary": 85000,
            "riskProfile": "conservateur",
        }
        resp = client.post("/api/v1/scenario/refresh-check", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["refreshNeeded"] is False
