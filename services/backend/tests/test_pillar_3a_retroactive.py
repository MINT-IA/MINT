"""Tests for retroactive 3a catch-up calculator (S52).

Validates the NEW 2026 law allowing up to 10 years of retroactive
Pillar 3a contributions with full tax deductibility.
"""

import pytest

from app.services.pillar_3a_deep.retroactive_3a_service import (
    HISTORICAL_3A_LIMITS,
    MAX_RETROACTIVE_YEARS,
    calculate_retroactive_3a,
)


class TestRetroactive3aBasic:
    """Core calculation logic."""

    def test_10_year_gap_sums_correctly(self):
        """10-year gap should sum historical limits from 2016-2025."""
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        expected = sum(
            HISTORICAL_3A_LIMITS.get(2026 - i, 6768.0) for i in range(1, 11)
        )
        assert abs(result.total_retroactive - expected) < 0.01

    def test_5_year_gap_sums_correctly(self):
        """5-year gap should sum limits from 2021-2025."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.30)
        expected = sum(
            HISTORICAL_3A_LIMITS.get(2026 - i, 6768.0) for i in range(1, 6)
        )
        assert abs(result.total_retroactive - expected) < 0.01

    def test_1_year_gap_single_limit(self):
        """1-year gap = single year limit (2025)."""
        result = calculate_retroactive_3a(gap_years=1, taux_marginal=0.25)
        assert result.total_retroactive == HISTORICAL_3A_LIMITS[2025]
        assert result.gap_years == 1

    def test_tax_savings_equals_total_times_rate(self):
        """economies_fiscales = total_retroactive * taux_marginal."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.30)
        expected = result.total_retroactive * 0.30
        assert abs(result.economies_fiscales - expected) < 0.01

    def test_current_year_not_in_retroactive(self):
        """Current year (2026) is NOT included in retroactive total."""
        result = calculate_retroactive_3a(gap_years=3, taux_marginal=0.25)
        years_in_breakdown = [e.year for e in result.breakdown]
        assert 2026 not in years_in_breakdown
        assert result.total_current_year == 7258.0

    def test_total_contribution_equals_retroactive_plus_current(self):
        """total_contribution = total_retroactive + total_current_year."""
        result = calculate_retroactive_3a(gap_years=7, taux_marginal=0.30)
        assert abs(
            result.total_contribution
            - (result.total_retroactive + result.total_current_year)
        ) < 0.01


class TestRetroactive3aEdgeCases:
    """Boundary conditions and edge cases."""

    def test_gap_years_clamped_to_max_10(self):
        """Gap years > 10 should be clamped to 10."""
        result = calculate_retroactive_3a(gap_years=15, taux_marginal=0.30)
        assert result.gap_years == MAX_RETROACTIVE_YEARS
        assert len(result.breakdown) == MAX_RETROACTIVE_YEARS

    def test_gap_years_clamped_to_min_1(self):
        """Gap years < 1 should be clamped to 1."""
        result = calculate_retroactive_3a(gap_years=0, taux_marginal=0.30)
        assert result.gap_years == 1
        assert len(result.breakdown) == 1

    def test_zero_taux_marginal_no_savings(self):
        """Zero marginal rate → zero tax savings."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.0)
        assert result.economies_fiscales == 0.0

    def test_max_taux_marginal(self):
        """50% marginal rate → half of retroactive as savings."""
        result = calculate_retroactive_3a(gap_years=3, taux_marginal=0.50)
        assert abs(
            result.economies_fiscales - result.total_retroactive * 0.50
        ) < 0.01

    def test_breakdown_count_matches_gap_years(self):
        """Breakdown should have exactly gap_years entries."""
        for gap in [1, 3, 5, 7, 10]:
            result = calculate_retroactive_3a(gap_years=gap, taux_marginal=0.25)
            assert len(result.breakdown) == gap


class TestRetroactive3aSansLpp:
    """Tests for independents without LPP (grand 3a)."""

    def test_sans_lpp_limits_higher(self):
        """Sans LPP limits should be proportionally higher."""
        with_lpp = calculate_retroactive_3a(
            gap_years=5, taux_marginal=0.30, has_lpp=True
        )
        sans_lpp = calculate_retroactive_3a(
            gap_years=5, taux_marginal=0.30, has_lpp=False
        )
        assert sans_lpp.total_retroactive > with_lpp.total_retroactive
        assert sans_lpp.total_current_year == 36288.0

    def test_sans_lpp_current_year_is_grand_3a(self):
        """Current year for sans LPP should be grand 3a limit."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.30, has_lpp=False
        )
        assert result.total_current_year == 36288.0


class TestRetroactive3aCompliance:
    """Compliance and output format."""

    def test_chiffre_choc_contains_key_elements(self):
        """Chiffre choc must contain year count and CHF amount."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.30)
        assert "5" in result.chiffre_choc
        assert "CHF" in result.chiffre_choc
        assert "2026" in result.chiffre_choc

    def test_disclaimer_present(self):
        """Disclaimer must be present and mention educational tool."""
        result = calculate_retroactive_3a(gap_years=1, taux_marginal=0.25)
        assert "ducatif" in result.disclaimer
        assert "OPP3" in result.disclaimer

    def test_sources_contain_legal_refs(self):
        """Sources must reference OPP3 and LIFD."""
        result = calculate_retroactive_3a(gap_years=1, taux_marginal=0.25)
        sources_text = " ".join(result.sources)
        assert "OPP3" in sources_text
        assert "LIFD" in sources_text

    def test_no_banned_terms_in_chiffre_choc(self):
        """Chiffre choc must not contain banned terms."""
        banned = ["garanti", "certain", "assur", "sans risque", "optimal", "meilleur"]
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        lower = result.chiffre_choc.lower()
        for term in banned:
            assert term not in lower, f"Banned term '{term}' found in chiffre choc"


class TestRetroactive3aGoldenProfiles:
    """Golden test profiles from CLAUDE.md."""

    def test_julien_10_year_catchup(self):
        """Julien: 49, VS, swiss_native, 35% marginal, 10-year gap."""
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        assert result.gap_years == 10
        assert result.total_retroactive > 68_000  # ~68.9k
        assert result.economies_fiscales > 24_000  # ~24.1k

    def test_lauren_5_year_catchup(self):
        """Lauren: 43, US/FATCA, VD, 25% marginal, 5-year gap."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.25)
        assert result.gap_years == 5
        assert result.economies_fiscales > 8_000  # ~8.7k

    def test_marco_independent_3_year(self):
        """Marco: 24, TI, independent sans LPP, 20% marginal, 3-year gap."""
        result = calculate_retroactive_3a(
            gap_years=3, taux_marginal=0.20, has_lpp=False
        )
        assert result.gap_years == 3
        assert result.total_retroactive > 100_000  # Grand 3a limits
        assert result.total_current_year == 36_288.0


class TestRetroactive3aParityFixes:
    """Parity fixes with Flutter — income cap + taux clamping (635c3c0)."""

    def test_sans_lpp_income_cap_applied(self):
        """Sans LPP with revenu_net_annuel applies 20% income cap."""
        result = calculate_retroactive_3a(
            gap_years=3, taux_marginal=0.30, has_lpp=False,
            revenu_net_annuel=80_000,
        )
        # 20% of 80K = 16K per year, well below grand limit (~34-36K)
        for entry in result.breakdown:
            assert abs(entry.limit - 16_000) < 1.0
        assert abs(result.total_retroactive - 48_000) < 10.0

    def test_sans_lpp_income_cap_current_year(self):
        """Sans LPP current year also respects 20% income cap."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.25, has_lpp=False,
            revenu_net_annuel=80_000,
        )
        assert result.total_current_year == 16_000.0

    def test_sans_lpp_high_income_uses_grand_limit(self):
        """Sans LPP with very high income: capped at grand limit, not 20%."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.25, has_lpp=False,
            revenu_net_annuel=500_000,  # 20% = 100K > grand limit ~36K
        )
        assert result.total_current_year == 36_288.0

    def test_sans_lpp_zero_income(self):
        """Sans LPP with zero income → zero limit."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.25, has_lpp=False,
            revenu_net_annuel=0,
        )
        assert result.total_retroactive == 0.0
        assert result.total_current_year == 0.0

    def test_taux_marginal_clamped_to_60_percent(self):
        """Taux marginal > 0.60 clamped to 0.60 (prevent absurd results)."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=1.50)
        # Should be clamped to 0.60, not produce savings > total
        assert result.economies_fiscales <= result.total_retroactive * 0.61

    def test_negative_taux_marginal_clamped_to_zero(self):
        """Negative taux marginal clamped to 0."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=-0.50)
        assert result.economies_fiscales == 0.0
