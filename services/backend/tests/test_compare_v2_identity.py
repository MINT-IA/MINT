"""Migration de l'écran comparaison cantonale sur le modèle v2.

``CantonalComparator.estimate_tax`` (et donc ``comparer_cantons`` /
``simuler_demenagement``, l'écran comparaison + coach) était le DERNIER
consommateur du bloc déprécié ``EFFECTIVE_RATES_100K_SINGLE`` (verdict C :
taux plat 100k x facteur quasi quadratique — différences d'impôt fausses,
taux marginal implicite 47.5% à 140k VD). Ce module verrouille l'identité
avec le modèle canonique v2 ``estimate_income_tax`` (130 points ESTV) :
le chiffre servi ne doit pas dépendre de la surface (RvC vs comparaison).
"""

import pytest

from app.services.fiscal.cantonal_comparator import (
    CANTONAL_COMMUNAL_TAX_CHF,
    CantonalComparator,
    estimate_income_tax,
    simuler_demenagement,
)


@pytest.fixture
def comparator():
    return CantonalComparator()


def test_estimate_tax_identity_with_v2_single(comparator):
    """charge_totale == modèle v2 sur le revenu imposable (85% du brut)."""
    for canton in ("ZH", "VD", "GE", "ZG"):
        est = comparator.estimate_tax(100_000, canton)
        assert est.charge_totale == pytest.approx(
            estimate_income_tax(85_000, canton), abs=0.02
        ), canton


def test_estimate_tax_identity_with_v2_married(comparator):
    """Marié sans enfant : convention canonique v2 (x0.80), pas un
    barème fédéral splitting maison + facteur 0.85 séparé."""
    est = comparator.estimate_tax(140_000, "VD", "marie", 0)
    assert est.charge_totale == pytest.approx(
        estimate_income_tax(140_000 * 0.85, "VD", is_married=True), abs=0.02
    )


def test_parts_sum_to_total(comparator):
    """fédéral + cantonal/communal == charge_totale (au centime)."""
    for civil in ("celibataire", "marie"):
        est = comparator.estimate_tax(120_000, "BE", civil, 0)
        assert est.impot_federal + est.impot_cantonal_communal == pytest.approx(
            est.charge_totale, abs=0.02
        )


def test_children_reduce_relative_to_married(comparator):
    """Enfants : réduction supplémentaire par rapport à marié sans enfant."""
    base = comparator.estimate_tax(100_000, "ZH", "marie", 0)
    two = comparator.estimate_tax(100_000, "ZH", "marie", 2)
    assert two.charge_totale < base.charge_totale


def test_fl_still_accepted_with_average_fallback(comparator):
    """FL (Liechtenstein) reste accepté — fallback moyenne 26 cantons,
    documenté (compat API : l'ancienne table le listait)."""
    est = comparator.estimate_tax(100_000, "FL")
    assert est.charge_totale > 0


def test_compare_all_cantons_still_26(comparator):
    rankings = comparator.compare_all_cantons(100_000)
    assert len(rankings) == 26
    assert rankings[0].canton == "ZG", "ZG le plus bas à 100k (ESTV v2)"
    assert rankings[-1].canton == "BS", "BS le plus haut à 100k (ESTV v2)"


def test_simulate_move_is_v2_difference():
    sim = simuler_demenagement(100_000, "GE", "ZG")
    expected = estimate_income_tax(85_000, "GE") - estimate_income_tax(
        85_000, "ZG"
    )
    assert sim["economie_annuelle"] == pytest.approx(expected, abs=0.05)


def test_effective_rates_table_removed():
    """Le bloc déprécié est bien supprimé — plus aucun consommateur."""
    import app.services.fiscal.cantonal_comparator as mod

    assert not hasattr(mod, "EFFECTIVE_RATES_100K_SINGLE")
