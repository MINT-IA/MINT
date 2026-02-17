"""
Tests for the Expat module (Sprint S23).

Covers:
    - FrontalierService: source tax, quasi-resident, 90-day rule,
      social charges, LAMal option — 30 tests
    - ExpatService: forfait fiscal, double taxation, AVS gap,
      departure plan, tax comparison — 25 tests
    - Compliance: disclaimer checks, banned words — 5 tests
    - API endpoints (integration) — 12 tests

Target: 72 tests.

Run: cd services/backend && python3 -m pytest tests/test_expat.py -v
"""

import pytest

from app.services.expat.frontalier_service import (
    FrontalierService,
    DISCLAIMER as FRONTALIER_DISCLAIMER,
    AVS_AI_APG_TAUX_EMPLOYE,
    AC_TAUX_EMPLOYE,
    AC_PLAFOND,
    AC_SOLIDARITE_TAUX,
    LAMAL_PRIMES_MENSUELLES,
)
from app.services.expat.expat_service import (
    ExpatService,
    DISCLAIMER as EXPAT_DISCLAIMER,
    CANTONS_SANS_FORFAIT,
    FORFAIT_FISCAL_BASE_CANTONALE,
    FORFAIT_FEDERAL_MINIMUM,
    CDI_PARTENAIRES,
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    AVS_COTISATION_MIN_VOLONTAIRE,
    AVS_COTISATION_MAX_VOLONTAIRE,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def frontalier_service():
    return FrontalierService()


@pytest.fixture
def expat_service():
    return ExpatService()


# ===========================================================================
# FrontalierService — Source Tax (10 tests)
# ===========================================================================

class TestSourceTax:
    """Tests for FrontalierService.calculate_source_tax()."""

    def test_standard_canton_vd(self, frontalier_service):
        """VD should calculate progressive source tax with cantonal multiplier."""
        result = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD",
        )
        assert result.salaire_brut == 100_000
        assert result.canton == "VD"
        assert result.impot_source > 0
        assert result.taux_effectif > 0
        assert result.regime_special is None

    def test_geneve_quasi_resident_regime(self, frontalier_service):
        """GE should flag quasi-resident special regime."""
        result = frontalier_service.calculate_source_tax(
            salary=100_000, canton="GE",
        )
        assert result.regime_special == "quasi_resident"
        assert result.impot_source == 0.0
        assert "quasi-resident" in result.recommandation.lower()

    def test_tessin_italy_regime(self, frontalier_service):
        """TI should flag Italy special regime."""
        result = frontalier_service.calculate_source_tax(
            salary=100_000, canton="TI",
        )
        assert result.regime_special == "italie"
        assert result.impot_source > 0  # ~4% approximation
        assert "Italie" in result.recommandation or "italien" in result.recommandation

    def test_zero_salary(self, frontalier_service):
        """Zero salary should give zero tax."""
        result = frontalier_service.calculate_source_tax(
            salary=0, canton="VD",
        )
        assert result.impot_source == 0.0
        assert result.taux_effectif == 0.0

    def test_high_salary(self, frontalier_service):
        """High salary should have progressive taxation."""
        result_low = frontalier_service.calculate_source_tax(
            salary=50_000, canton="ZH",
        )
        result_high = frontalier_service.calculate_source_tax(
            salary=200_000, canton="ZH",
        )
        assert result_high.taux_effectif > result_low.taux_effectif

    def test_married_has_deductions(self, frontalier_service):
        """Married status should reduce tax."""
        result_single = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD", marital_status="celibataire",
        )
        result_married = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD", marital_status="marie",
        )
        assert result_married.impot_source < result_single.impot_source

    def test_children_reduce_tax(self, frontalier_service):
        """Children should reduce source tax through deductions."""
        result_no_kids = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD", children=0,
        )
        result_kids = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD", children=3,
        )
        assert result_kids.impot_source < result_no_kids.impot_source

    def test_church_tax_increases_tax(self, frontalier_service):
        """Church tax should increase the source tax."""
        result_no_church = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD", church_tax=False,
        )
        result_church = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD", church_tax=True,
        )
        assert result_church.impot_source > result_no_church.impot_source

    def test_sources_contain_lifd(self, frontalier_service):
        """Sources should reference LIFD."""
        result = frontalier_service.calculate_source_tax(
            salary=100_000, canton="VD",
        )
        source_text = " ".join(result.sources)
        assert "LIFD" in source_text
        assert "art." in source_text

    def test_canton_case_insensitive(self, frontalier_service):
        """Canton should be normalized to uppercase."""
        result = frontalier_service.calculate_source_tax(
            salary=100_000, canton="vd",
        )
        assert result.canton == "VD"


# ===========================================================================
# FrontalierService — Quasi-Resident (8 tests)
# ===========================================================================

class TestQuasiResident:
    """Tests for FrontalierService.check_quasi_resident()."""

    def test_eligible_above_90_percent(self, frontalier_service):
        """Income ratio >= 90% should be eligible."""
        result = frontalier_service.check_quasi_resident(
            ch_income=95_000, worldwide_income=100_000,
        )
        assert result.eligible is True
        assert result.ratio_ch >= 90.0

    def test_not_eligible_below_90_percent(self, frontalier_service):
        """Income ratio < 90% should not be eligible."""
        result = frontalier_service.check_quasi_resident(
            ch_income=80_000, worldwide_income=100_000,
        )
        assert result.eligible is False
        assert result.ratio_ch < 90.0

    def test_exactly_90_percent(self, frontalier_service):
        """Exactly 90% should be eligible (>= threshold)."""
        result = frontalier_service.check_quasi_resident(
            ch_income=90_000, worldwide_income=100_000,
        )
        assert result.eligible is True
        assert result.ratio_ch == 90.0

    def test_boundary_89_percent(self, frontalier_service):
        """89% should not be eligible."""
        result = frontalier_service.check_quasi_resident(
            ch_income=89_000, worldwide_income=100_000,
        )
        assert result.eligible is False

    def test_boundary_91_percent(self, frontalier_service):
        """91% should be eligible."""
        result = frontalier_service.check_quasi_resident(
            ch_income=91_000, worldwide_income=100_000,
        )
        assert result.eligible is True

    def test_zero_worldwide_income(self, frontalier_service):
        """Zero worldwide income should not crash and not be eligible."""
        result = frontalier_service.check_quasi_resident(
            ch_income=0, worldwide_income=0,
        )
        assert result.eligible is False
        assert result.ratio_ch == 0.0

    def test_economie_potentielle_when_eligible(self, frontalier_service):
        """Eligible quasi-resident should show potential savings."""
        result = frontalier_service.check_quasi_resident(
            ch_income=95_000, worldwide_income=100_000,
        )
        assert result.economie_potentielle > 0

    def test_sources_reference_quasi_resident(self, frontalier_service):
        """Sources should reference quasi-resident legal basis."""
        result = frontalier_service.check_quasi_resident(
            ch_income=95_000, worldwide_income=100_000,
        )
        source_text = " ".join(result.sources)
        assert "quasi-resident" in source_text.lower() or "LIPP" in source_text


# ===========================================================================
# FrontalierService — 90-Day Rule (7 tests)
# ===========================================================================

class TestNinetyDayRule:
    """Tests for FrontalierService.simulate_90_day_rule()."""

    def test_below_60_days_low_risk(self, frontalier_service):
        """Under 60 days should be low risk."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=30, commute_days=200,
        )
        assert result.risque == "faible"
        assert result.depasse_seuil is False
        assert result.pays_imposition == "Suisse"

    def test_between_60_and_90_medium_risk(self, frontalier_service):
        """Between 61 and 90 days should be medium risk."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=80, commute_days=150,
        )
        assert result.risque == "moyen"
        assert result.depasse_seuil is False

    def test_above_90_days_high_risk(self, frontalier_service):
        """Over 90 days should be high risk."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=120, commute_days=100,
        )
        assert result.risque == "eleve"
        assert result.depasse_seuil is True

    def test_exactly_90_days_not_exceeded(self, frontalier_service):
        """Exactly 90 days should NOT exceed threshold (> not >=)."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=90, commute_days=150,
        )
        assert result.depasse_seuil is False
        assert result.risque == "moyen"

    def test_91_days_exceeded(self, frontalier_service):
        """91 days should exceed threshold."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=91, commute_days=150,
        )
        assert result.depasse_seuil is True
        assert result.risque == "eleve"

    def test_89_days_not_exceeded(self, frontalier_service):
        """89 days should not exceed threshold."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=89, commute_days=150,
        )
        assert result.depasse_seuil is False

    def test_mixte_when_commute_exceeds_home_office(self, frontalier_service):
        """When commute > home office but > 90 days, should be 'mixte'."""
        result = frontalier_service.simulate_90_day_rule(
            home_office_days=100, commute_days=120,
        )
        assert result.depasse_seuil is True
        assert result.pays_imposition == "mixte"


# ===========================================================================
# FrontalierService — Social Charges (5 tests)
# ===========================================================================

class TestSocialCharges:
    """Tests for FrontalierService.compare_social_charges()."""

    def test_avs_calculation(self, frontalier_service):
        """AVS employee contribution should be 5.3% of salary."""
        result = frontalier_service.compare_social_charges(
            salary=100_000, country_of_residence="FR",
        )
        expected_avs = round(100_000 * AVS_AI_APG_TAUX_EMPLOYE, 2)
        assert result.avs_ai_apg_employe == expected_avs

    def test_ac_capped_at_148200(self, frontalier_service):
        """AC should be capped at CHF 148'200."""
        result = frontalier_service.compare_social_charges(
            salary=200_000, country_of_residence="FR",
        )
        expected_ac = round(AC_PLAFOND * AC_TAUX_EMPLOYE, 2)
        assert result.ac_employe == expected_ac

    def test_ac_solidarite_above_cap(self, frontalier_service):
        """Salary above 148'200 should have AC solidarite."""
        result = frontalier_service.compare_social_charges(
            salary=200_000, country_of_residence="FR",
        )
        expected_solidarite = round((200_000 - AC_PLAFOND) * AC_SOLIDARITE_TAUX, 2)
        assert result.ac_solidarite == expected_solidarite
        assert result.ac_solidarite > 0

    def test_no_ac_solidarite_below_cap(self, frontalier_service):
        """Salary below 148'200 should have zero AC solidarite."""
        result = frontalier_service.compare_social_charges(
            salary=100_000, country_of_residence="FR",
        )
        assert result.ac_solidarite == 0.0

    def test_comparison_all_countries(self, frontalier_service):
        """All residence countries should return valid results."""
        for country in ["FR", "DE", "IT", "AT"]:
            result = frontalier_service.compare_social_charges(
                salary=100_000, country_of_residence=country,
            )
            assert result.total_ch_employe > 0
            assert result.total_residence_employe > 0
            assert result.pays_residence == country


# ===========================================================================
# FrontalierService — LAMal Option (5 tests)
# ===========================================================================

class TestLamalOption:
    """Tests for FrontalierService.estimate_lamal_option()."""

    def test_geneve_lamal_prime(self, frontalier_service):
        """GE LAMal prime should match the constant."""
        result = frontalier_service.estimate_lamal_option(
            age=35, canton="GE", family_size=1, residence_country="FR",
        )
        assert result.prime_lamal_mensuelle == LAMAL_PRIMES_MENSUELLES["GE"]
        assert result.prime_lamal_annuelle == round(LAMAL_PRIMES_MENSUELLES["GE"] * 12, 2)

    def test_young_adult_discount(self, frontalier_service):
        """Under 26 should get 25% reduction on LAMal."""
        result_young = frontalier_service.estimate_lamal_option(
            age=22, canton="GE", family_size=1, residence_country="FR",
        )
        result_adult = frontalier_service.estimate_lamal_option(
            age=35, canton="GE", family_size=1, residence_country="FR",
        )
        assert result_young.prime_lamal_mensuelle < result_adult.prime_lamal_mensuelle

    def test_family_size_multiplier(self, frontalier_service):
        """Family size > 1 should multiply the premium."""
        result_single = frontalier_service.estimate_lamal_option(
            age=35, canton="ZH", family_size=1, residence_country="FR",
        )
        result_family = frontalier_service.estimate_lamal_option(
            age=35, canton="ZH", family_size=3, residence_country="FR",
        )
        assert result_family.prime_lamal_annuelle == result_single.prime_lamal_annuelle * 3

    def test_all_residence_countries(self, frontalier_service):
        """All residence countries should return valid results."""
        for country in ["FR", "DE", "IT", "AT"]:
            result = frontalier_service.estimate_lamal_option(
                age=35, canton="GE", family_size=1, residence_country=country,
            )
            assert result.pays_residence == country
            assert result.prime_residence_mensuelle >= 0

    def test_sources_reference_lamal(self, frontalier_service):
        """Sources should reference LAMal."""
        result = frontalier_service.estimate_lamal_option(
            age=35, canton="GE", family_size=1, residence_country="FR",
        )
        source_text = " ".join(result.sources)
        assert "LAMal" in source_text


# ===========================================================================
# ExpatService — Forfait Fiscal (7 tests)
# ===========================================================================

class TestForfaitFiscal:
    """Tests for ExpatService.simulate_forfait_fiscal()."""

    def test_eligible_canton_vd(self, expat_service):
        """VD should be eligible with base 1'000'000."""
        result = expat_service.simulate_forfait_fiscal(
            canton="VD", living_expenses=500_000, actual_income=5_000_000,
        )
        assert result.eligible is True
        assert result.base_forfaitaire >= 1_000_000
        assert result.canton == "VD"

    def test_not_eligible_zh(self, expat_service):
        """ZH should not be eligible (abolished)."""
        result = expat_service.simulate_forfait_fiscal(
            canton="ZH", living_expenses=500_000, actual_income=5_000_000,
        )
        assert result.eligible is False

    def test_not_eligible_all_abolished_cantons(self, expat_service):
        """All abolished cantons should not be eligible."""
        for canton in CANTONS_SANS_FORFAIT:
            result = expat_service.simulate_forfait_fiscal(
                canton=canton, living_expenses=500_000, actual_income=5_000_000,
            )
            assert result.eligible is False, f"{canton} should not be eligible"

    def test_base_minimum_federal(self, expat_service):
        """Base should be at least CHF 400'000 (federal minimum)."""
        result = expat_service.simulate_forfait_fiscal(
            canton="SG", living_expenses=100_000, actual_income=2_000_000,
        )
        assert result.base_forfaitaire >= FORFAIT_FEDERAL_MINIMUM

    def test_base_uses_cantonal_minimum(self, expat_service):
        """VD should use cantonal minimum of 1'000'000."""
        result = expat_service.simulate_forfait_fiscal(
            canton="VD", living_expenses=100_000, actual_income=2_000_000,
        )
        assert result.base_forfaitaire >= FORFAIT_FISCAL_BASE_CANTONALE["VD"]

    def test_economie_high_income(self, expat_service):
        """Very high income should produce significant savings with forfait."""
        result = expat_service.simulate_forfait_fiscal(
            canton="VS", living_expenses=300_000, actual_income=10_000_000,
        )
        assert result.eligible is True
        assert result.economie > 0  # forfait should be cheaper for very high income

    def test_sources_reference_lifd_14(self, expat_service):
        """Sources should reference LIFD art. 14."""
        result = expat_service.simulate_forfait_fiscal(
            canton="VD", living_expenses=500_000, actual_income=3_000_000,
        )
        source_text = " ".join(result.sources)
        assert "LIFD" in source_text
        assert "art. 14" in source_text


# ===========================================================================
# ExpatService — Double Taxation (5 tests)
# ===========================================================================

class TestDoubleTaxation:
    """Tests for ExpatService.check_double_taxation()."""

    def test_france_convention_exists(self, expat_service):
        """France should have a CDI."""
        result = expat_service.check_double_taxation(
            residence_country="FR",
        )
        assert result.convention_existe is True
        assert result.pays_residence == "FR"
        assert len(result.repartition) > 0

    def test_all_partner_countries(self, expat_service):
        """All partner countries should have CDI."""
        for country in CDI_PARTENAIRES:
            result = expat_service.check_double_taxation(
                residence_country=country,
            )
            assert result.convention_existe is True
            assert result.date_convention != "N/A"

    def test_unknown_country_no_cdi(self, expat_service):
        """Unknown country should flag no CDI."""
        result = expat_service.check_double_taxation(
            residence_country="XX",
        )
        assert result.convention_existe is False
        assert result.date_convention == "N/A"

    def test_specific_income_types(self, expat_service):
        """Specific income types should only show requested types."""
        result = expat_service.check_double_taxation(
            residence_country="FR",
            income_types=["salaire", "dividendes"],
        )
        assert "salaire" in result.repartition
        assert "dividendes" in result.repartition
        assert "pension_avs" not in result.repartition

    def test_exit_tax_mentioned_in_optimisation(self, expat_service):
        """Optimisations should mention no exit tax."""
        result = expat_service.check_double_taxation(
            residence_country="FR",
        )
        combined = " ".join(result.optimisations)
        assert "exit tax" in combined.lower() or "PAS" in combined


# ===========================================================================
# ExpatService — AVS Gap (8 tests)
# ===========================================================================

class TestAVSGap:
    """Tests for ExpatService.estimate_avs_gap()."""

    def test_full_contribution_no_gap(self, expat_service):
        """44 years in CH should give full pension, no gap."""
        result = expat_service.estimate_avs_gap(
            years_abroad=0, years_in_ch=44,
        )
        assert result.annees_manquantes == 0
        assert result.rente_estimee_mensuelle == AVS_RENTE_MAX_MENSUELLE
        assert result.reduction_mensuelle == 0.0

    def test_partial_contribution(self, expat_service):
        """22 years should give ~50% pension."""
        result = expat_service.estimate_avs_gap(
            years_abroad=22, years_in_ch=22,
        )
        assert result.annees_manquantes == 22
        expected_rente = round(AVS_RENTE_MAX_MENSUELLE * (22 / 44), 2)
        assert result.rente_estimee_mensuelle == expected_rente

    def test_zero_years_no_pension(self, expat_service):
        """Zero years in CH should give no pension."""
        result = expat_service.estimate_avs_gap(
            years_abroad=20, years_in_ch=0,
        )
        assert result.annees_manquantes == 44
        assert result.rente_estimee_mensuelle == 0.0

    def test_one_year_minimum_pension(self, expat_service):
        """One year should give at least minimum pension."""
        result = expat_service.estimate_avs_gap(
            years_abroad=10, years_in_ch=1,
        )
        assert result.rente_estimee_mensuelle >= AVS_RENTE_MIN_MENSUELLE

    def test_voluntary_contribution_possible(self, expat_service):
        """Years abroad should indicate voluntary contribution is possible."""
        result = expat_service.estimate_avs_gap(
            years_abroad=10, years_in_ch=30,
        )
        assert result.cotisation_volontaire_possible is True
        assert result.cotisation_min == AVS_COTISATION_MIN_VOLONTAIRE
        assert result.cotisation_max == AVS_COTISATION_MAX_VOLONTAIRE

    def test_no_years_abroad_no_voluntary(self, expat_service):
        """No years abroad means no need for voluntary contribution."""
        result = expat_service.estimate_avs_gap(
            years_abroad=0, years_in_ch=44,
        )
        assert result.cotisation_volontaire_possible is False

    def test_more_than_44_years(self, expat_service):
        """More than 44 years should still cap at max pension."""
        result = expat_service.estimate_avs_gap(
            years_abroad=0, years_in_ch=50,
        )
        assert result.annees_manquantes == 0
        assert result.rente_estimee_mensuelle == AVS_RENTE_MAX_MENSUELLE

    def test_sources_reference_lavs(self, expat_service):
        """Sources should reference LAVS."""
        result = expat_service.estimate_avs_gap(
            years_abroad=5, years_in_ch=30,
        )
        source_text = " ".join(result.sources)
        assert "LAVS" in source_text


# ===========================================================================
# ExpatService — Departure Plan (5 tests)
# ===========================================================================

class TestDeparturePlan:
    """Tests for ExpatService.plan_departure()."""

    def test_basic_departure_plan(self, expat_service):
        """Should return a complete departure plan."""
        result = expat_service.plan_departure(
            departure_date="2026-12-31",
            canton="ZH",
            pillar_3a_balance=100_000,
            lpp_balance=300_000,
        )
        assert result.date_depart == "2026-12-31"
        assert result.canton == "ZH"
        assert result.impot_capital_3a > 0
        assert result.impot_capital_lpp > 0
        assert len(result.checklist) > 0

    def test_end_of_year_timing_optimal(self, expat_service):
        """End of year departure should be flagged as good timing."""
        result = expat_service.plan_departure(
            departure_date="2026-11-30",
            canton="VD",
            pillar_3a_balance=50_000,
            lpp_balance=200_000,
        )
        assert "Bon timing" in result.timing_optimal or "prorata" in result.timing_optimal

    def test_capital_tax_by_canton(self, expat_service):
        """Capital tax should vary by canton."""
        result_zh = expat_service.plan_departure(
            departure_date="2026-06-15",
            canton="ZH",
            pillar_3a_balance=100_000,
            lpp_balance=0,
        )
        result_zg = expat_service.plan_departure(
            departure_date="2026-06-15",
            canton="ZG",
            pillar_3a_balance=100_000,
            lpp_balance=0,
        )
        # ZG has lower capital tax than ZH
        assert result_zg.impot_capital_3a < result_zh.impot_capital_3a

    def test_checklist_has_items(self, expat_service):
        """Checklist should have at least 10 items."""
        result = expat_service.plan_departure(
            departure_date="2026-06-15",
            canton="ZH",
            pillar_3a_balance=50_000,
            lpp_balance=100_000,
        )
        assert len(result.checklist) >= 10

    def test_sources_reference_lflp(self, expat_service):
        """Sources should reference LFLP (libre passage)."""
        result = expat_service.plan_departure(
            departure_date="2026-06-15",
            canton="ZH",
            pillar_3a_balance=50_000,
            lpp_balance=100_000,
        )
        source_text = " ".join(result.sources)
        assert "LFLP" in source_text


# ===========================================================================
# ExpatService — Tax Comparison (5 tests)
# ===========================================================================

class TestTaxComparison:
    """Tests for ExpatService.compare_tax_burden()."""

    def test_ch_vs_france(self, expat_service):
        """CH should generally be advantageous vs France."""
        result = expat_service.compare_tax_burden(
            salary=120_000, canton="ZH", target_country="FR",
        )
        assert result.net_ch > 0
        assert result.net_cible > 0
        # ZH should be cheaper than France for CHF 120k salary
        assert result.difference_nette > 0

    def test_ch_vs_all_countries(self, expat_service):
        """All target countries should return valid results."""
        for country in ["FR", "DE", "IT", "AT", "UK", "US", "ES", "PT"]:
            result = expat_service.compare_tax_burden(
                salary=100_000, canton="ZH", target_country=country,
            )
            assert result.salaire_brut == 100_000
            assert result.pays_cible == country
            assert result.net_ch == round(result.salaire_brut - result.total_ch, 2)
            assert result.net_cible == round(result.salaire_brut - result.total_cible, 2)

    def test_zero_salary(self, expat_service):
        """Zero salary should give zero everything."""
        result = expat_service.compare_tax_burden(
            salary=0, canton="ZH", target_country="FR",
        )
        assert result.impot_ch == 0.0
        assert result.impot_cible == 0.0
        assert result.net_ch == 0.0

    def test_exit_tax_note_present(self, expat_service):
        """Exit tax note should mention no exit tax in CH."""
        result = expat_service.compare_tax_burden(
            salary=100_000, canton="ZH", target_country="FR",
        )
        assert "exit tax" in result.exit_tax_note.lower() or "PAS" in result.exit_tax_note

    def test_low_tax_canton_advantage(self, expat_service):
        """Low tax canton (ZG) should have higher net than high tax (GE)."""
        result_zg = expat_service.compare_tax_burden(
            salary=150_000, canton="ZG", target_country="FR",
        )
        result_ge = expat_service.compare_tax_burden(
            salary=150_000, canton="GE", target_country="FR",
        )
        assert result_zg.net_ch > result_ge.net_ch


# ===========================================================================
# Compliance & Disclaimer Tests (5 tests)
# ===========================================================================

class TestCompliance:
    """Verify disclaimers and compliance rules."""

    def test_frontalier_disclaimer_no_banned_words(self):
        """Frontalier disclaimer should not contain banned words."""
        banned = ["garanti", "certain", "sans risque"]
        for word in banned:
            assert word not in FRONTALIER_DISCLAIMER.lower(), f"Banned word '{word}' found"

    def test_expat_disclaimer_no_banned_words(self):
        """Expat disclaimer should not contain banned words."""
        banned = ["garanti", "certain", "sans risque"]
        for word in banned:
            assert word not in EXPAT_DISCLAIMER.lower(), f"Banned word '{word}' found"

    def test_frontalier_disclaimer_uses_estimation(self):
        """Frontalier disclaimer should use 'estimation' language."""
        assert "estimation" in FRONTALIER_DISCLAIMER.lower() or "educativ" in FRONTALIER_DISCLAIMER.lower()

    def test_expat_disclaimer_uses_estimation(self):
        """Expat disclaimer should use 'estimation' language."""
        assert "estimation" in EXPAT_DISCLAIMER.lower() or "educativ" in EXPAT_DISCLAIMER.lower()

    def test_disclaimers_mention_specialist(self):
        """Both disclaimers should recommend consulting a specialist."""
        assert "specialiste" in FRONTALIER_DISCLAIMER.lower()
        assert "specialiste" in EXPAT_DISCLAIMER.lower()


# ===========================================================================
# Edge Cases (5 tests)
# ===========================================================================

class TestEdgeCases:
    """Edge case tests."""

    def test_max_salary_source_tax(self, frontalier_service):
        """Very high salary should still calculate correctly."""
        result = frontalier_service.calculate_source_tax(
            salary=1_000_000, canton="VD",
        )
        assert result.impot_source > 0
        assert result.taux_effectif > 0
        assert result.taux_effectif < 100  # rate should be reasonable

    def test_unknown_canton_uses_default(self, frontalier_service):
        """Unknown canton should use default rates."""
        result = frontalier_service.calculate_source_tax(
            salary=100_000, canton="XX",
        )
        assert result.impot_source > 0

    def test_all_border_cantons_source_tax(self, frontalier_service):
        """All major border cantons should have specific rates."""
        border_cantons = ["GE", "VD", "VS", "BS", "TI", "BE", "ZH", "AG", "SG"]
        for canton in border_cantons:
            result = frontalier_service.calculate_source_tax(
                salary=80_000, canton=canton,
            )
            assert result.canton == canton

    def test_departure_plan_invalid_date(self, expat_service):
        """Invalid date should not crash, just give generic timing advice."""
        result = expat_service.plan_departure(
            departure_date="not-a-date",
            canton="ZH",
            pillar_3a_balance=50_000,
            lpp_balance=100_000,
        )
        assert result.timing_optimal is not None
        assert "non analysable" in result.timing_optimal or "general" in result.timing_optimal

    def test_forfait_fiscal_canton_case_insensitive(self, expat_service):
        """Canton should work case-insensitively."""
        result = expat_service.simulate_forfait_fiscal(
            canton="vd", living_expenses=500_000, actual_income=5_000_000,
        )
        assert result.canton == "VD"
        assert result.eligible is True


# ===========================================================================
# API Endpoint Tests (integration) — 12 tests
# ===========================================================================

class TestExpatEndpoints:
    """Integration tests for expat FastAPI endpoints."""

    def test_source_tax_endpoint(self, client):
        """POST /expat/frontalier/source-tax should return 200."""
        response = client.post(
            "/api/v1/expat/frontalier/source-tax",
            json={
                "salary": 100000,
                "canton": "VD",
                "maritalStatus": "celibataire",
                "children": 0,
                "churchTax": False,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "salaireBrut" in data
        assert "impotSource" in data
        assert "tauxEffectif" in data
        assert "disclaimer" in data

    def test_quasi_resident_endpoint(self, client):
        """POST /expat/frontalier/quasi-resident should return 200."""
        response = client.post(
            "/api/v1/expat/frontalier/quasi-resident",
            json={
                "chIncome": 95000,
                "worldwideIncome": 100000,
                "canton": "GE",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "eligible" in data
        assert "ratioCh" in data
        assert "disclaimer" in data

    def test_90_day_rule_endpoint(self, client):
        """POST /expat/frontalier/90-day-rule should return 200."""
        response = client.post(
            "/api/v1/expat/frontalier/90-day-rule",
            json={
                "homeOfficeDays": 80,
                "commuteDays": 150,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "depasseSeuil" in data
        assert "risque" in data
        assert "paysImposition" in data
        assert "disclaimer" in data

    def test_social_charges_endpoint(self, client):
        """POST /expat/frontalier/social-charges should return 200."""
        response = client.post(
            "/api/v1/expat/frontalier/social-charges",
            json={
                "salary": 100000,
                "countryOfResidence": "FR",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "avsAiApgEmploye" in data
        assert "totalChEmploye" in data
        assert "totalResidenceEmploye" in data
        assert "disclaimer" in data

    def test_lamal_option_endpoint(self, client):
        """POST /expat/frontalier/lamal-option should return 200."""
        response = client.post(
            "/api/v1/expat/frontalier/lamal-option",
            json={
                "age": 35,
                "canton": "GE",
                "familySize": 1,
                "residenceCountry": "FR",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "primeLamalMensuelle" in data
        assert "primeResidenceMensuelle" in data
        assert "economieLamal" in data
        assert "disclaimer" in data

    def test_forfait_fiscal_endpoint(self, client):
        """POST /expat/forfait-fiscal should return 200."""
        response = client.post(
            "/api/v1/expat/forfait-fiscal",
            json={
                "canton": "VD",
                "livingExpenses": 500000,
                "actualIncome": 3000000,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "eligible" in data
        assert "baseForfaitaire" in data
        assert "impotForfait" in data
        assert "economie" in data
        assert "disclaimer" in data

    def test_double_taxation_endpoint(self, client):
        """POST /expat/double-taxation should return 200."""
        response = client.post(
            "/api/v1/expat/double-taxation",
            json={
                "residenceCountry": "FR",
                "incomeTypes": ["salaire", "dividendes"],
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "conventionExiste" in data
        assert "repartition" in data
        assert "tauxDividendesMax" in data
        assert "disclaimer" in data

    def test_avs_gap_endpoint(self, client):
        """POST /expat/avs-gap should return 200."""
        response = client.post(
            "/api/v1/expat/avs-gap",
            json={
                "yearsAbroad": 10,
                "yearsInCh": 30,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "anneesCotisationCh" in data
        assert "anneesManquantes" in data
        assert "renteEstimeeMensuelle" in data
        assert "cotisationVolontairePossible" in data
        assert "disclaimer" in data

    def test_departure_plan_endpoint(self, client):
        """POST /expat/departure-plan should return 200."""
        response = client.post(
            "/api/v1/expat/departure-plan",
            json={
                "departureDate": "2026-12-31",
                "canton": "ZH",
                "pillar3ABalance": 100000,
                "lppBalance": 300000,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "impotCapital3A" in data
        assert "impotCapitalLpp" in data
        assert "checklist" in data
        assert len(data["checklist"]) > 0
        assert "timingOptimal" in data
        assert "disclaimer" in data

    def test_tax_comparison_endpoint(self, client):
        """POST /expat/tax-comparison should return 200."""
        response = client.post(
            "/api/v1/expat/tax-comparison",
            json={
                "salary": 120000,
                "canton": "ZH",
                "targetCountry": "FR",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "impotCh" in data
        assert "impotCible" in data
        assert "netCh" in data
        assert "netCible" in data
        assert "differenceNette" in data
        assert "exitTaxNote" in data
        assert "disclaimer" in data

    def test_source_tax_endpoint_camelcase(self, client):
        """API should accept camelCase and return camelCase."""
        response = client.post(
            "/api/v1/expat/frontalier/source-tax",
            json={
                "salary": 80000,
                "canton": "VD",
                "maritalStatus": "marie",
                "children": 2,
                "churchTax": False,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "salaireBrut" in data
        assert "impotSource" in data
        assert "tauxEffectif" in data
        assert "impotOrdinaireEstime" in data
        assert "recommandation" in data

    def test_forfait_fiscal_abolished_canton(self, client):
        """Forfait fiscal in abolished canton should return eligible=false."""
        response = client.post(
            "/api/v1/expat/forfait-fiscal",
            json={
                "canton": "ZH",
                "livingExpenses": 500000,
                "actualIncome": 3000000,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["eligible"] is False
