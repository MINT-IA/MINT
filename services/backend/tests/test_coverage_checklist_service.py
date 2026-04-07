"""
Tests for CoverageChecklistService (P1 — insurance coverage evaluation).

Covers:
    - Full coverage profile returns all items checked
    - Missing disability/death insurance flagged
    - Independent without LPP shows critical IJM/LAA gaps
    - Retiree / sans_emploi differences
    - Score calculation
    - Canton-specific obligatory insurance (VD menage)

Run: cd services/backend && python3 -m pytest tests/test_coverage_checklist_service.py -v
"""

import pytest

from app.services.coverage_checklist_service import (
    CoverageChecklistService,
    CoverageCheckInput,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def service():
    return CoverageChecklistService()


def _base_input(**overrides) -> CoverageCheckInput:
    defaults = dict(
        statut_professionnel="salarie",
        a_hypotheque=False,
        a_famille=False,
        est_locataire=False,
        voyages_frequents=False,
        a_ijm_collective=True,
        a_laa=True,
        a_rc_privee=True,
        a_menage=True,
        a_protection_juridique=True,
        a_assurance_voyage=True,
        a_assurance_deces=True,
        canton="GE",
    )
    defaults.update(overrides)
    return CoverageCheckInput(**defaults)


# ---------------------------------------------------------------------------
# Full Coverage Tests
# ---------------------------------------------------------------------------

class TestFullCoverage:

    def test_all_covered_high_score(self, service):
        """Fully covered profile returns high score (>= 80)."""
        data = _base_input()
        result = service.evaluate(data)
        assert result.score_couverture >= 80
        assert result.lacunes_critiques == 0

    def test_all_covered_no_critical_gaps(self, service):
        """Fully covered profile has 0 critical gaps."""
        data = _base_input()
        result = service.evaluate(data)
        assert result.lacunes_critiques == 0


# ---------------------------------------------------------------------------
# Missing Insurance Tests
# ---------------------------------------------------------------------------

class TestMissingInsurance:

    def test_missing_death_insurance_flagged_with_family(self, service):
        """Missing death insurance flagged as urgent when family depends on it."""
        data = _base_input(a_assurance_deces=False, a_famille=True)
        result = service.evaluate(data)
        deces_items = [
            i for i in result.checklist if i["id"] == "assurance_deces"
        ]
        assert len(deces_items) == 1
        assert deces_items[0]["statut"] == "non_couvert"
        assert deces_items[0]["urgence"] == "haute"

    def test_missing_death_insurance_low_urgency_no_family(self, service):
        """Missing death insurance is low urgency without dependents."""
        data = _base_input(a_assurance_deces=False, a_famille=False, a_hypotheque=False)
        result = service.evaluate(data)
        deces_items = [
            i for i in result.checklist if i["id"] == "assurance_deces"
        ]
        assert deces_items[0]["urgence"] == "basse"

    def test_missing_rc_privee_flagged(self, service):
        """Missing RC privee is always flagged as high urgency."""
        data = _base_input(a_rc_privee=False)
        result = service.evaluate(data)
        rc_items = [i for i in result.checklist if i["id"] == "rc_privee"]
        assert rc_items[0]["statut"] == "non_couvert"
        assert rc_items[0]["urgence"] == "haute"


# ---------------------------------------------------------------------------
# Independent Worker Tests
# ---------------------------------------------------------------------------

class TestIndependent:

    def test_independant_without_ijm_critical(self, service):
        """Independent without IJM has critical gap."""
        data = _base_input(
            statut_professionnel="independant",
            a_ijm_collective=False,
        )
        result = service.evaluate(data)
        ijm_items = [i for i in result.checklist if i["id"] == "ijm_individuelle"]
        assert ijm_items[0]["urgence"] == "critique"
        assert ijm_items[0]["statut"] == "non_couvert"
        assert result.lacunes_critiques >= 1

    def test_independant_without_laa_critical(self, service):
        """Independent without LAA has critical gap."""
        data = _base_input(
            statut_professionnel="independant",
            a_laa=False,
        )
        result = service.evaluate(data)
        laa_items = [i for i in result.checklist if i["id"] == "laa_privee"]
        assert laa_items[0]["urgence"] == "critique"
        assert laa_items[0]["statut"] == "non_couvert"

    def test_independant_has_rc_professionnelle(self, service):
        """Independent gets RC professionnelle in checklist."""
        data = _base_input(statut_professionnel="independant")
        result = service.evaluate(data)
        rc_pro = [i for i in result.checklist if i["id"] == "rc_professionnelle"]
        assert len(rc_pro) == 1

    def test_salarie_no_rc_professionnelle(self, service):
        """Salaried person does NOT get RC professionnelle."""
        data = _base_input(statut_professionnel="salarie")
        result = service.evaluate(data)
        rc_pro = [i for i in result.checklist if i["id"] == "rc_professionnelle"]
        assert len(rc_pro) == 0


# ---------------------------------------------------------------------------
# Canton-Specific Tests
# ---------------------------------------------------------------------------

class TestCantonSpecific:

    def test_vd_menage_obligatoire(self, service):
        """In VD, household insurance is obligatoire."""
        data = _base_input(canton="VD", a_menage=False)
        result = service.evaluate(data)
        menage = [i for i in result.checklist if i["id"] == "assurance_menage"]
        assert menage[0]["categorie"] == "obligatoire"
        assert menage[0]["urgence"] == "critique"

    def test_ge_menage_recommandee(self, service):
        """In GE, household insurance is only recommended, not obligatory."""
        data = _base_input(canton="GE", a_menage=False)
        result = service.evaluate(data)
        menage = [i for i in result.checklist if i["id"] == "assurance_menage"]
        assert menage[0]["categorie"] == "recommandee"


# ---------------------------------------------------------------------------
# Score + Recommendations Tests
# ---------------------------------------------------------------------------

class TestScoreAndRecommendations:

    def test_zero_coverage_low_score(self, service):
        """Nothing covered should yield low score."""
        data = _base_input(
            a_rc_privee=False,
            a_menage=False,
            a_protection_juridique=False,
            a_assurance_voyage=False,
            a_assurance_deces=False,
            a_ijm_collective=False,
            a_laa=False,
        )
        result = service.evaluate(data)
        assert result.score_couverture < 30

    def test_recommendations_for_uncovered(self, service):
        """Recommendations generated for each uncovered item."""
        data = _base_input(a_rc_privee=False, a_menage=False)
        result = service.evaluate(data)
        rec_ids = {r["id"] for r in result.recommandations}
        assert "rec_rc_privee" in rec_ids
        assert "rec_assurance_menage" in rec_ids

    def test_disclaimer_present(self, service):
        """Result includes compliance disclaimer."""
        result = service.evaluate(_base_input())
        assert "educatif" in result.disclaimer.lower()
