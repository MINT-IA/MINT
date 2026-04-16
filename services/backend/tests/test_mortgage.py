"""
Tests for the Mortgage & Real Estate module (Sprint S17).

Covers:
    - AffordabilityService: capacity OK/KO, equity OK/KO, edge cases
    - SaronVsFixedService: 3 scenarios, 10-year cost
    - ImputedRentalService: 5 cantons, flat-rate vs actual, net fiscal impact
    - AmortizationService: direct vs indirect on 10/20/30 years
    - EplCombinedService: 3a only, LPP only, mixed, buyback blocage
    - Edge cases: zero values, negatives, unknown cantons
    - Compliance: disclaimers, no forbidden terms

Run with:
    cd services/backend && python -m pytest tests/test_mortgage.py -v
"""

import pytest

from app.services.mortgage.affordability_service import AffordabilityService
from app.services.mortgage.saron_vs_fixed_service import SaronVsFixedService
from app.services.mortgage.imputed_rental_service import ImputedRentalService
from app.services.mortgage.amortization_service import AmortizationService
from app.services.mortgage.epl_combined_service import EplCombinedService

# Forbidden compliance terms
TERMES_INTERDITS = ["garanti", "certain", "assure", "assuré", "garantie"]


# ===========================================================================
# AffordabilityService Tests
# ===========================================================================

class TestAffordabilityService:
    """Tests for mortgage affordability (Tragbarkeitsrechnung)."""

    def setup_method(self):
        self.svc = AffordabilityService()

    def test_capacity_ok_standard_case(self):
        """Typical Swiss household: 150k income, 200k savings, 800k property."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=800_000,
            canton="ZH",
        )
        # 20% of 800k = 160k, savings 200k -> sufficient
        assert result.fonds_propres_suffisants is True
        # Mortgage = 800k - 200k = 600k
        assert result.montant_hypothecaire == 600_000.0
        # Theoretical charges: 600k*5%/12 + 600k*1%/12 + 800k*1%/12
        # = 2500 + 500 + 666.67 = ~3666.67
        assert result.charges_mensuelles_theoriques == pytest.approx(3666.67, abs=1)
        # Ratio: 44000 / 150000 = ~29.3% -> OK
        assert result.capacite_ok is True
        assert result.ratio_charges < 1/3

    def test_capacity_insufficient_income(self):
        """Income too low for the property price."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=80_000,
            epargne_disponible=300_000,
            prix_achat=1_200_000,
            canton="GE",
        )
        # Mortgage = 1.2M - 300k = 900k
        # Charges: 900k*5%/12 + 900k*1%/12 + 1.2M*1%/12 = 3750+750+1000 = 5500/month
        # Ratio: 66000/80000 = 82.5% > 33%
        assert result.capacite_ok is False
        assert result.ratio_charges > 1/3

    def test_equity_insufficient(self):
        """Not enough equity for 20% requirement."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=200_000,
            epargne_disponible=50_000,
            prix_achat=1_000_000,
            canton="VD",
        )
        # 20% of 1M = 200k, only 50k -> insufficient
        assert result.fonds_propres_suffisants is False

    def test_equity_with_3a_and_lpp(self):
        """Equity augmented with 3a and LPP."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=100_000,
            avoir_3a=50_000,
            avoir_lpp=80_000,
            prix_achat=1_000_000,
            canton="BE",
        )
        # Total equity = 100k + 50k + 80k = 230k >= 200k (20%)
        assert result.fonds_propres_suffisants is True
        # LPP cap: max 10% of 1M = 100k, so 80k is all usable
        assert result.detail_fonds_propres["avoir_lpp"] == 80_000.0

    def test_lpp_cap_10_percent(self):
        """LPP limited to 10% of purchase price."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=200_000,
            epargne_disponible=100_000,
            avoir_lpp=200_000,
            prix_achat=800_000,
            canton="ZH",
        )
        # LPP cap: 10% of 800k = 80k (not the full 200k)
        assert result.detail_fonds_propres["avoir_lpp"] == 80_000.0

    def test_no_target_price_calculates_max(self):
        """When no target price, calculate maximum affordable price."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=0,
            canton="ZH",
        )
        assert result.prix_max_accessible > 0
        # Max price should be constrained by both income and equity
        # Equity constraint: 200k / 0.20 = 1M
        assert result.prix_max_accessible <= 1_000_000.0

    def test_zero_income(self):
        """Zero income should give zero max price."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=0,
            epargne_disponible=200_000,
            prix_achat=0,
            canton="ZH",
        )
        assert result.prix_max_accessible == 0.0

    def test_checklist_not_empty(self):
        """Checklist should always have items."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=800_000,
        )
        assert len(result.checklist) >= 3

    def test_premier_eclairage_present(self):
        """Chiffre choc should always be present."""
        result = self.svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=800_000,
        )
        assert result.premier_eclairage.texte
        assert isinstance(result.premier_eclairage.montant, float)


# ===========================================================================
# SaronVsFixedService Tests
# ===========================================================================

class TestSaronVsFixedService:
    """Tests for SARON vs fixed rate comparison."""

    def setup_method(self):
        self.svc = SaronVsFixedService()

    def test_three_scenarios_returned(self):
        """Should return exactly 3 default scenarios."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=10,
        )
        assert len(result.scenarios) == 3
        noms = {s.nom for s in result.scenarios}
        assert noms == {"stable", "hausse", "baisse"}

    def test_fixed_cost_calculation(self):
        """Fixed rate cost should be straightforward."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=10,
            taux_fixe=0.025,
        )
        # 500k * 2.5% * 10 = 125k
        assert result.cout_total_fixe == pytest.approx(125_000.0, abs=1)
        # Monthly: 500k * 2.5% / 12 = 1041.67
        assert result.mensualite_fixe == pytest.approx(1041.67, abs=1)

    def test_stable_saron_lower_than_fixed(self):
        """With default rates, stable SARON should be cheaper than fixed."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=10,
        )
        stable = next(s for s in result.scenarios if s.nom == "stable")
        # SARON initial: 1.25% + 0.80% = 2.05%, stable
        # Fixed 10y: 2.50%
        assert stable.cout_total_interets < result.cout_total_fixe

    def test_rising_saron_scenario(self):
        """Rising SARON: monthly payment should increase over time."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=10,
        )
        hausse = next(s for s in result.scenarios if s.nom == "hausse")
        assert hausse.mensualite_max > hausse.mensualite_min

    def test_falling_saron_scenario(self):
        """Falling SARON: monthly payment should decrease over time."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=10,
        )
        baisse = next(s for s in result.scenarios if s.nom == "baisse")
        assert baisse.mensualite_min < baisse.mensualite_max

    def test_graphe_data_length(self):
        """Graph data should have one entry per year."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=10,
        )
        for scenario in result.scenarios:
            assert len(scenario.graphe_data) == 10

    def test_zero_mortgage(self):
        """Zero mortgage should result in zero costs."""
        result = self.svc.compare(
            montant_hypothecaire=0,
            duree_ans=10,
        )
        assert result.cout_total_fixe == 0.0
        for s in result.scenarios:
            assert s.cout_total_interets == 0.0

    def test_custom_rates(self):
        """Custom SARON and fixed rates should be used."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=5,
            taux_saron_actuel=0.01,
            marge_banque=0.01,
            taux_fixe=0.03,
        )
        assert result.taux_saron_actuel == 0.01
        assert result.marge_banque == 0.01
        assert result.taux_fixe == 0.03


# ===========================================================================
# ImputedRentalService Tests
# ===========================================================================

class TestImputedRentalService:
    """Tests for imputed rental value (Eigenmietwert)."""

    def setup_method(self):
        self.svc = ImputedRentalService()

    def test_zurich_valeur_locative(self):
        """ZH: 3.5% of market value."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
        )
        assert result.valeur_locative == pytest.approx(35_000.0, abs=1)
        assert result.taux_valeur_locative == 0.035

    def test_geneva_valeur_locative(self):
        """GE: 4.5% of market value."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="GE",
        )
        assert result.valeur_locative == pytest.approx(45_000.0, abs=1)

    def test_vaud_valeur_locative(self):
        """VD: 4.0% of market value."""
        result = self.svc.calculate(
            valeur_venale=800_000,
            canton="VD",
        )
        assert result.valeur_locative == pytest.approx(32_000.0, abs=1)

    def test_bern_valeur_locative(self):
        """BE: 3.8% of market value."""
        result = self.svc.calculate(
            valeur_venale=600_000,
            canton="BE",
        )
        assert result.valeur_locative == pytest.approx(22_800.0, abs=1)

    def test_zug_valeur_locative(self):
        """ZG: 2.8% (lowest)."""
        result = self.svc.calculate(
            valeur_venale=1_500_000,
            canton="ZG",
        )
        assert result.valeur_locative == pytest.approx(42_000.0, abs=1)

    def test_forfait_neuf_10_percent(self):
        """Property < 10 years: 10% flat-rate maintenance."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
            age_bien_ans=5,
        )
        assert result.forfait_entretien_applicable == 0.10

    def test_forfait_ancien_20_percent(self):
        """Property >= 10 years: 20% flat-rate maintenance."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
            age_bien_ans=15,
        )
        assert result.forfait_entretien_applicable == 0.20

    def test_reel_vs_forfait_recommendation(self):
        """When actual costs exceed flat-rate, recommend 'reel'."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
            frais_entretien_annuels=50_000,
            age_bien_ans=5,
        )
        # Forfait 10% of VL(35k) = 3500, actual = 50k -> recommend reel
        assert result.recommandation_forfait_vs_reel == "reel"

    def test_forfait_recommended_when_higher(self):
        """When flat-rate exceeds actual costs, recommend 'forfait'."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
            frais_entretien_annuels=500,
            age_bien_ans=5,
        )
        assert result.recommandation_forfait_vs_reel == "forfait"

    def test_deductions_exceed_valeur_locative(self):
        """High deductions -> fiscal advantage (negative net impact)."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
            interets_hypothecaires_annuels=30_000,
            frais_entretien_annuels=10_000,
            prime_assurance_batiment=2_000,
            age_bien_ans=5,
            taux_marginal_imposition=0.30,
        )
        # VL = 35000, deductions = 30000 + max(10000, 3500) + 2000 = 42000
        # Impact = 35000 - 42000 = -7000 -> advantage
        assert result.est_avantage_fiscal is True
        assert result.impact_revenu_imposable < 0

    def test_net_cost_when_low_deductions(self):
        """Low deductions -> net cost (positive net impact)."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="GE",
            interets_hypothecaires_annuels=5_000,
            frais_entretien_annuels=0,
            prime_assurance_batiment=0,
            age_bien_ans=5,
            taux_marginal_imposition=0.30,
        )
        # VL GE = 45000, deductions = 5000 + forfait(4500) + 0 = 9500
        # Impact = 45000 - 9500 = 35500 -> cost
        assert result.est_avantage_fiscal is False
        assert result.impact_revenu_imposable > 0

    def test_unknown_canton_uses_default(self):
        """Unknown canton should use default rate."""
        result = self.svc.calculate(
            valeur_venale=1_000_000,
            canton="XX",
        )
        assert result.taux_valeur_locative == 0.035  # default


# ===========================================================================
# AmortizationService Tests
# ===========================================================================

class TestAmortizationService:
    """Tests for direct vs indirect amortization."""

    def setup_method(self):
        self.svc = AmortizationService()

    def test_indirect_cheaper_typical_case(self):
        """Indirect amortization is typically more tax-efficient."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=15,
            versement_annuel_amortissement=7_000,
            taux_marginal_imposition=0.30,
            rendement_3a=0.02,
        )
        assert result.methode_avantageuse == "indirect"
        assert result.difference_nette > 0

    def test_direct_reduces_debt(self):
        """Direct: debt should decrease over time."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=10,
            versement_annuel_amortissement=10_000,
        )
        assert result.direct.dette_finale < 500_000.0
        assert result.direct.dette_finale == pytest.approx(400_000.0, abs=1)

    def test_indirect_debt_constant(self):
        """Indirect: debt should stay constant."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=10,
            versement_annuel_amortissement=7_000,
        )
        assert result.indirect.dette_finale == 500_000.0

    def test_indirect_3a_grows(self):
        """Indirect: 3a capital should grow over time."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=15,
            versement_annuel_amortissement=7_000,
            rendement_3a=0.03,
        )
        # 3a capital should exceed total contributions
        total_verse = 7000 * 15
        assert result.indirect.capital_3a_cumule > total_verse

    def test_10_year_comparison(self):
        """10-year comparison should produce valid results."""
        result = self.svc.compare(
            montant_hypothecaire=400_000,
            taux_interet=0.025,
            duree_ans=10,
        )
        assert len(result.graphe_data) == 10
        assert result.direct.interets_payes_total > 0
        assert result.indirect.interets_payes_total > 0

    def test_20_year_comparison(self):
        """20-year comparison."""
        result = self.svc.compare(
            montant_hypothecaire=600_000,
            taux_interet=0.02,
            duree_ans=20,
        )
        assert len(result.graphe_data) == 20
        # Over 20 years, indirect advantage should be significant
        assert result.difference_nette > 0

    def test_30_year_comparison(self):
        """30-year comparison."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=30,
        )
        assert len(result.graphe_data) == 30

    def test_default_versement(self):
        """When versement is 0, default to 1% of mortgage."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=10,
            versement_annuel_amortissement=0,
        )
        assert result.versement_annuel == pytest.approx(5_000.0, abs=1)

    def test_graph_data_coherent(self):
        """Graph data should show decreasing direct debt."""
        result = self.svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=10,
            versement_annuel_amortissement=10_000,
        )
        for i in range(1, len(result.graphe_data)):
            assert (result.graphe_data[i].dette_direct
                    <= result.graphe_data[i - 1].dette_direct)
            assert (result.graphe_data[i].capital_3a
                    >= result.graphe_data[i - 1].capital_3a)


# ===========================================================================
# EplCombinedService Tests
# ===========================================================================

class TestEplCombinedService:
    """Tests for combined EPL (3a + LPP) equity calculation."""

    def setup_method(self):
        self.svc = EplCombinedService()

    def test_3a_only(self):
        """Only 3a withdrawal, no LPP."""
        result = self.svc.calculate(
            avoir_3a=80_000,
            avoir_lpp_total=0,
            avoir_obligatoire=0,
            avoir_surobligatoire=0,
            age=35,
            canton="ZH",
            epargne_cash=50_000,
        )
        assert result.detail.retrait_3a == 80_000.0
        assert result.detail.retrait_lpp == 0.0
        assert result.detail.cash == 50_000.0
        # Net should be cash + 3a - tax
        assert result.total_fonds_propres > 50_000.0

    def test_lpp_only(self):
        """Only LPP withdrawal, no 3a."""
        result = self.svc.calculate(
            avoir_3a=0,
            avoir_lpp_total=200_000,
            avoir_obligatoire=120_000,
            avoir_surobligatoire=80_000,
            age=35,
            canton="VD",
            epargne_cash=50_000,
        )
        assert result.detail.retrait_3a == 0.0
        assert result.detail.retrait_lpp == 200_000.0  # age < 50, full amount
        assert result.detail.cash == 50_000.0

    def test_mixed_3a_and_lpp(self):
        """Combined 3a + LPP withdrawal."""
        result = self.svc.calculate(
            avoir_3a=60_000,
            avoir_lpp_total=150_000,
            avoir_obligatoire=100_000,
            avoir_surobligatoire=50_000,
            age=40,
            canton="BE",
            epargne_cash=100_000,
            prix_cible=1_000_000,
        )
        assert result.detail.retrait_3a == 60_000.0
        assert result.detail.retrait_lpp == 150_000.0
        assert result.detail.cash == 100_000.0
        assert result.pourcentage_prix_couvert > 0

    def test_buyback_blocage(self):
        """Recent buyback should block LPP withdrawal."""
        result = self.svc.calculate(
            avoir_3a=50_000,
            avoir_lpp_total=200_000,
            avoir_obligatoire=120_000,
            avoir_surobligatoire=80_000,
            age=40,
            canton="ZH",
            epargne_cash=50_000,
            a_rachete_recemment=True,
            annees_depuis_dernier_rachat=1,
        )
        # LPP should be blocked
        assert result.detail.retrait_lpp == 0.0
        # 3a should still be available
        assert result.detail.retrait_3a == 50_000.0

    def test_age_50_rule_lpp(self):
        """Age >= 50: LPP withdrawal limited."""
        result = self.svc.calculate(
            avoir_3a=0,
            avoir_lpp_total=400_000,
            avoir_obligatoire=250_000,
            avoir_surobligatoire=150_000,
            age=55,
            canton="ZH",
            epargne_cash=0,
        )
        # Age 50 rule: max(avoir_at_50, 50% of current) = 50% of 400k = 200k
        assert result.detail.retrait_lpp == 200_000.0

    def test_coverage_percentage(self):
        """Coverage should be calculated correctly."""
        result = self.svc.calculate(
            avoir_3a=50_000,
            avoir_lpp_total=100_000,
            avoir_obligatoire=60_000,
            avoir_surobligatoire=40_000,
            age=35,
            canton="ZH",
            epargne_cash=100_000,
            prix_cible=1_000_000,
        )
        # Total net should be calculated
        assert result.pourcentage_prix_couvert > 0
        assert result.pourcentage_prix_couvert < 100

    def test_mix_optimal_not_empty(self):
        """Optimal mix should have at least one step."""
        result = self.svc.calculate(
            avoir_3a=50_000,
            avoir_lpp_total=100_000,
            avoir_obligatoire=60_000,
            avoir_surobligatoire=40_000,
            age=35,
            canton="ZH",
            epargne_cash=50_000,
        )
        assert len(result.mix_optimal) >= 1

    def test_taxes_applied(self):
        """Taxes should reduce the net amount."""
        result = self.svc.calculate(
            avoir_3a=100_000,
            avoir_lpp_total=0,
            avoir_obligatoire=0,
            avoir_surobligatoire=0,
            age=35,
            canton="ZH",
            epargne_cash=0,
        )
        assert result.detail.impot_3a > 0
        assert result.detail.net_3a < 100_000.0


# ===========================================================================
# Edge Cases & Compliance
# ===========================================================================

class TestEdgeCases:
    """Edge cases: zero values, negatives, unknown cantons."""

    def test_affordability_all_zeros(self):
        """All zeros should not crash."""
        svc = AffordabilityService()
        result = svc.calculate_affordability(
            revenu_brut_annuel=0,
            epargne_disponible=0,
            prix_achat=0,
        )
        assert result.prix_max_accessible == 0.0
        assert result.disclaimer

    def test_saron_zero_duration(self):
        """Duration of 1 year (min) should work."""
        svc = SaronVsFixedService()
        result = svc.compare(
            montant_hypothecaire=500_000,
            duree_ans=1,
        )
        assert len(result.scenarios) == 3
        for s in result.scenarios:
            assert len(s.graphe_data) == 1

    def test_imputed_rental_zero_value(self):
        """Zero market value should give zero imputed rental."""
        svc = ImputedRentalService()
        result = svc.calculate(valeur_venale=0, canton="ZH")
        assert result.valeur_locative == 0.0

    def test_amortization_zero_mortgage(self):
        """Zero mortgage should not crash."""
        svc = AmortizationService()
        result = svc.compare(
            montant_hypothecaire=0,
            taux_interet=0.02,
            duree_ans=10,
        )
        assert result.direct.interets_payes_total == 0.0

    def test_epl_combined_all_zeros(self):
        """All zeros should give zero equity."""
        svc = EplCombinedService()
        result = svc.calculate(
            avoir_3a=0,
            avoir_lpp_total=0,
            avoir_obligatoire=0,
            avoir_surobligatoire=0,
            age=35,
            canton="ZH",
            epargne_cash=0,
        )
        assert result.total_fonds_propres == 0.0

    def test_affordability_unknown_canton(self):
        """Unknown canton should not crash."""
        svc = AffordabilityService()
        result = svc.calculate_affordability(
            revenu_brut_annuel=100_000,
            epargne_disponible=100_000,
            prix_achat=500_000,
            canton="XX",
        )
        assert result.canton == "XX"
        assert result.disclaimer


class TestCompliance:
    """Compliance: disclaimers, forbidden terms, sources."""

    def test_affordability_disclaimer(self):
        """Affordability disclaimer should be present and clean."""
        svc = AffordabilityService()
        result = svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=800_000,
        )
        assert result.disclaimer
        assert len(result.disclaimer) > 50
        for terme in TERMES_INTERDITS:
            assert terme not in result.disclaimer.lower()

    def test_saron_disclaimer(self):
        """SARON disclaimer should be present and clean."""
        svc = SaronVsFixedService()
        result = svc.compare(montant_hypothecaire=500_000, duree_ans=10)
        assert result.disclaimer
        for terme in TERMES_INTERDITS:
            assert terme not in result.disclaimer.lower()

    def test_imputed_rental_disclaimer(self):
        """Imputed rental disclaimer should be present and clean."""
        svc = ImputedRentalService()
        result = svc.calculate(valeur_venale=1_000_000, canton="ZH")
        assert result.disclaimer
        for terme in TERMES_INTERDITS:
            assert terme not in result.disclaimer.lower()

    def test_amortization_disclaimer(self):
        """Amortization disclaimer should be present and clean."""
        svc = AmortizationService()
        result = svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=10,
        )
        assert result.disclaimer
        for terme in TERMES_INTERDITS:
            assert terme not in result.disclaimer.lower()

    def test_epl_combined_disclaimer(self):
        """EPL combined disclaimer should be present and clean."""
        svc = EplCombinedService()
        result = svc.calculate(
            avoir_3a=50_000,
            avoir_lpp_total=100_000,
            avoir_obligatoire=60_000,
            avoir_surobligatoire=40_000,
            age=35,
            canton="ZH",
            epargne_cash=50_000,
        )
        assert result.disclaimer
        for terme in TERMES_INTERDITS:
            assert terme not in result.disclaimer.lower()

    def test_affordability_sources_not_empty(self):
        """Sources should cite legal bases."""
        svc = AffordabilityService()
        result = svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=800_000,
        )
        assert len(result.sources) >= 2
        # Should mention FINMA or ASB
        sources_text = " ".join(result.sources).lower()
        assert "finma" in sources_text or "asb" in sources_text

    def test_imputed_rental_sources_cite_lifd(self):
        """Imputed rental sources should cite LIFD."""
        svc = ImputedRentalService()
        result = svc.calculate(valeur_venale=1_000_000, canton="ZH")
        sources_text = " ".join(result.sources).lower()
        assert "lifd" in sources_text

    def test_amortization_sources_cite_opp3(self):
        """Amortization sources should cite OPP3."""
        svc = AmortizationService()
        result = svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.02,
            duree_ans=10,
        )
        sources_text = " ".join(result.sources).lower()
        assert "opp3" in sources_text

    def test_epl_sources_cite_lpp(self):
        """EPL sources should cite LPP."""
        svc = EplCombinedService()
        result = svc.calculate(
            avoir_3a=50_000,
            avoir_lpp_total=100_000,
            avoir_obligatoire=60_000,
            avoir_surobligatoire=40_000,
            age=35,
            canton="ZH",
            epargne_cash=50_000,
        )
        sources_text = " ".join(result.sources).lower()
        assert "lpp" in sources_text

    def test_no_forbidden_terms_in_premier_eclairage(self):
        """Chiffre choc texts should not contain forbidden terms."""
        svc = AffordabilityService()
        result = svc.calculate_affordability(
            revenu_brut_annuel=150_000,
            epargne_disponible=200_000,
            prix_achat=800_000,
        )
        for terme in TERMES_INTERDITS:
            assert terme not in result.premier_eclairage.texte.lower()


# ===========================================================================
# Additional edge case tests
# ===========================================================================

class TestAdditionalEdgeCases:
    """Additional tests to reach 40+ test count."""

    def test_affordability_negative_values_sanitized(self):
        """Negative inputs should be sanitized to 0."""
        svc = AffordabilityService()
        result = svc.calculate_affordability(
            revenu_brut_annuel=-50_000,
            epargne_disponible=-10_000,
            prix_achat=-100_000,
        )
        assert result.revenu_brut_annuel == 0.0
        assert result.fonds_propres_total == 0.0

    def test_saron_very_long_duration(self):
        """30-year duration should work correctly."""
        svc = SaronVsFixedService()
        result = svc.compare(
            montant_hypothecaire=800_000,
            duree_ans=30,
        )
        for s in result.scenarios:
            assert len(s.graphe_data) == 30
        assert result.cout_total_fixe > 0

    def test_imputed_rental_high_maintenance(self):
        """Very high maintenance should dominate deductions."""
        svc = ImputedRentalService()
        result = svc.calculate(
            valeur_venale=1_000_000,
            canton="ZH",
            frais_entretien_annuels=100_000,
            taux_marginal_imposition=0.30,
        )
        assert result.recommandation_forfait_vs_reel == "reel"
        assert result.deduction_entretien == 100_000.0

    def test_amortization_high_interest_rate(self):
        """High interest rate scenario."""
        svc = AmortizationService()
        result = svc.compare(
            montant_hypothecaire=500_000,
            taux_interet=0.08,
            duree_ans=10,
        )
        assert result.direct.interets_payes_total > 0
        assert result.indirect.interets_payes_total > 0

    def test_epl_combined_with_prix_cible(self):
        """With a target price, coverage % should be calculated."""
        svc = EplCombinedService()
        result = svc.calculate(
            avoir_3a=100_000,
            avoir_lpp_total=200_000,
            avoir_obligatoire=120_000,
            avoir_surobligatoire=80_000,
            age=35,
            canton="VD",
            epargne_cash=150_000,
            prix_cible=1_500_000,
        )
        assert result.pourcentage_prix_couvert > 0
        assert result.prix_cible == 1_500_000.0

    def test_epl_combined_alertes_present(self):
        """Alerts should mention important risks."""
        svc = EplCombinedService()
        result = svc.calculate(
            avoir_3a=100_000,
            avoir_lpp_total=300_000,
            avoir_obligatoire=200_000,
            avoir_surobligatoire=100_000,
            age=35,
            canton="ZH",
            epargne_cash=0,
            prix_cible=1_000_000,
        )
        assert len(result.alertes) >= 1
