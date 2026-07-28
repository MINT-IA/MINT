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


def test_married_table_covers_26_cantons_5_points():
    assert len(CANTONAL_CAPITAL_TAX_MARRIED_CHF) == 26
    assert set(CANTONAL_CAPITAL_TAX_MARRIED_CHF) == set(CANTONAL_CAPITAL_TAX_CHF)
    for c, pts in CANTONAL_CAPITAL_TAX_MARRIED_CHF.items():
        assert len(pts) == len(CAPITAL_TAX_POINTS_AMOUNT), c


# ── L'étalon interpole la table mariée (pas un rabais) ───────────────────────
@pytest.mark.parametrize("canton", CANTONS)
def test_estimate_uses_married_table_at_grid_points(canton):
    """À un point de grille, impôt marié == impôt célibataire − (part
    cantonale célibataire − part cantonale mariée) : l'IFD est identique
    (barème célibataire conservé), donc l'écart == l'écart cantonal de la
    table ESTV. Prouve l'interpolation sur la table mariée."""
    for i, amount_s in enumerate(_AMOUNTS):
        amount = float(amount_s)
        single = estimate_capital_withdrawal_tax(amount, canton)
        married = estimate_capital_withdrawal_tax(amount, canton, is_married=True)
        expected_delta = (
            CANTONAL_CAPITAL_TAX_CHF[canton][i]
            - CANTONAL_CAPITAL_TAX_MARRIED_CHF[canton][i]
        )
        assert single - married == pytest.approx(expected_delta, abs=0.02), (
            f"{canton}@{amount}: écart {single - married} != table "
            f"{expected_delta}"
        )


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
