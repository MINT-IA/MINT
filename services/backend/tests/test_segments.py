"""
Tests for Sociological Segments: Gender Gap, Frontalier, Independant.

Sprint S12, Chantier 6: 50+ tests covering:
    - TestGenderGap (10+ tests): 60% vs 100%, 80% vs 100%, age impact,
      coordination deduction, rente projection
    - TestFrontalier (15+ tests): 5 countries x (3a rights, fiscal regime,
      LPP rules), quasi-resident GE
    - TestIndependant (10+ tests): AVS calculation, 3a plafond, coverage
      gaps, protection cost
    - TestSegmentsEndpoints (10+ tests): 3 endpoints x (success, validation
      error, specific scenarios)
    - TestSegmentsCompliance (5+ tests): no banned terms, sources present,
      French language
"""

import pytest
from app.services.gender_gap_service import (
    GenderGapService,
    GenderGapInput,
    COORDINATION_DEDUCTION,
    SALAIRE_COORDONNE_MAX,
    CONVERSION_RATE,
    OFS_GENDER_GAP_STAT,
)
from app.services.frontalier_service import (
    FrontalierService,
    FrontalierInput,
    COUNTRY_RULES,
    PAYS_FRONTALIERS,
)
from app.services.independant_service import (
    IndependantService,
    IndependantInput,
    AVS_FULL_RATE,
    AVS_MINIMUM_CONTRIBUTION,
    AVS_MINIMUM_INCOME_THRESHOLD,
    PLAFOND_3A_INDEPENDANT_MAX,
    PLAFOND_3A_INDEPENDANT_TAUX,
    PLAFOND_3A_SALARIE,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def gender_gap_service():
    return GenderGapService()


@pytest.fixture
def frontalier_service():
    return FrontalierService()


@pytest.fixture
def independant_service():
    return IndependantService()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _gg_input(**kwargs) -> GenderGapInput:
    """Create a GenderGapInput with sensible defaults."""
    defaults = dict(
        taux_activite=60.0,
        age=40,
        revenu_annuel=60_000.0,
        salaire_coordonne=34_275.0,
        avoir_lpp=100_000.0,
        annees_cotisation=10,
        canton="GE",
    )
    defaults.update(kwargs)
    return GenderGapInput(**defaults)


def _front_input(**kwargs) -> FrontalierInput:
    """Create a FrontalierInput with sensible defaults."""
    defaults = dict(
        pays_residence="FR",
        permis="G",
        canton_travail="GE",
        revenu_brut=85_000.0,
        a_3a=False,
        a_lpp=True,
        etat_civil="celibataire",
        nombre_enfants=0,
        part_revenu_suisse=1.0,
    )
    defaults.update(kwargs)
    return FrontalierInput(**defaults)


def _ind_input(**kwargs) -> IndependantInput:
    """Create an IndependantInput with sensible defaults."""
    defaults = dict(
        revenu_net=80_000.0,
        age=35,
        a_lpp_volontaire=False,
        a_3a=False,
        a_ijm=False,
        a_laa=False,
        canton="GE",
    )
    defaults.update(kwargs)
    return IndependantInput(**defaults)


# ===========================================================================
# TestGenderGap
# ===========================================================================

class TestGenderGap:
    """Tests for gender gap pension analysis."""

    def test_60_vs_100_has_gap(self, gender_gap_service):
        """60% activity should produce a positive pension gap vs 100%."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=60.0))
        assert result.lacune_annuelle_chf > 0
        assert result.rente_estimee_plein_temps > result.rente_estimee_actuelle

    def test_80_vs_100_smaller_gap(self, gender_gap_service):
        """80% activity gap should be smaller than 60% gap."""
        result_60 = gender_gap_service.analyze(_gg_input(taux_activite=60.0))
        result_80 = gender_gap_service.analyze(_gg_input(taux_activite=80.0))
        assert result_80.lacune_annuelle_chf < result_60.lacune_annuelle_chf
        assert result_80.lacune_annuelle_chf > 0

    def test_100_no_gap(self, gender_gap_service):
        """100% activity should produce zero gap."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=100.0))
        assert result.lacune_annuelle_chf == 0
        assert result.rente_estimee_plein_temps == result.rente_estimee_actuelle

    def test_coordination_deduction_impact(self, gender_gap_service):
        """Non-prorated coordination deduction should show positive impact for part-time."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=60.0))
        # impact_coordination = prorated salaire_coord - non-prorated salaire_coord
        # For part-time, prorated deduction is lower, so coordinated salary is higher
        assert result.impact_coordination > 0

    def test_coordination_deduction_zero_at_100(self, gender_gap_service):
        """At 100%, prorated and non-prorated coordination are the same."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=100.0))
        assert result.impact_coordination == 0

    def test_age_impact_younger_larger_gap(self, gender_gap_service):
        """Younger workers accumulate larger lifetime gaps due to more years."""
        result_30 = gender_gap_service.analyze(
            _gg_input(taux_activite=60.0, age=30)
        )
        result_55 = gender_gap_service.analyze(
            _gg_input(taux_activite=60.0, age=55)
        )
        assert result_30.lacune_cumulee_chf > result_55.lacune_cumulee_chf

    def test_rente_projection_positive(self, gender_gap_service):
        """Rente estimates should be positive with positive inputs."""
        result = gender_gap_service.analyze(_gg_input())
        assert result.rente_estimee_actuelle > 0
        assert result.rente_estimee_plein_temps > 0

    def test_lacune_cumulee_is_20x_annual(self, gender_gap_service):
        """Cumulated gap should be ~20x annual gap."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=60.0))
        assert result.lacune_cumulee_chf == pytest.approx(
            result.lacune_annuelle_chf * 20, rel=1e-6
        )

    def test_ofs_statistic_present(self, gender_gap_service):
        """OFS 2024 statistic should be in statistics."""
        result = gender_gap_service.analyze(_gg_input())
        assert any("37%" in s for s in result.statistiques)
        assert any("OFS" in s for s in result.statistiques)

    def test_recommendations_have_sources(self, gender_gap_service):
        """All recommendations should have a source reference."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=60.0))
        assert len(result.recommandations) > 0
        for rec in result.recommandations:
            assert rec["source"], f"Recommendation {rec['id']} has no source"
            assert len(rec["source"]) > 3

    def test_disclaimer_present(self, gender_gap_service):
        """Result should have a non-empty disclaimer."""
        result = gender_gap_service.analyze(_gg_input())
        assert result.disclaimer
        assert "indicative" in result.disclaimer.lower()

    def test_low_salary_below_lpp_threshold(self, gender_gap_service):
        """Salary below LPP entry threshold should trigger alert."""
        result = gender_gap_service.analyze(
            _gg_input(taux_activite=40.0, revenu_annuel=18_000.0)
        )
        assert any("seuil" in a.lower() for a in result.alerts)

    def test_very_low_activity_rate_alert(self, gender_gap_service):
        """Activity rate < 50% should trigger specific alert."""
        result = gender_gap_service.analyze(
            _gg_input(taux_activite=30.0, revenu_annuel=30_000.0)
        )
        assert any("50%" in a for a in result.alerts)

    def test_zero_activity_no_crash(self, gender_gap_service):
        """Zero activity rate should not crash."""
        result = gender_gap_service.analyze(
            _gg_input(taux_activite=0.0, revenu_annuel=0.0)
        )
        assert result.lacune_annuelle_chf == 0
        assert result.disclaimer


# ===========================================================================
# TestFrontalier
# ===========================================================================

class TestFrontalier:
    """Tests for cross-border worker analysis."""

    # --- France ---

    def test_fr_no_3a_default(self, frontalier_service):
        """French frontalier without quasi-resident status has no 3a right."""
        result = frontalier_service.analyze(
            _front_input(pays_residence="FR", part_revenu_suisse=0.7)
        )
        assert result.droit_3a is False

    def test_fr_fiscal_regime(self, frontalier_service):
        """French frontalier should see source-based taxation."""
        result = frontalier_service.analyze(_front_input(pays_residence="FR"))
        assert "source" in result.regime_fiscal.lower()

    def test_fr_quasi_resident_ge_has_3a(self, frontalier_service):
        """French quasi-resident in GE (>=90% CH income) should have 3a right."""
        result = frontalier_service.analyze(
            _front_input(
                pays_residence="FR",
                canton_travail="GE",
                part_revenu_suisse=0.95,
            )
        )
        assert result.droit_3a is True
        assert "quasi-resident" in result.droit_3a_detail.lower()

    def test_fr_quasi_resident_below_threshold(self, frontalier_service):
        """French worker in GE with < 90% CH income: no quasi-resident 3a."""
        result = frontalier_service.analyze(
            _front_input(
                pays_residence="FR",
                canton_travail="GE",
                part_revenu_suisse=0.80,
            )
        )
        assert result.droit_3a is False

    # --- Germany ---

    def test_de_no_3a(self, frontalier_service):
        """German frontalier has no 3a right."""
        result = frontalier_service.analyze(_front_input(pays_residence="DE"))
        assert result.droit_3a is False

    def test_de_fiscal_regime(self, frontalier_service):
        """German frontalier should see source-based taxation info."""
        result = frontalier_service.analyze(_front_input(pays_residence="DE"))
        assert "source" in result.regime_fiscal.lower()
        assert "4.5%" in result.regime_fiscal

    def test_de_avs_coordination(self, frontalier_service):
        """German frontalier AVS should mention coordination."""
        result = frontalier_service.analyze(_front_input(pays_residence="DE"))
        assert "totalisation" in result.regime_avs.lower()

    # --- Italy ---

    def test_it_no_3a(self, frontalier_service):
        """Italian frontalier has no 3a right."""
        result = frontalier_service.analyze(_front_input(pays_residence="IT"))
        assert result.droit_3a is False

    def test_it_new_agreement_2024(self, frontalier_service):
        """Italian frontalier should see 2024 agreement info."""
        result = frontalier_service.analyze(_front_input(pays_residence="IT"))
        assert "2024" in result.regime_fiscal
        assert "80%" in result.regime_fiscal

    def test_it_alert_new_agreement(self, frontalier_service):
        """Italian frontalier should get alert about new agreement."""
        result = frontalier_service.analyze(_front_input(pays_residence="IT"))
        assert any("2024" in a for a in result.alertes)

    # --- Austria ---

    def test_at_no_3a(self, frontalier_service):
        """Austrian frontalier has no 3a right."""
        result = frontalier_service.analyze(_front_input(pays_residence="AT"))
        assert result.droit_3a is False

    def test_at_fiscal_regime(self, frontalier_service):
        """Austrian frontalier should see source-based taxation."""
        result = frontalier_service.analyze(_front_input(pays_residence="AT"))
        assert "source" in result.regime_fiscal.lower()

    # --- Liechtenstein ---

    def test_li_no_3a(self, frontalier_service):
        """Liechtenstein frontalier has no 3a right."""
        result = frontalier_service.analyze(_front_input(pays_residence="LI"))
        assert result.droit_3a is False

    def test_li_specific_convention(self, frontalier_service):
        """Liechtenstein should mention specific bilateral convention."""
        result = frontalier_service.analyze(_front_input(pays_residence="LI"))
        assert "specifique" in result.regime_fiscal.lower() or \
               "CH-LI" in result.regime_fiscal

    # --- Common rules ---

    def test_lpp_libre_passage_all_countries(self, frontalier_service):
        """LPP regime should mention libre passage for all countries."""
        for pays in PAYS_FRONTALIERS:
            result = frontalier_service.analyze(
                _front_input(pays_residence=pays)
            )
            assert "libre passage" in result.regime_lpp.lower(), \
                f"Missing libre passage for {pays}"

    def test_avs_coordination_all_countries(self, frontalier_service):
        """AVS regime should mention coordination for all countries."""
        for pays in PAYS_FRONTALIERS:
            result = frontalier_service.analyze(
                _front_input(pays_residence=pays)
            )
            assert "coordination" in result.regime_avs.lower() or \
                   "totalisation" in result.regime_avs.lower(), \
                f"Missing AVS coordination for {pays}"

    def test_missing_lpp_alert(self, frontalier_service):
        """Worker without LPP affiliation should get an alert."""
        result = frontalier_service.analyze(
            _front_input(a_lpp=False)
        )
        assert any("LPP" in a and "obligatoire" in a for a in result.alertes)

    def test_has_3a_but_no_right_alert(self, frontalier_service):
        """Worker with 3a but no right should get warning."""
        result = frontalier_service.analyze(
            _front_input(pays_residence="DE", a_3a=True)
        )
        assert any("3a" in a.lower() or "3e pilier" in a.lower()
                    for a in result.alertes)

    def test_checklist_present(self, frontalier_service):
        """Result should include a checklist."""
        result = frontalier_service.analyze(_front_input())
        assert len(result.checklist) > 0
        for item in result.checklist:
            assert "item" in item
            assert "source" in item

    def test_enfants_recommandation(self, frontalier_service):
        """Worker with children should get family allowances recommendation."""
        result = frontalier_service.analyze(
            _front_input(nombre_enfants=2)
        )
        rec_ids = [r["id"] for r in result.recommandations]
        assert "allocations_familiales" in rec_ids

    def test_disclaimer_present(self, frontalier_service):
        """Result should have a disclaimer."""
        result = frontalier_service.analyze(_front_input())
        assert result.disclaimer
        assert "indicative" in result.disclaimer.lower()


# ===========================================================================
# TestIndependant
# ===========================================================================

class TestIndependant:
    """Tests for self-employed worker analysis."""

    def test_avs_full_rate_high_income(self, independant_service):
        """High income (> 58800): full AVS rate 10.6%."""
        cotisation = independant_service.calculate_avs_contribution(100_000.0)
        expected = round(100_000.0 * AVS_FULL_RATE, 2)
        assert cotisation == expected

    def test_avs_minimum_low_income(self, independant_service):
        """Very low income (< 9800): minimum contribution."""
        cotisation = independant_service.calculate_avs_contribution(5_000.0)
        assert cotisation == AVS_MINIMUM_CONTRIBUTION

    def test_avs_degressive_middle(self, independant_service):
        """Income in degressive range: rate < 10.6%."""
        cotisation = independant_service.calculate_avs_contribution(30_000.0)
        # Should be between minimum and full rate
        assert cotisation > AVS_MINIMUM_CONTRIBUTION
        assert cotisation < 30_000.0 * AVS_FULL_RATE

    def test_avs_zero_income(self, independant_service):
        """Zero income: zero contribution."""
        cotisation = independant_service.calculate_avs_contribution(0.0)
        assert cotisation == 0.0

    def test_3a_grand_plafond_no_lpp(self, independant_service):
        """Without LPP: 3a grand plafond = 20% of income, max 35280."""
        plafond = independant_service.calculate_3a_plafond(80_000.0)
        expected = min(80_000.0 * 0.20, PLAFOND_3A_INDEPENDANT_MAX)
        assert plafond == expected  # 16000

    def test_3a_grand_plafond_capped(self, independant_service):
        """Very high income: 3a capped at 35280."""
        plafond = independant_service.calculate_3a_plafond(300_000.0)
        assert plafond == PLAFOND_3A_INDEPENDANT_MAX

    def test_3a_with_lpp_small_plafond(self, independant_service):
        """With voluntary LPP: use small plafond (7056)."""
        result = independant_service.analyze(
            _ind_input(a_lpp_volontaire=True)
        )
        assert result.plafond_3a_grand == PLAFOND_3A_SALARIE

    def test_no_ijm_critical_gap(self, independant_service):
        """Missing IJM should show as critical gap."""
        result = independant_service.analyze(
            _ind_input(a_ijm=False)
        )
        lacune_types = [lc["type"] for lc in result.lacunes_couverture]
        assert "ijm" in lacune_types
        ijm_lacune = next(
            lc for lc in result.lacunes_couverture if lc["type"] == "ijm"
        )
        assert ijm_lacune["severite"] == "critique"

    def test_no_ijm_urgence(self, independant_service):
        """Missing IJM should trigger an urgent action."""
        result = independant_service.analyze(
            _ind_input(a_ijm=False)
        )
        urgence_ids = [u["id"] for u in result.urgences]
        assert "ijm_urgence" in urgence_ids

    def test_no_laa_gap(self, independant_service):
        """Missing LAA should show as coverage gap."""
        result = independant_service.analyze(
            _ind_input(a_laa=False)
        )
        lacune_types = [lc["type"] for lc in result.lacunes_couverture]
        assert "laa" in lacune_types

    def test_no_lpp_gap(self, independant_service):
        """Without voluntary LPP: should show LPP gap."""
        result = independant_service.analyze(
            _ind_input(a_lpp_volontaire=False)
        )
        lacune_types = [lc["type"] for lc in result.lacunes_couverture]
        assert "lpp" in lacune_types

    def test_full_coverage_no_lacunes(self, independant_service):
        """With all coverages: no gaps except potentially 3a if missing."""
        result = independant_service.analyze(
            _ind_input(
                a_lpp_volontaire=True,
                a_3a=True,
                a_ijm=True,
                a_laa=True,
            )
        )
        assert len(result.lacunes_couverture) == 0

    def test_protection_cost_positive(self, independant_service):
        """Protection cost should be positive for any income."""
        result = independant_service.analyze(_ind_input(revenu_net=80_000.0))
        assert result.cout_protection_totale > 0

    def test_protection_cost_includes_avs(self, independant_service):
        """Protection cost should include AVS contribution."""
        result = independant_service.analyze(_ind_input(revenu_net=80_000.0))
        assert result.cout_protection_totale >= result.cotisations_avs

    def test_checklist_present(self, independant_service):
        """Result should include a checklist."""
        result = independant_service.analyze(_ind_input())
        assert len(result.checklist) > 0
        for item in result.checklist:
            assert "item" in item
            assert "source" in item

    def test_disclaimer_present(self, independant_service):
        """Result should have a disclaimer."""
        result = independant_service.analyze(_ind_input())
        assert result.disclaimer
        assert "indicative" in result.disclaimer.lower()

    def test_older_worker_bilan_recommendation(self, independant_service):
        """Worker >= 40 without LPP should get bilan recommendation."""
        result = independant_service.analyze(
            _ind_input(age=45, a_lpp_volontaire=False)
        )
        rec_ids = [r["id"] for r in result.recommandations]
        assert "bilan_prevoyance" in rec_ids


# ===========================================================================
# TestSegmentsEndpoints
# ===========================================================================

class TestSegmentsEndpoints:
    """Tests for the FastAPI segments endpoints."""

    # --- Gender Gap ---

    def test_gender_gap_endpoint_success(self, client):
        """POST /api/v1/segments/gender-gap/simulate returns 200."""
        payload = {
            "tauxActivite": 60,
            "age": 40,
            "revenuAnnuel": 60000,
            "salaireCoordonne": 34275,
            "avoirLpp": 100000,
            "anneesCotisation": 10,
            "canton": "GE",
        }
        response = client.post(
            "/api/v1/segments/gender-gap/simulate", json=payload
        )
        assert response.status_code == 200
        data = response.json()
        assert "lacuneAnnuelleChf" in data
        assert "renteEstimeePleinTemps" in data
        assert "recommandations" in data
        assert "disclaimer" in data
        assert data["lacuneAnnuelleChf"] > 0

    def test_gender_gap_endpoint_validation_error(self, client):
        """POST with missing required fields returns 422."""
        payload = {"age": 40}
        response = client.post(
            "/api/v1/segments/gender-gap/simulate", json=payload
        )
        assert response.status_code == 422

    def test_gender_gap_endpoint_100_no_gap(self, client):
        """POST with 100% activity should show zero gap."""
        payload = {
            "tauxActivite": 100,
            "age": 40,
            "revenuAnnuel": 100000,
            "salaireCoordonne": 62475,
            "avoirLpp": 200000,
            "anneesCotisation": 15,
            "canton": "ZH",
        }
        response = client.post(
            "/api/v1/segments/gender-gap/simulate", json=payload
        )
        assert response.status_code == 200
        data = response.json()
        assert data["lacuneAnnuelleChf"] == 0

    # --- Frontalier ---

    def test_frontalier_endpoint_success(self, client):
        """POST /api/v1/segments/frontalier/simulate returns 200."""
        payload = {
            "paysResidence": "FR",
            "permis": "G",
            "cantonTravail": "GE",
            "revenuBrut": 85000,
            "a3a": False,
            "aLpp": True,
            "etatCivil": "celibataire",
            "nombreEnfants": 0,
            "partRevenuSuisse": 1.0,
        }
        response = client.post(
            "/api/v1/segments/frontalier/simulate", json=payload
        )
        assert response.status_code == 200
        data = response.json()
        assert "regimeFiscal" in data
        assert "droit3a" in data
        assert "disclaimer" in data
        assert isinstance(data["droit3a"], bool)

    def test_frontalier_endpoint_validation_error(self, client):
        """POST with missing fields returns 422."""
        payload = {"paysResidence": "FR"}
        response = client.post(
            "/api/v1/segments/frontalier/simulate", json=payload
        )
        assert response.status_code == 422

    def test_frontalier_endpoint_invalid_country(self, client):
        """POST with invalid country returns 422."""
        payload = {
            "paysResidence": "XX",
            "permis": "G",
            "cantonTravail": "GE",
            "revenuBrut": 85000,
        }
        response = client.post(
            "/api/v1/segments/frontalier/simulate", json=payload
        )
        assert response.status_code == 422

    def test_frontalier_endpoint_quasi_resident(self, client):
        """POST for quasi-resident GE should show 3a right."""
        payload = {
            "paysResidence": "FR",
            "permis": "G",
            "cantonTravail": "GE",
            "revenuBrut": 100000,
            "a3a": False,
            "aLpp": True,
            "etatCivil": "marie",
            "nombreEnfants": 1,
            "partRevenuSuisse": 0.95,
        }
        response = client.post(
            "/api/v1/segments/frontalier/simulate", json=payload
        )
        assert response.status_code == 200
        data = response.json()
        assert data["droit3a"] is True

    # --- Independant ---

    def test_independant_endpoint_success(self, client):
        """POST /api/v1/segments/independant/simulate returns 200."""
        payload = {
            "revenuNet": 80000,
            "age": 35,
            "aLppVolontaire": False,
            "a3a": False,
            "aIjm": False,
            "aLaa": False,
            "canton": "GE",
        }
        response = client.post(
            "/api/v1/segments/independant/simulate", json=payload
        )
        assert response.status_code == 200
        data = response.json()
        assert "cotisationsAvs" in data
        assert "plafond3aGrand" in data
        assert "coutProtectionTotale" in data
        assert "lacunesCouverture" in data
        assert "urgences" in data
        assert "disclaimer" in data
        assert data["cotisationsAvs"] > 0

    def test_independant_endpoint_validation_error(self, client):
        """POST with missing fields returns 422."""
        payload = {"age": 35}
        response = client.post(
            "/api/v1/segments/independant/simulate", json=payload
        )
        assert response.status_code == 422

    def test_independant_endpoint_full_coverage(self, client):
        """POST with full coverage should have no gaps."""
        payload = {
            "revenuNet": 80000,
            "age": 35,
            "aLppVolontaire": True,
            "a3a": True,
            "aIjm": True,
            "aLaa": True,
            "canton": "ZH",
        }
        response = client.post(
            "/api/v1/segments/independant/simulate", json=payload
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["lacunesCouverture"]) == 0
        assert len(data["urgences"]) == 0


# ===========================================================================
# TestSegmentsCompliance
# ===========================================================================

class TestSegmentsCompliance:
    """Compliance tests: no banned terms, sources, French language."""

    def test_gender_gap_no_banned_terms(self, gender_gap_service):
        """Gender gap results should not contain banned terms."""
        result = gender_gap_service.analyze(_gg_input(taux_activite=60.0))
        banned = ["garanti", "certain"]
        all_text = (
            result.disclaimer
            + " ".join(result.statistiques)
            + " ".join(result.alerts)
            + " ".join(r["description"] for r in result.recommandations)
        ).lower()
        for term in banned:
            assert term not in all_text, f"Banned term '{term}' in gender gap result"

    def test_frontalier_no_banned_terms(self, frontalier_service):
        """Frontalier results should not contain banned terms."""
        for pays in PAYS_FRONTALIERS:
            result = frontalier_service.analyze(
                _front_input(pays_residence=pays)
            )
            banned = ["garanti", "certain"]
            all_text = (
                result.disclaimer
                + result.regime_fiscal
                + result.droit_3a_detail
                + result.regime_lpp
                + result.regime_avs
                + " ".join(result.alertes)
                + " ".join(r["description"] for r in result.recommandations)
            ).lower()
            for term in banned:
                assert term not in all_text, \
                    f"Banned term '{term}' in frontalier ({pays}) result"

    def test_independant_no_banned_terms(self, independant_service):
        """Independant results should not contain banned terms."""
        result = independant_service.analyze(_ind_input())
        banned = ["garanti", "certain"]
        all_text = (
            result.disclaimer
            + " ".join(lc["description"] for lc in result.lacunes_couverture)
            + " ".join(r["description"] for r in result.recommandations)
            + " ".join(u["description"] for u in result.urgences)
        ).lower()
        for term in banned:
            assert term not in all_text, \
                f"Banned term '{term}' in independant result"

    def test_all_recommendations_have_sources(self):
        """All recommendations across all services should have sources."""
        gg = GenderGapService()
        result_gg = gg.analyze(_gg_input(taux_activite=60.0))
        for rec in result_gg.recommandations:
            assert rec["source"], f"GG rec {rec['id']} missing source"

        fr = FrontalierService()
        for pays in PAYS_FRONTALIERS:
            result_fr = fr.analyze(_front_input(pays_residence=pays))
            for rec in result_fr.recommandations:
                assert rec["source"], \
                    f"Frontalier rec {rec['id']} ({pays}) missing source"

        ind = IndependantService()
        result_ind = ind.analyze(_ind_input())
        for rec in result_ind.recommandations:
            assert rec["source"], f"Independant rec {rec['id']} missing source"

    def test_french_language_in_results(self):
        """Results should be in French (spot-check common words)."""
        french_words = [
            "votre", "vous", "de", "est", "le", "la", "les",
            "un", "une", "en", "des",
        ]

        gg = GenderGapService()
        result_gg = gg.analyze(_gg_input(taux_activite=60.0))
        gg_text = result_gg.disclaimer.lower()
        assert any(w in gg_text for w in french_words), "Gender gap not in French"

        fr = FrontalierService()
        result_fr = fr.analyze(_front_input())
        fr_text = result_fr.disclaimer.lower()
        assert any(w in fr_text for w in french_words), "Frontalier not in French"

        ind = IndependantService()
        result_ind = ind.analyze(_ind_input())
        ind_text = result_ind.disclaimer.lower()
        assert any(w in ind_text for w in french_words), "Independant not in French"

    def test_disclaimers_on_all_endpoints(self, client):
        """All 3 endpoints should return a non-empty disclaimer."""
        # Gender gap
        r1 = client.post("/api/v1/segments/gender-gap/simulate", json={
            "tauxActivite": 60, "age": 40, "revenuAnnuel": 60000,
        })
        assert r1.status_code == 200
        assert len(r1.json()["disclaimer"]) > 20

        # Frontalier
        r2 = client.post("/api/v1/segments/frontalier/simulate", json={
            "paysResidence": "FR", "permis": "G", "cantonTravail": "GE",
            "revenuBrut": 85000,
        })
        assert r2.status_code == 200
        assert len(r2.json()["disclaimer"]) > 20

        # Independant
        r3 = client.post("/api/v1/segments/independant/simulate", json={
            "revenuNet": 80000, "age": 35,
        })
        assert r3.status_code == 200
        assert len(r3.json()["disclaimer"]) > 20
