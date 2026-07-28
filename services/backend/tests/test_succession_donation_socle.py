"""
Tests du socle succession/donation (ADR 2026-07-28, P4).

Le socle remplace les tables de taux plats par un verdict directionnel
par canton × catégorie : statut (exonere/taxe/taxe_lourd), plage max
UNIQUEMENT quand la source primaire la donne, mécanismes sourcés,
variable de bascule pour les concubins.

Source : ESTV Steuermäppchen Erbschafts-/Schenkungssteuer, période 2025,
archivée dans .planning/audit-etat-des-lieux-2026-07/constants-audit/
succession_donation_2025/socle_extraction.json.

Run: cd services/backend && python3 -m pytest tests/test_succession_donation_socle.py -v
"""

import json
from pathlib import Path

import pytest

from app.services.fiscal.succession_donation_socle import (
    SOCLE_CANTONS,
    SOCLE_SOURCE,
    verdict,
)

ARCHIVE_PATH = (
    Path(__file__).resolve().parents[3]
    / ".planning/audit-etat-des-lieux-2026-07/constants-audit"
    / "succession_donation_2025/socle_extraction.json"
)

CATEGORIES = ("conjoint", "descendant", "parent", "fratrie", "concubin", "tiers")


# ===========================================================================
# Parité socle ↔ archive (patron test_parite_table_archive, test_expat.py)
# ===========================================================================

class TestPariteSocleArchive:
    """Le module == l'archive JSON, champ par champ.

    Sans ce test, une coquille dans les littéraux Python shipperait verte
    et le refresh annuel ESTV n'aurait pas de point d'update mécanique.
    """

    def test_source_citee(self):
        arch = json.loads(ARCHIVE_PATH.read_text())
        assert "ESTV" in SOCLE_SOURCE
        assert "2025" in SOCLE_SOURCE
        assert arch["meta"]["source"] == SOCLE_SOURCE

    def test_26_cantons(self):
        arch = json.loads(ARCHIVE_PATH.read_text())
        assert set(SOCLE_CANTONS) == set(arch["cantons"])
        assert len(SOCLE_CANTONS) == 26

    def test_parite_champ_par_champ(self):
        arch = json.loads(ARCHIVE_PATH.read_text())
        for canton, arch_data in arch["cantons"].items():
            module_data = SOCLE_CANTONS[canton]
            assert set(module_data) == set(arch_data), (
                f"{canton}: clés {sorted(module_data)} != {sorted(arch_data)}"
            )
            for champ, arch_val in arch_data.items():
                mod_val = module_data[champ]
                if champ == "categories" and arch_val is not None:
                    assert set(mod_val) == set(arch_val), f"{canton}.categories"
                    for cat, arch_cat in arch_val.items():
                        assert mod_val[cat] == arch_cat, (
                            f"{canton}.categories.{cat}: "
                            f"module {mod_val[cat]!r} != archive {arch_cat!r}"
                        )
                else:
                    assert mod_val == arch_val, (
                        f"{canton}.{champ}: module {mod_val!r} != archive {arch_val!r}"
                    )


# ===========================================================================
# Verdicts — faits durs de l'ADR
# ===========================================================================

class TestVerdicts:

    def test_conjoint_exonere_26_cantons(self):
        """Seule généralisation qui tient 26/26 (ADR) : conjoint exonéré."""
        for canton in SOCLE_CANTONS:
            v = verdict(canton, "conjoint", "succession")
            assert v["statut"] == "exonere", f"{canton}: {v['statut']}"

    def test_descendant_pas_exonere_partout(self):
        """« Descendants exonérés » est FAUX comme généralisation : VD, NE, AI
        imposent la ligne directe (ADR, faits corrigés par le panel)."""
        for canton in ("VD", "NE", "AI"):
            v = verdict(canton, "descendant", "succession")
            assert v["statut"] == "taxe", f"{canton}: {v['statut']}"

    def test_vd_descendant_taxe_avec_franchise_1m(self):
        """VD ligne directe : statut taxe + déduction 1'000'000 par souche."""
        v = verdict("VD", "descendant", "succession")
        assert v["statut"] == "taxe"
        assert v["plage_max_pct"] is None  # pas de plage catégorielle sourcée
        assert any("1000000" in m for m in v["mecanismes"]), v["mecanismes"]

    def test_be_tiers_plage_40(self):
        """BE tiers : taxe_lourd, plage sourcée ~40 % (2.5 % × 16)."""
        v = verdict("BE", "tiers", "succession")
        assert v["statut"] == "taxe_lourd"
        assert v["plage_max_pct"] == 40

    def test_zh_concubin_bascule_franchise_50k_5ans(self):
        """ZH concubin : taxé (übrige ×6), bascule mariage/pacte, condition
        cantonale franchise 50'000 si ≥5 ans de ménage commun."""
        v = verdict("ZH", "concubin", "succession")
        assert v["statut"] == "taxe"
        assert v["bascule"] is not None
        assert "ariage" in v["bascule"]  # Mariage/mariage
        assert "50000" in v["bascule"]
        assert "5 ans" in v["bascule"]

    def test_sz_ow_tout_exonere(self):
        """SZ et OW : aucun impôt succession/donation, toutes catégories."""
        for canton in ("SZ", "OW"):
            for cat in CATEGORIES:
                for tt in ("succession", "donation"):
                    v = verdict(canton, cat, tt)
                    assert v["statut"] == "exonere", f"{canton}.{cat}.{tt}"
                    assert v["plage_max_pct"] is None

    def test_lu_donation_pas_d_impot_message_dedie(self):
        """LU ne prélève AUCUN impôt sur les donations (donation=False dans le
        socle — l'ancienne table donation l'inscrivait à fratrie 8 %/tiers
        25 %, erreur prouvée par l'ADR). Le verdict doit le DIRE."""
        for cat in CATEGORIES:
            v = verdict("LU", cat, "donation")
            assert v["statut"] == "exonere", f"LU.{cat}"
            joined = " ".join(v["mecanismes"])
            assert "Lucerne" in joined, joined
            assert "donation" in joined.lower()

    def test_lu_succession_reste_taxee(self):
        """LU succession : fratrie/tiers restent taxés (donation ≠ succession)."""
        assert verdict("LU", "fratrie", "succession")["statut"] == "taxe"
        assert verdict("LU", "tiers", "succession")["statut"] == "taxe_lourd"

    def test_plage_seulement_si_taxe_lourd(self):
        """Jamais de plage fabriquée : plage seulement pour la classe au
        tarif maximal (max_effectif_tiers_pct est un plafond de classe tiers)."""
        for canton in SOCLE_CANTONS:
            for cat in CATEGORIES:
                v = verdict(canton, cat, "succession")
                if v["statut"] != "taxe_lourd":
                    assert v["plage_max_pct"] is None, f"{canton}.{cat}"

    def test_ge_tiers_plage_hors_centimes_documentee(self):
        """GE tiers : plage 26 % avec le caveat centimes additionnels dans
        les mécanismes (la charge réelle est supérieure, non chiffrable)."""
        v = verdict("GE", "tiers", "succession")
        assert v["plage_max_pct"] == 26
        assert any("centimes" in m.lower() for m in v["mecanismes"]), v["mecanismes"]

    def test_source_obligatoire_partout(self):
        for canton in SOCLE_CANTONS:
            for cat in CATEGORIES:
                v = verdict(canton, cat, "succession")
                assert "ESTV" in v["source"], f"{canton}.{cat}"

    def test_canton_inconnu_honnete(self):
        """Canton hors socle : statut « inconnu », zéro chiffre fabriqué."""
        v = verdict("XX", "fratrie", "succession")
        assert v["statut"] == "inconnu"
        assert v["plage_max_pct"] is None
        assert v["mecanismes"]  # renvoi explicite, pas un défaut silencieux

    def test_categorie_invalide_rejetee(self):
        with pytest.raises(ValueError):
            verdict("GE", "cousin", "succession")

    def test_type_transmission_invalide_rejete(self):
        with pytest.raises(ValueError):
            verdict("GE", "tiers", "heritage")
