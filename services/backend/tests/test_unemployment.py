"""
Tests for the Unemployment (LACI) module (Sprint S19).

Covers:
    - Unemployment calculator — rate, cap, duration, eligibility
    - Timeline and checklist generation
    - Compliance (disclaimer, sources, banned terms)
    - API endpoints (integration)

Target: 30 tests.

Run: cd services/backend && python3 -m pytest tests/test_unemployment.py -v
"""

import re
import pytest

from app.services.unemployment.calculator import (
    UnemploymentCalculator,
    DISCLAIMER,
    SOURCES,
    GAIN_ASSURE_MAX,
    UNEMPLOYMENT_RATE_BASE,
    UNEMPLOYMENT_RATE_ENHANCED,
    DELAI_CARENCE_STANDARD,
    WORKING_DAYS_PER_MONTH,
    get_orp_link,
)


# ===========================================================================
# Fixtures
# ===========================================================================

@pytest.fixture
def calculator():
    return UnemploymentCalculator()


# ===========================================================================
# Rate determination tests
# ===========================================================================

class TestUnemploymentRate:
    """Tests for LACI art. 22: indemnity rate (70% or 80%)."""

    def test_standard_rate_70_percent(self, calculator):
        """No children, salary > 3797 -> 70%."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=False, has_disability=False,
        )
        assert result["taux_indemnite"] == UNEMPLOYMENT_RATE_BASE
        assert result["taux_indemnite"] == 0.70

    def test_enhanced_rate_80_children(self, calculator):
        """has_children=True -> 80%."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=True, has_disability=False,
        )
        assert result["taux_indemnite"] == UNEMPLOYMENT_RATE_ENHANCED
        assert result["taux_indemnite"] == 0.80

    def test_enhanced_rate_80_disability(self, calculator):
        """has_disability=True -> 80%."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=False, has_disability=True,
        )
        assert result["taux_indemnite"] == UNEMPLOYMENT_RATE_ENHANCED

    def test_enhanced_rate_80_low_salary(self, calculator):
        """gain < 3797 -> 80% (LACI art. 22 al. 2)."""
        result = calculator.calculate(
            gain_assure_mensuel=3500, age=35, annees_cotisation=18,
            has_children=False, has_disability=False,
        )
        assert result["taux_indemnite"] == UNEMPLOYMENT_RATE_ENHANCED

    def test_rate_at_threshold_boundary(self, calculator):
        """gain exactly at 3797 -> should be 70% (not strictly below)."""
        result = calculator.calculate(
            gain_assure_mensuel=3797, age=35, annees_cotisation=18,
            has_children=False, has_disability=False,
        )
        # 3797 is NOT < 3797, so standard rate applies
        assert result["taux_indemnite"] == UNEMPLOYMENT_RATE_BASE


# ===========================================================================
# Gain assuré cap tests
# ===========================================================================

class TestGainAssureCap:
    """Tests for LACI art. 23: gain assuré capped at 12'350 CHF/month."""

    def test_gain_assure_capped_at_12350(self, calculator):
        """High earner -> cap at 12'350."""
        result = calculator.calculate(
            gain_assure_mensuel=20000, age=35, annees_cotisation=18,
        )
        assert result["gain_assure_retenu"] == GAIN_ASSURE_MAX

    def test_gain_assure_below_cap(self, calculator):
        """Normal salary -> use actual gain."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        assert result["gain_assure_retenu"] == 6000.0

    def test_gain_assure_exactly_at_cap(self, calculator):
        """Gain exactly at cap -> use cap value."""
        result = calculator.calculate(
            gain_assure_mensuel=12350, age=35, annees_cotisation=18,
        )
        assert result["gain_assure_retenu"] == GAIN_ASSURE_MAX

    def test_high_earner_alert(self, calculator):
        """High earner should get an alert about the cap."""
        result = calculator.calculate(
            gain_assure_mensuel=20000, age=35, annees_cotisation=18,
        )
        assert any("depasse" in a for a in result["alertes"])


# ===========================================================================
# Benefit calculation tests
# ===========================================================================

class TestBenefitCalculation:
    """Tests for daily and monthly benefit amounts."""

    def test_daily_benefit_calculation(self, calculator):
        """daily = gain_retenu * rate / 21.75."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=False,
        )
        expected_daily = round(6000 * 0.70 / WORKING_DAYS_PER_MONTH, 2)
        assert result["indemnite_journaliere"] == expected_daily

    def test_monthly_benefit_calculation(self, calculator):
        """monthly = daily * 21.75."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=False,
        )
        expected_monthly = round(
            result["indemnite_journaliere"] * WORKING_DAYS_PER_MONTH, 2
        )
        assert result["indemnite_mensuelle"] == expected_monthly

    def test_monthly_benefit_with_80_percent(self, calculator):
        """Monthly benefit at 80% should be higher than at 70%."""
        result_70 = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=False,
        )
        result_80 = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
            has_children=True,
        )
        assert result_80["indemnite_mensuelle"] > result_70["indemnite_mensuelle"]


# ===========================================================================
# Duration tests (LACI art. 27)
# ===========================================================================

class TestDuration:
    """Tests for number of indemnities based on age and contribution months."""

    def test_duration_age_under_25(self, calculator):
        """Under 25 with 12+ months -> 200 indemnities."""
        result = calculator.calculate(
            gain_assure_mensuel=4000, age=22, annees_cotisation=12,
        )
        assert result["nombre_indemnites"] == 200

    def test_duration_age_25_54_12months(self, calculator):
        """25-54 with 12-17 months -> 200 indemnities."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=15,
        )
        assert result["nombre_indemnites"] == 200

    def test_duration_age_25_54_18months(self, calculator):
        """25-54 with 18+ months -> 260 indemnities."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        assert result["nombre_indemnites"] == 260

    def test_duration_age_25_54_22months(self, calculator):
        """25-54 with 22+ months -> 400 indemnities (LACI art. 27 al. 2 lit. c)."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=24,
        )
        assert result["nombre_indemnites"] == 400

    def test_duration_age_55_59(self, calculator):
        """55+ with 22+ months -> 520 indemnities (LACI art. 27 al. 2 lit. d)."""
        result = calculator.calculate(
            gain_assure_mensuel=8000, age=57, annees_cotisation=22,
        )
        assert result["nombre_indemnites"] == 520

    def test_duration_age_60_plus(self, calculator):
        """60+ with 22+ months -> 520 indemnities."""
        result = calculator.calculate(
            gain_assure_mensuel=8000, age=62, annees_cotisation=24,
        )
        assert result["nombre_indemnites"] == 520

    def test_duration_mois_calculated(self, calculator):
        """duree_mois = nombre_indemnites / 21.75."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        expected = round(result["nombre_indemnites"] / WORKING_DAYS_PER_MONTH, 1)
        assert result["duree_mois"] == expected

    def test_edge_case_age_55_boundary(self, calculator):
        """Age exactly 55 with 22+ months -> 520 (LACI art. 27 al. 2 lit. d)."""
        result = calculator.calculate(
            gain_assure_mensuel=8000, age=55, annees_cotisation=22,
        )
        assert result["nombre_indemnites"] == 520

    def test_edge_case_max_duration_520(self, calculator):
        """Maximum duration should be 520 indemnities."""
        result = calculator.calculate(
            gain_assure_mensuel=8000, age=64, annees_cotisation=24,
        )
        assert result["nombre_indemnites"] == 520


# ===========================================================================
# Eligibility tests
# ===========================================================================

class TestEligibility:
    """Tests for eligibility rules (LACI art. 13)."""

    def test_not_eligible_under_12_months(self, calculator):
        """Less than 12 months contributions -> not eligible."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=10,
        )
        assert result["eligible"] is False
        assert result["raison_non_eligible"] is not None
        assert "cotisation" in result["raison_non_eligible"].lower()

    def test_eligible_at_12_months(self, calculator):
        """Exactly 12 months -> eligible."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=12,
        )
        assert result["eligible"] is True

    def test_edge_case_gain_zero(self, calculator):
        """Zero gain -> not eligible."""
        result = calculator.calculate(
            gain_assure_mensuel=0, age=35, annees_cotisation=18,
        )
        assert result["eligible"] is False


# ===========================================================================
# Délai de carence
# ===========================================================================

class TestDelaiCarence:
    """Tests for waiting period."""

    def test_delai_carence_5_days(self, calculator):
        """Standard waiting period is always 5 days."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        assert result["delai_carence_jours"] == DELAI_CARENCE_STANDARD
        assert result["delai_carence_jours"] == 5


# ===========================================================================
# Timeline and checklist
# ===========================================================================

class TestTimelineChecklist:
    """Tests for timeline and checklist generation."""

    def test_timeline_contains_orp(self, calculator):
        """First timeline step should be ORP registration."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        assert len(result["timeline"]) > 0
        assert "ORP" in result["timeline"][0]["action"]

    def test_timeline_contains_libre_passage(self, calculator):
        """Timeline should contain LPP transfer at day 30."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        lpp_steps = [s for s in result["timeline"] if s["jour"] == 30 and "LPP" in s["action"]]
        assert len(lpp_steps) >= 1

    def test_timeline_ordered_by_day(self, calculator):
        """Timeline steps should be ordered by day number."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        days = [step["jour"] for step in result["timeline"]]
        assert days == sorted(days)

    def test_checklist_non_empty(self, calculator):
        """Checklist should be non-empty for eligible person."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        assert len(result["checklist"]) >= 5


# ===========================================================================
# Compliance
# ===========================================================================

class TestUnemploymentCompliance:
    """Tests for compliance rules: disclaimer, sources, banned terms."""

    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
        r"\bsans\s+risque\b",
    ]

    def test_disclaimer_contains_laci(self):
        """Disclaimer should reference the legal context."""
        assert "educatif" in DISCLAIMER.lower()
        assert "LSFin" in DISCLAIMER

    def test_disclaimer_uses_specialiste(self):
        """Disclaimer should use 'specialiste' (not 'conseiller')."""
        assert "specialiste" in DISCLAIMER.lower()
        assert "conseiller" not in DISCLAIMER.lower()

    def test_sources_contain_legal_refs(self):
        """Sources should cite specific LACI/OAC articles."""
        assert len(SOURCES) >= 4
        source_text = " ".join(SOURCES)
        assert "LACI" in source_text
        assert "OAC" in source_text

    def test_premier_eclairage_non_empty(self, calculator):
        """Chiffre choc should be a non-empty string."""
        result = calculator.calculate(
            gain_assure_mensuel=6000, age=35, annees_cotisation=18,
        )
        assert len(result["premier_eclairage"]) > 20

    def test_no_banned_terms_in_disclaimer(self):
        """Disclaimer should not contain banned terms."""
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, DISCLAIMER, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in disclaimer: {matches}"
            )


# ===========================================================================
# ORP link helper
# ===========================================================================

class TestOrpLinks:
    """Tests for ORP link retrieval."""

    def test_orp_link_known_canton(self):
        """Known canton should return cantonal URL."""
        result = get_orp_link("ZH")
        assert result["canton"] == "ZH"
        assert "zh" in result["url"].lower()

    def test_orp_link_unknown_canton(self):
        """Unknown canton should fallback to arbeit.swiss."""
        result = get_orp_link("XX")
        assert result["url"] == "https://www.arbeit.swiss"

    def test_orp_link_case_insensitive(self):
        """Canton code should be case-insensitive."""
        result = get_orp_link("ge")
        assert result["canton"] == "GE"


# ===========================================================================
# API endpoints (integration)
# ===========================================================================

class TestUnemploymentEndpoints:
    """Tests for the Unemployment FastAPI endpoints."""

    def test_calculate_endpoint(self, client):
        """POST /unemployment/calculate should return 200."""
        response = client.post(
            "/api/v1/unemployment/calculate",
            json={
                "gainAssureMensuel": 6000,
                "age": 35,
                "anneesCotisation": 18,
                "hasChildren": False,
                "hasDisability": False,
                "canton": "ZH",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "tauxIndemnite" in data
        assert "indemniteJournaliere" in data
        assert "nombreIndemnites" in data
        assert "disclaimer" in data
        assert "sources" in data
        assert data["eligible"] is True

    def test_checklist_endpoint(self, client):
        """GET /unemployment/checklist should return 200."""
        response = client.get("/api/v1/unemployment/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "checklist" in data
        assert "timeline" in data
        assert len(data["checklist"]) >= 5

    def test_orp_link_endpoint(self, client):
        """GET /unemployment/orp-link/ZH should return 200."""
        response = client.get("/api/v1/unemployment/orp-link/ZH")
        assert response.status_code == 200
        data = response.json()
        assert data["canton"] == "ZH"
        assert "url" in data
