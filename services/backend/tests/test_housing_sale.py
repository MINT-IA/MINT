"""
Tests for HousingSaleService (Sprint S24 — housingSale life event).

L'impot sur les gains immobiliers est desormais delegue au modele calibre
``fiscal.gains_immobiliers_calibres`` (ADR 2026-07-28 P5). Les anciennes
assertions gravees sur la table fabriquee ``TAUX_PLUS_VALUE_IMMOBILIERE`` (par
duree, exoneration 0 % apres 20-25 ans) etaient fausses sur ZH, VD et GE ; elles
sont remplacees ici par des assertions etalon :
    - ZH : tarif progressif par montant + majoration/rabais de duree (jamais 0 %).
    - VD : bareme degressif 25 lignes.
    - GE : 2 % des 25 ans (l'exoneration totale est morte, revision 1.1.2025).
    - BE / LU / BS + cantons inconnus : aucun impot chiffre (None), verdict
      mecanisme / inconnu.

Run: cd services/backend && python3 -m pytest tests/test_housing_sale.py -v
"""

import pytest

from app.services.housing_sale_service import (
    HousingSaleService,
    HousingSaleInput,
)
from app.services.fiscal.gains_immobiliers_calibres import (
    impot_base_zh,
    impot_zh,
    taux_ge,
    taux_vd,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def service():
    return HousingSaleService()


@pytest.fixture
def base_input():
    """A standard sale scenario: bought 800k in 2015, selling 1M in 2025 (GE)."""
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
# TestHousingSaleTaxRate — calibrated cantons + mechanism/unknown (12 tests)
# ===========================================================================

class TestHousingSaleTaxRate:
    """Tests for the calibrated gains-tax model per canton."""

    def test_zurich_short_detention_majoration(self, service):
        """ZH: 1 year -> progressive tarif + majoration de courte duree (×1.25)."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2024, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        # imposable 200k, duree 1 -> base(200k) × 1.25
        assert result.modele_gain == "calibre"
        assert result.impot_plus_value == impot_zh(200_000, 1)
        assert result.impot_plus_value == 86_750.0

    def test_zurich_long_detention_never_exempt(self, service):
        """ZH: >= 20 years -> rabais plafonne a 50 %, JAMAIS 0 % (correction P5)."""
        inp = HousingSaleInput(
            prix_achat=300_000, prix_vente=500_000,
            annee_achat=2000, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        # imposable 200k, duree 25 -> base(200k) × 0.5
        assert result.impot_plus_value == impot_zh(200_000, 25)
        assert result.impot_plus_value == round(impot_base_zh(200_000) * 0.5, 2)
        assert result.impot_plus_value > 0

    def test_bern_mecanisme_no_number(self, service):
        """BE: gains tax exists but is not tabulated -> no fabricated number."""
        inp = HousingSaleInput(
            prix_achat=400_000, prix_vente=500_000,
            annee_achat=2025, annee_vente=2025, canton="BE",
        )
        result = service.calculate(inp)
        assert result.modele_gain == "mecanisme"
        assert result.impot_plus_value is None
        assert result.taux_imposition_plus_value is None
        assert result.produit_net is None

    def test_bern_long_detention_still_mecanisme(self, service):
        """BE: long ownership still yields no fabricated number."""
        inp = HousingSaleInput(
            prix_achat=200_000, prix_vente=500_000,
            annee_achat=1998, annee_vente=2025, canton="BE",
        )
        result = service.calculate(inp)
        assert result.modele_gain == "mecanisme"
        assert result.impot_plus_value is None

    def test_vaud_7_years(self, service):
        """VD: 7 years -> bareme degressif = 16 %."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == taux_vd(7)
        assert result.taux_imposition_plus_value == 0.16
        assert result.impot_plus_value == 200_000 * 0.16

    def test_geneve_15_years(self, service):
        """GE: 15 years -> 10 %."""
        inp = HousingSaleInput(
            prix_achat=800_000, prix_vente=1_200_000,
            annee_achat=2010, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == taux_ge(15)
        assert result.taux_imposition_plus_value == 0.10

    def test_lucerne_mecanisme(self, service):
        """LU: not calibrated -> mechanism, no number."""
        inp = HousingSaleInput(
            prix_achat=400_000, prix_vente=550_000,
            annee_achat=2018, annee_vente=2025, canton="LU",
        )
        result = service.calculate(inp)
        assert result.modele_gain == "mecanisme"
        assert result.impot_plus_value is None

    def test_basel_mecanisme(self, service):
        """BS: not calibrated -> mechanism, no number."""
        inp = HousingSaleInput(
            prix_achat=300_000, prix_vente=600_000,
            annee_achat=2000, annee_vente=2025, canton="BS",
        )
        result = service.calculate(inp)
        assert result.modele_gain == "mecanisme"
        assert result.impot_plus_value is None

    def test_unknown_canton_inconnu(self, service):
        """Unknown canton -> honest 'inconnu' verdict, no fabricated rate."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2020, annee_vente=2025, canton="TG",
        )
        result = service.calculate(inp)
        assert result.modele_gain == "inconnu"
        assert result.taux_imposition_plus_value is None
        assert result.impot_plus_value is None
        assert result.produit_net is None

    def test_geneve_25_years_two_percent(self, service):
        """GE: >= 25 years -> 2 % (revision 1.1.2025), no longer exempt."""
        inp = HousingSaleInput(
            prix_achat=200_000, prix_vente=800_000,
            annee_achat=1995, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        # 30 years -> 2 %
        assert result.taux_imposition_plus_value == 0.02
        assert result.impot_plus_value == 600_000 * 0.02

    def test_vaud_double_occupation(self, service):
        """VD: proven owner-occupation years count double (art. 72 al. 4)."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2017, annee_vente=2025, canton="VD",  # 8 years owned
            annees_occupation=8,
        )
        result = service.calculate(inp)
        # duree effective 8 + 8 = 16 -> 11 %
        assert result.taux_imposition_plus_value == taux_vd(16)
        assert result.taux_imposition_plus_value == 0.11

    def test_tax_amount_computation(self, service):
        """VD tax = taxable gain * rate."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=700_000,
            annee_achat=2018, annee_vente=2025, canton="VD",
        )
        result = service.calculate(inp)
        expected_tax = 200_000 * taux_vd(7)
        assert result.impot_plus_value == expected_tax


# ===========================================================================
# TestHousingSaleRemploi — reinvestment deferral (6 tests)
# ===========================================================================

class TestHousingSaleRemploi:
    """Tests for reinvestment tax deferral (remploi). Deferral applies to tax."""

    def test_no_remploi_zero_report(self, service, base_input):
        """No remploi project: zero deferral (GE calibrated)."""
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
        # imposable 500k, taux VD 7y = 16% -> impot 80k ; ratio 0.5 -> report 40k
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
        assert "70,000" in epl_alerts[0] or "70'000" in epl_alerts[0]


# ===========================================================================
# TestHousingSaleNetProceeds — net proceeds (5 tests)
# ===========================================================================

class TestHousingSaleNetProceeds:
    """Tests for net proceeds calculation (calibrated cantons)."""

    def test_net_proceeds_basic(self, service, base_input):
        """Net = sale price - mortgage - tax - EPL."""
        result = service.calculate(base_input)
        # GE 10y = 10% ; taxable 120k -> tax 12k
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
        # GE 10y = 10% ; taxable 300k -> tax 30k
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
        # GE 10y = 10% ; taxable 200k -> tax 20k
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

    def test_very_long_detention_30_years_ge(self, service):
        """GE: 30 years -> 2 % (not exempt anymore, revision 1.1.2025)."""
        inp = HousingSaleInput(
            prix_achat=200_000, prix_vente=800_000,
            annee_achat=1995, annee_vente=2025, canton="GE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition_plus_value == 0.02
        assert result.impot_effectif == 600_000 * 0.02

    def test_same_year_sale_zh(self, service):
        """ZH: same-year sale (duration 0) -> majoration de courte duree."""
        inp = HousingSaleInput(
            prix_achat=500_000, prix_vente=550_000,
            annee_achat=2025, annee_vente=2025, canton="ZH",
        )
        result = service.calculate(inp)
        assert result.duree_detention == 0
        # imposable 50k, duree 0 -> base(50k) × 1.5
        assert result.impot_plus_value == impot_zh(50_000, 0)
        assert result.impot_plus_value == round(impot_base_zh(50_000) * 1.5, 2)

    def test_negative_plus_value_no_tax(self, service):
        """Negative gain: no tax due (calibrated canton -> 0, not None)."""
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

    def test_premier_eclairage_present(self, service, base_input):
        """Chiffre choc should contain montant and texte."""
        result = service.calculate(base_input)
        assert "montant" in result.premier_eclairage
        assert "texte" in result.premier_eclairage
        assert isinstance(result.premier_eclairage["montant"], float)
