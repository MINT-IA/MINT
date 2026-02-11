"""
Tests for HousingSaleService (Sprint S24 — housingSale life event).

Covers:
    - TestHousingSalePlusValue — basic gain calculations (7 tests)
    - TestHousingSaleTaxRate — all 6 cantons, various durations (10 tests)
    - TestHousingSaleRemploi — full, partial, no remploi (6 tests)
    - TestHousingSaleEPL — EPL repayment with/without LPP/3a (5 tests)
    - TestHousingSaleNetProceeds — net proceeds calculation (5 tests)
    - TestHousingSaleCompliance — disclaimer, sources, banned terms (5 tests)
    - TestHousingSaleEdgeCases — zero price, very long detention, etc. (6 tests)

Target: 44 tests.

Run: cd services/backend && python3 -m pytest tests/test_housing_sale.py -v
"""

import pytest

from app.services.housing_sale_service import (
    HousingSaleService,
    HousingSaleInput,
    HousingSaleResult,
    DISCLAIMER,
    SOURCES,
    TAUX_PLUS_VALUE_IMMOBILIERE,
    TAUX_PLUS_VALUE_DEFAULT,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def service():
    return HousingSaleService()


@pytest.fixture
def base_input():
    """A standard sale scenario: bought 800k in 2015, selling 1M in 2025."""
    return HousingSaleInput(
        prix_achat=800_000,
        prix_vente=1_000_000,
        annee_achat=2015,
        annee_vente=2025,
        investissements_valorisants=50_000,
        frais_acquisition=30_000,
        canton="GE",
        residence_principale=True,
        epl_lpp_utilise=0,
        epl_3a_utilise=0,
        hypotheque_restante=400_000,
        projet_remploi=False,
        prix_remploi=0,
    )


# ===========================================================================
# TestHousingSalePlusValue — basic calculations (7 tests)
# ===========================================================================

class TestHousingSalePlusValue:
    """Tests for plus-value (capital gain) calculations."""

    def test_plus_value_brute_basic(self, service, base_input):
        """Gross gain = sale price - purchase price."""
        result = service.calculate(base_input)
        assert result.plus_value_brute == 200_000

    def test_plus_value_imposable_after_deductions(self, service, base_input):
        """Taxable gain = gross - renovations - acquisition fees."""
        result = service.calculate(base_input)
        # 1M - 800k - 50k - 30k = 120k
        assert result.plus_value_imposable == 120_000

    def test_plus_value_imposable_zero_when_loss(self, service):
        """When sale price < purchase price, taxable gain is 0."""
        inp = HousingSaleInput(
            prix_achat=1_000_000, prix_vente=900_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        assert result.plus_value_brute == -100_000
        assert result.plus_value_imposable == 0.0

    def test_plus_value_zero_same_price(self, service):
        """Bought and sold at the same price: zero gain."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=500_000,
            annee_achat=2020, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        assert result.plus_value_brute == 0
        assert result.plus_value_imposable == 0

    def test_deductions_reduce_taxable_gain(self, service):
        """Renovations and fees reduce the taxable capital gain."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2015, annee_vente=2025,
            investissements_valorisants=100_000,
            frais_acquisition=25_000,
            canton="ZH",
        )
        result = service.calculate(inp)
        # 700k - 500k - 100k - 25k = 75k
        assert result.plus_value_imposable == 75_000

    def test_deductions_exceeding_gain_gives_zero(self, service):
        """If deductions exceed the gain, taxable gain is 0 (not negative)."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=550_000,
            annee_achat=2015, annee_vente=2025,
            investissements_valorisants=80_000,
            frais_acquisition=20_000,
            canton="VD",
        )
        result = service.calculate(inp)
        # 550k - 500k - 80k - 20k = -50k -> capped at 0
        assert result.plus_value_imposable == 0.0
        assert result.impot_plus_value == 0.0

    def test_duree_detention_calculation(self, service, base_input):
        """Duration = year of sale - year of purchase."""
        result = service.calculate(base_input)
        assert result.duree_detention == 10


# ===========================================================================
# TestHousingSaleTaxRate — all 6 cantons, various durations (10 tests)
# ===========================================================================

class TestHousingSaleTaxRate:
    """Tests for canton-specific tax rate schedules."""

    def test_zurich_short_detention_high_rate(self, service):
        """ZH: < 2 years = 50%."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2024, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.50

    def test_zurich_20_years_exempt(self, service):
        """ZH: >= 20 years = 0% (exempt)."""
        inp = HousingSaleInput(
            prix_achat=300_000, prix_vente=500_000,
            annee_achat=2000, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.0
        assert result.impot_plus_value == 0.0

    def test_bern_1_year_45_percent(self, service):
        """BE: < 1 year = 45%."""
        inp = HousingSaleInput(
            prix_achat=400_000, prix_vente=500_000,
            annee_achat=2025, annee_vente=2025, canton="BE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.45

    def test_bern_25_years_exempt(self, service):
        """BE: >= 25 years = 0%."""
        inp = HousingSaleInput(
            prix_achat=200_000, prix_vente=500_000,
            annee_achat=1998, annee_vente=2025, canton="BE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.0

    def test_vaud_5_to_10_years(self, service):
        """VD: 5-10 years = 20%."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.20

    def test_geneve_10_to_25_years(self, service):
        """GE: 10-25 years = 10%."""
        inp = HousingSaleInput(
            prix_achat=800_000, prix_vente=1_200_000,
            annee_achat=2010, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.10

    def test_lucerne_5_to_10_years(self, service):
        """LU: 5-10 years = 21%."""
        inp = HousingSaleInput(
            prix_achat=400_000, prix_vente=550_000,
            annee_achat=2018, annee_vente=2025, canton="LU",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.21

    def test_basel_long_detention(self, service):
        """BS: >= 20 years = 10% (not fully exempt)."""
        inp = HousingSaleInput(
            prix_achat=300_000, prix_vente=600_000,
            annee_achat=2000, annee_vente=2025, canton="BS",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.10

    def test_unknown_canton_uses_default(self, service):
        """Unknown canton should use default rates."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2020, annee_vente=2025, canton="TG",
        )
        result = service.calculate(inp)
        # TG not in our dict, should use default: 5 years -> bracket (5, 10) = 0.22
        assert result.taux_imposition_plus_value == 0.22

    def test_tax_amount_computation(self, service):
        """Tax = taxable gain * rate."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
        )
        result = service.calculate(inp)
        # Taxable gain = 200k, rate = 20%
        expected_tax = 200_000 * 0.20
        assert result.impot_plus_value == expected_tax


# ===========================================================================
# TestHousingSaleRemploi — reinvestment deferral (6 tests)
# ===========================================================================

class TestHousingSaleRemploi:
    """Tests for reinvestment tax deferral (remploi)."""

    def test_no_remploi_zero_report(self, service, base_input):
        """No remploi project: zero deferral."""
        result = service.calculate(base_input)
        assert result.remploi_report == 0.0

    def test_full_remploi_equal_price(self, service):
        """Full remploi: replacement price >= sale price -> full deferral."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
            projet_remploi=True, prix_remploi=700_000,
        )
        result = service.calculate(inp)
        # Full deferral
        assert result.remploi_report == result.impot_plus_value
        assert result.impot_effectif == 0.0

    def test_full_remploi_higher_price(self, service):
        """Full remploi: replacement price > sale price -> full deferral."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
            projet_remploi=True, prix_remploi=900_000,
        )
        result = service.calculate(inp)
        assert result.remploi_report == result.impot_plus_value
        assert result.impot_effectif == 0.0

    def test_partial_remploi(self, service):
        """Partial remploi: replacement price < sale price -> proportional deferral."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=1_000_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
            projet_remploi=True, prix_remploi=500_000,
        )
        result = service.calculate(inp)
        # Tax on 500k gain at 20% = 100k
        # Ratio = 500k / 1M = 0.50 -> report = 50k
        expected_report = round(result.impot_plus_value * 0.50, 2)
        assert result.remploi_report == expected_report
        assert result.impot_effectif == round(result.impot_plus_value - expected_report, 2)

    def test_remploi_with_zero_tax(self, service):
        """Remploi with zero tax (no gain): no deferral needed."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=500_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
            projet_remploi=True, prix_remploi=600_000,
        )
        result = service.calculate(inp)
        assert result.remploi_report == 0.0

    def test_remploi_zero_prix_remploi(self, service):
        """Remploi project but zero replacement price: no deferral."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
            projet_remploi=True, prix_remploi=0,
        )
        result = service.calculate(inp)
        assert result.remploi_report == 0.0


# ===========================================================================
# TestHousingSaleEPL — EPL repayment (5 tests)
# ===========================================================================

class TestHousingSaleEPL:
    """Tests for EPL (early pension withdrawal) repayment on sale."""

    def test_epl_lpp_repayment(self, service):
        """LPP EPL must be repaid from sale proceeds."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
            epl_lpp_utilise=60_000,
        )
        result = service.calculate(inp)
        assert result.remboursement_epl_lpp == 60_000

    def test_epl_3a_repayment(self, service):
        """3a EPL must be repaid from sale proceeds."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
            epl_3a_utilise=30_000,
        )
        result = service.calculate(inp)
        assert result.remboursement_epl_3a == 30_000

    def test_both_epl_repayment(self, service):
        """Both LPP and 3a EPL must be repaid."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
            epl_lpp_utilise=60_000, epl_3a_utilise=30_000,
        )
        result = service.calculate(inp)
        assert result.remboursement_epl_lpp == 60_000
        assert result.remboursement_epl_3a == 30_000

    def test_no_epl_zero_repayment(self, service, base_input):
        """No EPL used: zero repayment."""
        result = service.calculate(base_input)
        assert result.remboursement_epl_lpp == 0.0
        assert result.remboursement_epl_3a == 0.0

    def test_epl_alert_triggered(self, service):
        """EPL repayment should trigger an alert."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
            epl_lpp_utilise=50_000, epl_3a_utilise=20_000,
        )
        result = service.calculate(inp)
        epl_alerts = [a for a in result.alerts if "EPL" in a]
        assert len(epl_alerts) > 0
        assert "70,000" in epl_alerts[0] or "70'000" in epl_alerts[0] or "70,000" in epl_alerts[0]


# ===========================================================================
# TestHousingSaleNetProceeds — net proceeds (5 tests)
# ===========================================================================

class TestHousingSaleNetProceeds:
    """Tests for net proceeds calculation."""

    def test_net_proceeds_basic(self, service, base_input):
        """Net = sale price - mortgage - tax - EPL."""
        result = service.calculate(base_input)
        # Sale: 1M, mortgage: 400k, tax: 120k * 0.10 (GE 10y) = 12k
        # EPL: 0
        expected = 1_000_000 - 400_000 - 12_000
        assert result.produit_net == expected

    def test_net_proceeds_with_epl(self, service):
        """Net proceeds include EPL repayment deduction."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=800_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
            epl_lpp_utilise=50_000, epl_3a_utilise=20_000,
            hypotheque_restante=300_000,
        )
        result = service.calculate(inp)
        # Gain: 300k imposable, rate 10% (GE 10y) -> tax 30k
        expected = 800_000 - 300_000 - 30_000 - 50_000 - 20_000
        assert result.produit_net == expected

    def test_net_proceeds_with_remploi(self, service):
        """Net proceeds benefit from remploi tax deferral."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
            hypotheque_restante=200_000,
            projet_remploi=True, prix_remploi=700_000,
        )
        result = service.calculate(inp)
        # Tax deferred fully -> impot_effectif = 0
        expected = 700_000 - 200_000 - 0
        assert result.produit_net == expected

    def test_net_proceeds_negative(self, service):
        """Net proceeds can be negative (underwater)."""
        inp = HousingSaleInput(
            prix_achat=800_000, prix_vente=600_000,
            annee_achat=2020, annee_vente=2025, canton="GE",
            hypotheque_restante=700_000,
        )
        result = service.calculate(inp)
        # Tax: 0 (loss), net = 600k - 700k = -100k
        assert result.produit_net < 0
        assert result.produit_net == -100_000

    def test_net_proceeds_no_mortgage(self, service):
        """No mortgage: higher net proceeds."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2015, annee_vente=2025, canton="GE",
            hypotheque_restante=0,
        )
        result = service.calculate(inp)
        # Gain: 200k, rate 10% (GE 10y) -> tax 20k
        expected = 700_000 - 0 - 20_000
        assert result.produit_net == expected


# ===========================================================================
# TestHousingSaleCompliance — disclaimer, sources, banned terms (5 tests)
# ===========================================================================

class TestHousingSaleCompliance:
    """Tests for compliance outputs."""

    def test_disclaimer_present(self, service, base_input):
        """Result must include a disclaimer."""
        result = service.calculate(base_input)
        assert result.disclaimer is not None
        assert len(result.disclaimer) > 50

    def test_disclaimer_mentions_educatif(self, service, base_input):
        """Disclaimer must mention 'outil educatif'."""
        result = service.calculate(base_input)
        assert "outil educatif" in result.disclaimer

    def test_disclaimer_mentions_lsfin(self, service, base_input):
        """Disclaimer must mention 'LSFin'."""
        result = service.calculate(base_input)
        assert "LSFin" in result.disclaimer

    def test_disclaimer_no_banned_terms(self, service, base_input):
        """Disclaimer must not contain banned terms."""
        result = service.calculate(base_input)
        banned = ["garanti", "certain", "assure", "sans risque",
                   "optimal", "meilleur", "parfait", "conseiller"]
        disclaimer_lower = result.disclaimer.lower()
        for word in banned:
            assert word not in disclaimer_lower, f"Banned term '{word}' found in disclaimer"

    def test_sources_present(self, service, base_input):
        """Result must include legal sources."""
        result = service.calculate(base_input)
        assert len(result.sources) >= 5
        sources_text = " ".join(result.sources)
        assert "LIFD" in sources_text
        assert "OPP2" in sources_text
        assert "LPP" in sources_text


# ===========================================================================
# TestHousingSaleEdgeCases — edge cases (6 tests)
# ===========================================================================

class TestHousingSaleEdgeCases:
    """Edge case tests."""

    def test_zero_purchase_price(self, service):
        """Zero purchase price (inherited property)."""
        inp = HousingSaleInput(
            prix_achat=0, prix_vente=500_000,
            annee_achat=2010, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        assert result.plus_value_brute == 500_000
        assert result.plus_value_imposable == 500_000

    def test_very_long_detention_30_years(self, service):
        """30 years of ownership: should use lowest bracket."""
        inp = HousingSaleInput(
            prix_achat=200_000, prix_vente=800_000,
            annee_achat=1995, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        # GE: 25-999 years = 0%
        assert result.taux_imposition_plus_value == 0.0
        assert result.impot_effectif == 0.0

    def test_same_year_sale(self, service):
        """Bought and sold in same year: duration = 0."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=550_000,
            annee_achat=2025, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        assert result.duree_detention == 0
        # ZH: 0-2 years = 50%
        assert result.taux_imposition_plus_value == 0.50

    def test_negative_plus_value_no_tax(self, service):
        """Negative gain: no tax due."""
        inp = HousingSaleInput(
            prix_achat=800_000, prix_vente=700_000,
            annee_achat=2020, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        assert result.plus_value_brute == -100_000
        assert result.impot_plus_value == 0.0
        assert result.impot_effectif == 0.0

    def test_checklist_has_items(self, service, base_input):
        """Checklist should have at least 5 items."""
        result = service.calculate(base_input)
        assert len(result.checklist) >= 5

    def test_chiffre_choc_present(self, service, base_input):
        """Chiffre choc should contain montant and texte."""
        result = service.calculate(base_input)
        assert "montant" in result.chiffre_choc
        assert "texte" in result.chiffre_choc
        assert isinstance(result.chiffre_choc["montant"], float)
