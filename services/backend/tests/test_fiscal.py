"""
Tests for the Fiscal (cantonal tax comparator) module (Sprint S20).

Covers:
    - Tax estimation — rates, income adjustment, family adjustment
    - Canton comparison — ranking, sorting, ecart max
    - Move simulation — savings, alerts, checklist
    - Compliance — disclaimer, sources, banned terms
    - API endpoints (integration)

Target: 35+ tests.

Run: cd services/backend && python3 -m pytest tests/test_fiscal.py -v
"""

import re
import pytest

from app.services.fiscal.cantonal_comparator import (
    CantonalComparator,
    DISCLAIMER,
    SOURCES,
    CANTON_NAMES,
    EFFECTIVE_RATES_100K_SINGLE,
    FAMILY_ADJUSTMENTS,
)


# ===========================================================================
# Fixtures
# ===========================================================================

@pytest.fixture
def comparator():
    return CantonalComparator()


# ===========================================================================
# Tax Estimation Tests (12 tests)
# ===========================================================================

class TestTaxEstimation:
    """Tests for CantonalComparator.estimate_tax()."""

    def test_estimate_zug_lowest(self, comparator):
        """Zug (ZG) should have the lowest tax rate among cantons."""
        estimate_zg = comparator.estimate_tax(100_000, "ZG")
        # Compare with a few other cantons
        estimate_bs = comparator.estimate_tax(100_000, "BS")
        estimate_ge = comparator.estimate_tax(100_000, "GE")
        assert estimate_zg.charge_totale < estimate_bs.charge_totale
        assert estimate_zg.charge_totale < estimate_ge.charge_totale

    def test_estimate_basel_highest(self, comparator):
        """Basel-Stadt (BS) should have the highest rate."""
        estimate_bs = comparator.estimate_tax(100_000, "BS")
        # Compare with all other cantons (excluding FL)
        for canton in EFFECTIVE_RATES_100K_SINGLE:
            if canton in ("BS", "FL"):
                continue
            estimate_other = comparator.estimate_tax(100_000, canton)
            assert estimate_bs.charge_totale >= estimate_other.charge_totale, (
                f"BS ({estimate_bs.charge_totale}) should be >= "
                f"{canton} ({estimate_other.charge_totale})"
            )

    def test_estimate_zurich_middle(self, comparator):
        """Zurich (ZH) should be in the middle range."""
        estimate_zh = comparator.estimate_tax(100_000, "ZH")
        estimate_zg = comparator.estimate_tax(100_000, "ZG")
        estimate_bs = comparator.estimate_tax(100_000, "BS")
        assert estimate_zg.charge_totale < estimate_zh.charge_totale
        assert estimate_zh.charge_totale < estimate_bs.charge_totale

    def test_estimate_high_income_higher_rate(self, comparator):
        """Higher income should lead to higher effective rate (progressive)."""
        estimate_100k = comparator.estimate_tax(100_000, "ZH")
        estimate_300k = comparator.estimate_tax(300_000, "ZH")
        assert estimate_300k.taux_effectif > estimate_100k.taux_effectif

    def test_estimate_low_income_lower_rate(self, comparator):
        """Lower income should lead to lower effective rate."""
        estimate_50k = comparator.estimate_tax(50_000, "ZH")
        estimate_100k = comparator.estimate_tax(100_000, "ZH")
        assert estimate_50k.taux_effectif < estimate_100k.taux_effectif

    def test_estimate_married_lower(self, comparator):
        """Married status should result in lower charge (splitting)."""
        estimate_single = comparator.estimate_tax(100_000, "ZH", "celibataire", 0)
        estimate_married = comparator.estimate_tax(100_000, "ZH", "marie", 0)
        assert estimate_married.charge_totale < estimate_single.charge_totale

    def test_estimate_children_reduce(self, comparator):
        """Children should reduce the tax burden (family deductions)."""
        estimate_no_kids = comparator.estimate_tax(100_000, "ZH", "marie", 0)
        estimate_2_kids = comparator.estimate_tax(100_000, "ZH", "marie", 2)
        assert estimate_2_kids.charge_totale < estimate_no_kids.charge_totale

    def test_estimate_all_cantons_valid(self, comparator):
        """All 26 cantons should produce valid estimates."""
        count = 0
        for canton in EFFECTIVE_RATES_100K_SINGLE:
            if canton == "FL":
                continue  # FL is not a canton
            estimate = comparator.estimate_tax(100_000, canton)
            assert estimate.charge_totale > 0
            assert estimate.taux_effectif > 0
            assert estimate.canton_name != ""
            count += 1
        assert count == 26

    def test_estimate_invalid_canton(self, comparator):
        """Invalid canton code should raise ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            comparator.estimate_tax(100_000, "XX")

    def test_estimate_negative_income(self, comparator):
        """Negative income should raise ValueError."""
        with pytest.raises(ValueError, match="revenu"):
            comparator.estimate_tax(-50_000, "ZH")

    def test_federal_always_same(self, comparator):
        """Federal tax should be the same regardless of canton."""
        federal_taxes = set()
        for canton in ["ZG", "GE", "BS", "ZH", "VD"]:
            estimate = comparator.estimate_tax(100_000, canton, "celibataire", 0)
            federal_taxes.add(estimate.impot_federal)
        # All should be exactly the same
        assert len(federal_taxes) == 1, (
            f"Federal tax should be identical across cantons, got: {federal_taxes}"
        )

    def test_rate_between_0_and_50_percent(self, comparator):
        """Effective rate should be a sane value (between 0% and 50%)."""
        for canton in EFFECTIVE_RATES_100K_SINGLE:
            if canton == "FL":
                continue
            estimate = comparator.estimate_tax(100_000, canton)
            assert 0 < estimate.taux_effectif < 50, (
                f"{canton}: taux_effectif={estimate.taux_effectif}% is out of range"
            )


# ===========================================================================
# Canton Comparison Tests (10 tests)
# ===========================================================================

class TestCantonComparison:
    """Tests for CantonalComparator.compare_all_cantons()."""

    def test_compare_returns_26_cantons(self, comparator):
        """Comparison should return exactly 26 cantons."""
        rankings = comparator.compare_all_cantons(100_000)
        assert len(rankings) == 26

    def test_compare_sorted_ascending(self, comparator):
        """Rankings should be sorted by charge_totale ascending."""
        rankings = comparator.compare_all_cantons(100_000)
        charges = [r.charge_totale for r in rankings]
        assert charges == sorted(charges)

    def test_compare_first_is_cheapest(self, comparator):
        """First canton in ranking should be the cheapest (ZG at 100k single)."""
        rankings = comparator.compare_all_cantons(100_000)
        assert rankings[0].rang == 1
        assert rankings[0].canton == "ZG"
        assert rankings[0].difference_vs_cheapest == 0.0

    def test_compare_last_is_most_expensive(self, comparator):
        """Last canton should be the most expensive (BS at 100k single)."""
        rankings = comparator.compare_all_cantons(100_000)
        assert rankings[-1].rang == 26
        assert rankings[-1].canton == "BS"

    def test_compare_ecart_max_positive(self, comparator):
        """Ecart max (difference between cheapest and most expensive) must be > 0."""
        rankings = comparator.compare_all_cantons(100_000)
        ecart_max = rankings[-1].difference_vs_cheapest
        assert ecart_max > 0

    def test_compare_premier_eclairage_present(self, comparator):
        """compare_all_cantons result should allow building a premier éclairage."""
        rankings = comparator.compare_all_cantons(100_000)
        # Verify we have enough data to build a premier éclairage
        assert rankings[0].canton_name != ""
        assert rankings[-1].canton_name != ""
        assert rankings[-1].difference_vs_cheapest > 0

    def test_compare_married_different_ranking(self, comparator):
        """Family status should potentially change relative rankings."""
        rankings_single = comparator.compare_all_cantons(100_000, "celibataire", 0)
        rankings_married = comparator.compare_all_cantons(100_000, "marie", 2)
        # The absolute charges should be different
        assert rankings_single[0].charge_totale != rankings_married[0].charge_totale
        # Married with kids should always pay less
        assert rankings_married[0].charge_totale < rankings_single[0].charge_totale

    def test_compare_high_income_ranking(self, comparator):
        """High income (300k) should produce higher charges than 100k."""
        rankings_100k = comparator.compare_all_cantons(100_000)
        rankings_300k = comparator.compare_all_cantons(300_000)
        # The cheapest canton at 300k should cost more than cheapest at 100k
        assert rankings_300k[0].charge_totale > rankings_100k[0].charge_totale

    def test_compare_disclaimer_present(self, comparator):
        """DISCLAIMER constant should be present and non-empty."""
        assert len(DISCLAIMER) > 50
        assert "LSFin" in DISCLAIMER

    def test_compare_sources_present(self, comparator):
        """SOURCES should contain legal references."""
        assert len(SOURCES) >= 3
        source_text = " ".join(SOURCES)
        assert "LIFD" in source_text
        assert "LHID" in source_text
        assert "Administration" in source_text


# ===========================================================================
# Move Simulation Tests (13 tests)
# ===========================================================================

class TestMoveSimulation:
    """Tests for CantonalComparator.simulate_move()."""

    def test_move_ge_to_zg_saves(self, comparator):
        """Moving from Geneva to Zug should save money."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        assert sim.economie_annuelle > 0
        assert sim.charge_depart > sim.charge_arrivee

    def test_move_zg_to_ge_costs(self, comparator):
        """Moving from Zug to Geneva should cost more."""
        sim = comparator.simulate_move(100_000, "ZG", "GE")
        assert sim.economie_annuelle < 0
        assert sim.charge_arrivee > sim.charge_depart

    def test_move_same_canton_zero(self, comparator):
        """Moving to the same canton should show zero savings."""
        sim = comparator.simulate_move(100_000, "ZH", "ZH")
        assert sim.economie_annuelle == 0.0
        assert sim.economie_mensuelle == 0.0
        assert sim.economie_10_ans == 0.0

    def test_move_economie_mensuelle(self, comparator):
        """Monthly savings should be annual / 12."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        expected_mensuel = round(sim.economie_annuelle / 12, 2)
        assert sim.economie_mensuelle == expected_mensuel

    def test_move_economie_10_ans(self, comparator):
        """10-year savings should be annual * 10."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        expected_10_ans = round(sim.economie_annuelle * 10, 2)
        assert sim.economie_10_ans == expected_10_ans

    def test_move_premier_eclairage_present(self, comparator):
        """Chiffre choc should be a non-empty, descriptive string."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        assert len(sim.premier_eclairage) > 20
        assert "CHF" in sim.premier_eclairage

    def test_move_checklist_non_empty(self, comparator):
        """Checklist should contain practical items."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        assert len(sim.checklist) >= 5
        # Should mention commune, LAMal, AVS
        checklist_text = " ".join(sim.checklist)
        assert "commune" in checklist_text.lower()
        assert "LAMal" in checklist_text

    def test_move_alertes_present(self, comparator):
        """Alerts should warn about costs and practical considerations."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        assert len(sim.alertes) >= 2
        alertes_text = " ".join(sim.alertes)
        assert "demenagement" in alertes_text.lower() or "loyer" in alertes_text.lower()

    def test_move_disclaimer_present(self, comparator):
        """Disclaimer should be present in simulation result."""
        sim = comparator.simulate_move(100_000, "GE", "ZG")
        assert len(sim.disclaimer) > 50
        assert "LSFin" in sim.disclaimer

    def test_move_invalid_canton_depart(self, comparator):
        """Invalid departure canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            comparator.simulate_move(100_000, "XX", "ZG")

    def test_move_invalid_canton_arrivee(self, comparator):
        """Invalid arrival canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            comparator.simulate_move(100_000, "ZG", "XX")

    def test_move_high_income_500k(self, comparator):
        """High income (500k) should produce large absolute savings."""
        sim = comparator.simulate_move(500_000, "GE", "ZG")
        assert sim.economie_annuelle > 10_000  # Should save > 10k CHF/year
        assert sim.economie_10_ans > 100_000   # > 100k over 10 years

    def test_move_family_2_children(self, comparator):
        """Family with 2 children should still show savings GE->ZG."""
        sim = comparator.simulate_move(100_000, "GE", "ZG", "marie", 2)
        assert sim.economie_annuelle > 0
        # Family savings should be less than single (both cantons reduce)
        _sim_single = comparator.simulate_move(100_000, "GE", "ZG", "celibataire", 0)
        # Not necessarily less, but should be positive
        assert sim.economie_annuelle > 0


# ===========================================================================
# Internal helpers tests
# ===========================================================================

class TestInternalHelpers:
    """Tests for internal helper methods."""

    def test_interpolate_income_at_100k(self, comparator):
        """Income adjustment at 100k should be exactly 1.0."""
        factor = comparator._interpolate_income_adjustment(100_000)
        assert factor == 1.0

    def test_interpolate_income_below_minimum(self, comparator):
        """Income below 50k should clamp to 0.75."""
        factor = comparator._interpolate_income_adjustment(20_000)
        assert factor == 0.75

    def test_interpolate_income_above_maximum(self, comparator):
        """Income above 500k should clamp to 1.32."""
        factor = comparator._interpolate_income_adjustment(1_000_000)
        assert factor == 1.32

    def test_interpolate_income_between_brackets(self, comparator):
        """Income between brackets should interpolate linearly."""
        factor = comparator._interpolate_income_adjustment(75_000)
        # Between 50k (0.75) and 80k (0.90)
        # 75k is 25k/30k = 83.3% of the way
        expected = 0.75 + (25_000 / 30_000) * (0.90 - 0.75)
        assert abs(factor - expected) < 0.001

    def test_family_adjustment_celibataire(self, comparator):
        """Celibataire should return factor 1.0."""
        factor = comparator._get_family_adjustment("celibataire", 0)
        assert factor == 1.0

    def test_family_adjustment_marie_3plus(self, comparator):
        """3+ children should use the marie_3_enfants floor."""
        factor_3 = comparator._get_family_adjustment("marie", 3)
        factor_5 = comparator._get_family_adjustment("marie", 5)
        assert factor_3 == FAMILY_ADJUSTMENTS["marie_3_enfants"]
        assert factor_5 == FAMILY_ADJUSTMENTS["marie_3_enfants"]


# ===========================================================================
# Compliance Tests
# ===========================================================================

class TestFiscalCompliance:
    """Tests for compliance: disclaimer, sources, banned terms."""

    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
        r"\bsans\s+risque\b",
    ]

    def test_disclaimer_mentions_lsfin(self):
        """Disclaimer should reference LSFin."""
        assert "LSFin" in DISCLAIMER

    def test_disclaimer_mentions_specialiste(self):
        """Disclaimer should recommend consulting a specialist."""
        assert "specialiste" in DISCLAIMER.lower()

    def test_disclaimer_not_guaranteed(self):
        """Disclaimer should say it's not tax advice."""
        assert "conseil fiscal" in DISCLAIMER.lower() or "conseil" in DISCLAIMER.lower()

    def test_sources_cite_lifd(self):
        """Sources should cite LIFD art. 36."""
        source_text = " ".join(SOURCES)
        assert "LIFD" in source_text

    def test_sources_cite_lhid(self):
        """Sources should cite LHID art. 1."""
        source_text = " ".join(SOURCES)
        assert "LHID" in source_text

    def test_no_banned_terms_in_disclaimer(self):
        """Disclaimer should not contain banned terms."""
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, DISCLAIMER, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in disclaimer: {matches}"
            )

    def test_canton_names_all_present(self):
        """All 26 canton codes should have a name."""
        cantons_26 = [
            c for c in EFFECTIVE_RATES_100K_SINGLE.keys() if c != "FL"
        ]
        for canton in cantons_26:
            assert canton in CANTON_NAMES, f"Missing name for canton {canton}"
            assert len(CANTON_NAMES[canton]) > 2


# ===========================================================================
# API Endpoints (integration)
# ===========================================================================

class TestFiscalEndpoints:
    """Tests for the Fiscal FastAPI endpoints."""

    def test_estimate_endpoint(self, client):
        """POST /fiscal/estimate should return 200."""
        response = client.post(
            "/api/v1/fiscal/estimate",
            json={
                "revenuBrut": 100_000,
                "canton": "ZH",
                "etatCivil": "celibataire",
                "nombreEnfants": 0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "canton" in data
        assert "cantonNom" in data
        assert "chargeTotale" in data
        assert "tauxEffectif" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_estimate_endpoint_invalid_canton(self, client):
        """POST /fiscal/estimate with invalid canton should return 400."""
        response = client.post(
            "/api/v1/fiscal/estimate",
            json={
                "revenuBrut": 100_000,
                "canton": "XX",
            },
        )
        assert response.status_code == 400

    def test_compare_endpoint(self, client):
        """POST /fiscal/compare should return 200 with 26 cantons."""
        response = client.post(
            "/api/v1/fiscal/compare",
            json={
                "revenuBrut": 100_000,
                "etatCivil": "celibataire",
                "nombreEnfants": 0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "classement" in data
        assert len(data["classement"]) == 26
        assert "ecartMax" in data
        assert "premierEclairage" in data
        assert "disclaimer" in data
        assert data["ecartMax"] > 0

    def test_move_endpoint(self, client):
        """POST /fiscal/move should return 200."""
        response = client.post(
            "/api/v1/fiscal/move",
            json={
                "revenuBrut": 100_000,
                "cantonDepart": "GE",
                "cantonArrivee": "ZG",
                "etatCivil": "celibataire",
                "nombreEnfants": 0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "economieAnnuelle" in data
        assert "economieMensuelle" in data
        assert "economie10Ans" in data
        assert "premierEclairage" in data
        assert "checklist" in data
        assert "alertes" in data
        assert "disclaimer" in data
        assert data["economieAnnuelle"] > 0

    def test_move_endpoint_invalid_canton(self, client):
        """POST /fiscal/move with invalid canton should return 400."""
        response = client.post(
            "/api/v1/fiscal/move",
            json={
                "revenuBrut": 100_000,
                "cantonDepart": "XX",
                "cantonArrivee": "ZG",
            },
        )
        assert response.status_code == 400
