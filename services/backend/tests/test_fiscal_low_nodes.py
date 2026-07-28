"""Etalon des noeuds bas (< 40k) — parite archive<->table, monotonie, INC-1.

Ces tests verrouillent l'extension de CANTONAL_COMMUNAL_TAX_CHF vers le bas
(noeuds 15k/25k/35k, collecte ESTV 2026-07-28) qui corrige le finding INC-1 :
sous l'ancien premier noeud (40k), l'interpolation lineaire depuis (0,0)
surestimait l'impot cantonal jusqu'a +59.8% (GE 30k : 2780 vs ESTV 1739).

Archive : .planning/audit-etat-des-lieux-2026-07/constants-audit/
          etalon_noeuds_bas_2026/consolidated.json
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.fiscal.cantonal_comparator import (
    CANTONAL_COMMUNAL_TAX_CHF,
    CANTONAL_TAX_POINTS_INCOME,
    estimate_income_tax_parts,
)

# parents[0]=tests/, [1]=backend/, [2]=services/, [3]=repo root.
REPO_ROOT = Path(__file__).resolve().parents[3]
ARCHIVE = (
    REPO_ROOT
    / ".planning/audit-etat-des-lieux-2026-07/constants-audit"
    / "etalon_noeuds_bas_2026/consolidated.json"
)

NEW_LOW_NODES = [15_000, 25_000, 35_000]
INC1_CANTONS = ("GE", "BL", "GR", "TI")


@pytest.fixture(scope="module")
def archive() -> dict:
    assert ARCHIVE.exists(), f"archive etalon noeuds bas absente : {ARCHIVE}"
    return json.loads(ARCHIVE.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# 1. Grille des points revenu : les 3 noeuds bas precedent 40k, strict croissant.
# ---------------------------------------------------------------------------

def test_income_grid_starts_at_low_nodes():
    assert CANTONAL_TAX_POINTS_INCOME[:4] == [15_000, 25_000, 35_000, 40_000]


def test_income_grid_strictly_increasing():
    g = CANTONAL_TAX_POINTS_INCOME
    assert all(g[i] < g[i + 1] for i in range(len(g) - 1)), g


def test_income_grid_has_8_points():
    assert len(CANTONAL_TAX_POINTS_INCOME) == 8


# ---------------------------------------------------------------------------
# 2. Monotonie de la table etendue : chaque canton strictement croissant sur 8 pts.
# ---------------------------------------------------------------------------

def test_table_row_length_matches_grid():
    for c, pts in CANTONAL_COMMUNAL_TAX_CHF.items():
        assert len(pts) == len(CANTONAL_TAX_POINTS_INCOME), c


def test_table_strictly_increasing_per_canton():
    """L'interpolation lineaire suppose une table monotone : un impot qui
    baisserait quand le revenu monte casserait le taux marginal (pente < 0)."""
    for c, pts in CANTONAL_COMMUNAL_TAX_CHF.items():
        assert all(pts[i] < pts[i + 1] for i in range(len(pts) - 1)), (c, pts)


def test_low_nodes_below_first_committed_node():
    """Les 3 noeuds bas restent sous l'ancien premier noeud (40k)."""
    for c, pts in CANTONAL_COMMUNAL_TAX_CHF.items():
        assert pts[2] < pts[3], (c, pts[:4])  # 35k < 40k


# ---------------------------------------------------------------------------
# 3. Parite archive <-> table : les 3 noeuds bas == capture ESTV archivee.
# ---------------------------------------------------------------------------

def test_low_nodes_match_estv_archive(archive):
    """Les valeurs 15k/25k/35k de la table == etalon ESTV archive (arrondi CHF).

    Verrouille la calibration a sa source primaire : toute derive de la table
    (ou de l'archive) sans re-collecte est detectee."""
    added = archive["added_nodes_for_table"]
    assert set(added) == set(CANTONAL_COMMUNAL_TAX_CHF), "cantons manquants"
    for c in CANTONAL_COMMUNAL_TAX_CHF:
        assert CANTONAL_COMMUNAL_TAX_CHF[c][:3] == added[c], (
            f"{c}: table {CANTONAL_COMMUNAL_TAX_CHF[c][:3]} != archive {added[c]}"
        )


def test_archive_node_integrity_gate_full(archive):
    """L'archive prouve que les 26 chefs-lieux reproduisent leurs 5 noeuds
    committes a +/-1 CHF (aucune donnee hors porte)."""
    assert archive["meta"]["cantons_hors_porte"] == []
    assert archive["meta"]["cantons_dans_la_porte"] == 26


# ---------------------------------------------------------------------------
# 4. Regression INC-1 : plus de surestimation a 30k ; erreur ramenee en bande.
# ---------------------------------------------------------------------------

def test_inc1_30k_no_longer_overestimates(archive):
    """A 30k, l'impot cantonal modele est proche de l'ESTV (bande <= 8%),
    la ou l'ancien modele surestimait de +47 a +60% sur GE/BL/GR/TI."""
    errs = archive["measured_error_vs_estv"]
    for c in CANTONAL_COMMUNAL_TAX_CHF:
        estv = errs[c]["30000"]["estv_cantonal_communal"]
        _, cant = estimate_income_tax_parts(30_000.0, c)
        rel = abs(cant - estv) / estv
        assert rel <= 0.08, f"{c} 30k: modele {cant:.0f} vs ESTV {estv:.0f} ({rel:.1%})"


def test_inc1_ge_30k_regression():
    """GE 30k : l'ancien modele donnait ~2780 (lineaire depuis 0) ; le nouveau
    doit etre proche de l'ESTV 1739 (bande <= 5%)."""
    _, cant = estimate_income_tax_parts(30_000.0, "GE")
    assert cant < 2_000, f"GE 30k cantonal={cant:.0f} (ESTV 1739 ; ancien 2780)"
    assert abs(cant - 1739) / 1739 <= 0.05


def test_inc1_all_four_failure_points_improved(archive):
    """Les 4 points d'echec documentes d'INC-1 sont tous ramenes sous 7%
    (l'ancien modele : +46 a +60%)."""
    errs = archive["measured_error_vs_estv"]
    for c in INC1_CANTONS:
        old = abs(errs[c]["30000"]["old_rel_err_pct"])
        new = abs(errs[c]["30000"]["new_rel_err_pct"])
        assert old > 40.0, f"{c}: l'ancien ecart mesure devrait etre > 40% ({old})"
        assert new <= 7.0, f"{c}: nouvel ecart {new}% > 7%"
