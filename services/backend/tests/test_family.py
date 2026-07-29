"""
Tests for the Family module (Sprint S22).

Covers:
    - MariageService: fiscal comparison, matrimonial regimes, survivor benefits — 18 tests
    - NaissanceService: APG, allocations, tax deductions, career gap — 20 tests
    - ConcubinageService: comparison, inheritance tax, checklist — 14 tests
    - API endpoints (integration) — 12 tests

Target: 64 tests.

Run: cd services/backend && python3 -m pytest tests/test_family.py -v
"""

import re

import pytest

from app.services.family.mariage_service import (
    MariageService,
    deduction_double_activite,
    DEDUCTION_MARIES,
    DEDUCTION_ASSURANCES_MARIES,
    DEDUCTION_ASSURANCES_CELIBATAIRE,
    DEDUCTION_PAR_ENFANT,
    AVS_SURVIVOR_FACTOR,
    LPP_SURVIVOR_FACTOR,
    DISCLAIMER as MARIAGE_DISCLAIMER,
)
from app.constants.social_insurance import PILIER_3A_PLAFOND_AVEC_LPP as PLAFOND_3A
from app.services.family.naissance_service import (
    NaissanceService,
    APG_TAUX,
    APG_MAX_JOUR,
    ALLOCATIONS_ENFANT_PAR_CANTON,
    ALLOCATIONS_FORMATION_PAR_CANTON,
    DEDUCTION_PAR_ENFANT as DEDUCTION_ENFANT_NAISSANCE,
    DEDUCTION_FRAIS_GARDE_MAX,
    LPP_DEDUCTION_COORDINATION,
    DISCLAIMER as NAISSANCE_DISCLAIMER,
)
from app.services.family.concubinage_service import (
    ConcubinageService,
    DISCLAIMER as CONCUBINAGE_DISCLAIMER,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mariage_service():
    return MariageService()


@pytest.fixture
def naissance_service():
    return NaissanceService()


@pytest.fixture
def concubinage_service():
    return ConcubinageService()


# ===========================================================================
# MariageService — Fiscal Comparison (10 tests)
# ===========================================================================

class TestMariageFiscalComparison:
    """Tests for MariageService.compare_fiscal_impact()."""

    def test_penalite_mariage_two_equal_high_incomes(self, mariage_service):
        """Two equal high incomes should create a marriage penalty."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=120_000, revenu_2=120_000, canton="ZH", enfants=0,
        )
        # When 2 high earners marry, combined income hits higher brackets
        assert result.est_penalite_mariage is True
        assert result.difference > 0
        assert "Penalite" in result.premier_eclairage

    def test_bonus_mariage_one_income(self, mariage_service):
        """Single earner + stay-at-home spouse should create a marriage bonus."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=120_000, revenu_2=0, canton="ZH", enfants=0,
        )
        # Single earner benefits from married bracket (lower rates)
        assert result.est_penalite_mariage is False
        assert result.difference < 0
        assert "Bonus" in result.premier_eclairage

    def test_revenus_cumules(self, mariage_service):
        """Combined revenue should equal sum of both incomes."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=80_000, revenu_2=50_000, canton="GE",
        )
        assert result.revenus_cumules == 130_000

    def test_deductions_double_activite(self, mariage_service):
        """Both partners working should include the double-activity deduction,
        computed as the LIFD art. 33 al. 2 formula (50% of the lower income,
        bounded) — NOT a fixed amount."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        expected_da = deduction_double_activite(80_000, 60_000)
        expected_deductions = (
            DEDUCTION_MARIES + DEDUCTION_ASSURANCES_MARIES + expected_da
        )
        assert result.deductions_mariage == expected_deductions
        # The formula scales with income — it is not the old fixed 2'800.
        assert expected_da != 2_800.0

    def test_deductions_no_double_activite_single_earner(self, mariage_service):
        """Single earner: no double-activity deduction."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=100_000, revenu_2=0, canton="ZH",
        )
        expected_deductions = DEDUCTION_MARIES + DEDUCTION_ASSURANCES_MARIES
        assert result.deductions_mariage == expected_deductions

    def test_deductions_with_children(self, mariage_service):
        """Children should add 6800/enfant to marriage deductions."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=100_000, revenu_2=50_000, canton="ZH", enfants=2,
        )
        expected_da = deduction_double_activite(100_000, 50_000)
        base = DEDUCTION_MARIES + DEDUCTION_ASSURANCES_MARIES + expected_da
        expected = base + DEDUCTION_PAR_ENFANT * 2
        assert result.deductions_mariage == expected

    def test_canton_ge_higher_tax_than_zh(self, mariage_service):
        """GE should have higher tax than ZH (higher cantonal multiplier)."""
        result_ge = mariage_service.compare_fiscal_impact(
            revenu_1=100_000, revenu_2=80_000, canton="GE",
        )
        result_zh = mariage_service.compare_fiscal_impact(
            revenu_1=100_000, revenu_2=80_000, canton="ZH",
        )
        assert result_ge.impot_maries_total > result_zh.impot_maries_total

    def test_zero_income_both(self, mariage_service):
        """Zero income for both should give zero tax."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=0, revenu_2=0, canton="ZH",
        )
        assert result.impot_celibataires_total == 0
        assert result.impot_maries_total == 0
        assert result.difference == 0

    def test_sources_contain_lifd(self, mariage_service):
        """Sources should reference LIFD articles."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        source_text = " ".join(result.sources)
        assert "LIFD" in source_text
        assert "art." in source_text

    def test_premier_eclairage_contains_chf(self, mariage_service):
        """Chiffre choc should contain CHF amount."""
        result = mariage_service.compare_fiscal_impact(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        assert "CHF" in result.premier_eclairage

    def test_tax_delegates_to_canonical_engine(self, mariage_service, monkeypatch):
        """Anti-façade : compare_fiscal_impact DOIT déléguer la charge fiscale
        au moteur canonique estimate_income_tax() — deux appels célibataires
        (is_married=False) et un appel marié (is_married=True), sur les revenus
        imposables attendus, et sa valeur de retour doit alimenter le résultat.

        On espionne l'import : une ré-implémentation locale du barème (l'ancien
        défaut — barèmes IFD 2024 + multiplicateur cantonal heuristique)
        échouerait ce test même en reproduisant les mêmes nombres.
        """
        calls = []

        def spy(taxable_income, canton, is_married=False, **kwargs):
            calls.append((round(taxable_income, 2), canton, is_married))
            return 5000.0 if is_married else 1000.0

        monkeypatch.setattr(
            "app.services.family.mariage_service.estimate_income_tax", spy
        )

        revenu_1, revenu_2, canton, enfants = 100_000, 70_000, "VD", 1
        deductions = (
            DEDUCTION_MARIES
            + DEDUCTION_ASSURANCES_MARIES
            + deduction_double_activite(revenu_1, revenu_2)
            + DEDUCTION_PAR_ENFANT * enfants
        )
        ri_marie = round(max(0, revenu_1 + revenu_2 - deductions), 2)
        ri_1 = round(max(0, revenu_1 - DEDUCTION_ASSURANCES_CELIBATAIRE
                         - DEDUCTION_PAR_ENFANT * enfants / 2), 2)
        ri_2 = round(max(0, revenu_2 - DEDUCTION_ASSURANCES_CELIBATAIRE
                         - DEDUCTION_PAR_ENFANT * enfants / 2), 2)

        result = mariage_service.compare_fiscal_impact(
            revenu_1=revenu_1, revenu_2=revenu_2, canton=canton, enfants=enfants,
        )

        # Exactement 3 délégations : 2 célibataires (False) + 1 marié (True).
        assert len(calls) == 3
        assert sum(1 for c in calls if c[2] is False) == 2
        assert sum(1 for c in calls if c[2] is True) == 1
        # Les bons revenus imposables sont transmis au moteur canonique.
        assert (ri_1, canton, False) in calls
        assert (ri_2, canton, False) in calls
        assert (ri_marie, canton, True) in calls
        # La valeur de retour du moteur alimente réellement le résultat.
        assert result.impot_maries_total == 5000.0
        assert result.impot_celibataires_total == round(1000.0 + 1000.0, 2)


# ===========================================================================
# MariageService — Regime Matrimonial (5 tests)
# ===========================================================================

class TestRegimeMatrimonial:
    """Tests for MariageService.simulate_regime_matrimonial()."""

    def test_participation_acquets_equal_split(self, mariage_service):
        """Participation aux acquets: acquets split 50/50."""
        result = mariage_service.simulate_regime_matrimonial(
            patrimoine_1=300_000, patrimoine_2=100_000,
            regime="participation_acquets",
        )
        assert result.regime == "participation_acquets"
        assert result.patrimoine_total == 400_000
        # Acquets are split 50/50
        assert result.part_conjoint_1 == 200_000
        assert result.part_conjoint_2 == 200_000

    def test_separation_biens_no_split(self, mariage_service):
        """Separation de biens: each keeps their own."""
        result = mariage_service.simulate_regime_matrimonial(
            patrimoine_1=300_000, patrimoine_2=100_000,
            regime="separation_biens",
        )
        assert result.regime == "separation_biens"
        assert result.part_conjoint_1 == 300_000
        assert result.part_conjoint_2 == 100_000

    def test_communaute_biens_full_split(self, mariage_service):
        """Communaute de biens: everything split 50/50."""
        result = mariage_service.simulate_regime_matrimonial(
            patrimoine_1=500_000, patrimoine_2=100_000,
            regime="communaute_biens",
        )
        assert result.regime == "communaute_biens"
        assert result.patrimoine_total == 600_000
        assert result.part_conjoint_1 == 300_000
        assert result.part_conjoint_2 == 300_000

    def test_sources_contain_cc(self, mariage_service):
        """Sources should reference Code Civil (CC) articles."""
        result = mariage_service.simulate_regime_matrimonial(
            patrimoine_1=100_000, patrimoine_2=50_000,
            regime="communaute_biens",
        )
        source_text = " ".join(result.sources)
        assert "CC" in source_text

    def test_zero_patrimoine(self, mariage_service):
        """Zero patrimoine should give zero parts."""
        result = mariage_service.simulate_regime_matrimonial(
            patrimoine_1=0, patrimoine_2=0,
            regime="participation_acquets",
        )
        assert result.patrimoine_total == 0
        assert result.part_conjoint_1 == 0
        assert result.part_conjoint_2 == 0


# ===========================================================================
# MariageService — Survivor Benefits (3 tests)
# ===========================================================================

class TestSurvivorBenefits:
    """Tests for MariageService.estimate_survivor_benefits()."""

    def test_avs_survivor_80_percent(self, mariage_service):
        """AVS survivor rente should be 80% of deceased's rente."""
        result = mariage_service.estimate_survivor_benefits(
            rente_lpp=2000, rente_avs=2520,
        )
        assert result.rente_survivant_avs_mensuelle == round(2520 * AVS_SURVIVOR_FACTOR, 2)
        assert result.rente_survivant_avs_mensuelle == 2016.0

    def test_lpp_survivor_60_percent(self, mariage_service):
        """LPP survivor rente should be 60% of insured rente."""
        result = mariage_service.estimate_survivor_benefits(
            rente_lpp=2000, rente_avs=2520,
        )
        assert result.rente_survivant_lpp_mensuelle == round(2000 * LPP_SURVIVOR_FACTOR, 2)
        assert result.rente_survivant_lpp_mensuelle == 1200.0

    def test_total_survivor_sum(self, mariage_service):
        """Total survivor should be AVS + LPP survivor rentes."""
        result = mariage_service.estimate_survivor_benefits(
            rente_lpp=2000, rente_avs=2520,
        )
        expected_total = 2016.0 + 1200.0
        assert result.total_survivant_mensuel == expected_total
        assert result.total_survivant_annuel == round(expected_total * 12, 2)
        assert "CHF" in result.premier_eclairage
        source_text = " ".join(result.sources)
        assert "LAVS" in source_text
        assert "LPP" in source_text


# ===========================================================================
# NaissanceService — Conge parental APG (6 tests)
# ===========================================================================

class TestCongeParentalAPG:
    """Tests for NaissanceService.simulate_conge_parental()."""

    def test_maternite_14_semaines(self, naissance_service):
        """Maternity leave should be 14 weeks / 98 days."""
        result = naissance_service.simulate_conge_parental(
            salaire_mensuel=6000, is_mother=True,
        )
        assert result.type_conge == "maternite"
        assert result.duree_semaines == 14
        assert result.duree_jours == 98

    def test_paternite_2_semaines(self, naissance_service):
        """Paternity leave should be 2 weeks / 14 calendar days."""
        result = naissance_service.simulate_conge_parental(
            salaire_mensuel=6000, is_mother=False,
        )
        assert result.type_conge == "paternite"
        assert result.duree_semaines == 2
        assert result.duree_jours == 14

    def test_apg_80_percent(self, naissance_service):
        """APG should be 80% of daily salary."""
        result = naissance_service.simulate_conge_parental(
            salaire_mensuel=6000, is_mother=True,
        )
        # Daily salary = 6000 * 12 / 360 = 200
        expected_daily = 6000 * 12 / 360
        expected_apg = expected_daily * APG_TAUX
        assert result.salaire_journalier == round(expected_daily, 2)
        assert result.apg_journalier == round(min(expected_apg, APG_MAX_JOUR), 2)

    def test_apg_capped_at_220_per_day(self, naissance_service):
        """APG should be capped at CHF 220/day for high earners."""
        # Salary that would give > 220/day at 80%:
        # daily = S * 12 / 360; 0.8 * daily > 220 => daily > 275 => S > 8250
        result = naissance_service.simulate_conge_parental(
            salaire_mensuel=10_000, is_mother=True,
        )
        assert result.apg_journalier == APG_MAX_JOUR
        assert result.est_plafonne is True

    def test_apg_not_capped_low_salary(self, naissance_service):
        """Low salary should not hit the APG cap."""
        result = naissance_service.simulate_conge_parental(
            salaire_mensuel=4000, is_mother=True,
        )
        # daily = 4000 * 12 / 360 = 133.33; 80% = 106.67 < 220
        assert result.apg_journalier < APG_MAX_JOUR
        assert result.est_plafonne is False

    def test_perte_revenu_positive(self, naissance_service):
        """Revenue loss should be positive (salary > APG)."""
        result = naissance_service.simulate_conge_parental(
            salaire_mensuel=6000, is_mother=True,
        )
        assert result.perte_revenu > 0
        assert "CHF" in result.premier_eclairage


# ===========================================================================
# NaissanceService — Allocations familiales (8 tests)
# ===========================================================================

class TestAllocationsFamiliales:
    """Tests for NaissanceService.estimate_allocations()."""

    def test_geneve_311_per_child(self, naissance_service):
        """GE should give CHF 311/month per child under 16 (OFAS 2026)."""
        result = naissance_service.estimate_allocations(
            canton="GE", nb_enfants=1, ages_enfants=[5],
        )
        assert result.total_mensuel == 311.0
        assert result.total_annuel == 3732.0

    def test_zurich_215_per_child(self, naissance_service):
        """ZH should give CHF 215/month per child (federal minimum, OFAS 2026)."""
        result = naissance_service.estimate_allocations(
            canton="ZH", nb_enfants=1, ages_enfants=[10],
        )
        assert result.total_mensuel == 215.0

    def test_valais_327_per_child(self, naissance_service):
        """VS should give CHF 327/month per child (OFAS 2026)."""
        result = naissance_service.estimate_allocations(
            canton="VS", nb_enfants=1, ages_enfants=[3],
        )
        assert result.total_mensuel == 327.0

    def test_zug_330_per_child(self, naissance_service):
        """ZG should give CHF 330/month per child (OFAS 2026)."""
        result = naissance_service.estimate_allocations(
            canton="ZG", nb_enfants=1, ages_enfants=[8],
        )
        assert result.total_mensuel == 330.0

    def test_jura_275_per_child(self, naissance_service):
        """JU should give CHF 275/month per child."""
        result = naissance_service.estimate_allocations(
            canton="JU", nb_enfants=1, ages_enfants=[2],
        )
        assert result.total_mensuel == 275.0

    def test_formation_allocation_16_plus(self, naissance_service):
        """Child 16+ should get the cantonal formation allocation (per-canton
        lookup, not enfant + 50 — the old +50 model was factually wrong)."""
        result = naissance_service.estimate_allocations(
            canton="ZH", nb_enfants=1, ages_enfants=[18],
        )
        expected = ALLOCATIONS_FORMATION_PAR_CANTON["ZH"]  # 268, not 215 + 50
        assert result.total_mensuel == expected
        assert result.total_mensuel == 268.0

    def test_multiple_children(self, naissance_service):
        """Multiple children should sum allocations (OFAS 2026: GE enfant 311,
        formation 415)."""
        result = naissance_service.estimate_allocations(
            canton="GE", nb_enfants=3, ages_enfants=[3, 8, 17],
        )
        # 2 children under 16: enfant 311 each; 1 child 17 in formation: 415.
        expected = 311 + 311 + 415
        assert result.total_mensuel == expected
        assert result.total_annuel == round(expected * 12, 2)

    def test_child_over_25_no_allocation(self, naissance_service):
        """Child over 25 should get no allocation."""
        result = naissance_service.estimate_allocations(
            canton="ZH", nb_enfants=1, ages_enfants=[26],
        )
        assert result.total_mensuel == 0.0


# ===========================================================================
# NaissanceService — Impact fiscal enfant (4 tests)
# ===========================================================================

class TestImpactFiscalEnfant:
    """Tests for NaissanceService.calculate_impact_fiscal_enfant()."""

    def test_deduction_per_child_6800(self, naissance_service):
        """Deduction per child should be CHF 6'800 (IFD 2026, art. 35 al. 1 let. a)."""
        result = naissance_service.calculate_impact_fiscal_enfant(
            revenu_imposable=100_000, taux_marginal=0.30, nb_enfants=2,
        )
        assert result.deduction_enfants == DEDUCTION_ENFANT_NAISSANCE * 2
        assert result.deduction_enfants == 13_600

    def test_frais_garde_capped_25800(self, naissance_service):
        """Daycare deduction should be capped at CHF 25'800 (IFD 2026, art. 33 al. 3)."""
        result = naissance_service.calculate_impact_fiscal_enfant(
            revenu_imposable=100_000, taux_marginal=0.30, nb_enfants=1,
            frais_garde=30_000,
        )
        assert result.deduction_frais_garde == DEDUCTION_FRAIS_GARDE_MAX
        assert result.deduction_frais_garde == 25_800

    def test_economie_impot_calculation(self, naissance_service):
        """Tax savings should be total deduction * marginal rate."""
        result = naissance_service.calculate_impact_fiscal_enfant(
            revenu_imposable=100_000, taux_marginal=0.30, nb_enfants=1,
            frais_garde=10_000,
        )
        expected_deduction = DEDUCTION_ENFANT_NAISSANCE + 10_000
        expected_savings = round(expected_deduction * 0.30, 2)
        assert result.deduction_totale == expected_deduction
        assert result.economie_impot_estimee == expected_savings

    def test_no_frais_garde(self, naissance_service):
        """No daycare should give 0 daycare deduction."""
        result = naissance_service.calculate_impact_fiscal_enfant(
            revenu_imposable=100_000, taux_marginal=0.30, nb_enfants=1,
            frais_garde=0,
        )
        assert result.deduction_frais_garde == 0
        assert result.deduction_totale == DEDUCTION_ENFANT_NAISSANCE


# ===========================================================================
# NaissanceService — Career Gap (4 tests)
# ===========================================================================

class TestCareerGap:
    """Tests for NaissanceService.project_career_gap()."""

    def test_lpp_loss_calculation(self, naissance_service):
        """LPP loss should be based on coordinated salary and bonification rate."""
        result = naissance_service.project_career_gap(
            salaire_annuel=80_000, duree_interruption_mois=12, age=35,
        )
        # Coordinated salary = 80000 - 26460 = 53540
        # Rate at age 35 = 10%
        # Annual loss = 54275 * 0.10 = 5427.5
        salaire_coordonne = 80_000 - LPP_DEDUCTION_COORDINATION
        expected_annual = round(salaire_coordonne * 0.10, 2)
        assert result.perte_lpp_annuelle == expected_annual
        assert result.perte_lpp_totale == expected_annual  # 12 months = 1 year

    def test_3a_loss_calculation(self, naissance_service):
        """3a loss should be 7258 per year of interruption."""
        result = naissance_service.project_career_gap(
            salaire_annuel=80_000, duree_interruption_mois=24, age=35,
        )
        assert result.perte_3a_annuelle == PLAFOND_3A
        assert result.perte_3a_totale == round(PLAFOND_3A * 2, 2)

    def test_revenue_loss(self, naissance_service):
        """Revenue loss should be salary * months / 12."""
        result = naissance_service.project_career_gap(
            salaire_annuel=80_000, duree_interruption_mois=6, age=35,
        )
        assert result.perte_revenu_totale == 40_000

    def test_premier_eclairage_present(self, naissance_service):
        """Chiffre choc should mention LPP and 3a."""
        result = naissance_service.project_career_gap(
            salaire_annuel=80_000, duree_interruption_mois=12, age=35,
        )
        assert "LPP" in result.premier_eclairage
        assert "3a" in result.premier_eclairage
        assert "CHF" in result.premier_eclairage


# ===========================================================================
# ConcubinageService — Comparison (5 tests)
# ===========================================================================

class TestConcubinageComparison:
    """Tests for ConcubinageService.compare_mariage_vs_concubinage()."""

    def test_comparison_returns_6_domaines(self, concubinage_service):
        """Comparison should cover 6 domains."""
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        assert len(result.comparaisons) == 6

    def test_protection_scores(self, concubinage_service):
        """Marriage protection score should be higher than concubinage."""
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        assert result.score_protection_mariage > result.score_protection_concubinage

    def test_avs_splitting_advantage_mariage(self, concubinage_service):
        """AVS splitting should favor marriage."""
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        avs_comparison = [c for c in result.comparaisons if "AVS" in c.domaine][0]
        assert avs_comparison.avantage == "mariage"

    def test_succession_advantage_mariage(self, concubinage_service):
        """Succession should favor marriage."""
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        succession_comparison = [c for c in result.comparaisons if "Succession" in c.domaine][0]
        assert succession_comparison.avantage == "mariage"

    def test_sources_contain_key_laws(self, concubinage_service):
        """Sources should reference LIFD, LAVS, LPP, CC."""
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="ZH",
        )
        source_text = " ".join(result.sources)
        assert "LIFD" in source_text
        assert "LAVS" in source_text
        assert "LPP" in source_text
        assert "CC" in source_text


# ===========================================================================
# ConcubinageService — Succession : verite du modele (non-regression)
#
# L'ancienne classe TestInheritanceTax verrouillait `patrimoine x taux` :
# elle attendait un montant (`impot_concubin == 500_000 * 0.18`), une
# `difference` en francs et un « CHF » dans le premier éclairage. Le montant
# ET le taux ayant ete retires, ces attentes sont devenues le contraire du
# contrat. Elles sont remplacees par les trois classes ci-dessous.
# ===========================================================================

# Tout montant rendu par ce service passe par un token "CHF" (aucun autre
# format monetaire n'est produit dans le fichier) : chercher ce token suffit
# a prouver qu'aucun montant d'impot successoral n'est emis.
_MONTANT_RE = re.compile(r"CHF|francs", re.IGNORECASE)

# Le taux plat par canton a ete retire lui aussi : il est dementi sur au
# moins deux cantons, et le bareme reel depend aussi de la commune, du
# montant reçu, du lien et de la duree de vie commune.
_POURCENTAGE_RE = re.compile(r"\d\s*(?:%|pour\s*cent)")

# Les mots francais du perimetre succession, aplatis en ASCII (regle #2).
_ASCII_FR_RE = re.compile(
    r"\b(impot|impots|heritier|heritiers|heritiere|heritieres|maries|etiez"
    r"|exonere|exoneres|exonerent|exoneree|difference|reserve|deces)\b",
    re.IGNORECASE,
)

# Une fin de phrase = ponctuation + espace + majuscule. La contrainte de
# majuscule evite de couper « CC art. 462 » en plein milieu d'une citation.
_PHRASE_RE = re.compile(r"(?<=[.!?;])\s+(?=[«\"A-ZÀ-Ý])")


def _strip_accents(texte: str) -> str:
    import unicodedata
    return "".join(
        c for c in unicodedata.normalize("NFD", texte)
        if unicodedata.category(c) != "Mn"
    )


def _phrases(texte: str) -> list[str]:
    return [p for p in _PHRASE_RE.split(texte) if p.strip()]


def _phrases_exoneration(texte: str) -> list[str]:
    return [p for p in _phrases(texte) if "exoner" in _strip_accents(p).lower()]


def _textes_exposure(result) -> list[str]:
    """Tous les textes rendus par compare_succession_concubin_vs_conjoint()."""
    return [
        result.premier_eclairage,
        result.regle_transmission,
        result.charge_concubin,
        *result.facteurs_determinants,
        *result.sources,
    ]


class TestSuccessionNiMontantNiTaux:
    """La succession du concubinage expose un mecanisme, ni montant ni taux.

    `patrimoine x taux` supposait que 100 % du patrimoine pouvait revenir au
    ou a la partenaire. Depuis la revision du droit successoral en vigueur au
    1.1.2023, un concubin sans testament n'herite de rien et, avec testament,
    la quotite disponible plafonne a 1/2 en presence de descendants
    (CC art. 470-471). Le taux plat par canton est tombe avec le montant.
    """

    def test_methode_estimate_inheritance_tax_supprimee(self, concubinage_service):
        """Un nom qui promet une estimation finit par etre rebranche sur un chiffre."""
        assert not hasattr(concubinage_service, "estimate_inheritance_tax")

    def test_table_de_taux_supprimee(self):
        """Pas de table dormante qu'un futur ecran rebranchera."""
        import app.services.family.concubinage_service as module
        assert not hasattr(module, "TAUX_SUCCESSION_PAR_CANTON")
        assert not hasattr(module, "_DEFAULT_TAUX_SUCCESSION")

    def test_n_expose_aucun_champ_montant_ni_taux(self, concubinage_service):
        """Ni patrimoine, ni impot, ni difference, ni taux dans la sortie."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        for champ_mort in (
            "patrimoine", "impot_conjoint", "impot_concubin", "difference",
            "taux_conjoint", "taux_concubin",
        ):
            assert not hasattr(result, champ_mort), f"{champ_mort} encore expose"

    def test_ne_prend_plus_de_patrimoine(self, concubinage_service):
        """Le patrimoine ne doit plus etre un parametre : il ne decide plus rien."""
        with pytest.raises(TypeError):
            concubinage_service.compare_succession_concubin_vs_conjoint(
                patrimoine=500_000, canton="GE",
            )

    def test_aucun_texte_ne_porte_de_montant_ni_de_pourcentage(self, concubinage_service):
        """C'est ce que le coach peut resservir : aucun chiffre fiscal dedans."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        for texte in _textes_exposure(result):
            assert not _MONTANT_RE.search(texte), texte
            assert not _POURCENTAGE_RE.search(texte), texte

    def test_regle_de_la_quotite_disponible_enoncee(self, concubinage_service):
        """A la place du chiffre : la regle qui decide l'arbitrage."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        regle = result.regle_transmission.lower()
        assert "testament" in regle
        assert "quotité disponible" in regle
        assert "470" in result.regle_transmission  # CC art. 470-471

    def test_charge_du_concubin_dite_sans_la_chiffrer(self, concubinage_service):
        """Le taux « tiers » et l'ampleur de l'ecart cantonal, sans pourcentage."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        charge = _strip_accents(result.charge_concubin).lower()
        assert "tiers" in charge
        assert "communal" in charge

    def test_les_quatre_facteurs_sont_nommes(self, concubinage_service):
        """L'utilisateur doit comprendre ce qu'il faudrait pour obtenir un chiffre."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        facteurs = " ".join(result.facteurs_determinants).lower()
        assert "commune" in facteurs          # canton ET commune
        assert "reçu" in facteurs             # montant effectivement perçu
        assert "lien" in facteurs             # lien avec la personne défunte
        assert "durée de vie commune" in facteurs
        assert len(result.facteurs_determinants) == 4

    def test_exoneration_jamais_imputee_au_code_civil(self, concubinage_service):
        """CC art. 462 regle la part successorale CIVILE, pas une exoneration fiscale."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        assert all("462" not in s for s in result.sources), result.sources

        phrases = [p for texte in _textes_exposure(result) for p in _phrases_exoneration(texte)]
        assert phrases, "aucune phrase ne mentionne l'exoneration"
        for phrase in phrases:
            assert "462" not in phrase, phrase
            assert "cantonal" in _strip_accents(phrase).lower(), phrase

    def test_portee_de_l_exoneration_est_tous_les_cantons(self, concubinage_service):
        """L'exoneration du conjoint vaut dans TOUS les cantons, pas « la plupart »."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        blob = " ".join(_textes_exposure(result)).lower()
        assert "plupart des cantons" not in blob
        assert "tous les cantons" in blob

    def test_textes_succession_accentues(self, concubinage_service):
        """Regle #2 du depot : pas de francais aplati en ASCII."""
        result = concubinage_service.compare_succession_concubin_vs_conjoint(canton="GE")
        for texte in _textes_exposure(result):
            trouve = _ASCII_FR_RE.search(texte)
            assert trouve is None, f"{trouve.group(0)!r} dans : {texte}"


class TestComparaisonSuccessionNiMontantNiTaux:
    """La comparaison mariage/concubinage ne chiffre plus la succession."""

    def test_comparaison_ne_prend_plus_de_patrimoine(self, concubinage_service):
        """Parametre mort une fois le chiffre retire : retire aussi."""
        with pytest.raises(TypeError):
            concubinage_service.compare_mariage_vs_concubinage(
                revenu_1=80_000, revenu_2=60_000, canton="VD", patrimoine=500_000,
            )

    def test_comparaison_n_expose_ni_montant_ni_taux_successoral(self, concubinage_service):
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="VD",
        )
        for champ_mort in (
            "impot_succession_conjoint", "impot_succession_concubin",
            "taux_succession_conjoint", "taux_succession_concubin",
        ):
            assert not hasattr(result, champ_mort), f"{champ_mort} encore expose"

    def test_premier_eclairage_comparaison_ne_porte_aucun_chiffre_fiscal(
        self, concubinage_service,
    ):
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="VD",
        )
        assert not _MONTANT_RE.search(result.premier_eclairage), result.premier_eclairage
        assert not _POURCENTAGE_RE.search(result.premier_eclairage), result.premier_eclairage

    def test_ligne_succession_ne_porte_aucun_chiffre_fiscal(self, concubinage_service):
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="VD",
        )
        ligne = [c for c in result.comparaisons if "Succession" in c.domaine][0]
        for texte in (ligne.mariage, ligne.concubinage):
            assert not _MONTANT_RE.search(texte), texte
            assert not _POURCENTAGE_RE.search(texte), texte

    def test_synthese_ne_chiffre_plus_la_succession(self, concubinage_service):
        """La synthese garde l'ecart d'impot sur le REVENU, jamais un ecart successoral."""
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="VD",
        )
        for phrase in _phrases(result.synthese):
            if "succession" in _strip_accents(phrase).lower():
                assert not _MONTANT_RE.search(phrase), phrase

    def test_ligne_succession_impute_l_exoneration_au_droit_fiscal_cantonal(
        self, concubinage_service,
    ):
        result = concubinage_service.compare_mariage_vs_concubinage(
            revenu_1=80_000, revenu_2=60_000, canton="VD",
        )
        ligne = [c for c in result.comparaisons if "Succession" in c.domaine][0]
        phrases = _phrases_exoneration(ligne.mariage) + _phrases_exoneration(ligne.concubinage)
        assert phrases, "aucune phrase ne mentionne l'exoneration"
        for phrase in phrases:
            assert "462" not in phrase, phrase
            assert "cantonal" in _strip_accents(phrase).lower(), phrase
        assert "plupart des cantons" not in ligne.mariage.lower()


class TestSuccessionEndpointNiMontantNiTaux:
    """Le contrat HTTP suit le service : le mecanisme, aucun chiffre fiscal."""

    def test_endpoint_succession_ne_rend_ni_montant_ni_taux(self, client):
        response = client.post(
            "/api/v1/family/concubinage/succession",
            json={"canton": "ZH"},
        )
        assert response.status_code == 200, response.text
        data = response.json()
        for champ_mort in (
            "patrimoine", "impotConjoint", "impotConcubin", "difference",
            "tauxConjoint", "tauxConcubin",
        ):
            assert champ_mort not in data, f"{champ_mort} encore dans la reponse"
        assert data["canton"] == "ZH"
        assert data["regleTransmission"]
        assert data["chargeConcubin"]
        assert len(data["facteursDeterminants"]) == 4
        assert not _MONTANT_RE.search(data["premierEclairage"])
        assert not _POURCENTAGE_RE.search(data["premierEclairage"])

    def test_endpoint_succession_n_exige_plus_le_patrimoine(self, client):
        """Ne plus reclamer un champ dont on n'a aucun usage defendable."""
        from app.schemas.family import SuccessionRequest
        assert "patrimoine" not in SuccessionRequest.model_fields
        assert "is_married" not in SuccessionRequest.model_fields
        # Un corps sans patrimoine passe : plus de 422 sur ce champ.
        response = client.post(
            "/api/v1/family/concubinage/succession", json={"canton": "VD"},
        )
        assert response.status_code == 200, response.text

    def test_endpoint_compare_ne_rend_aucun_chiffre_successoral(self, client):
        response = client.post(
            "/api/v1/family/concubinage/compare",
            json={"revenu1": 80000, "revenu2": 60000, "canton": "VD", "enfants": 0},
        )
        assert response.status_code == 200, response.text
        data = response.json()
        for champ_mort in (
            "impotSuccessionConjoint", "impotSuccessionConcubin",
            "tauxSuccessionConjoint", "tauxSuccessionConcubin",
        ):
            assert champ_mort not in data, f"{champ_mort} encore dans la reponse"
        assert not _MONTANT_RE.search(data["premierEclairage"])
        assert not _POURCENTAGE_RE.search(data["premierEclairage"])


# ===========================================================================
# ConcubinageService — Checklist (4 tests)
# ===========================================================================

class TestChecklistConcubinage:
    """Tests for ConcubinageService.checklist_concubinage()."""

    def test_checklist_has_items(self, concubinage_service):
        """Checklist should have at least 10 items."""
        result = concubinage_service.checklist_concubinage()
        assert len(result.items) >= 10

    def test_checklist_priorite_haute(self, concubinage_service):
        """High priority should include testament."""
        result = concubinage_service.checklist_concubinage()
        assert len(result.priorite_haute) >= 3
        combined = " ".join(result.priorite_haute)
        assert "testament" in combined.lower()

    def test_checklist_priorite_moyenne(self, concubinage_service):
        """Medium priority should include contrat de concubinage."""
        result = concubinage_service.checklist_concubinage()
        assert len(result.priorite_moyenne) >= 2
        combined = " ".join(result.priorite_moyenne)
        assert "concubinage" in combined.lower()

    def test_checklist_sources(self, concubinage_service):
        """Checklist sources should reference CC and LPP."""
        result = concubinage_service.checklist_concubinage()
        source_text = " ".join(result.sources)
        assert "CC" in source_text
        assert "LPP" in source_text


# ===========================================================================
# MariageService — Checklist Mariage (8 tests)
# ===========================================================================

class TestChecklistMariage:
    """Tests for MariageService.checklist_mariage()."""

    def test_checklist_has_items(self, mariage_service):
        """Checklist should have at least 10 items."""
        result = mariage_service.checklist_mariage()
        assert len(result.items) >= 10

    def test_checklist_priorite_haute_contains_etat_civil(self, mariage_service):
        """High priority should mention etat civil."""
        result = mariage_service.checklist_mariage()
        combined = " ".join(result.priorite_haute).lower()
        assert "etat civil" in combined

    def test_checklist_priorite_haute_contains_regime(self, mariage_service):
        """High priority should mention regime matrimonial."""
        result = mariage_service.checklist_mariage()
        combined = " ".join(result.priorite_haute).lower()
        assert "regime matrimonial" in combined or "participation aux acquets" in combined

    def test_checklist_priorite_haute_contains_declaration_fiscale(self, mariage_service):
        """High priority should mention fiscal declaration."""
        result = mariage_service.checklist_mariage()
        combined = " ".join(result.priorite_haute).lower()
        assert "declaration fiscale" in combined or "fiscale commune" in combined

    def test_checklist_with_3a_adds_item(self, mariage_service):
        """Having 3a should add a 3a-specific item to medium priority."""
        result_with = mariage_service.checklist_mariage(has_3a=True)
        result_without = mariage_service.checklist_mariage(has_3a=False)
        assert len(result_with.items) > len(result_without.items)
        combined = " ".join(result_with.priorite_moyenne).lower()
        assert "3a" in combined

    def test_checklist_with_property_adds_item(self, mariage_service):
        """Having property should add a property-specific item."""
        result_with = mariage_service.checklist_mariage(has_property=True)
        result_without = mariage_service.checklist_mariage(has_property=False)
        assert len(result_with.items) > len(result_without.items)
        combined = " ".join(result_with.priorite_moyenne).lower()
        assert "hypothecaire" in combined or "copropriete" in combined

    def test_checklist_with_lpp_adds_item(self, mariage_service):
        """Having LPP should add a LPP-specific item."""
        result_with = mariage_service.checklist_mariage(has_lpp=True)
        result_without = mariage_service.checklist_mariage(has_lpp=False)
        assert len(result_with.items) > len(result_without.items)
        combined = " ".join(result_with.priorite_moyenne).lower()
        assert "lpp" in combined or "caisse de pension" in combined

    def test_checklist_sources_contain_cc_lifd_lpp(self, mariage_service):
        """Sources should reference CC, LIFD, and LPP."""
        result = mariage_service.checklist_mariage()
        source_text = " ".join(result.sources)
        assert "CC" in source_text
        assert "LIFD" in source_text
        assert "LPP" in source_text

    def test_checklist_has_premier_eclairage(self, mariage_service):
        """Checklist should include a premier éclairage."""
        result = mariage_service.checklist_mariage()
        assert len(result.premier_eclairage) > 0
        assert "demarches" in result.premier_eclairage.lower() or "regime" in result.premier_eclairage.lower()

    def test_checklist_has_disclaimer(self, mariage_service):
        """Checklist should include a disclaimer."""
        result = mariage_service.checklist_mariage()
        assert len(result.disclaimer) > 0
        assert "specialiste" in result.disclaimer.lower()

    def test_checklist_canton_personalisation(self, mariage_service):
        """Canton should appear in the checklist items."""
        result = mariage_service.checklist_mariage(canton="GE")
        combined = " ".join(result.items)
        assert "GE" in combined

    def test_checklist_no_banned_words(self, mariage_service):
        """Checklist should not contain banned words."""
        result = mariage_service.checklist_mariage(
            has_3a=True, has_lpp=True, has_property=True, canton="VD",
        )
        banned = ["garanti", "certain", "assure", "sans risque", "optimal",
                  "meilleur", "parfait", "conseiller"]
        all_text = " ".join(result.items + [result.premier_eclairage, result.disclaimer])
        for word in banned:
            assert word not in all_text.lower(), f"Banned word '{word}' found in checklist"


# ===========================================================================
# NaissanceService — Checklist Naissance (8 tests)
# ===========================================================================

class TestChecklistNaissance:
    """Tests for NaissanceService.checklist_naissance()."""

    def test_checklist_has_items(self, naissance_service):
        """Checklist should have at least 10 items."""
        result = naissance_service.checklist_naissance()
        assert len(result.items) >= 10

    def test_checklist_priorite_haute_etat_civil(self, naissance_service):
        """High priority should mention 3 jours etat civil."""
        result = naissance_service.checklist_naissance()
        combined = " ".join(result.priorite_haute).lower()
        assert "3 jours" in combined
        assert "etat civil" in combined

    def test_checklist_priorite_haute_allocations(self, naissance_service):
        """High priority should mention allocations familiales."""
        result = naissance_service.checklist_naissance()
        combined = " ".join(result.priorite_haute).lower()
        assert "allocations familiales" in combined or "lafam" in combined

    def test_checklist_priorite_haute_conge_maternite(self, naissance_service):
        """High priority should mention conge maternite (14 semaines)."""
        result = naissance_service.checklist_naissance()
        combined = " ".join(result.priorite_haute).lower()
        assert "maternite" in combined
        assert "14 semaines" in combined

    def test_checklist_priorite_haute_conge_paternite(self, naissance_service):
        """High priority should mention conge paternite (2 semaines)."""
        result = naissance_service.checklist_naissance()
        combined = " ".join(result.priorite_haute).lower()
        assert "paternite" in combined
        assert "2 semaines" in combined

    def test_checklist_priorite_haute_lamal_3_mois(self, naissance_service):
        """High priority should mention LAMal 3-month deadline for baby."""
        result = naissance_service.checklist_naissance()
        combined = " ".join(result.priorite_haute).lower()
        assert "3 mois" in combined
        assert "lamal" in combined or "assurance maladie" in combined

    def test_checklist_concubin_adds_reconnaissance_paternite(self, naissance_service):
        """Concubins should get extra items for paternity recognition."""
        result_concubin = naissance_service.checklist_naissance(civil_status="concubin")
        result_marie = naissance_service.checklist_naissance(civil_status="marie")
        assert len(result_concubin.items) > len(result_marie.items)
        combined = " ".join(result_concubin.priorite_moyenne).lower()
        assert "reconnaissance de paternite" in combined

    def test_checklist_celibataire_adds_reconnaissance_paternite(self, naissance_service):
        """Celibataires should get extra items for paternity recognition."""
        result_celibataire = naissance_service.checklist_naissance(civil_status="celibataire")
        combined = " ".join(result_celibataire.priorite_moyenne).lower()
        assert "reconnaissance de paternite" in combined

    def test_checklist_with_3a_adds_beneficiary_item(self, naissance_service):
        """Having 3a should add a 3a beneficiary item in medium priority."""
        result_with = naissance_service.checklist_naissance(has_3a=True)
        combined = " ".join(result_with.priorite_moyenne).lower()
        assert "3a" in combined
        assert "beneficiaires" in combined

    def test_checklist_with_lpp_adds_item(self, naissance_service):
        """Having LPP should add a LPP-specific item."""
        result_with = naissance_service.checklist_naissance(has_lpp=True)
        result_without = naissance_service.checklist_naissance(has_lpp=False)
        assert len(result_with.items) > len(result_without.items)

    def test_checklist_sources_contain_key_laws(self, naissance_service):
        """Sources should reference CC, LAPG, LAFam, LAMal."""
        result = naissance_service.checklist_naissance()
        source_text = " ".join(result.sources)
        assert "CC" in source_text
        assert "LAPG" in source_text
        assert "LAFam" in source_text
        assert "LAMal" in source_text

    def test_checklist_has_premier_eclairage(self, naissance_service):
        """Checklist should include a premier éclairage."""
        result = naissance_service.checklist_naissance()
        assert len(result.premier_eclairage) > 0
        assert "CHF" in result.premier_eclairage

    def test_checklist_has_disclaimer(self, naissance_service):
        """Checklist should include a disclaimer."""
        result = naissance_service.checklist_naissance()
        assert len(result.disclaimer) > 0
        assert "specialiste" in result.disclaimer.lower()

    def test_checklist_canton_allocation_in_premier_eclairage(self, naissance_service):
        """Chiffre choc should mention the canton allocation amount."""
        result = naissance_service.checklist_naissance(canton="GE")
        assert "GE" in result.premier_eclairage
        # GE allocation = 311 * 12 = 3732 (OFAS 2026)
        assert "3,732" in result.premier_eclairage or "3'732" in result.premier_eclairage or "3732" in result.premier_eclairage

    def test_checklist_unknown_canton_uses_federal_minimum(self, naissance_service):
        """Anti-régression : un canton inconnu retombe sur le minimum fédéral
        LAFam 215/mois (2'580/an), pas l'ancien 200 (2'400/an)."""
        result = naissance_service.checklist_naissance(canton="XX")
        # 215 * 12 = 2580 ; l'ancien fallback 200 aurait donné 2400.
        assert "2,580" in result.premier_eclairage or "2'580" in result.premier_eclairage or "2580" in result.premier_eclairage
        assert "2400" not in result.premier_eclairage and "2'400" not in result.premier_eclairage

    def test_checklist_no_banned_words(self, naissance_service):
        """Checklist should not contain banned words."""
        result = naissance_service.checklist_naissance(
            civil_status="concubin", canton="VD", has_3a=True, has_lpp=True,
        )
        banned = ["garanti", "certain", "assure", "sans risque", "optimal",
                  "meilleur", "parfait", "conseiller"]
        all_text = " ".join(result.items + [result.premier_eclairage, result.disclaimer])
        for word in banned:
            assert word not in all_text.lower(), f"Banned word '{word}' found in checklist"

    def test_checklist_marie_with_3a_mentions_double_deduction(self, naissance_service):
        """Married with 3a should mention double 3a deductions."""
        result = naissance_service.checklist_naissance(
            civil_status="marie", has_3a=True,
        )
        combined = " ".join(result.items).lower()
        assert "double" in combined or "deux conjoints" in combined or "chacun" in combined


# ===========================================================================
# DISCLAIMER checks (3 tests)
# ===========================================================================

class TestDisclaimers:
    """Verify disclaimers follow compliance rules."""

    def test_mariage_disclaimer_no_banned_words(self):
        """Mariage disclaimer should not contain banned words."""
        banned = ["garanti", "certain", "assure", "sans risque", "conseiller"]
        for word in banned:
            assert word not in MARIAGE_DISCLAIMER.lower()

    def test_naissance_disclaimer_no_banned_words(self):
        """Naissance disclaimer should not contain banned words."""
        banned = ["garanti", "certain", "assure", "sans risque", "conseiller"]
        for word in banned:
            assert word not in NAISSANCE_DISCLAIMER.lower()

    def test_concubinage_disclaimer_no_banned_words(self):
        """Concubinage disclaimer should not contain banned words."""
        banned = ["garanti", "certain", "assure", "sans risque", "conseiller"]
        for word in banned:
            assert word not in CONCUBINAGE_DISCLAIMER.lower()


# ===========================================================================
# Edge Cases (2 tests)
# ===========================================================================

class TestEdgeCases:
    """Edge case tests."""

    def test_many_children_allocations(self, naissance_service):
        """5 children should correctly sum allocations."""
        result = naissance_service.estimate_allocations(
            canton="GE", nb_enfants=5,
            ages_enfants=[1, 3, 7, 12, 17],
        )
        # 4 children under 16: GE enfant 311 each; 1 child 17 (formation): 415.
        expected = 311 * 4 + 415
        assert result.total_mensuel == expected

    def test_career_gap_zero_salary_below_seuil(self, naissance_service):
        """Salary below LPP threshold should give 0 coordinated salary."""
        result = naissance_service.project_career_gap(
            salaire_annuel=20_000,  # below LPP_SEUIL_ENTREE threshold
            duree_interruption_mois=12,
            age=30,
        )
        # Coordinated salary = max(0, 20000 - 26460) = 0
        assert result.perte_lpp_annuelle == 0.0
        assert result.perte_lpp_totale == 0.0


# ===========================================================================
# API Endpoint Tests (integration) — 12 tests
# ===========================================================================

class TestFamilyEndpoints:
    """Integration tests for family FastAPI endpoints."""

    def test_mariage_compare_endpoint(self, client):
        """POST /family/mariage/compare should return 200."""
        response = client.post(
            "/api/v1/family/mariage/compare",
            json={
                "revenu1": 100000,
                "revenu2": 80000,
                "canton": "ZH",
                "enfants": 0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "impotCelibatairesTotal" in data
        assert "impotMariesTotal" in data
        assert "difference" in data
        assert "estPenaliteMariage" in data
        assert "premierEclairage" in data
        assert "disclaimer" in data

    def test_mariage_regime_endpoint(self, client):
        """POST /family/mariage/regime should return 200."""
        response = client.post(
            "/api/v1/family/mariage/regime",
            json={
                "patrimoine1": 300000,
                "patrimoine2": 100000,
                "regime": "participation_acquets",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "regime" in data
        assert "partConjoint1" in data
        assert "partConjoint2" in data
        assert "disclaimer" in data

    def test_mariage_survivant_endpoint(self, client):
        """POST /family/mariage/survivant should return 200."""
        response = client.post(
            "/api/v1/family/mariage/survivant",
            json={
                "renteLpp": 2000,
                "renteAvs": 2520,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "renteSurvivantAvsMensuelle" in data
        assert "renteSurvivantLppMensuelle" in data
        assert "totalSurvivantMensuel" in data
        assert "disclaimer" in data

    def test_naissance_conge_maternite_endpoint(self, client):
        """POST /family/naissance/conge for maternity should return 200."""
        response = client.post(
            "/api/v1/family/naissance/conge",
            json={
                "salaireMensuel": 6000,
                "isMother": True,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["typeConge"] == "maternite"
        assert data["dureeSemaines"] == 14
        assert "apgJournalier" in data
        assert "disclaimer" in data

    def test_naissance_conge_paternite_endpoint(self, client):
        """POST /family/naissance/conge for paternity should return 200."""
        response = client.post(
            "/api/v1/family/naissance/conge",
            json={
                "salaireMensuel": 6000,
                "isMother": False,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["typeConge"] == "paternite"
        assert data["dureeSemaines"] == 2

    def test_naissance_allocations_endpoint(self, client):
        """POST /family/naissance/allocations should return 200."""
        response = client.post(
            "/api/v1/family/naissance/allocations",
            json={
                "canton": "GE",
                "nbEnfants": 2,
                "agesEnfants": [5, 17],
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "totalMensuel" in data
        assert "totalAnnuel" in data
        assert "detail" in data
        assert "disclaimer" in data

    def test_naissance_impact_fiscal_endpoint(self, client):
        """POST /family/naissance/impact-fiscal should return 200."""
        response = client.post(
            "/api/v1/family/naissance/impact-fiscal",
            json={
                "revenuImposable": 100000,
                "tauxMarginal": 0.30,
                "nbEnfants": 2,
                "fraisGarde": 15000,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "deductionEnfants" in data
        assert "deductionFraisGarde" in data
        assert "economieImpotEstimee" in data
        assert "disclaimer" in data

    def test_naissance_career_gap_endpoint(self, client):
        """POST /family/naissance/career-gap should return 200."""
        response = client.post(
            "/api/v1/family/naissance/career-gap",
            json={
                "salaireAnnuel": 80000,
                "dureeInterruptionMois": 12,
                "age": 35,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "perteLppTotale" in data
        assert "perte3ATotale" in data
        assert "perteRevenuTotale" in data
        assert "disclaimer" in data

    def test_concubinage_compare_endpoint(self, client):
        """POST /family/concubinage/compare should return 200."""
        response = client.post(
            "/api/v1/family/concubinage/compare",
            json={
                "revenu1": 80000,
                "revenu2": 60000,
                "canton": "ZH",
                "enfants": 0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "comparaisons" in data
        assert len(data["comparaisons"]) == 6
        assert "scoreProtectionMariage" in data
        assert "scoreProtectionConcubinage" in data
        assert "disclaimer" in data

    def test_concubinage_succession_endpoint(self, client):
        """POST /family/concubinage/succession should return 200."""
        response = client.post(
            "/api/v1/family/concubinage/succession",
            json={"canton": "ZH"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "regleTransmission" in data
        assert "chargeConcubin" in data
        assert "facteursDeterminants" in data
        assert "disclaimer" in data

    def test_concubinage_checklist_endpoint(self, client):
        """GET /family/concubinage/checklist should return 200."""
        response = client.get("/api/v1/family/concubinage/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) >= 10
        assert "prioriteHaute" in data
        assert "prioriteMoyenne" in data
        assert "prioriteBasse" in data
        assert "disclaimer" in data

    def test_mariage_checklist_endpoint(self, client):
        """POST /family/mariage/checklist should return 200."""
        response = client.post(
            "/api/v1/family/mariage/checklist",
            json={
                "has3A": True,
                "hasLpp": True,
                "hasProperty": False,
                "canton": "ZH",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) >= 10
        assert "prioriteHaute" in data
        assert "prioriteMoyenne" in data
        assert "prioriteBasse" in data
        assert "premierEclairage" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_naissance_checklist_endpoint(self, client):
        """POST /family/naissance/checklist should return 200."""
        response = client.post(
            "/api/v1/family/naissance/checklist",
            json={
                "civilStatus": "concubin",
                "canton": "GE",
                "has3A": True,
                "hasLpp": True,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) >= 10
        assert "prioriteHaute" in data
        assert "prioriteMoyenne" in data
        assert "prioriteBasse" in data
        assert "premierEclairage" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_mariage_compare_camelcase_aliases(self, client):
        """API should accept camelCase and return camelCase."""
        response = client.post(
            "/api/v1/family/mariage/compare",
            json={
                "revenu1": 90000,
                "revenu2": 70000,
                "canton": "GE",
                "enfants": 1,
            },
        )
        assert response.status_code == 200
        data = response.json()
        # Response should use camelCase
        assert "impotCelibatairesTotal" in data
        assert "impotMariesTotal" in data
        assert "estPenaliteMariage" in data
        assert "revenusCumules" in data
        assert "deductionsMariage" in data
        assert "premierEclairage" in data
