"""
Tests for Assurances module (Sprint S13, Chantier 7).

Covers:
    - LAMal Franchise Optimizer (service + edge cases)
    - Coverage Checklist (service + profile-based logic)
    - API endpoints (POST /lamal/optimize, POST /coverage/check)
    - Compliance (no banned terms, disclaimer, sources, gender-neutral)

Target: 35+ tests.
"""

import pytest
import re
from app.services.lamal_franchise_service import (
    LamalFranchiseOptimizer,
    LamalFranchiseInput,
    FRANCHISE_LEVELS_ADULT,
    FRANCHISE_LEVELS_CHILD,
    QUOTE_PART_CAP_ADULT,
    QUOTE_PART_CAP_CHILD,
)
from app.services.coverage_checklist_service import (
    CoverageChecklistService,
    CoverageCheckInput,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def optimizer():
    return LamalFranchiseOptimizer()


@pytest.fixture
def coverage_service():
    return CoverageChecklistService()


# ===========================================================================
# TestLamalFranchise — Service layer (12+ tests)
# ===========================================================================

class TestLamalFranchise:
    """Tests for the LAMal franchise optimizer service."""

    def test_low_expenses_franchise_2500_optimal(self, optimizer):
        """Low expenses (< 500 CHF) should result in franchise 2500 being optimal."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=200.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert result.franchise_optimale == 2500

    def test_high_expenses_franchise_300_optimal(self, optimizer):
        """High expenses with modest premium should result in franchise 300 being optimal.
        With a lower premium, the absolute savings from higher franchises are smaller,
        so the out-of-pocket costs dominate and franchise 300 wins."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=200.0,
            depenses_sante_annuelles=8000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert result.franchise_optimale == 300

    def test_medium_expenses_intermediate_franchise(self, optimizer):
        """Medium expenses should result in an intermediate franchise."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=1500.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        # Should be between 300 and 2500 (inclusive)
        assert 300 <= result.franchise_optimale <= 2500

    def test_break_even_calculation_has_entries(self, optimizer):
        """Break-even calculation should produce entries for consecutive pairs."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=1000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert len(result.break_even_points) > 0
        # Each entry should have the expected keys
        for bp in result.break_even_points:
            assert "franchise_basse" in bp
            assert "franchise_haute" in bp
            assert "seuil_depenses" in bp
            assert bp["seuil_depenses"] >= 0

    def test_break_even_monotonic(self, optimizer):
        """Break-even thresholds should generally increase with franchise level."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=1000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        if len(result.break_even_points) >= 2:
            for i in range(len(result.break_even_points) - 1):
                assert (
                    result.break_even_points[i]["seuil_depenses"]
                    <= result.break_even_points[i + 1]["seuil_depenses"]
                )

    def test_quote_part_cap_700_adult(self, optimizer):
        """Quote-part should be capped at 700 CHF for adults."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=50000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        # For franchise 300, quote_part = min((50000-300)*0.10, 700) = 700
        entry_300 = [e for e in result.comparaison if e["franchise"] == 300][0]
        assert entry_300["quote_part"] == QUOTE_PART_CAP_ADULT

    def test_children_franchise_levels(self, optimizer):
        """Children should use child franchise levels [0, 100, ..., 600]."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=120.0,
            depenses_sante_annuelles=300.0,
            age_category="child",
        )
        result = optimizer.optimize(inp)
        franchises = [e["franchise"] for e in result.comparaison]
        assert franchises == FRANCHISE_LEVELS_CHILD

    def test_children_quote_part_cap_350(self, optimizer):
        """Quote-part should be capped at 350 CHF for children."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=120.0,
            depenses_sante_annuelles=20000.0,
            age_category="child",
        )
        result = optimizer.optimize(inp)
        # For franchise 0, QP = min(20000 * 0.10, 350) = 350
        entry_0 = [e for e in result.comparaison if e["franchise"] == 0][0]
        assert entry_0["quote_part"] == QUOTE_PART_CAP_CHILD

    def test_zero_expenses(self, optimizer):
        """Zero expenses: franchise_effective and quote_part should be 0 for all levels."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=0.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        for entry in result.comparaison:
            assert entry["franchise_effective"] == 0.0
            assert entry["quote_part"] == 0.0
        # Highest franchise should be optimal (lowest premiums, no out-of-pocket)
        assert result.franchise_optimale == 2500

    def test_very_high_expenses(self, optimizer):
        """Very high expenses with modest premium: franchise 300 should be optimal."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=200.0,
            depenses_sante_annuelles=100000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert result.franchise_optimale == 300

    def test_recommendation_generation_low_expenses(self, optimizer):
        """Low expenses should generate recommendation for high franchise."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=200.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert len(result.recommandations) >= 1
        assert any("elevee" in r["titre"].lower() for r in result.recommandations)

    def test_recommendation_generation_high_expenses(self, optimizer):
        """High expenses should generate recommendation for low franchise."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=8000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert any("basse" in r["titre"].lower() for r in result.recommandations)

    def test_deadline_reminder_present(self, optimizer):
        """Deadline reminder should always be present and mention 30 novembre."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=1000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert "30 novembre" in result.alerte_delai
        assert len(result.alerte_delai) > 0

    def test_comparaison_has_all_adult_levels(self, optimizer):
        """Comparison should include all 6 adult franchise levels."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=1000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        assert len(result.comparaison) == len(FRANCHISE_LEVELS_ADULT)
        franchises = [e["franchise"] for e in result.comparaison]
        assert franchises == FRANCHISE_LEVELS_ADULT

    def test_cout_total_decreasing_then_increasing(self, optimizer):
        """For medium expenses, total cost should decrease then increase across franchises."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=2000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        costs = [e["cout_total"] for e in result.comparaison]
        # There should be a minimum somewhere (not necessarily at the extremes)
        min_cost = min(costs)
        assert min_cost < costs[0] or min_cost < costs[-1]

    def test_economie_vs_ref_for_reference_is_zero(self, optimizer):
        """The reference franchise should have 0 economie_vs_ref."""
        inp = LamalFranchiseInput(
            prime_mensuelle_base=400.0,
            depenses_sante_annuelles=1000.0,
            age_category="adult",
        )
        result = optimizer.optimize(inp)
        entry_300 = [e for e in result.comparaison if e["franchise"] == 300][0]
        assert entry_300["economie_vs_ref"] == 0.0


# ===========================================================================
# TestCoverageCheck — Service layer (10+ tests)
# ===========================================================================

class TestCoverageCheck:
    """Tests for the coverage checklist service."""

    def test_independant_without_ijm_critique(self, coverage_service):
        """Independant without IJM should have critique alert."""
        inp = CoverageCheckInput(
            statut_professionnel="independant",
            a_ijm_collective=False,
        )
        result = coverage_service.evaluate(inp)
        ijm_items = [i for i in result.checklist if i["id"] == "ijm_individuelle"]
        assert len(ijm_items) == 1
        assert ijm_items[0]["urgence"] == "critique"
        assert ijm_items[0]["statut"] == "non_couvert"
        assert result.lacunes_critiques >= 1

    def test_independant_without_laa_critique(self, coverage_service):
        """Independant without LAA should have critique alert."""
        inp = CoverageCheckInput(
            statut_professionnel="independant",
            a_laa=False,
        )
        result = coverage_service.evaluate(inp)
        laa_items = [i for i in result.checklist if i["id"] == "laa_privee"]
        assert len(laa_items) == 1
        assert laa_items[0]["urgence"] == "critique"
        assert laa_items[0]["statut"] == "non_couvert"

    def test_salarie_full_coverage_high_score(self, coverage_service):
        """Salarie with full coverage should have a high score."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
            a_ijm_collective=True,
            a_laa=True,
            a_rc_privee=True,
            a_menage=True,
            a_protection_juridique=True,
            a_assurance_voyage=True,
            a_assurance_deces=True,
        )
        result = coverage_service.evaluate(inp)
        assert result.score_couverture >= 80

    def test_locataire_protection_juridique_recommended(self, coverage_service):
        """Locataire should have protection juridique recommended."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
            est_locataire=True,
        )
        result = coverage_service.evaluate(inp)
        pj_items = [i for i in result.checklist if i["id"] == "protection_juridique"]
        assert len(pj_items) == 1
        assert pj_items[0]["categorie"] == "recommandee"

    def test_famille_hypotheque_assurance_deces_haute(self, coverage_service):
        """Famille with hypotheque should have assurance deces with haute urgence."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
            a_hypotheque=True,
            a_famille=True,
            a_assurance_deces=False,
        )
        result = coverage_service.evaluate(inp)
        deces_items = [i for i in result.checklist if i["id"] == "assurance_deces"]
        assert len(deces_items) == 1
        assert deces_items[0]["urgence"] == "haute"
        assert deces_items[0]["categorie"] == "recommandee"

    def test_score_calculation_accuracy(self, coverage_service):
        """Score should be 0-100 and reflect coverage state."""
        # No coverage at all
        inp_none = CoverageCheckInput(
            statut_professionnel="independant",
            a_ijm_collective=False,
            a_laa=False,
            a_rc_privee=False,
            a_menage=False,
        )
        result_none = coverage_service.evaluate(inp_none)
        assert 0 <= result_none.score_couverture <= 100

        # Full coverage
        inp_full = CoverageCheckInput(
            statut_professionnel="salarie",
            a_ijm_collective=True,
            a_laa=True,
            a_rc_privee=True,
            a_menage=True,
            a_protection_juridique=True,
            a_assurance_voyage=True,
            a_assurance_deces=True,
        )
        result_full = coverage_service.evaluate(inp_full)
        assert result_full.score_couverture > result_none.score_couverture

    def test_all_items_have_sources(self, coverage_service):
        """Every checklist item should have a source reference."""
        inp = CoverageCheckInput(
            statut_professionnel="independant",
        )
        result = coverage_service.evaluate(inp)
        for item in result.checklist:
            assert "source" in item
            assert len(item["source"]) > 0

    def test_independant_has_rc_professionnelle(self, coverage_service):
        """Independant should have RC professionnelle in checklist."""
        inp = CoverageCheckInput(
            statut_professionnel="independant",
        )
        result = coverage_service.evaluate(inp)
        rc_pro = [i for i in result.checklist if i["id"] == "rc_professionnelle"]
        assert len(rc_pro) == 1

    def test_salarie_no_rc_professionnelle(self, coverage_service):
        """Salarie should NOT have RC professionnelle in checklist."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
        )
        result = coverage_service.evaluate(inp)
        rc_pro = [i for i in result.checklist if i["id"] == "rc_professionnelle"]
        assert len(rc_pro) == 0

    def test_canton_vd_menage_obligatoire(self, coverage_service):
        """Canton VD should mark assurance menage as obligatoire."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
            canton="VD",
            a_menage=False,
        )
        result = coverage_service.evaluate(inp)
        menage = [i for i in result.checklist if i["id"] == "assurance_menage"]
        assert len(menage) == 1
        assert menage[0]["categorie"] == "obligatoire"
        assert menage[0]["urgence"] == "critique"

    def test_canton_ge_menage_not_obligatoire(self, coverage_service):
        """Canton GE should mark assurance menage as recommandee (not obligatoire)."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
            canton="GE",
        )
        result = coverage_service.evaluate(inp)
        menage = [i for i in result.checklist if i["id"] == "assurance_menage"]
        assert len(menage) == 1
        assert menage[0]["categorie"] == "recommandee"

    def test_voyages_frequents_assurance_voyage_recommended(self, coverage_service):
        """Frequent traveler should have travel insurance recommended."""
        inp = CoverageCheckInput(
            statut_professionnel="salarie",
            voyages_frequents=True,
        )
        result = coverage_service.evaluate(inp)
        voyage = [i for i in result.checklist if i["id"] == "assurance_voyage"]
        assert len(voyage) == 1
        assert voyage[0]["categorie"] == "recommandee"
        assert voyage[0]["urgence"] == "moyenne"

    def test_recommendations_for_uncovered_items(self, coverage_service):
        """Recommendations should be generated for uncovered items."""
        inp = CoverageCheckInput(
            statut_professionnel="independant",
            a_ijm_collective=False,
            a_laa=False,
            a_rc_privee=False,
        )
        result = coverage_service.evaluate(inp)
        assert len(result.recommandations) >= 3
        # Critical items should be first
        if len(result.recommandations) >= 2:
            assert result.recommandations[0]["priorite"] == "haute"


# ===========================================================================
# TestAssurancesEndpoints — API integration (6+ tests)
# ===========================================================================

class TestAssurancesEndpoints:
    """Tests for the FastAPI endpoints."""

    def test_lamal_optimize_returns_200(self, client):
        """POST /api/v1/assurances/lamal/optimize returns 200."""
        payload = {
            "primeMensuelleBase": 400.0,
            "depensesSanteAnnuelles": 1500.0,
            "ageCategory": "adult",
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "comparaison" in data
        assert "franchiseOptimale" in data
        assert "breakEvenPoints" in data
        assert "recommandations" in data
        assert "alerteDelai" in data
        assert "disclaimer" in data

    def test_lamal_optimize_structure(self, client):
        """POST /lamal/optimize response structure is correct."""
        payload = {
            "primeMensuelleBase": 350.0,
            "depensesSanteAnnuelles": 500.0,
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        assert response.status_code == 200
        data = response.json()

        # Check comparaison structure
        assert len(data["comparaison"]) == 6  # 6 adult franchise levels
        first = data["comparaison"][0]
        assert "franchise" in first
        assert "primeAnnuelle" in first
        assert "franchiseEffective" in first
        assert "quotePart" in first
        assert "coutTotal" in first
        assert "economieVsRef" in first

    def test_coverage_check_returns_200(self, client):
        """POST /api/v1/assurances/coverage/check returns 200."""
        payload = {
            "statutProfessionnel": "salarie",
            "aHypotheque": False,
            "aFamille": True,
            "estLocataire": True,
            "voyagesFrequents": False,
            "aIjmCollective": True,
            "aLaa": True,
            "aRcPrivee": True,
            "aMenage": True,
            "aProtectionJuridique": False,
            "aAssuranceVoyage": False,
            "aAssuranceDeces": False,
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "checklist" in data
        assert "scoreCouverture" in data
        assert "lacunesCritiques" in data
        assert "recommandations" in data
        assert "disclaimer" in data

    def test_coverage_check_structure(self, client):
        """POST /coverage/check response checklist items have correct structure."""
        payload = {
            "statutProfessionnel": "independant",
            "canton": "ZH",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        assert response.status_code == 200
        data = response.json()

        assert len(data["checklist"]) >= 7
        first = data["checklist"][0]
        assert "id" in first
        assert "categorie" in first
        assert "titre" in first
        assert "description" in first
        assert "urgence" in first
        assert "statut" in first
        assert "source" in first

    def test_invalid_input_returns_422(self, client):
        """Invalid input should return 422."""
        # Missing required field
        payload = {
            "depensesSanteAnnuelles": 1000.0,
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        assert response.status_code == 422

    def test_invalid_prime_returns_422(self, client):
        """Negative prime should return 422."""
        payload = {
            "primeMensuelleBase": -100.0,
            "depensesSanteAnnuelles": 1000.0,
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        assert response.status_code == 422

    def test_invalid_statut_returns_422(self, client):
        """Invalid statut professionnel should return 422."""
        payload = {
            "statutProfessionnel": "invalid_status",
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        assert response.status_code == 422

    def test_lamal_optimize_child(self, client):
        """POST /lamal/optimize with child category should use child levels."""
        payload = {
            "primeMensuelleBase": 120.0,
            "depensesSanteAnnuelles": 500.0,
            "ageCategory": "child",
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert len(data["comparaison"]) == 7  # 7 child franchise levels
        franchises = [e["franchise"] for e in data["comparaison"]]
        assert franchises == [0, 100, 200, 300, 400, 500, 600]


# ===========================================================================
# TestAssurancesCompliance — Compliance checks (4+ tests)
# ===========================================================================

class TestAssurancesCompliance:
    """Tests for compliance rules (banned terms, disclaimers, sources, gender)."""

    # Banned terms: "garanti", "assure" (as guarantee), "certain"
    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        # "assure" in guarantee context: check "est assure" but NOT "salaire assure"
        # We check for "est assure" / "sont assures" patterns
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
    ]

    def _collect_all_text(self, data: dict) -> str:
        """Recursively collect all text from a response dict."""
        texts = []
        if isinstance(data, dict):
            for value in data.values():
                texts.append(self._collect_all_text(value))
        elif isinstance(data, list):
            for item in data:
                texts.append(self._collect_all_text(item))
        elif isinstance(data, str):
            texts.append(data)
        return " ".join(texts)

    def test_no_banned_terms_lamal(self, client):
        """LAMal optimizer output should not contain banned terms."""
        payload = {
            "primeMensuelleBase": 400.0,
            "depensesSanteAnnuelles": 1500.0,
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        data = response.json()
        all_text = self._collect_all_text(data).lower()

        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_text, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in LAMal output: {matches}"
            )

    def test_no_banned_terms_coverage(self, client):
        """Coverage check output should not contain banned terms."""
        payload = {
            "statutProfessionnel": "independant",
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        data = response.json()
        all_text = self._collect_all_text(data).lower()

        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_text, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in coverage output: {matches}"
            )

    def test_disclaimer_always_present_lamal(self, client):
        """LAMal optimizer should always include a disclaimer."""
        payload = {
            "primeMensuelleBase": 400.0,
            "depensesSanteAnnuelles": 1500.0,
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        data = response.json()
        assert "disclaimer" in data
        assert len(data["disclaimer"]) > 50
        # Should mention educational nature
        assert "educatif" in data["disclaimer"].lower() or "indicatif" in data["disclaimer"].lower()

    def test_disclaimer_always_present_coverage(self, client):
        """Coverage check should always include a disclaimer."""
        payload = {
            "statutProfessionnel": "salarie",
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        data = response.json()
        assert "disclaimer" in data
        assert len(data["disclaimer"]) > 50

    def test_all_recommendations_have_sources_lamal(self, client):
        """All LAMal recommendations should have source references."""
        payload = {
            "primeMensuelleBase": 400.0,
            "depensesSanteAnnuelles": 1500.0,
        }
        response = client.post("/api/v1/assurances/lamal/optimize", json=payload)
        data = response.json()
        for rec in data["recommandations"]:
            assert "source" in rec
            assert len(rec["source"]) > 0

    def test_all_recommendations_have_sources_coverage(self, client):
        """All coverage recommendations should have source references."""
        payload = {
            "statutProfessionnel": "independant",
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        data = response.json()
        for rec in data["recommandations"]:
            assert "source" in rec
            assert len(rec["source"]) > 0

    def test_all_checklist_items_have_sources(self, client):
        """All checklist items should have source references."""
        payload = {
            "statutProfessionnel": "independant",
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        data = response.json()
        for item in data["checklist"]:
            assert "source" in item
            assert len(item["source"]) > 0

    def test_gender_neutral_language(self, client):
        """Output should use gender-neutral language."""
        # Test coverage output which has more descriptive text
        payload = {
            "statutProfessionnel": "independant",
            "canton": "GE",
        }
        response = client.post("/api/v1/assurances/coverage/check", json=payload)
        data = response.json()
        all_text = self._collect_all_text(data).lower()

        # Should use "personne" / gender-neutral forms, not gendered terms
        # Should NOT use "il doit", "elle doit" etc.
        gendered_patterns = [
            r"\bil doit\b",
            r"\belle doit\b",
            r"\bl'assure doit\b",
        ]
        for pattern in gendered_patterns:
            matches = re.findall(pattern, all_text)
            assert len(matches) == 0, (
                f"Gendered pattern '{pattern}' found: {matches}"
            )
