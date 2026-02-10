"""
Tests for the First Job module (Sprint S19).

Covers:
    - Salary breakdown (AVS, AC, AANP, LPP, net)
    - 3a recommendation
    - LAMal franchise comparison
    - Checklist and alerts
    - Compliance (disclaimer, sources, banned terms)
    - API endpoints (integration)

Target: 25 tests.

Run: cd services/backend && python3 -m pytest tests/test_first_job.py -v
"""

import re
import pytest

from app.services.first_job.onboarding_service import (
    FirstJobOnboardingService,
    DISCLAIMER,
    SOURCES,
    AVS_AI_APG_RATE,
    AC_RATE,
    AANP_RATE,
    LPP_ENTRY_THRESHOLD,
    LPP_COORDINATION_DEDUCTION,
    LPP_MIN_COORDINATED,
    PILLAR_3A_LIMIT,
    LAMAL_FRANCHISES,
    LAMAL_QUOTE_PART_MAX,
    get_first_job_checklist,
)


# ===========================================================================
# Fixtures
# ===========================================================================

@pytest.fixture
def service():
    return FirstJobOnboardingService()


# ===========================================================================
# Salary Breakdown tests
# ===========================================================================

class TestSalaryBreakdown:
    """Tests for gross-to-net salary decomposition."""

    def test_salary_breakdown_basic(self, service):
        """5000 CHF gross -> reasonable breakdown."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        bd = result["decomposition_salaire"]
        assert bd["brut"] == 5000
        assert bd["net_estime"] > 0
        assert bd["net_estime"] < bd["brut"]

    def test_avs_deduction_5_30_percent(self, service):
        """AVS/AI/APG deduction should be 5.30% of gross."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        bd = result["decomposition_salaire"]
        expected = round(5000 * AVS_AI_APG_RATE, 2)
        assert bd["avs_ai_apg"] == expected

    def test_ac_deduction_1_1_percent(self, service):
        """AC deduction should be 1.1% for salary under 148'200/year."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        bd = result["decomposition_salaire"]
        expected = round(5000 * AC_RATE, 2)
        assert bd["ac"] == expected

    def test_aanp_deduction(self, service):
        """AANP deduction should be ~1.3% of gross."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        bd = result["decomposition_salaire"]
        expected = round(5000 * AANP_RATE, 2)
        assert bd["aanp"] == expected

    def test_lpp_above_threshold(self, service):
        """Annual salary > 22'050 and age >= 25 -> LPP deduction > 0."""
        # 5000 * 12 = 60'000 > 22'050
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=30,
        )
        bd = result["decomposition_salaire"]
        assert bd["lpp_employe"] > 0

    def test_lpp_below_threshold(self, service):
        """Annual salary < 22'050 -> no LPP deduction."""
        # 1500 * 12 = 18'000 < 22'050
        result = service.analyze_salary(
            salaire_brut_mensuel=1500, canton="ZH", age=30,
        )
        bd = result["decomposition_salaire"]
        assert bd["lpp_employe"] == 0.0

    def test_lpp_below_age_25(self, service):
        """Age < 25 -> no LPP bonification de vieillesse."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=22,
        )
        bd = result["decomposition_salaire"]
        assert bd["lpp_employe"] == 0.0

    def test_net_salary_positive(self, service):
        """Net salary should always be positive for reasonable gross."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=30,
        )
        bd = result["decomposition_salaire"]
        assert bd["net_estime"] > 0

    def test_employer_contributions_positive(self, service):
        """Employer invisible contributions should be positive."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=30,
        )
        bd = result["decomposition_salaire"]
        assert bd["cotisations_invisibles_employeur"] > 0

    def test_part_time_salary(self, service):
        """taux_activite=80% -> LPP and AC calculated on adjusted annual."""
        result_100 = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=30, taux_activite=100,
        )
        result_80 = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=30, taux_activite=80,
        )
        # At 80%, annual income is lower, so LPP coordinated salary is different
        # AVS/AC are still on gross (they're on the actual monthly salary)
        bd_100 = result_100["decomposition_salaire"]
        bd_80 = result_80["decomposition_salaire"]
        # Same gross salary, so AVS should be the same
        assert bd_100["avs_ai_apg"] == bd_80["avs_ai_apg"]
        # LPP may differ due to lower annual basis
        # Both should have LPP > 0 since 5000*12*0.8=48000 > 22050
        assert bd_80["lpp_employe"] > 0

    def test_edge_case_minimum_salary(self, service):
        """Very low salary should still produce valid breakdown."""
        result = service.analyze_salary(
            salaire_brut_mensuel=500, canton="ZH", age=20,
        )
        bd = result["decomposition_salaire"]
        assert bd["brut"] == 500
        assert bd["net_estime"] > 0
        assert bd["net_estime"] < 500

    def test_deductions_sum_to_difference(self, service):
        """Sum of deductions should equal brut - net."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=30,
        )
        bd = result["decomposition_salaire"]
        total_deductions = bd["avs_ai_apg"] + bd["ac"] + bd["aanp"] + bd["lpp_employe"]
        expected_net = round(bd["brut"] - total_deductions, 2)
        assert abs(bd["net_estime"] - expected_net) < 0.01


# ===========================================================================
# 3a Recommendation tests
# ===========================================================================

class TestPillar3aRecommendation:
    """Tests for 3a (pillar 3a) recommendations."""

    def test_3a_eligible(self, service):
        """Working person should be eligible for 3a."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        assert result["recommandations_3a"]["eligible"] is True

    def test_3a_plafond_7258(self, service):
        """3a annual limit for employees should be 7'258 CHF."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        assert result["recommandations_3a"]["plafond_annuel"] == PILLAR_3A_LIMIT

    def test_3a_monthly_suggestion(self, service):
        """Monthly suggestion should be plafond / 12."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        expected = round(PILLAR_3A_LIMIT / 12, 2)
        assert result["recommandations_3a"]["montant_mensuel_suggere"] == expected

    def test_3a_insurance_warning(self, service):
        """Should contain warning about insurance-linked 3a products."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        alerte = result["recommandations_3a"]["alerte_assurance_vie"]
        assert "assurance-vie" in alerte.lower()
        assert len(alerte) > 20

    def test_3a_tax_savings_positive(self, service):
        """Tax savings should be positive for working person."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        assert result["recommandations_3a"]["economie_fiscale_estimee"] > 0


# ===========================================================================
# LAMal Franchise tests
# ===========================================================================

class TestLamalFranchise:
    """Tests for LAMal franchise recommendations."""

    def test_lamal_franchise_options_6(self, service):
        """Should have exactly 6 franchise options."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        options = result["recommandation_lamal"]["franchises_disponibles"]
        assert len(options) == 6

    def test_lamal_franchise_values(self, service):
        """Franchise values should be 300, 500, 1000, 1500, 2000, 2500."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        options = result["recommandation_lamal"]["franchises_disponibles"]
        franchises = [o["franchise"] for o in options]
        assert franchises == LAMAL_FRANCHISES

    def test_lamal_cost_comparison(self, service):
        """Each option should have cost_annuel_max > 0."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        options = result["recommandation_lamal"]["franchises_disponibles"]
        for opt in options:
            assert opt["cout_annuel_max"] > 0
            assert opt["prime_mensuelle_estimee"] > 0

    def test_lamal_recommended_franchise_young_healthy(self, service):
        """Young person (< 35) -> recommended franchise 2500."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        assert result["recommandation_lamal"]["franchise_recommandee"] == 2500

    def test_lamal_recommended_franchise_older(self, service):
        """Older person (50+) -> recommended franchise 300."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=55,
        )
        assert result["recommandation_lamal"]["franchise_recommandee"] == 300


# ===========================================================================
# Checklist and alerts
# ===========================================================================

class TestFirstJobChecklistAlerts:
    """Tests for checklist and alerts."""

    def test_checklist_contains_3a(self, service):
        """Checklist should mention 3a."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        checklist_text = " ".join(result["checklist_premier_emploi"])
        assert "3a" in checklist_text

    def test_checklist_contains_lamal(self, service):
        """Checklist should mention LAMal."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        checklist_text = " ".join(result["checklist_premier_emploi"])
        assert "LAMal" in checklist_text or "franchise" in checklist_text.lower()

    def test_checklist_contains_rc(self, service):
        """Checklist should mention RC (responsabilite civile)."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        checklist_text = " ".join(result["checklist_premier_emploi"])
        assert "RC" in checklist_text

    def test_checklist_non_empty(self, service):
        """Checklist should have at least 5 items."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        assert len(result["checklist_premier_emploi"]) >= 5


# ===========================================================================
# Compliance
# ===========================================================================

class TestFirstJobCompliance:
    """Tests for compliance: disclaimer, sources, banned terms."""

    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
        r"\bsans\s+risque\b",
    ]

    def test_disclaimer_present(self):
        """Disclaimer should be present and reference educatif + LSFin."""
        assert "educatif" in DISCLAIMER.lower()
        assert "LSFin" in DISCLAIMER
        assert "specialiste" in DISCLAIMER.lower()

    def test_sources_present(self):
        """Sources should cite specific legal references."""
        assert len(SOURCES) >= 5
        source_text = " ".join(SOURCES)
        assert "LAVS" in source_text
        assert "LPP" in source_text
        assert "OPP3" in source_text
        assert "LAMal" in source_text

    def test_no_banned_terms_in_disclaimer(self):
        """Disclaimer should not contain banned terms."""
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, DISCLAIMER, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in disclaimer: {matches}"
            )

    def test_chiffre_choc_present(self, service):
        """Chiffre choc should be non-empty."""
        result = service.analyze_salary(
            salaire_brut_mensuel=5000, canton="ZH", age=25,
        )
        assert len(result["chiffre_choc"]) > 20
        assert "CHF" in result["chiffre_choc"]


# ===========================================================================
# API endpoints (integration)
# ===========================================================================

class TestFirstJobEndpoints:
    """Tests for the First Job FastAPI endpoints."""

    def test_analyze_endpoint(self, client):
        """POST /first-job/analyze should return 200."""
        response = client.post(
            "/api/v1/first-job/analyze",
            json={
                "salaireBrutMensuel": 5000,
                "canton": "ZH",
                "age": 25,
                "etatCivil": "celibataire",
                "hasChildren": False,
                "tauxActivite": 100.0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "decompositionSalaire" in data
        assert "recommandations3A" in data
        assert "recommandationLamal" in data
        assert "checklistPremierEmploi" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_analyze_endpoint_salary_breakdown(self, client):
        """POST /first-job/analyze -> salary breakdown has all fields."""
        response = client.post(
            "/api/v1/first-job/analyze",
            json={
                "salaireBrutMensuel": 6000,
                "canton": "VD",
                "age": 30,
                "etatCivil": "celibataire",
                "hasChildren": False,
                "tauxActivite": 100.0,
            },
        )
        assert response.status_code == 200
        bd = response.json()["decompositionSalaire"]
        assert "brut" in bd
        assert "avsAiApg" in bd
        assert "ac" in bd
        assert "aanp" in bd
        assert "lppEmploye" in bd
        assert "netEstime" in bd
        assert "cotisationsInvisiblesEmployeur" in bd

    def test_checklist_endpoint(self, client):
        """GET /first-job/checklist should return 200."""
        response = client.get("/api/v1/first-job/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "checklist" in data
        assert len(data["checklist"]) >= 5
