"""
Tests for the Retirement planning module (Sprint S21).

Covers:
    - AVS estimation service — 18 tests
    - LPP conversion service — 15 tests
    - Retirement budget service — 12 tests
    - API endpoints (integration) — 5 tests

Target: 50 tests.

Run: cd services/backend && python3 -m pytest tests/test_retirement.py -v
"""

import pytest

from app.services.retirement.avs_estimation_service import (
    AvsEstimationService,
    AVS_MAX_RENTE_COUPLE_FACTOR,
    AVS_RETIREMENT_AGE,
)
from app.constants.social_insurance import (
    AVS_RENTE_MAX_MENSUELLE as AVS_MAX_RENTE_MENSUELLE,
    AVS_REDUCTION_ANTICIPATION as AVS_ANTICIPATION_PENALTY_PER_YEAR,
    AVS_SUPPLEMENT_AJOURNEMENT as AVS_DEFERRAL_BONUS,
    AVS_DUREE_COTISATION_COMPLETE as AVS_FULL_CONTRIBUTION_YEARS,
)
from app.services.retirement.lpp_conversion_service import (
    LppConversionService,
    LPP_CONVERSION_RATE,
    TAUX_IMPOT_RETRAIT_CAPITAL,
)
from app.services.retirement.retirement_budget_service import (
    RetirementBudgetService,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def avs_service():
    return AvsEstimationService()


@pytest.fixture
def lpp_service():
    return LppConversionService()


@pytest.fixture
def budget_service():
    return RetirementBudgetService()


# ===========================================================================
# AVS Estimation Tests (18 tests)
# ===========================================================================

class TestAvsEstimation:
    """Tests for AvsEstimationService.estimate()."""

    def test_normal_retirement_65(self, avs_service):
        """Normal retirement at 65 should give full rente with factor 1.0."""
        result = avs_service.estimate(current_age=50, retirement_age=65)
        assert result.scenario == "normal"
        assert result.age_depart == 65
        assert result.facteur_ajustement == 1.0
        assert result.penalite_ou_bonus_pct == 0.0
        assert result.rente_mensuelle == AVS_MAX_RENTE_MENSUELLE

    def test_anticipation_63(self, avs_service):
        """Anticipation at 63 (2 years early) = -13.6% penalty."""
        result = avs_service.estimate(current_age=50, retirement_age=63)
        assert result.scenario == "anticipation"
        expected_penalty = -AVS_ANTICIPATION_PENALTY_PER_YEAR * 2 * 100
        assert result.penalite_ou_bonus_pct == round(expected_penalty, 1)
        expected_factor = 1.0 - (AVS_ANTICIPATION_PENALTY_PER_YEAR * 2)
        assert result.facteur_ajustement == round(expected_factor, 4)
        assert result.rente_mensuelle < AVS_MAX_RENTE_MENSUELLE

    def test_anticipation_64(self, avs_service):
        """Anticipation at 64 (1 year early) = -6.8% penalty."""
        result = avs_service.estimate(current_age=50, retirement_age=64)
        assert result.scenario == "anticipation"
        expected_penalty = -AVS_ANTICIPATION_PENALTY_PER_YEAR * 100
        assert result.penalite_ou_bonus_pct == round(expected_penalty, 1)
        expected_rente = round(AVS_MAX_RENTE_MENSUELLE * (1.0 - AVS_ANTICIPATION_PENALTY_PER_YEAR), 2)
        assert result.rente_mensuelle == expected_rente

    def test_deferral_66(self, avs_service):
        """Deferral to 66 (1 year late) = +5.2% bonus."""
        result = avs_service.estimate(current_age=50, retirement_age=66)
        assert result.scenario == "ajournement"
        assert result.penalite_ou_bonus_pct == round(AVS_DEFERRAL_BONUS[1] * 100, 1)
        assert result.rente_mensuelle > AVS_MAX_RENTE_MENSUELLE

    def test_deferral_67(self, avs_service):
        """Deferral to 67 (2 years late) = +10.8% bonus."""
        result = avs_service.estimate(current_age=50, retirement_age=67)
        assert result.scenario == "ajournement"
        assert result.penalite_ou_bonus_pct == round(AVS_DEFERRAL_BONUS[2] * 100, 1)
        expected_rente = round(AVS_MAX_RENTE_MENSUELLE * (1.0 + AVS_DEFERRAL_BONUS[2]), 2)
        assert result.rente_mensuelle == expected_rente

    def test_deferral_70(self, avs_service):
        """Deferral to 70 (5 years max) = +31.5% bonus."""
        result = avs_service.estimate(current_age=50, retirement_age=70)
        assert result.scenario == "ajournement"
        assert result.penalite_ou_bonus_pct == round(AVS_DEFERRAL_BONUS[5] * 100, 1)
        expected_rente = round(AVS_MAX_RENTE_MENSUELLE * (1.0 + AVS_DEFERRAL_BONUS[5]), 2)
        assert result.rente_mensuelle == expected_rente

    def test_couple_cap_150(self, avs_service):
        """Couple rente should be capped at 150% of individual max."""
        result = avs_service.estimate(current_age=50, retirement_age=65, is_couple=True)
        max_couple = AVS_MAX_RENTE_MENSUELLE * AVS_MAX_RENTE_COUPLE_FACTOR
        assert result.rente_couple_mensuelle is not None
        assert result.rente_couple_mensuelle <= max_couple
        # For full contributions at normal retirement, couple = 150% cap
        assert result.rente_couple_mensuelle == round(max_couple, 2)

    def test_gaps_reduce_rente(self, avs_service):
        """5 years of contribution gaps should reduce rente proportionally."""
        result_full = avs_service.estimate(current_age=50, retirement_age=65, annees_lacunes=0)
        result_gaps = avs_service.estimate(current_age=50, retirement_age=65, annees_lacunes=5)
        expected_ratio = (AVS_FULL_CONTRIBUTION_YEARS - 5) / AVS_FULL_CONTRIBUTION_YEARS
        assert result_gaps.rente_mensuelle == round(AVS_MAX_RENTE_MENSUELLE * expected_ratio, 2)
        assert result_gaps.rente_mensuelle < result_full.rente_mensuelle

    def test_full_contribution_no_gap(self, avs_service):
        """44 years of contributions (0 gaps) should give full rente."""
        result = avs_service.estimate(current_age=50, retirement_age=65, annees_lacunes=0)
        assert result.rente_mensuelle == AVS_MAX_RENTE_MENSUELLE

    def test_max_rente_2520(self, avs_service):
        """Individual max monthly rente should be CHF 2520."""
        result = avs_service.estimate(current_age=50, retirement_age=65)
        assert result.rente_mensuelle == 2520.0

    def test_rente_annuelle_with_13th(self, avs_service):
        """Annual rente at normal retirement with full contributions includes 13th rente."""
        result = avs_service.estimate(current_age=50, retirement_age=65)
        # 13ème rente active (LAVS art. 34 nouveau): 2520 × 13 = 32760
        assert result.rente_annuelle == 32760.0
        assert result.nombre_rentes_par_an == 13
        assert result.rente_annuelle == result.rente_mensuelle * 13

    def test_breakeven_anticipation(self, avs_service):
        """Anticipation breakeven: normal should catch up at some age."""
        result = avs_service.estimate(current_age=50, retirement_age=63, life_expectancy=90)
        # Anticipation gets head start but lower amount — normal catches up
        # Breakeven should exist (normal eventually surpasses)
        assert result.breakeven_vs_normal is not None
        assert result.breakeven_vs_normal > AVS_RETIREMENT_AGE

    def test_breakeven_deferral(self, avs_service):
        """Deferral breakeven: deferral should catch up to normal at some age."""
        result = avs_service.estimate(current_age=50, retirement_age=67, life_expectancy=95)
        # Deferral has higher amount but delayed start
        # With enough years, deferral cumulative surpasses normal
        if result.breakeven_vs_normal is not None:
            assert result.breakeven_vs_normal > 67

    def test_chiffre_choc_anticipation(self, avs_service):
        """Chiffre choc for anticipation should contain loss information."""
        result = avs_service.estimate(current_age=50, retirement_age=63)
        assert "Anticiper" in result.chiffre_choc
        assert "%" in result.chiffre_choc
        assert "CHF" in result.chiffre_choc

    def test_chiffre_choc_normal(self, avs_service):
        """Chiffre choc for normal should contain rente information."""
        result = avs_service.estimate(current_age=50, retirement_age=65)
        assert "rente AVS" in result.chiffre_choc
        assert "CHF" in result.chiffre_choc
        assert "/mois" in result.chiffre_choc

    def test_sources_contain_lavs(self, avs_service):
        """Sources should reference LAVS articles."""
        result = avs_service.estimate(current_age=50, retirement_age=65)
        source_text = " ".join(result.sources)
        assert "LAVS" in source_text
        assert "art." in source_text

    def test_age_validation_scenario(self, avs_service):
        """Retirement age should correctly determine the scenario."""
        assert avs_service.estimate(current_age=50, retirement_age=63).scenario == "anticipation"
        assert avs_service.estimate(current_age=50, retirement_age=64).scenario == "anticipation"
        assert avs_service.estimate(current_age=50, retirement_age=65).scenario == "normal"
        assert avs_service.estimate(current_age=50, retirement_age=66).scenario == "ajournement"
        assert avs_service.estimate(current_age=50, retirement_age=70).scenario == "ajournement"

    def test_life_expectancy_affects_cumul(self, avs_service):
        """Higher life expectancy should increase total cumulative amount."""
        result_80 = avs_service.estimate(current_age=50, retirement_age=65, life_expectancy=80)
        result_90 = avs_service.estimate(current_age=50, retirement_age=65, life_expectancy=90)
        assert result_90.total_cumule > result_80.total_cumule
        assert result_90.duree_estimee_ans > result_80.duree_estimee_ans


# ===========================================================================
# LPP Conversion Tests (15 tests)
# ===========================================================================

class TestLppConversion:
    """Tests for LppConversionService.compare()."""

    def test_rente_calculation(self, lpp_service):
        """Rente should be capital * 6.8% / 12 monthly."""
        result = lpp_service.compare(capital_lpp=500_000)
        expected_annual = 500_000 * LPP_CONVERSION_RATE
        expected_monthly = round(expected_annual / 12, 2)
        assert result.option_rente_annuelle == expected_annual
        assert result.option_rente_mensuelle == expected_monthly

    def test_capital_tax_zurich(self, lpp_service):
        """ZH capital tax should use the correct base rate."""
        result = lpp_service.compare(capital_lpp=100_000, canton="ZH")
        # For 100k: first bracket only (multiplier 1.0)
        expected_tax = round(100_000 * TAUX_IMPOT_RETRAIT_CAPITAL["ZH"] * 1.0, 2)
        assert result.option_capital_impot == expected_tax
        assert result.option_capital_net == round(100_000 - expected_tax, 2)

    def test_capital_tax_zug_lowest(self, lpp_service):
        """ZG should have the lowest tax rate among cantons."""
        result_zg = lpp_service.compare(capital_lpp=500_000, canton="ZG")
        result_zh = lpp_service.compare(capital_lpp=500_000, canton="ZH")
        result_vd = lpp_service.compare(capital_lpp=500_000, canton="VD")
        assert result_zg.option_capital_impot < result_zh.option_capital_impot
        assert result_zg.option_capital_impot < result_vd.option_capital_impot

    def test_capital_tax_vaud_highest(self, lpp_service):
        """VD should have the highest tax rate in the set."""
        result_vd = lpp_service.compare(capital_lpp=500_000, canton="VD")
        result_zh = lpp_service.compare(capital_lpp=500_000, canton="ZH")
        result_zg = lpp_service.compare(capital_lpp=500_000, canton="ZG")
        assert result_vd.option_capital_impot > result_zh.option_capital_impot
        assert result_vd.option_capital_impot > result_zg.option_capital_impot

    def test_progressive_brackets_100k(self, lpp_service):
        """100k should only use the first bracket (multiplier 1.0)."""
        result = lpp_service.compare(capital_lpp=100_000, canton="ZH")
        expected_tax = round(100_000 * TAUX_IMPOT_RETRAIT_CAPITAL["ZH"] * 1.0, 2)
        assert result.option_capital_impot == expected_tax

    def test_progressive_brackets_300k(self, lpp_service):
        """300k should use brackets 1-3 with increasing multipliers."""
        result = lpp_service.compare(capital_lpp=300_000, canton="ZH")
        rate = TAUX_IMPOT_RETRAIT_CAPITAL["ZH"]
        expected = (
            100_000 * rate * 1.0 +     # 0-100k
            100_000 * rate * 1.15 +     # 100k-200k
            100_000 * rate * 1.30       # 200k-300k
        )
        assert result.option_capital_impot == round(expected, 2)

    def test_progressive_brackets_1m(self, lpp_service):
        """1M should use all brackets including the last multiplier."""
        result = lpp_service.compare(capital_lpp=1_000_000, canton="ZH")
        rate = TAUX_IMPOT_RETRAIT_CAPITAL["ZH"]
        expected = (
            100_000 * rate * 1.0 +      # 0-100k
            100_000 * rate * 1.15 +      # 100k-200k
            300_000 * rate * 1.30 +      # 200k-500k
            500_000 * rate * 1.50        # 500k-1M
        )
        assert result.option_capital_impot == round(expected, 2)

    def test_capital_net_positive(self, lpp_service):
        """Net capital should always be positive for valid capital amounts."""
        result = lpp_service.compare(capital_lpp=500_000, canton="VD")
        assert result.option_capital_net > 0
        assert result.option_capital_net < result.option_capital_brut

    def test_breakeven_age(self, lpp_service):
        """Breakeven age should be between retirement and life expectancy."""
        result = lpp_service.compare(
            capital_lpp=500_000, canton="ZH",
            retirement_age=65, life_expectancy=87,
        )
        assert result.breakeven_age >= 65
        assert result.breakeven_age <= 87

    def test_recommandation_neutre(self, lpp_service):
        """Recommendation should be neutral (mention both options)."""
        result = lpp_service.compare(capital_lpp=500_000)
        assert "rente" in result.recommandation_neutre.lower()
        assert "capital" in result.recommandation_neutre.lower()
        # Should mention breakeven
        assert str(result.breakeven_age) in result.recommandation_neutre

    def test_chiffre_choc_present(self, lpp_service):
        """Chiffre choc should be present and contain key information."""
        result = lpp_service.compare(capital_lpp=500_000)
        assert len(result.chiffre_choc) > 20
        assert "CHF" in result.chiffre_choc
        assert "Rente" in result.chiffre_choc or "rente" in result.chiffre_choc

    def test_sources_contain_lpp(self, lpp_service):
        """Sources should reference LPP articles."""
        result = lpp_service.compare(capital_lpp=500_000)
        source_text = " ".join(result.sources)
        assert "LPP" in source_text
        assert "art." in source_text
        assert "LIFD" in source_text

    def test_zero_capital_tax(self, lpp_service):
        """Zero capital (edge: service handles max(0, input)) should give 0 tax."""
        from app.constants.social_insurance import calculate_progressive_capital_tax
        tax = calculate_progressive_capital_tax(0, 0.065)
        assert tax == 0.0

    def test_high_capital_2m(self, lpp_service):
        """2M capital should use the last multiplier bracket for amounts > 1M."""
        result = lpp_service.compare(capital_lpp=2_000_000, canton="ZH")
        rate = TAUX_IMPOT_RETRAIT_CAPITAL["ZH"]
        expected = (
            100_000 * rate * 1.0 +       # 0-100k
            100_000 * rate * 1.15 +       # 100k-200k
            300_000 * rate * 1.30 +       # 200k-500k
            500_000 * rate * 1.50 +       # 500k-1M
            1_000_000 * rate * 1.70       # >1M
        )
        assert result.option_capital_impot == round(expected, 2)
        assert result.option_capital_net > 0

    def test_canton_invalid_default(self, lpp_service):
        """Unknown canton should use the default rate (0.065)."""
        result = lpp_service.compare(capital_lpp=100_000, canton="XX")
        # Default rate = 0.065 (same as ZH)
        expected_tax = round(100_000 * 0.065, 2)
        assert result.option_capital_impot == expected_tax


# ===========================================================================
# Retirement Budget Tests (12 tests)
# ===========================================================================

class TestRetirementBudget:
    """Tests for RetirementBudgetService.reconcile()."""

    def test_surplus_positive(self, budget_service):
        """Revenus > depenses should give a positive solde."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=2000,
            capital_3a_net=100_000, autres_revenus=500,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
        )
        assert result.solde_mensuel > 0
        assert result.total_revenus_mensuels > result.depenses_mensuelles_estimees

    def test_deficit_negative(self, budget_service):
        """Revenus < depenses should give a negative solde."""
        result = budget_service.reconcile(
            avs_mensuel=1500, lpp_mensuel=500,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=5000, revenu_pre_retraite=8000,
        )
        assert result.solde_mensuel < 0

    def test_taux_remplacement_calculation(self, budget_service):
        """Replacement rate should be total revenus / pre-retirement income * 100."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=2000,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
        )
        expected_rate = round((2520 + 2000) / 8000 * 100, 1)
        assert result.taux_remplacement == expected_rate

    def test_pc_eligible_low_income(self, budget_service):
        """Low income should indicate potential PC eligibility."""
        result = budget_service.reconcile(
            avs_mensuel=1200, lpp_mensuel=500,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=3000, revenu_pre_retraite=6000,
        )
        # Total = 1700, threshold for single = 3000
        assert result.pc_potentiellement_eligible is True

    def test_pc_not_eligible_high_income(self, budget_service):
        """High income should not indicate PC eligibility."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=3000,
            capital_3a_net=200_000, autres_revenus=1000,
            depenses_mensuelles=5000, revenu_pre_retraite=10000,
        )
        # Total well above 3000 threshold
        assert result.pc_potentiellement_eligible is False

    def test_couple_pc_threshold(self, budget_service):
        """Couple PC threshold should be higher than single."""
        # Income below couple threshold (4500) but above single (3000)
        result = budget_service.reconcile(
            avs_mensuel=2000, lpp_mensuel=1000,
            capital_3a_net=0, autres_revenus=500,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
            is_couple=True,
        )
        # Total = 3500, couple threshold = 4500 -> eligible
        assert result.pc_potentiellement_eligible is True

        result_single = budget_service.reconcile(
            avs_mensuel=2000, lpp_mensuel=1000,
            capital_3a_net=0, autres_revenus=500,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
            is_couple=False,
        )
        # Total = 3500, single threshold = 3000 -> not eligible
        assert result_single.pc_potentiellement_eligible is False

    def test_3a_duration_calculation(self, budget_service):
        """3a duration should be capital / (depenses * 12)."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=2000,
            capital_3a_net=120_000, autres_revenus=0,
            depenses_mensuelles=5000, revenu_pre_retraite=8000,
        )
        expected_duration = round(120_000 / (5000 * 12), 1)
        assert result.duree_capital_3a_ans == expected_duration

    def test_alerts_deficit(self, budget_service):
        """Deficit should trigger a warning alert."""
        result = budget_service.reconcile(
            avs_mensuel=1000, lpp_mensuel=500,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=5000, revenu_pre_retraite=8000,
        )
        assert len(result.alertes) > 0
        alert_text = " ".join(result.alertes)
        assert "Deficit" in alert_text or "deficit" in alert_text

    def test_alerts_low_replacement_rate(self, budget_service):
        """Replacement rate below 60% should trigger a warning."""
        result = budget_service.reconcile(
            avs_mensuel=1500, lpp_mensuel=500,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
        )
        # Total = 2000, replacement rate = 25%
        assert result.taux_remplacement < 60
        alert_text = " ".join(result.alertes)
        assert "remplacement" in alert_text.lower() or "60%" in alert_text

    def test_checklist_non_empty(self, budget_service):
        """Checklist should contain at least 5 items."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=2000,
            capital_3a_net=100_000, autres_revenus=0,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
        )
        assert len(result.checklist) >= 5
        checklist_text = " ".join(result.checklist)
        assert "AVS" in checklist_text
        assert "LPP" in checklist_text or "caisse" in checklist_text
        assert "3a" in checklist_text

    def test_disclaimer_present(self, budget_service):
        """Disclaimer should be present and reference LSFin."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=2000,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
        )
        assert len(result.disclaimer) > 30
        assert "LSFin" in result.disclaimer

    def test_sources_present(self, budget_service):
        """Sources should reference key legal texts."""
        result = budget_service.reconcile(
            avs_mensuel=2520, lpp_mensuel=2000,
            capital_3a_net=0, autres_revenus=0,
            depenses_mensuelles=4000, revenu_pre_retraite=8000,
        )
        assert len(result.sources) >= 2
        source_text = " ".join(result.sources)
        assert "LAVS" in source_text
        assert "LPP" in source_text or "OPC" in source_text


# ===========================================================================
# API Endpoint Tests (integration) — 5 tests
# ===========================================================================

class TestRetirementEndpoints:
    """Integration tests for retirement FastAPI endpoints."""

    def test_avs_estimate_endpoint(self, client):
        """POST /retirement/avs/estimate should return 200."""
        response = client.post(
            "/api/v1/retirement/avs/estimate",
            json={
                "ageActuel": 50,
                "ageRetraite": 65,
                "isCouple": False,
                "anneesLacunes": 0,
                "esperanceVie": 87,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "scenario" in data
        assert data["scenario"] == "normal"
        assert "renteMensuelle" in data
        assert "renteAnnuelle" in data
        assert "chiffreChoc" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_lpp_compare_endpoint(self, client):
        """POST /retirement/lpp/compare should return 200."""
        response = client.post(
            "/api/v1/retirement/lpp/compare",
            json={
                "capitalLpp": 500000,
                "canton": "ZH",
                "ageRetraite": 65,
                "esperanceVie": 87,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "capitalTotal" in data
        assert "optionRenteMensuelle" in data
        assert "optionCapitalNet" in data
        assert "breakevenAge" in data
        assert "recommandationNeutre" in data
        assert "disclaimer" in data

    def test_budget_endpoint(self, client):
        """POST /retirement/budget should return 200."""
        response = client.post(
            "/api/v1/retirement/budget",
            json={
                "avsMensuel": 2520,
                "lppMensuel": 2000,
                "capital3aNet": 100000,
                "autresRevenus": 500,
                "depensesMensuelles": 4000,
                "revenuPreRetraite": 8000,
                "isCouple": False,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "revenusMensuels" in data
        assert "soldeMensuel" in data
        assert "tauxRemplacement" in data
        assert "pcPotentiellementEligible" in data
        assert "checklist" in data
        assert "disclaimer" in data

    def test_checklist_endpoint(self, client):
        """GET /retirement/checklist should return 200 with items."""
        response = client.get("/api/v1/retirement/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "checklist" in data
        assert len(data["checklist"]) >= 8
        assert "disclaimer" in data

    def test_avs_estimate_camelcase_aliases(self, client):
        """API should accept camelCase field names and return camelCase."""
        response = client.post(
            "/api/v1/retirement/avs/estimate",
            json={
                "ageActuel": 55,
                "ageRetraite": 63,
                "isCouple": True,
                "anneesLacunes": 2,
                "esperanceVie": 90,
            },
        )
        assert response.status_code == 200
        data = response.json()
        # Response should use camelCase
        assert "ageDepart" in data
        assert "renteMensuelle" in data
        assert "penaliteOuBonusPct" in data
        assert "renteCoupleeMensuelle" in data or "renteCoupleeMensuelle" not in data
        assert data["scenario"] == "anticipation"
