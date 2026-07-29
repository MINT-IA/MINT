"""Tests du module ``fiscal.gains_immobiliers_calibres``.

Deux garanties :

1. PARITE archive ↔ py : chaque constante du module est identique, champ par
   champ, a la retranscription de l'archive de sources primaires
   ``.planning/audit-etat-des-lieux-2026-07/constants-audit/gains_immobiliers_2026/extraction.json``.
   Le meme patron existe cote Dart (parite py ↔ dart).
2. REJEU des 4 vecteurs officiels ZH du tableau B (impot de base, sans
   majoration ni rabais) + les cas cibles de l'ADR P5.

Depuis un fichier sous ``services/backend/tests``, la racine du depot est
``Path(__file__).resolve().parents[3]``.

Run : cd services/backend && python3 -m pytest tests/test_gains_immobiliers_calibres.py -q
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.fiscal.gains_immobiliers_calibres import (
    BAREME_GE,
    BAREME_VD,
    FRANCHISE_ZH,
    MAJORATION_ZH_MOINS_1_AN,
    MAJORATION_ZH_MOINS_2_ANS,
    RABAIS_ZH_PLAFOND,
    RABAIS_ZH_TABLE,
    TRANCHES_ZH,
    duree_effective_vd,
    impot_base_zh,
    impot_zh,
    taux_ge,
    taux_vd,
    verdict_gain_immobilier,
)

REPO_ROOT = Path(__file__).resolve().parents[3]
ARCHIVE = (
    REPO_ROOT
    / ".planning"
    / "audit-etat-des-lieux-2026-07"
    / "constants-audit"
    / "gains_immobiliers_2026"
    / "extraction.json"
)


@pytest.fixture(scope="module")
def archive() -> dict:
    assert ARCHIVE.exists(), f"archive introuvable : {ARCHIVE}"
    return json.loads(ARCHIVE.read_text(encoding="utf-8"))


# ===========================================================================
# PARITE archive ↔ py — champ par champ
# ===========================================================================

class TestPariteZH:
    def test_franchise(self, archive):
        assert FRANCHISE_ZH == archive["ZH"]["franchise_chf"]

    def test_tranches_par_gain(self, archive):
        arch = archive["ZH"]["tranches_par_gain"]
        assert len(TRANCHES_ZH) == len(arch)
        for (portion, taux), entry in zip(TRANCHES_ZH, arch):
            assert portion == entry["portion_chf"]
            assert taux == entry["taux"]

    def test_majoration(self, archive):
        maj = archive["ZH"]["majoration_courte_duree"]
        assert MAJORATION_ZH_MOINS_1_AN == maj["moins_de_1_an"]
        assert MAJORATION_ZH_MOINS_2_ANS == maj["moins_de_2_ans"]

    def test_rabais_table(self, archive):
        arch = archive["ZH"]["rabais_longue_duree"]
        assert RABAIS_ZH_PLAFOND == arch["plafond"]
        table = arch["table_annees_pleines"]
        assert len(RABAIS_ZH_TABLE) == len(table)
        for annees_str, taux in table.items():
            assert RABAIS_ZH_TABLE[int(annees_str)] == taux


class TestPariteVD:
    def test_bareme(self, archive):
        arch = archive["VD"]["bareme_par_annees_de_possession"]
        assert len(BAREME_VD) == len(arch)
        for (de, a_exclu, taux), entry in zip(BAREME_VD, arch):
            assert de == entry["de"]
            assert a_exclu == entry["a_exclu"]
            assert taux == entry["taux"]


class TestPariteGE:
    def test_bareme(self, archive):
        arch = archive["GE"]["bareme_par_annees_de_possession"]
        assert len(BAREME_GE) == len(arch)
        for (de, a_exclu, taux), entry in zip(BAREME_GE, arch):
            assert de == entry["de"]
            assert a_exclu == entry["a_exclu"]
            assert taux == entry["taux"]


# ===========================================================================
# REJEU des vecteurs officiels ZH (tableau B) — impot de base
# ===========================================================================

class TestVecteursOfficielsZH:
    def test_rejeu_tableau_b(self, archive):
        for vecteur in archive["ZH"]["vecteurs_officiels_tableau_B"]:
            gain = vecteur["gewinn_chf"]
            attendu = vecteur["steuer_chf"]
            assert impot_base_zh(gain) == attendu, (
                f"ZH tableau B : gain {gain} -> {impot_base_zh(gain)} != {attendu}"
            )

    def test_vecteurs_valeurs_gelees(self):
        # Meme controle, valeurs gelees dans le test (garde-fou si l'archive bouge).
        assert impot_base_zh(5000) == 550
        assert impot_base_zh(25000) == 4650
        assert impot_base_zh(50000) == 11900
        assert impot_base_zh(64900) == 17115


# ===========================================================================
# ZH — franchise, majoration, rabais
# ===========================================================================

class TestImpotZH:
    def test_franchise_gain_sous_seuil(self):
        assert impot_zh(4999, 3) == 0.0
        assert impot_zh(0, 10) == 0.0

    def test_a_5000_le_tarif_s_applique(self):
        # 2 <= annees < 5 : ni majoration ni rabais -> tarif de base.
        assert impot_zh(5000, 3) == 550.0

    def test_majoration_moins_1_an(self):
        # 5000 -> 550 base, majore de 50 % -> 825.
        assert impot_zh(5000, 0) == 825.0

    def test_majoration_moins_2_ans(self):
        # 5000 -> 550 base, majore de 25 % -> 687.5.
        assert impot_zh(5000, 1) == 687.5

    def test_rabais_20_ans_moitie(self):
        assert impot_zh(25000, 20) == round(impot_base_zh(25000) * 0.5, 2)
        assert impot_zh(50000, 25) == round(impot_base_zh(50000) * 0.5, 2)

    def test_rabais_5_ans(self):
        assert impot_zh(25000, 5) == round(impot_base_zh(25000) * (1 - 0.05), 2)

    def test_entre_2_et_5_ans_pas_d_ajustement(self):
        base = impot_base_zh(25000)
        assert impot_zh(25000, 2) == base
        assert impot_zh(25000, 4) == base


# ===========================================================================
# VD — bareme, double comptage, bornes
# ===========================================================================

class TestTauxVD:
    def test_double_comptage_occupation(self):
        # 8 ans possedes + 8 ans occupes -> duree effective 16 -> 11 %.
        assert duree_effective_vd(8, 8) == 16
        assert taux_vd(16) == 0.11

    def test_occupation_plafonnee_a_la_possession(self):
        # Occupation superieure a la possession : creditee au plus a la possession.
        assert duree_effective_vd(5, 12) == 10

    def test_borne_basse(self):
        assert taux_vd(0) == 0.30

    def test_borne_haute(self):
        assert taux_vd(24) == 0.07
        assert taux_vd(40) == 0.07

    def test_sans_occupation(self):
        assert duree_effective_vd(10, 0) == 10
        assert taux_vd(10) == 0.14


# ===========================================================================
# GE — bareme, revision 2025
# ===========================================================================

class TestTauxGE:
    def test_24_ans(self):
        assert taux_ge(24) == 0.10

    def test_25_ans_revision_2025(self):
        assert taux_ge(25) == 0.02
        assert taux_ge(40) == 0.02

    def test_borne_basse(self):
        assert taux_ge(0) == 0.50
        assert taux_ge(1) == 0.50


# ===========================================================================
# Dispatcher verdict
# ===========================================================================

class TestVerdict:
    def test_zh_calibre(self):
        v = verdict_gain_immobilier("ZH", 25000, 3)
        assert v["modele"] == "calibre"
        assert v["impot_chf"] == 4650.0
        assert v["taux_effectif_pct"] == round(4650 / 25000 * 100, 2)
        assert "225" in v["source"]

    def test_vd_calibre_avec_occupation(self):
        v = verdict_gain_immobilier("VD", 100000, 8, annees_occupation=8)
        assert v["modele"] == "calibre"
        # duree effective 16 -> 11 %
        assert v["impot_chf"] == 11000.0
        assert any("double comptage" in m for m in v["mecanismes"])

    def test_ge_calibre(self):
        v = verdict_gain_immobilier("GE", 100000, 25)
        assert v["modele"] == "calibre"
        assert v["impot_chf"] == 2000.0  # 2 %

    def test_be_mecanisme(self):
        v = verdict_gain_immobilier("BE", 100000, 5)
        assert v["modele"] == "mecanisme"
        assert v["impot_chf"] is None
        assert v["taux_effectif_pct"] is None
        assert v["mecanismes"] and "Berne" in v["mecanismes"][0]

    def test_lu_bs_mecanisme(self):
        for canton in ("LU", "BS"):
            v = verdict_gain_immobilier(canton, 100000, 5)
            assert v["modele"] == "mecanisme"
            assert v["impot_chf"] is None

    def test_canton_inconnu(self):
        v = verdict_gain_immobilier("TG", 100000, 5)
        assert v["modele"] == "inconnu"
        assert v["impot_chf"] is None
        assert v["taux_effectif_pct"] is None

    def test_aucun_chiffre_hors_calibre(self):
        # Regle dure ADR P5 : jamais de montant hors ZH/VD/GE.
        for canton in ("BE", "LU", "BS", "TG", "AG", "FR"):
            v = verdict_gain_immobilier(canton, 500000, 3)
            assert v["impot_chf"] is None
