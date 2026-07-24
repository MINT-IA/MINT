"""couple_optimizer sur le modèle fiscal v2 (beads MINT_nosync-5up).

La copie privée du pattern v1 (« taux effectif 100k x facteur revenu »,
supprimé de cantonal_comparator par PR #997) est remplacée par le modèle
canonique. Identités verrouillées + tombstone des tables v1.
"""

import pytest

import app.services.couple_optimizer.couple_optimizer as co
from app.services.fiscal.cantonal_comparator import estimate_income_tax


def test_v1_tables_removed():
    """Tombstone : les tables privées v1 sont supprimées du module."""
    assert not hasattr(co, "_EFFECTIVE_RATES_100K")
    assert not hasattr(co, "_INCOME_ADJUSTMENT")
    assert not hasattr(co, "_interpolate_income_adjustment")


def test_tax_saving_is_exact_v2_difference():
    saving = co._estimate_tax_saving(140_000, 12_000, "VD")
    expected = estimate_income_tax(140_000, "VD") - estimate_income_tax(
        128_000, "VD"
    )
    assert saving == pytest.approx(expected, abs=0.01)


def test_marginal_rate_is_v2_local_slope():
    rate = co._estimate_marginal_rate(140_000, "VD")
    expected = (
        estimate_income_tax(140_000, "VD")
        - estimate_income_tax(139_000, "VD")
    ) / 1000
    assert rate == pytest.approx(expected, abs=1e-9)
    assert 0.0 <= rate <= 0.50


def test_marginal_low_income_follows_v2_slope():
    """Bas revenu : la marginale suit la pente du modèle v2 — y compris
    sa limite DITE (segment linéaire depuis (0,0) sous 40k : ~14% à 8k
    VD, artefact d'interpolation documenté dans estimate_income_tax,
    pas un plancher artificiel ajouté par ce module). L'ancien clamp
    [0.05, 0.45] est remplacé par [0.0, 0.50]."""
    rate = co._estimate_marginal_rate(8_000, "VD")
    expected = (
        estimate_income_tax(8_000, "VD") - estimate_income_tax(7_000, "VD")
    ) / 1000
    assert rate == pytest.approx(expected, abs=1e-9)


def test_monthly_tax_is_v2_over_12():
    monthly = co._estimate_monthly_income_tax(
        120_000, "GE", etat_civil="marie", nombre_enfants=0
    )
    expected = estimate_income_tax(120_000, "GE", is_married=True) / 12
    assert monthly == pytest.approx(expected, abs=0.01)


def test_children_ratio_reduces_married_tax():
    base = co._estimate_monthly_income_tax(
        120_000, "GE", etat_civil="marie", nombre_enfants=0
    )
    kids = co._estimate_monthly_income_tax(
        120_000, "GE", etat_civil="marie", nombre_enfants=2
    )
    assert kids == pytest.approx(
        base * co._FAMILY_ADJUSTMENT["marie_2_enfants"]
        / co._FAMILY_ADJUSTMENT["marie_sans_enfant"],
        abs=0.01,
    )
