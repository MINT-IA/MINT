"""
Tests for LPP Deep Dive module (Sprint S15).

Covers:
    - Rachat echelonne service (stepped buyback simulator) — 15 tests
    - Libre passage service (vested benefits advisor) — 12 tests
    - EPL service (home ownership encouragement simulator) — 12 tests
    - API endpoints (integration) — 6 tests
    - Compliance (banned terms, disclaimer, gender-neutral, sources) — 5 tests

Target: 50 tests.

Run: cd services/backend && python3 -m pytest tests/test_lpp_deep.py -v
"""

import re
import pytest

from app.services.lpp_deep.rachat_echelonne_service import (
    RachatEchelonneService,
    DISCLAIMER as RACHAT_DISCLAIMER,
    TAUX_MARGINAUX_PAR_CANTON,
)
from app.services.lpp_deep.libre_passage_service import (
    LibrePassageService,
    DISCLAIMER as LP_DISCLAIMER,
)
from app.services.lpp_deep.epl_service import (
    EPLService,
    DISCLAIMER as EPL_DISCLAIMER,
    TAUX_IMPOT_RETRAIT_CAPITAL,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def rachat_service():
    return RachatEchelonneService()


@pytest.fixture
def lp_service():
    return LibrePassageService()


@pytest.fixture
def epl_service():
    return EPLService()


# ===========================================================================
# TestRachatEchelonne — Stepped buyback simulator (15 tests)
# ===========================================================================

class TestRachatEchelonne:
    """Tests for the stepped LPP buyback simulator."""

    def test_basic_simulation_returns_plan(self, rachat_service):
        """Simulation should return a plan with the correct number of years."""
        result = rachat_service.simulate(
            avoir_actuel=200000,
            rachat_max=50000,
            revenu_imposable=150000,
            taux_marginal_estime=None,
            canton="VD",
            horizon_rachat_annees=5,
        )
        assert len(result.plan) == 5
        assert result.horizon_annees == 5

    def test_total_rachat_equals_max(self, rachat_service):
        """Total of all yearly buybacks should equal the rachat_max."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=30000,
            revenu_imposable=120000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=3,
        )
        total = sum(entry.montant_rachat for entry in result.plan)
        assert abs(total - 30000) < 0.01
        assert result.total_rachat == 30000

    def test_each_year_has_positive_savings(self, rachat_service):
        """Each year should have positive tax savings."""
        result = rachat_service.simulate(
            avoir_actuel=150000,
            rachat_max=40000,
            revenu_imposable=180000,
            taux_marginal_estime=None,
            canton="GE",
            horizon_rachat_annees=4,
        )
        for entry in result.plan:
            assert entry.economie_fiscale > 0
            assert entry.cout_net > 0
            assert entry.cout_net < entry.montant_rachat

    def test_bloc_comparison_present(self, rachat_service):
        """Bloc comparison (all in 1 year) should be present."""
        result = rachat_service.simulate(
            avoir_actuel=200000,
            rachat_max=50000,
            revenu_imposable=150000,
            taux_marginal_estime=None,
            canton="VD",
            horizon_rachat_annees=5,
        )
        assert result.bloc_economie_fiscale > 0
        assert result.bloc_cout_net > 0

    def test_epl_blocage_calculation(self, rachat_service):
        """EPL blocage should be horizon + 3 years."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=20000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=4,
        )
        assert result.blocage_epl_fin == 4 + 3  # 7

    def test_horizon_clamped_to_1_5(self, rachat_service):
        """Horizon should be clamped between 1 and 5."""
        result_low = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=10000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=0,
        )
        assert result_low.horizon_annees == 1

        result_high = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=10000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=10,
        )
        assert result_high.horizon_annees == 5

    def test_custom_marginal_rate(self, rachat_service):
        """When taux_marginal_estime is provided, it should be used."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=20000,
            revenu_imposable=100000,
            taux_marginal_estime=0.35,
            canton="ZH",
            horizon_rachat_annees=1,
        )
        # With 35% marginal rate, savings should be around 35% * 20000
        entry = result.plan[0]
        assert entry.taux_marginal_avant == 0.35

    def test_canton_rates_differ(self, rachat_service):
        """Different cantons should produce different tax savings."""
        result_zg = rachat_service.simulate(
            avoir_actuel=200000,
            rachat_max=50000,
            revenu_imposable=200000,
            taux_marginal_estime=None,
            canton="ZG",
            horizon_rachat_annees=3,
        )
        result_ge = rachat_service.simulate(
            avoir_actuel=200000,
            rachat_max=50000,
            revenu_imposable=200000,
            taux_marginal_estime=None,
            canton="GE",
            horizon_rachat_annees=3,
        )
        # GE has higher tax rates than ZG
        assert result_ge.total_economie_fiscale > result_zg.total_economie_fiscale

    def test_zero_rachat_max(self, rachat_service):
        """Zero rachat_max should produce zero savings."""
        result = rachat_service.simulate(
            avoir_actuel=200000,
            rachat_max=0,
            revenu_imposable=150000,
            taux_marginal_estime=None,
            canton="VD",
            horizon_rachat_annees=3,
        )
        assert result.total_economie_fiscale == 0.0
        assert result.total_cout_net == 0.0

    def test_disclaimer_present(self, rachat_service):
        """Disclaimer should be present in the result."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=20000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=3,
        )
        assert len(result.disclaimer) > 50
        assert "educatif" in result.disclaimer.lower()

    def test_sources_present(self, rachat_service):
        """Legal sources should be present."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=20000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=3,
        )
        assert len(result.sources) >= 3
        sources_text = " ".join(result.sources)
        assert "LPP art. 79b" in sources_text
        assert "LIFD" in sources_text

    def test_alerts_include_epl_blocage(self, rachat_service):
        """Alerts should include EPL blocage warning."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=20000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=3,
        )
        epl_alerts = [a for a in result.alerts if "EPL" in a or "blocage" in a.lower()]
        assert len(epl_alerts) > 0

    def test_single_year_horizon(self, rachat_service):
        """Single year horizon should match bloc calculation."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=20000,
            revenu_imposable=100000,
            taux_marginal_estime=None,
            canton="ZH",
            horizon_rachat_annees=1,
        )
        assert len(result.plan) == 1
        # Single year should have similar savings to bloc
        assert abs(result.total_economie_fiscale - result.bloc_economie_fiscale) < 0.01

    def test_revenu_apres_is_less_than_avant(self, rachat_service):
        """Taxable income after buyback should be less than before."""
        result = rachat_service.simulate(
            avoir_actuel=100000,
            rachat_max=30000,
            revenu_imposable=150000,
            taux_marginal_estime=None,
            canton="VD",
            horizon_rachat_annees=3,
        )
        for entry in result.plan:
            assert entry.revenu_imposable_apres < entry.revenu_imposable_avant

    def test_all_26_cantons_supported(self, rachat_service):
        """All 26 cantons should be in the rate table."""
        assert len(TAUX_MARGINAUX_PAR_CANTON) == 26


# ===========================================================================
# TestLibrePassage — Vested benefits advisor (12 tests)
# ===========================================================================

class TestLibrePassage:
    """Tests for the libre passage (vested benefits) advisor."""

    def test_changement_emploi_avec_nouvel_employeur(self, lp_service):
        """Job change with new employer should recommend transfer."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
            a_nouveau_employeur=True,
            delai_jours=15,
        )
        assert len(result.checklist) > 0
        checklist_text = " ".join(item.description for item in result.checklist)
        assert "transferer" in checklist_text.lower() or "transfert" in checklist_text.lower()

    def test_changement_emploi_sans_nouvel_employeur(self, lp_service):
        """Job change without new employer should recommend libre passage foundation."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
            a_nouveau_employeur=False,
        )
        checklist_text = " ".join(item.description for item in result.checklist)
        assert "libre passage" in checklist_text.lower()

    def test_delai_depasse_alert(self, lp_service):
        """Alert should fire when transfer delay exceeds 6 months."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
            a_nouveau_employeur=True,
            delai_jours=200,
        )
        alert_messages = [a.message for a in result.alertes]
        alert_text = " ".join(alert_messages)
        assert "depasse" in alert_text.lower() or "200 jours" in alert_text

    def test_depart_suisse_eu_aele(self, lp_service):
        """Departure to EU/AELE should restrict withdrawal to surobligatoire."""
        result = lp_service.analyze(
            statut="depart_suisse",
            avoir_libre_passage=100000,
            age=40,
            destination="eu_aele",
            avoir_obligatoire=60000,
            avoir_surobligatoire=40000,
        )
        assert result.peut_retirer_capital is True
        assert result.montant_retirable == 40000.0
        assert result.montant_bloque == 60000.0

    def test_depart_suisse_hors_eu(self, lp_service):
        """Departure outside EU should allow full withdrawal."""
        result = lp_service.analyze(
            statut="depart_suisse",
            avoir_libre_passage=100000,
            age=40,
            destination="hors_eu",
        )
        assert result.peut_retirer_capital is True
        assert result.montant_retirable == 100000.0
        assert result.montant_bloque == 0.0

    def test_cessation_activite_young(self, lp_service):
        """Cessation of activity for young person should keep capital blocked."""
        result = lp_service.analyze(
            statut="cessation_activite",
            avoir_libre_passage=50000,
            age=30,
        )
        assert result.peut_retirer_capital is False
        assert result.montant_bloque == 50000.0

    def test_cessation_activite_near_retirement(self, lp_service):
        """Cessation of activity near retirement should allow withdrawal."""
        result = lp_service.analyze(
            statut="cessation_activite",
            avoir_libre_passage=200000,
            age=60,
        )
        assert result.peut_retirer_capital is True
        assert result.montant_retirable == 200000.0

    def test_centrale_2e_pilier_recommendation(self, lp_service):
        """Should always recommend checking the Centrale du 2e pilier."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
            a_nouveau_employeur=True,
        )
        all_text = " ".join(
            [r.description for r in result.recommandations]
            + [item.description for item in result.checklist]
        )
        assert "sfbvg.ch" in all_text.lower() or "centrale" in all_text.lower()

    def test_disclaimer_present(self, lp_service):
        """Disclaimer should be present."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
        )
        assert "educatif" in result.disclaimer.lower()
        assert len(result.disclaimer) > 50

    def test_sources_present(self, lp_service):
        """Legal sources should be present."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
        )
        sources_text = " ".join(result.sources)
        assert "LFLP" in sources_text
        assert "LPP" in sources_text

    def test_two_libre_passage_accounts_recommendation(self, lp_service):
        """Should recommend 2 libre passage accounts for tax optimization."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
            a_nouveau_employeur=False,
        )
        recs_text = " ".join(r.description for r in result.recommandations)
        assert "2 comptes" in recs_text.lower() or "deux comptes" in recs_text.lower()

    def test_delai_ideal_alert(self, lp_service):
        """Alert should fire when delay exceeds ideal 30 days."""
        result = lp_service.analyze(
            statut="changement_emploi",
            avoir_libre_passage=80000,
            age=35,
            a_nouveau_employeur=True,
            delai_jours=60,
        )
        alert_messages = [a.message for a in result.alertes]
        alert_text = " ".join(alert_messages)
        assert "60 jours" in alert_text or "delai" in alert_text.lower()


# ===========================================================================
# TestEPL — Home ownership encouragement simulator (12 tests)
# ===========================================================================

class TestEPL:
    """Tests for the EPL (home ownership encouragement) simulator."""

    def test_basic_withdrawal_under_50(self, epl_service):
        """Under 50, full LPP amount should be withdrawable."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=100000,
        )
        assert result.montant_retirable_max == 200000.0
        assert result.montant_effectif == 100000.0
        assert result.regle_age_50_appliquee is False

    def test_age_50_rule_applies(self, epl_service):
        """At age >= 50, withdrawal is limited."""
        result = epl_service.simulate(
            avoir_lpp_total=300000,
            avoir_obligatoire=180000,
            avoir_surobligatoire=120000,
            age=55,
            montant_retrait_souhaite=300000,
            avoir_a_50_ans=180000,
        )
        assert result.regle_age_50_appliquee is True
        # max(180000, 50% of 300000 = 150000) = 180000
        assert result.montant_retirable_max == 180000.0
        assert result.montant_effectif == 180000.0

    def test_age_50_rule_uses_50_pct_when_higher(self, epl_service):
        """At age >= 50, should use 50% if higher than avoir_at_50."""
        result = epl_service.simulate(
            avoir_lpp_total=400000,
            avoir_obligatoire=240000,
            avoir_surobligatoire=160000,
            age=55,
            montant_retrait_souhaite=400000,
            avoir_a_50_ans=100000,
        )
        # max(100000, 50% of 400000 = 200000) = 200000
        assert result.montant_retirable_max == 200000.0

    def test_minimum_20000_rule(self, epl_service):
        """Withdrawal below 20'000 CHF should be rejected."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=15000,
        )
        assert result.respecte_minimum is False
        assert result.montant_effectif == 0.0

    def test_buyback_blocage_active(self, epl_service):
        """Recent buyback (< 3 years) should block EPL withdrawal."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=50000,
            a_rachete_recemment=True,
            annees_depuis_dernier_rachat=1,
        )
        assert result.blocage_rachat is True
        assert result.annees_restantes_blocage == 2
        assert result.montant_effectif == 0.0

    def test_buyback_blocage_expired(self, epl_service):
        """Buyback more than 3 years ago should not block EPL."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=50000,
            a_rachete_recemment=True,
            annees_depuis_dernier_rachat=4,
        )
        assert result.blocage_rachat is False
        assert result.montant_effectif == 50000.0

    def test_tax_estimate_present(self, epl_service):
        """Tax estimate should be calculated."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=100000,
            canton="VD",
        )
        assert result.impot_retrait_estime > 0
        assert result.taux_impot_retrait == TAUX_IMPOT_RETRAIT_CAPITAL["VD"]
        # 100000 * 0.08 = 8000
        assert result.impot_retrait_estime == 8000.0

    def test_impact_prestations_calculated(self, epl_service):
        """Impact on death and disability benefits should be calculated."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=100000,
        )
        impact = result.impact_prestations
        assert impact.rente_invalidite_reduction_pct > 0
        assert impact.capital_deces_reduction_pct > 0
        assert impact.rente_invalidite_reduction_chf > 0
        assert len(impact.message) > 50

    def test_impact_50_percent_withdrawal(self, epl_service):
        """Withdrawing 50% should show ~50% reduction in benefits."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=100000,
        )
        impact = result.impact_prestations
        assert impact.rente_invalidite_reduction_pct == 50.0

    def test_checklist_present(self, epl_service):
        """Checklist should include essential items."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=100000,
        )
        assert len(result.checklist) >= 5
        checklist_text = " ".join(result.checklist)
        assert "residence principale" in checklist_text.lower()
        assert "conjoint" in checklist_text.lower() or "consentement" in checklist_text.lower()

    def test_alerts_for_large_withdrawal(self, epl_service):
        """Large withdrawal (>50% of LPP) should trigger alert."""
        result = epl_service.simulate(
            avoir_lpp_total=100000,
            avoir_obligatoire=60000,
            avoir_surobligatoire=40000,
            age=35,
            montant_retrait_souhaite=80000,
        )
        alert_text = " ".join(result.alertes)
        assert "80%" in alert_text or "significativement" in alert_text.lower()

    def test_disclaimer_present(self, epl_service):
        """Disclaimer should be present."""
        result = epl_service.simulate(
            avoir_lpp_total=200000,
            avoir_obligatoire=120000,
            avoir_surobligatoire=80000,
            age=35,
            montant_retrait_souhaite=50000,
        )
        assert "educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer


# ===========================================================================
# TestLPPDeepEndpoints — API integration (6 tests)
# ===========================================================================

class TestLPPDeepEndpoints:
    """Tests for the LPP Deep FastAPI endpoints."""

    def test_rachat_echelonne_endpoint(self, client):
        """POST /lpp-deep/rachat-echelonne should return 200."""
        response = client.post(
            "/api/v1/lpp-deep/rachat-echelonne",
            json={
                "avoirActuel": 200000,
                "rachatMax": 50000,
                "revenuImposable": 150000,
                "canton": "VD",
                "horizonRachatAnnees": 5,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["plan"]) == 5
        assert data["totalRachat"] == 50000
        assert "disclaimer" in data
        assert "sources" in data
        assert len(data["sources"]) >= 3

    def test_libre_passage_endpoint(self, client):
        """POST /lpp-deep/libre-passage should return 200."""
        response = client.post(
            "/api/v1/lpp-deep/libre-passage",
            json={
                "statut": "changement_emploi",
                "avoirLibrePassage": 80000,
                "age": 35,
                "aNouvelEmployeur": True,
                "delaiJours": 15,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["checklist"]) > 0
        assert "disclaimer" in data
        assert "sources" in data

    def test_epl_endpoint(self, client):
        """POST /lpp-deep/epl should return 200."""
        response = client.post(
            "/api/v1/lpp-deep/epl",
            json={
                "avoirLppTotal": 200000,
                "avoirObligatoire": 120000,
                "avoirSurobligatoire": 80000,
                "age": 35,
                "montantRetraitSouhaite": 100000,
                "canton": "VD",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["montantRetirableMax"] == 200000.0
        assert data["montantEffectif"] == 100000.0
        assert "impactPrestations" in data
        assert "disclaimer" in data

    def test_rachat_echelonne_validation_error(self, client):
        """Invalid input should return 422."""
        response = client.post(
            "/api/v1/lpp-deep/rachat-echelonne",
            json={
                "avoirActuel": -1,  # Invalid: negative
                "rachatMax": 50000,
                "revenuImposable": 150000,
                "canton": "VD",
            },
        )
        assert response.status_code == 422

    def test_epl_with_buyback_blocage_endpoint(self, client):
        """EPL with recent buyback should show blocage."""
        response = client.post(
            "/api/v1/lpp-deep/epl",
            json={
                "avoirLppTotal": 200000,
                "avoirObligatoire": 120000,
                "avoirSurobligatoire": 80000,
                "age": 35,
                "montantRetraitSouhaite": 100000,
                "aRacheteRecemment": True,
                "anneesDernierRachat": 1,
                "canton": "ZH",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["blocageRachat"] is True
        assert data["montantEffectif"] == 0.0
        assert data["anneesRestantesBlocage"] == 2

    def test_libre_passage_depart_suisse_endpoint(self, client):
        """Libre passage with departure should return correct withdrawal info."""
        response = client.post(
            "/api/v1/lpp-deep/libre-passage",
            json={
                "statut": "depart_suisse",
                "avoirLibrePassage": 100000,
                "age": 40,
                "destination": "hors_eu",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["peutRetirerCapital"] is True
        assert data["montantRetirable"] == 100000.0
        assert data["montantBloque"] == 0.0


# ===========================================================================
# TestLPPDeepCompliance — Compliance checks (5 tests)
# ===========================================================================

class TestLPPDeepCompliance:
    """Tests for compliance rules (banned terms, disclaimer, gender-neutral, sources)."""

    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
    ]

    def _collect_all_text(self, data) -> str:
        """Recursively collect all text from a response."""
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

    def test_no_banned_terms_in_responses(self, client):
        """No response should contain banned terms (garanti, certain, etc.)."""
        endpoints_and_bodies = [
            ("/api/v1/lpp-deep/rachat-echelonne", {
                "avoirActuel": 200000,
                "rachatMax": 50000,
                "revenuImposable": 150000,
                "canton": "VD",
                "horizonRachatAnnees": 5,
            }),
            ("/api/v1/lpp-deep/libre-passage", {
                "statut": "changement_emploi",
                "avoirLibrePassage": 80000,
                "age": 35,
                "aNouvelEmployeur": True,
            }),
            ("/api/v1/lpp-deep/epl", {
                "avoirLppTotal": 200000,
                "avoirObligatoire": 120000,
                "avoirSurobligatoire": 80000,
                "age": 35,
                "montantRetraitSouhaite": 100000,
                "canton": "VD",
            }),
        ]

        for url, body in endpoints_and_bodies:
            response = client.post(url, json=body)
            data = response.json()
            all_text = self._collect_all_text(data).lower()

            for pattern in self.BANNED_PATTERNS:
                matches = re.findall(pattern, all_text, re.IGNORECASE)
                assert len(matches) == 0, (
                    f"Banned pattern '{pattern}' found in {url}: {matches}"
                )

    def test_disclaimer_in_all_responses(self, client):
        """All responses should include a disclaimer with 'educatif'."""
        endpoints_and_bodies = [
            ("/api/v1/lpp-deep/rachat-echelonne", {
                "avoirActuel": 200000,
                "rachatMax": 50000,
                "revenuImposable": 150000,
                "canton": "VD",
            }),
            ("/api/v1/lpp-deep/libre-passage", {
                "statut": "cessation_activite",
                "avoirLibrePassage": 80000,
                "age": 35,
            }),
            ("/api/v1/lpp-deep/epl", {
                "avoirLppTotal": 200000,
                "avoirObligatoire": 120000,
                "avoirSurobligatoire": 80000,
                "age": 35,
                "montantRetraitSouhaite": 50000,
            }),
        ]

        for url, body in endpoints_and_bodies:
            response = client.post(url, json=body)
            data = response.json()
            assert "disclaimer" in data, f"No disclaimer in {url}"
            assert len(data["disclaimer"]) > 50
            assert "educatif" in data["disclaimer"].lower(), (
                f"Disclaimer in {url} should contain 'educatif'"
            )
            assert "LSFin" in data["disclaimer"], (
                f"Disclaimer in {url} should reference LSFin"
            )

    def test_gender_neutral_language_in_disclaimers(self, rachat_service, lp_service, epl_service):
        """Disclaimers should use gender-neutral language."""
        disclaimers = [
            RACHAT_DISCLAIMER,
            LP_DISCLAIMER,
            EPL_DISCLAIMER,
        ]
        for disclaimer in disclaimers:
            assert "un ou une specialiste" in disclaimer.lower(), (
                f"Disclaimer should use 'un ou une specialiste': {disclaimer}"
            )

    def test_legal_sources_in_all_services(self, client):
        """All responses should include legal sources."""
        endpoints_and_bodies = [
            ("/api/v1/lpp-deep/rachat-echelonne", {
                "avoirActuel": 200000,
                "rachatMax": 50000,
                "revenuImposable": 150000,
                "canton": "VD",
            }),
            ("/api/v1/lpp-deep/libre-passage", {
                "statut": "changement_emploi",
                "avoirLibrePassage": 80000,
                "age": 35,
            }),
            ("/api/v1/lpp-deep/epl", {
                "avoirLppTotal": 200000,
                "avoirObligatoire": 120000,
                "avoirSurobligatoire": 80000,
                "age": 35,
                "montantRetraitSouhaite": 50000,
            }),
        ]

        for url, body in endpoints_and_bodies:
            response = client.post(url, json=body)
            data = response.json()
            assert "sources" in data, f"No sources in {url}"
            assert len(data["sources"]) >= 2, (
                f"Should have at least 2 legal sources in {url}"
            )
            sources_text = " ".join(data["sources"])
            assert "LPP" in sources_text or "LFLP" in sources_text, (
                f"Sources should reference LPP or LFLP in {url}"
            )

    def test_no_banned_terms_in_service_layer(self):
        """Service disclaimers should not contain banned terms."""
        all_disclaimers = RACHAT_DISCLAIMER + LP_DISCLAIMER + EPL_DISCLAIMER

        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_disclaimers, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in service disclaimers: {matches}"
            )
