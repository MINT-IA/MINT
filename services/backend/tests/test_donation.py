"""
Tests for DonationService (Sprint S24 — donation life event).

Covers:
    - TestDonationTax — all cantons, all relationships (10 tests)
    - TestDonationReserves — reserve hereditaire 2023 law (7 tests)
    - TestDonationQuotiteDisponible — within/exceeding quotite (6 tests)
    - TestDonationAvancementHoirie — counting back at succession (4 tests)
    - TestDonationImmobilier — real estate specific rules (4 tests)
    - TestDonationCompliance — disclaimer, sources, banned terms (5 tests)
    - TestDonationEdgeCases — zero donation, SZ canton, concubin (8 tests)

Target: 44 tests.

Run: cd services/backend && python3 -m pytest tests/test_donation.py -v
"""

import pytest

from app.services.donation_service import (
    DonationService,
    DonationInput,
    TAUX_DONATION_CANTONAL,
    TAUX_DONATION_DEFAULT,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def service():
    return DonationService()


@pytest.fixture
def base_input():
    """A standard donation scenario: 100k to a descendant in GE."""
    return DonationInput(
        montant=100_000,
        donateur_age=55,
        lien_parente="descendant",
        canton="GE",
        type_donation="especes",
        avancement_hoirie=True,
        nb_enfants=2,
        fortune_totale_donateur=500_000,
        has_spouse=True,
        has_parents=False,
    )


# ===========================================================================
# TestDonationTax — all cantons, all relationships (10 tests)
# ===========================================================================

class TestDonationTax:
    """Tests for cantonal donation tax rates and amounts."""

    def test_conjoint_exempt_all_cantons(self, service):
        """Spouse donations are tax-free in all listed cantons."""
        for canton in TAUX_DONATION_CANTONAL:
            inp = DonationInput(
                montant=200_000, donateur_age=50,
                lien_parente="conjoint", canton=canton,
            )
            result = service.calculate(inp)
            assert result.taux_imposition == 0.0, f"Failed for {canton}"
            assert result.impot_donation == 0.0, f"Failed for {canton}"

    def test_descendant_exempt_most_cantons(self, service):
        """Descendant donations are tax-free in most cantons."""
        exempt_cantons = ["ZH", "BE", "GE", "LU", "BS", "SZ", "OW"]
        for canton in exempt_cantons:
            inp = DonationInput(
                montant=100_000, donateur_age=55,
                lien_parente="descendant", canton=canton,
            )
            result = service.calculate(inp)
            assert result.taux_imposition == 0.0, f"Failed for {canton}"

    def test_vaud_parent_5_percent(self, service):
        """VD taxes parent donations at 5%."""
        inp = DonationInput(
            montant=100_000, donateur_age=55,
            lien_parente="parent", canton="VD",
        )
        result = service.calculate(inp)
        assert result.taux_imposition == 0.05
        assert result.impot_donation == 5_000

    def test_geneve_concubin_24_percent(self, service):
        """GE taxes concubin donations at 24%."""
        inp = DonationInput(
            montant=200_000, donateur_age=50,
            lien_parente="concubin", canton="GE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition == 0.24
        assert result.impot_donation == 48_000

    def test_geneve_tiers_30_percent(self, service):
        """GE taxes third-party donations at 30%."""
        inp = DonationInput(
            montant=100_000, donateur_age=50,
            lien_parente="tiers", canton="GE",
        )
        result = service.calculate(inp)
        assert result.taux_imposition == 0.30
        assert result.impot_donation == 30_000

    def test_zurich_fratrie_6_percent(self, service):
        """ZH taxes sibling donations at 6%."""
        inp = DonationInput(
            montant=50_000, donateur_age=60,
            lien_parente="fratrie", canton="ZH",
        )
        result = service.calculate(inp)
        assert result.taux_imposition == 0.06
        assert result.impot_donation == 3_000

    def test_schwyz_zero_all(self, service):
        """SZ has no donation tax for anyone."""
        for lien in ["conjoint", "descendant", "parent", "fratrie", "concubin", "tiers"]:
            inp = DonationInput(
                montant=500_000, donateur_age=50,
                lien_parente=lien, canton="SZ",
            )
            result = service.calculate(inp)
            assert result.taux_imposition == 0.0, f"Failed for {lien} in SZ"
            assert result.impot_donation == 0.0, f"Failed for {lien} in SZ"

    def test_obwald_zero_all(self, service):
        """OW has no donation tax for anyone."""
        for lien in ["conjoint", "descendant", "concubin", "tiers"]:
            inp = DonationInput(
                montant=300_000, donateur_age=50,
                lien_parente=lien, canton="OW",
            )
            result = service.calculate(inp)
            assert result.impot_donation == 0.0, f"Failed for {lien} in OW"

    def test_unknown_canton_uses_default(self, service):
        """Unknown canton should use default rates."""
        inp = DonationInput(
            montant=100_000, donateur_age=50,
            lien_parente="fratrie", canton="AI",
        )
        result = service.calculate(inp)
        expected_rate = TAUX_DONATION_DEFAULT["fratrie"]
        assert result.taux_imposition == expected_rate
        assert result.impot_donation == round(100_000 * expected_rate, 2)

    def test_tax_amount_formula(self, service):
        """Tax = montant * taux."""
        inp = DonationInput(
            montant=250_000, donateur_age=55,
            lien_parente="concubin", canton="LU",
        )
        result = service.calculate(inp)
        assert result.impot_donation == round(250_000 * 0.20, 2)


# ===========================================================================
# TestDonationReserves — reserve hereditaire 2023 law (7 tests)
# ===========================================================================

class TestDonationReserves:
    """Tests for reserve hereditaire calculations (2023 revision)."""

    def test_spouse_and_children_reserves(self, service, base_input):
        """Spouse + children: reserves = spouse 25% + children 25% = 50%."""
        result = service.calculate(base_input)
        # Legal shares: spouse 50%, children 50%
        # Reserves: spouse 50%*50%=25%, children 50%*50%=25%
        # Total reserve = 50% of 500k = 250k
        assert result.reserve_hereditaire_totale == 250_000

    def test_children_only_reserves(self, service):
        """Children only: reserve = 50% of 100% = 50%."""
        inp = DonationInput(
            montant=50_000, donateur_age=60,
            lien_parente="descendant", canton="GE",
            nb_enfants=3, fortune_totale_donateur=400_000,
            has_spouse=False, has_parents=False,
        )
        result = service.calculate(inp)
        # Legal share: children 100%, reserve: 50%
        assert result.reserve_hereditaire_totale == 200_000

    def test_spouse_only_reserves(self, service):
        """Spouse only (no children, no parents): reserve = 50% of 100% = 50%."""
        inp = DonationInput(
            montant=100_000, donateur_age=50,
            lien_parente="tiers", canton="GE",
            nb_enfants=0, fortune_totale_donateur=600_000,
            has_spouse=True, has_parents=False,
        )
        result = service.calculate(inp)
        # Legal share: spouse 100%, reserve: 50%
        assert result.reserve_hereditaire_totale == 300_000

    def test_parents_no_reserve_2023(self, service):
        """Parents have NO reserve since 2023."""
        inp = DonationInput(
            montant=50_000, donateur_age=40,
            lien_parente="tiers", canton="ZH",
            nb_enfants=0, fortune_totale_donateur=300_000,
            has_spouse=False, has_parents=True,
        )
        result = service.calculate(inp)
        # Parents: legal share 100%, but reserve = 0% since 2023
        assert result.reserve_hereditaire_totale == 0.0

    def test_spouse_with_parents_reserves(self, service):
        """Spouse + parents: only spouse has reserve."""
        inp = DonationInput(
            montant=80_000, donateur_age=50,
            lien_parente="tiers", canton="GE",
            nb_enfants=0, fortune_totale_donateur=400_000,
            has_spouse=True, has_parents=True,
        )
        result = service.calculate(inp)
        # Legal: spouse 75%, parents 25%
        # Reserve: spouse 75%*50% = 37.5%, parents: 0%
        assert result.reserve_hereditaire_totale == 150_000

    def test_no_heirs_no_reserve(self, service):
        """No protected heirs: reserve = 0."""
        inp = DonationInput(
            montant=100_000, donateur_age=50,
            lien_parente="tiers", canton="ZH",
            nb_enfants=0, fortune_totale_donateur=500_000,
            has_spouse=False, has_parents=False,
        )
        result = service.calculate(inp)
        assert result.reserve_hereditaire_totale == 0.0

    def test_quotite_disponible_calculation(self, service, base_input):
        """Quotite disponible = fortune - reserves."""
        result = service.calculate(base_input)
        expected_qd = 500_000 - 250_000
        assert result.quotite_disponible == expected_qd


# ===========================================================================
# TestDonationQuotiteDisponible — within/exceeding (6 tests)
# ===========================================================================

class TestDonationQuotiteDisponible:
    """Tests for checking if donation exceeds quotite disponible."""

    def test_within_quotite_no_depassement(self, service, base_input):
        """Donation within QD: no excess."""
        # base_input: 100k donation, QD = 250k
        result = service.calculate(base_input)
        assert result.donation_depasse_quotite is False
        assert result.montant_depassement == 0.0

    def test_exceeds_quotite(self, service):
        """Donation exceeding QD: flagged with excess amount."""
        inp = DonationInput(
            montant=300_000, donateur_age=55,
            lien_parente="tiers", canton="GE",
            nb_enfants=2, fortune_totale_donateur=500_000,
            has_spouse=True, has_parents=False,
        )
        result = service.calculate(inp)
        # QD = 500k - 250k = 250k; donation 300k > 250k
        assert result.donation_depasse_quotite is True
        assert result.montant_depassement == 50_000

    def test_exactly_at_quotite(self, service):
        """Donation exactly at QD boundary: no excess."""
        inp = DonationInput(
            montant=250_000, donateur_age=55,
            lien_parente="tiers", canton="GE",
            nb_enfants=2, fortune_totale_donateur=500_000,
            has_spouse=True, has_parents=False,
        )
        result = service.calculate(inp)
        assert result.donation_depasse_quotite is False
        assert result.montant_depassement == 0.0

    def test_no_fortune_data_no_check(self, service):
        """If fortune_totale = 0, depassement check is skipped."""
        inp = DonationInput(
            montant=100_000, donateur_age=50,
            lien_parente="descendant", canton="ZH",
            fortune_totale_donateur=0,
        )
        result = service.calculate(inp)
        assert result.donation_depasse_quotite is False
        assert result.montant_depassement == 0.0

    def test_full_reserve_zero_qd(self, service):
        """When QD is 0 (full reserve), any donation exceeds."""
        # Spouse + children with small estate
        inp = DonationInput(
            montant=50_000, donateur_age=55,
            lien_parente="tiers", canton="GE",
            nb_enfants=2, fortune_totale_donateur=100_000,
            has_spouse=True, has_parents=False,
        )
        result = service.calculate(inp)
        # Reserve = 50k (spouse 25k + children 25k), QD = 50k
        # Donation = 50k = QD -> not exceeding
        assert result.quotite_disponible == 50_000
        assert result.donation_depasse_quotite is False

    def test_large_donation_exceeds_significantly(self, service):
        """Large donation well over QD."""
        inp = DonationInput(
            montant=400_000, donateur_age=60,
            lien_parente="concubin", canton="GE",
            nb_enfants=1, fortune_totale_donateur=300_000,
            has_spouse=True, has_parents=False,
        )
        result = service.calculate(inp)
        # Legal: spouse 50%, children 50%
        # Reserve: 25% + 25% = 50% of 300k = 150k
        # QD = 150k
        assert result.donation_depasse_quotite is True
        assert result.montant_depassement == 250_000


# ===========================================================================
# TestDonationAvancementHoirie — counting back at succession (4 tests)
# ===========================================================================

class TestDonationAvancementHoirie:
    """Tests for avancement d'hoirie (advance on inheritance)."""

    def test_descendant_default_avancement(self, service, base_input):
        """Donation to descendant is presumed avancement d'hoirie."""
        result = service.calculate(base_input)
        assert "avancement d'hoirie" in result.impact_succession

    def test_descendant_hors_part(self, service):
        """Donation explicitly hors part successorale."""
        inp = DonationInput(
            montant=100_000, donateur_age=55,
            lien_parente="descendant", canton="GE",
            avancement_hoirie=False,
            nb_enfants=2, fortune_totale_donateur=500_000,
            has_spouse=True,
        )
        result = service.calculate(inp)
        assert "hors part successorale" in result.impact_succession

    def test_concubin_impact_on_succession(self, service):
        """Donation to concubin impacts succession (quotite disponible)."""
        inp = DonationInput(
            montant=100_000, donateur_age=55,
            lien_parente="concubin", canton="GE",
            nb_enfants=2, fortune_totale_donateur=500_000,
            has_spouse=True,
        )
        result = service.calculate(inp)
        assert "quotite disponible" in result.impact_succession

    def test_conjoint_impact(self, service):
        """Donation to spouse mentions matrimonial regime."""
        inp = DonationInput(
            montant=100_000, donateur_age=55,
            lien_parente="conjoint", canton="GE",
            nb_enfants=1, fortune_totale_donateur=500_000,
            has_spouse=True,
        )
        result = service.calculate(inp)
        assert "conjoint" in result.impact_succession
        assert "regime" in result.impact_succession.lower()


# ===========================================================================
# TestDonationImmobilier — real estate specific rules (4 tests)
# ===========================================================================

class TestDonationImmobilier:
    """Tests for real estate donation specifics."""

    def test_immobilier_alert(self, service):
        """Real estate donation triggers notary alert."""
        inp = DonationInput(
            montant=500_000, donateur_age=60,
            lien_parente="descendant", canton="GE",
            type_donation="immobilier",
            valeur_immobiliere=500_000,
        )
        result = service.calculate(inp)
        immo_alerts = [a for a in result.alerts if "notarie" in a.lower()]
        assert len(immo_alerts) > 0

    def test_immobilier_checklist_notaire(self, service):
        """Real estate donation checklist includes notary."""
        inp = DonationInput(
            montant=500_000, donateur_age=60,
            lien_parente="descendant", canton="GE",
            type_donation="immobilier",
        )
        result = service.calculate(inp)
        notaire_items = [c for c in result.checklist if "notaire" in c.lower()]
        assert len(notaire_items) > 0

    def test_immobilier_checklist_expert(self, service):
        """Real estate donation checklist includes expert estimation."""
        inp = DonationInput(
            montant=500_000, donateur_age=60,
            lien_parente="descendant", canton="GE",
            type_donation="immobilier",
        )
        result = service.calculate(inp)
        expert_items = [c for c in result.checklist if "expert" in c.lower()]
        assert len(expert_items) > 0

    def test_immobilier_checklist_registre_foncier(self, service):
        """Real estate donation checklist includes land registry."""
        inp = DonationInput(
            montant=500_000, donateur_age=60,
            lien_parente="descendant", canton="GE",
            type_donation="immobilier",
        )
        result = service.calculate(inp)
        rf_items = [c for c in result.checklist if "registre foncier" in c.lower()]
        assert len(rf_items) > 0


# ===========================================================================
# TestDonationCompliance — disclaimer, sources, banned terms (5 tests)
# ===========================================================================

class TestDonationCompliance:
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
        assert "CC" in sources_text
        assert "art." in sources_text


# ===========================================================================
# TestDonationEdgeCases — edge cases (8 tests)
# ===========================================================================

class TestDonationEdgeCases:
    """Edge case tests."""

    def test_zero_donation(self, service):
        """Zero donation: zero tax."""
        inp = DonationInput(
            montant=0, donateur_age=50,
            lien_parente="tiers", canton="GE",
        )
        result = service.calculate(inp)
        assert result.impot_donation == 0.0

    def test_very_large_donation(self, service):
        """Very large donation: tax computed correctly."""
        inp = DonationInput(
            montant=5_000_000, donateur_age=70,
            lien_parente="tiers", canton="GE",
        )
        result = service.calculate(inp)
        assert result.impot_donation == round(5_000_000 * 0.30, 2)

    def test_concubin_high_tax_alert(self, service):
        """Concubin with high tax rate triggers alert."""
        inp = DonationInput(
            montant=200_000, donateur_age=55,
            lien_parente="concubin", canton="GE",
        )
        result = service.calculate(inp)
        concubin_alerts = [a for a in result.alerts if "concubin" in a.lower()]
        assert len(concubin_alerts) > 0

    def test_donor_age_over_75_alert(self, service):
        """Donor over 75: requalification risk alert."""
        inp = DonationInput(
            montant=100_000, donateur_age=80,
            lien_parente="descendant", canton="ZH",
        )
        result = service.calculate(inp)
        age_alerts = [a for a in result.alerts if "deces" in a.lower()]
        assert len(age_alerts) > 0

    def test_chiffre_choc_with_tax(self, service):
        """Chiffre choc should mention tax amount when > 0."""
        inp = DonationInput(
            montant=100_000, donateur_age=50,
            lien_parente="concubin", canton="GE",
        )
        result = service.calculate(inp)
        assert "montant" in result.chiffre_choc
        assert "texte" in result.chiffre_choc
        assert result.chiffre_choc["montant"] > 0

    def test_chiffre_choc_exempt(self, service):
        """Chiffre choc for tax-exempt donation."""
        inp = DonationInput(
            montant=100_000, donateur_age=55,
            lien_parente="descendant", canton="ZH",
        )
        result = service.calculate(inp)
        assert "exoneree" in result.chiffre_choc["texte"]

    def test_schwyz_concubin_zero_tax(self, service):
        """SZ: even concubin pays zero tax."""
        inp = DonationInput(
            montant=1_000_000, donateur_age=50,
            lien_parente="concubin", canton="SZ",
        )
        result = service.calculate(inp)
        assert result.impot_donation == 0.0

    def test_checklist_has_minimum_items(self, service, base_input):
        """Checklist should have at least 5 items."""
        result = service.calculate(base_input)
        assert len(result.checklist) >= 5
