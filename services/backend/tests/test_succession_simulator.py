"""
Tests for SuccessionSimulator (P0 — legal compliance).

Covers:
    - Reserves hereditaires: spouse 50%, children share 50% (CC art. 471)
    - No children: spouse 75%, parents 25%
    - Concubinage: partner gets 0% by law
    - Edge cases: 1 child, 5+ children, no heirs
    - 2023 law revision: parents reserve removed
    - Quotite disponible computation

Run: cd services/backend && python3 -m pytest tests/test_succession_simulator.py -v
"""

import pytest

from app.services.succession_simulator import SuccessionSimulator, SuccessionInput


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def simulator():
    return SuccessionSimulator()


def _base_input(**overrides) -> SuccessionInput:
    """Create a default SuccessionInput."""
    defaults = dict(
        fortune_totale=1_000_000,
        etat_civil="marie",
        a_conjoint=True,
        nombre_enfants=2,
        a_parents_vivants=False,
        a_fratrie=False,
        a_concubin=False,
        a_testament=False,
        canton="GE",
    )
    defaults.update(overrides)
    return SuccessionInput(**defaults)


# ---------------------------------------------------------------------------
# Legal Distribution Tests (CC art. 457-462)
# ---------------------------------------------------------------------------

class TestLegalDistribution:

    def test_married_with_children(self, simulator):
        """Married + children: spouse 50%, children share 50%."""
        data = _base_input(nombre_enfants=2)
        result = simulator.simulate(data)
        leg = result.repartition_legale
        assert leg["conjoint_part_pct"] == 0.5
        assert leg["enfants_part_pct"] == 0.5
        assert leg["conjoint_montant"] == 500_000
        assert leg["enfants_montant_total"] == 500_000
        assert leg["enfant_montant_chacun"] == 250_000

    def test_married_no_children_parents_alive(self, simulator):
        """Married, no children, parents alive: spouse 75%, parents 25%."""
        data = _base_input(nombre_enfants=0, a_parents_vivants=True)
        result = simulator.simulate(data)
        leg = result.repartition_legale
        assert leg["conjoint_part_pct"] == 0.75
        assert leg["parents_part_pct"] == 0.25
        assert leg["conjoint_montant"] == 750_000
        assert leg["parents_montant"] == 250_000

    def test_married_no_children_no_parents(self, simulator):
        """Married, no children, no parents: spouse gets everything."""
        data = _base_input(nombre_enfants=0, a_parents_vivants=False)
        result = simulator.simulate(data)
        leg = result.repartition_legale
        assert leg["conjoint_part_pct"] == 1.0
        assert leg["conjoint_montant"] == 1_000_000

    def test_concubin_gets_zero_by_law(self, simulator):
        """Concubin gets 0% — no automatic inheritance rights."""
        data = _base_input(
            etat_civil="concubin",
            a_conjoint=False,
            a_concubin=True,
            nombre_enfants=2,
        )
        result = simulator.simulate(data)
        leg = result.repartition_legale
        assert leg["conjoint_part_pct"] == 0.0
        assert leg["conjoint_montant"] == 0.0
        # Children get everything
        assert leg["enfants_part_pct"] == 1.0

    def test_single_one_child(self, simulator):
        """Single with 1 child: child gets 100%."""
        data = _base_input(
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=1,
        )
        result = simulator.simulate(data)
        leg = result.repartition_legale
        assert leg["enfants_part_pct"] == 1.0
        assert leg["enfant_montant_chacun"] == 1_000_000

    def test_five_children_equal_share(self, simulator):
        """5 children share equally."""
        data = _base_input(nombre_enfants=5)
        result = simulator.simulate(data)
        leg = result.repartition_legale
        # Children share 50% (married), so each gets 10%
        assert leg["enfant_montant_chacun"] == pytest.approx(100_000, abs=1)


# ---------------------------------------------------------------------------
# Reserves Hereditaires Tests (CC art. 470-471, 2023 revision)
# ---------------------------------------------------------------------------

class TestReservesHereditaires:

    def test_spouse_reserve_half_of_legal_share(self, simulator):
        """Spouse reserve = 1/2 of their legal share."""
        data = _base_input(nombre_enfants=2)
        result = simulator.simulate(data)
        res = result.reserves_hereditaires
        # Spouse legal share = 50%, reserve = 50% * 50% = 25%
        assert res["conjoint_reserve_pct"] == 0.25
        assert res["conjoint_reserve_montant"] == 250_000

    def test_descendants_reserve_2023(self, simulator):
        """Descendants reserve = 1/2 of legal share (2023 law, was 3/4)."""
        data = _base_input(nombre_enfants=2)
        result = simulator.simulate(data)
        res = result.reserves_hereditaires
        # Children legal share = 50%, reserve = 50% * 50% = 25%
        assert res["enfants_reserve_pct"] == 0.25
        assert res["enfants_reserve_montant"] == 250_000

    def test_parents_reserve_removed_2023(self, simulator):
        """Parents reserve = 0 since 2023 revision."""
        data = _base_input(nombre_enfants=0, a_parents_vivants=True)
        result = simulator.simulate(data)
        res = result.reserves_hereditaires
        assert res["parents_reserve_pct"] == 0.0
        assert res["parents_reserve_montant"] == 0.0

    def test_quotite_disponible(self, simulator):
        """Quotite disponible = estate - total reserves."""
        data = _base_input(nombre_enfants=2)
        result = simulator.simulate(data)
        # Total reserves = 25% (spouse) + 25% (children) = 50% = 500k
        assert result.quotite_disponible == 500_000


# ---------------------------------------------------------------------------
# Concubin Alerts
# ---------------------------------------------------------------------------

class TestConcubinAlerts:

    def test_concubin_alert_present(self, simulator):
        """Concubin alert warns about lack of inheritance rights."""
        data = _base_input(
            etat_civil="concubin",
            a_conjoint=False,
            a_concubin=True,
            nombre_enfants=0,
            a_parents_vivants=True,
        )
        result = simulator.simulate(data)
        assert "AUCUN droit" in result.alerte_concubin

    def test_no_concubin_alert_when_married(self, simulator):
        """No concubin alert for married individuals."""
        data = _base_input(a_concubin=False)
        result = simulator.simulate(data)
        assert result.alerte_concubin == ""


# ---------------------------------------------------------------------------
# Edge Cases + Compliance
# ---------------------------------------------------------------------------

class TestSuccessionEdgeCases:

    def test_no_heirs_canton_inherits(self, simulator):
        """No heirs at all: canton inherits (CC art. 466)."""
        data = _base_input(
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=0,
            a_parents_vivants=False,
            a_fratrie=False,
        )
        result = simulator.simulate(data)
        leg = result.repartition_legale
        assert leg["canton_part_pct"] == 1.0
        assert leg["canton_montant"] == 1_000_000

    def test_disclaimer_present(self, simulator):
        """Result includes compliance disclaimer."""
        result = simulator.simulate(_base_input())
        assert "educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_3a_beneficiary_order(self, simulator):
        """OPP3 art. 2 beneficiary order is returned."""
        result = simulator.simulate(_base_input())
        assert len(result.ordre_3a_opp3) >= 5
        assert any("Conjoint" in item for item in result.ordre_3a_opp3)
