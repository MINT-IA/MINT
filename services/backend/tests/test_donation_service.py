"""
Tests for DonationService — additional coverage (P0).

The existing test_donation.py covers 44 tests. This file adds targeted tests
for tax rates, reserve computation, quotite disponible, and edge cases
not covered there.

Run: cd services/backend && python3 -m pytest tests/test_donation_service.py -v
"""

import pytest

from app.services.donation_service import (
    DonationService,
    DonationInput,
    TAUX_DONATION_DEFAULT,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def service():
    return DonationService()


def _base_input(**overrides) -> DonationInput:
    defaults = dict(
        montant=100_000,
        donateur_age=55,
        lien_parente="descendant",
        canton="GE",
        fortune_totale_donateur=1_000_000,
        nb_enfants=2,
        has_spouse=True,
        has_parents=False,
    )
    defaults.update(overrides)
    return DonationInput(**defaults)


# ---------------------------------------------------------------------------
# Tax Rate Tests
# ---------------------------------------------------------------------------

class TestDonationTax:

    def test_zero_donation_returns_zero_tax(self, service):
        """Donation of 0 CHF returns 0 tax."""
        data = _base_input(montant=0)
        result = service.calculate(data)
        assert result.impot_donation == 0

    def test_descendant_exempt_ge(self, service):
        """Donation to descendant in GE is tax-exempt."""
        data = _base_input(lien_parente="descendant", canton="GE")
        result = service.calculate(data)
        assert result.taux_imposition == 0.0
        assert result.impot_donation == 0.0

    def test_concubin_taxed_ge(self, service):
        """Donation to concubin in GE is taxed at 24%."""
        data = _base_input(lien_parente="concubin", canton="GE", montant=100_000)
        result = service.calculate(data)
        assert result.taux_imposition == 0.24
        assert result.impot_donation == 24_000

    def test_sz_canton_zero_tax_for_all(self, service):
        """Canton SZ has no donation tax for any relationship."""
        for lien in ("conjoint", "descendant", "concubin", "tiers"):
            data = _base_input(lien_parente=lien, canton="SZ")
            result = service.calculate(data)
            assert result.impot_donation == 0.0

    def test_unknown_canton_uses_default(self, service):
        """Unknown canton falls back to default rates."""
        data = _base_input(lien_parente="fratrie", canton="XX")
        result = service.calculate(data)
        assert result.taux_imposition == TAUX_DONATION_DEFAULT["fratrie"]


# ---------------------------------------------------------------------------
# Reserve + Quotite Disponible Tests
# ---------------------------------------------------------------------------

class TestDonationReserves:

    def test_donation_within_quotite(self, service):
        """Donation within quotite disponible: no depassement."""
        # Spouse + 2 children: reserves = 25% + 25% = 50%, QD = 500k
        data = _base_input(montant=400_000, fortune_totale_donateur=1_000_000)
        result = service.calculate(data)
        assert not result.donation_depasse_quotite
        assert result.montant_depassement == 0

    def test_donation_exceeds_quotite(self, service):
        """Donation exceeding quotite disponible flagged."""
        # QD = 500k, donation = 600k
        data = _base_input(montant=600_000, fortune_totale_donateur=1_000_000)
        result = service.calculate(data)
        assert result.donation_depasse_quotite is True
        assert result.montant_depassement == 100_000

    def test_no_fortune_no_depassement_check(self, service):
        """If fortune_totale_donateur=0, depassement check is skipped."""
        data = _base_input(montant=50_000, fortune_totale_donateur=0)
        result = service.calculate(data)
        assert not result.donation_depasse_quotite


# ---------------------------------------------------------------------------
# Compliance
# ---------------------------------------------------------------------------

class TestDonationCompliance:

    def test_disclaimer_present(self, service):
        """Result includes compliance disclaimer."""
        result = service.calculate(_base_input())
        assert "educatif" in result.disclaimer.lower()

    def test_sources_present(self, service):
        """Result includes legal sources."""
        result = service.calculate(_base_input())
        assert len(result.sources) >= 3
        assert any("CC art." in s for s in result.sources)

    def test_premier_eclairage_present(self, service):
        """Result includes a premier éclairage."""
        result = service.calculate(_base_input())
        assert "montant" in result.premier_eclairage
        assert "texte" in result.premier_eclairage
