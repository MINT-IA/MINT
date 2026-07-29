"""Recalibrage capital MARIÉ — étalon ESTV (triage AnnAssign #1095).

Prouve que l'impôt capital marié est dérivé de la table ÉTALON
``CANTONAL_CAPITAL_TAX_MARRIED_CHF`` (collecte ESTV API_calculateManyCapitalTaxes,
état civil marié) par interpolation — comme le célibataire — et NON plus du
rabais forfaitaire inventé ``MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON`` (8/26 +
FALLBACK 0.82), supprimé.

Données brutes : .planning/audit-etat-des-lieux-2026-07/constants-audit/
capital_marie_2026/ (consolidated.json + raw_married.json + README).
"""

import json
from pathlib import Path

import pytest

import app.constants.social_insurance as si
from app.services.fiscal.cantonal_comparator import (
    CANTONAL_CAPITAL_TAX_CHF,
    CANTONAL_CAPITAL_TAX_MARRIED_CHF,
    CAPITAL_TAX_POINTS_AMOUNT,
    estimate_capital_withdrawal_tax,
)

REPO_ROOT = Path(__file__).resolve().parents[3]
ARCHIVE = (
    REPO_ROOT
    / ".planning/audit-etat-des-lieux-2026-07/constants-audit"
    / "capital_marie_2026/consolidated.json"
)
_ARCH = json.loads(ARCHIVE.read_text(encoding="utf-8"))
_MARIE = _ARCH["points_chf_marie"]
_IFD_MARIE = _ARCH["ifd_marie_par_montant"]
_AMOUNTS = [str(a) for a in CAPITAL_TAX_POINTS_AMOUNT]

CANTONS = sorted(CANTONAL_CAPITAL_TAX_MARRIED_CHF)


# ── Parité archive ↔ table générée, point par point ──────────────────────────
@pytest.mark.parametrize("canton", CANTONS)
def test_married_table_matches_estv_archive(canton):
    """La table étalon == la collecte ESTV mariée archivée, au CHF près."""
    table = CANTONAL_CAPITAL_TAX_MARRIED_CHF[canton]
    for i, amount in enumerate(_AMOUNTS):
        assert table[i] == _MARIE[canton][amount], (
            f"{canton}@{amount}: table {table[i]} != archive ESTV "
            f"{_MARIE[canton][amount]}"
        )


def test_married_table_covers_26_cantons_full_grid():
    assert len(CANTONAL_CAPITAL_TAX_MARRIED_CHF) == 26
    assert set(CANTONAL_CAPITAL_TAX_MARRIED_CHF) == set(CANTONAL_CAPITAL_TAX_CHF)
    # Grille 7 noeuds (175k/350k ajoutés CAP-1 #1098).
    assert len(CAPITAL_TAX_POINTS_AMOUNT) == 7
    for c, pts in CANTONAL_CAPITAL_TAX_MARRIED_CHF.items():
        assert len(pts) == len(CAPITAL_TAX_POINTS_AMOUNT), c


# ── L'étalon reproduit le TOTAL marié ESTV (cantonal + IFD) aux grilles ──────
@pytest.mark.parametrize("canton", CANTONS)
def test_married_total_matches_estv_at_grid_points(canton):
    """À un point de grille, impôt marié == min(cantonal_marié + IFD_marié
    ESTV, célibataire). Les DEUX parts (cantonale ET IFD art. 38 al. 2) sont
    l'étalon marié ESTV. La borne min() ne mord qu'à SO 1M (arrondi ESTV
    +1 CHF, documenté)."""
    for i, amount_s in enumerate(_AMOUNTS):
        amount = float(amount_s)
        single = estimate_capital_withdrawal_tax(amount, canton)
        married = estimate_capital_withdrawal_tax(amount, canton, is_married=True)
        estv_married = round(
            min(_MARIE[canton][amount_s] + _IFD_MARIE[amount_s][0], single), 2
        )
        assert married == pytest.approx(estv_married, abs=0.02), (
            f"{canton}@{amount}: {married} != ESTV marié {estv_married}"
        )
        # IFD marié < célibataire (sauf 1M égal) -> marié < célibataire aux
        # cantons sans réduction cantonale AUSSI (ex. BS/LU) via le fédéral.
        assert married <= single + 0.01


# ── Invariant de sanité : marié ≤ célibataire sur toute la grille ────────────
@pytest.mark.parametrize("canton", CANTONS)
def test_married_not_higher_than_single(canton):
    """Marié ≤ célibataire à ±1 CHF (SO : l'ESTV arrondit le marié +1 CHF
    à 750k/1M, sans réduction — artefact d'arrondi, documenté)."""
    for amount_s in _AMOUNTS:
        amount = float(amount_s)
        single = estimate_capital_withdrawal_tax(amount, canton)
        married = estimate_capital_withdrawal_tax(amount, canton, is_married=True)
        assert married <= single + 1.0, f"{canton}@{amount}: {married} > {single}"


# ── Suppression prouvée du rabais forfaitaire inventé ────────────────────────
def test_married_discount_by_canton_table_removed():
    assert not hasattr(si, "MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON")
    assert not hasattr(si, "MARRIED_CAPITAL_TAX_DISCOUNT_FALLBACK")
    assert not hasattr(si, "married_capital_tax_discount_for")


def test_no_married_fallback_literal_in_module():
    """Plus aucun FALLBACK marié forfaitaire dans le module constants."""
    src = Path(si.__file__).read_text(encoding="utf-8")
    assert "MARRIED_CAPITAL_TAX_DISCOUNT_FALLBACK" not in src
    assert "MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON" not in src
    assert "married_capital_tax_discount_for" not in src
