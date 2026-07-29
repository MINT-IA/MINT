"""Impot sur les gains immobiliers — modeles calibres ZH / VD / GE.

SOURCE DES CHIFFRES

Toutes les tranches et tous les taux de ce module sont RETRANSCRITS champ par
champ depuis l'archive de sources primaires
``.planning/audit-etat-des-lieux-2026-07/constants-audit/gains_immobiliers_2026/``
(collecte du 2026-07-28, ADR ``.planning/decisions/2026-07-28-remplacements-succession-donation-immo-lamal.md``
item P5). Aucune valeur ne vient de memoire ni d'une source secondaire.

- ZH : tarif progressif PAR MONTANT DE GAIN (§ 225 StG, Zürcher Steuerbuch
  Nr. 225-1, StA eForm 225.1 / 09.25), majoration de courte duree, rabais de
  longue duree plafonne, franchise 5'000 CHF. La coherence interne est
  verifiee : chaque vecteur du tableau B recalcule par la formule des tranches
  redonne le montant imprime (rejoue dans les tests).
- VD : bareme DEGRESSIF PAR DUREE de possession (LI RSV 642.11, art. 72), avec
  double comptage des annees d'occupation personnelle prouvees (art. 72 al. 4).
- GE : bareme DEGRESSIF PAR DUREE (LCP rsGE D 3 05, art. 84), 2 % des 25 ans
  depuis la revision du 1.1.2025 (l'exoneration totale au-dela de 25 ans est
  morte).

PERIMETRE

Seuls ZH, VD et GE sont calibres. BE / LU / BS portent un impot sur les gains
immobiliers reel dont le tarif n'est pas tabulable ici (quotites communales,
tarifs lies au revenu) : on decrit le mecanisme et on renvoie au calculateur
cantonal officiel, sans chiffre. Tout autre canton renvoie un verdict honnete
« inconnu ». JAMAIS de montant fabrique hors ZH / VD / GE.

Ton educatif, scenarios et ordres de grandeur — pas de conseil ni de promesse
de rendement (LSFin art. 7-10).
"""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple


# ══════════════════════════════════════════════════════════════════════════════
# ZH — Zürich : tarif progressif par montant de gain (§ 225 StG)
# ══════════════════════════════════════════════════════════════════════════════

SOURCE_ZH: str = (
    "Tarif fur die Grundstuckgewinnsteuer, § 225 StG — Steueramt Kanton Zurich, "
    "Zurcher Steuerbuch Nr. 225-1 (StA eForm 225.1 / 09.25)."
)

# Franchise : les gains inferieurs a ce seuil ne sont pas imposes.
FRANCHISE_ZH: float = 5000.0

# Tranches progressives PAR PORTION DE GAIN. Chaque entree = (portion_chf, taux).
# La derniere portion (None) s'applique a tout le gain au-dela de 100'000 CHF.
TRANCHES_ZH: List[Tuple[Optional[float], float]] = [
    (4000.0, 0.10),   # 10 % sur les premiers 4'000
    (6000.0, 0.15),   # 15 % sur les 6'000 suivants
    (8000.0, 0.20),   # 20 % sur les 8'000 suivants
    (12000.0, 0.25),  # 25 % sur les 12'000 suivants
    (20000.0, 0.30),  # 30 % sur les 20'000 suivants
    (50000.0, 0.35),  # 35 % sur les 50'000 suivants
    (None, 0.40),     # 40 % sur la part au-dela de 100'000
]

# Majoration pour courte duree de possession (« erhöht sich »). S'applique a
# l'impot déjà calcule par le tarif.
MAJORATION_ZH_MOINS_1_AN: float = 0.50   # < 1 an : impot × 1.5
MAJORATION_ZH_MOINS_2_ANS: float = 0.25  # < 2 ans : impot × 1.25

# Rabais pour longue duree de possession (« ermässigt sich »). Table par annees
# pleines de possession : 5 % a 5 ans, + 3 % par annee pleine, plafonne a 50 %.
# S'applique a l'impot déjà calcule par le tarif.
RABAIS_ZH_TABLE: Dict[int, float] = {
    5: 0.05, 6: 0.08, 7: 0.11, 8: 0.14, 9: 0.17,
    10: 0.20, 11: 0.23, 12: 0.26, 13: 0.29, 14: 0.32,
    15: 0.35, 16: 0.38, 17: 0.41, 18: 0.44, 19: 0.47,
    20: 0.50,
}
RABAIS_ZH_PLAFOND: float = 0.50  # >= 20 ans


def impot_base_zh(gain_chf: float) -> float:
    """Tarif de base ZH (Grundtarif) : somme progressive des tranches.

    C'est le tarif AVANT franchise, majoration de courte duree ou rabais de
    longue duree — exactement ce que rejouent les vecteurs officiels du
    tableau B. Un gain nul ou negatif ne produit aucun impot.
    """
    if gain_chf <= 0:
        return 0.0
    reste = float(gain_chf)
    impot = 0.0
    for portion_chf, taux in TRANCHES_ZH:
        if reste <= 0:
            break
        if portion_chf is None:
            impot += reste * taux
            reste = 0.0
        else:
            part = min(reste, portion_chf)
            impot += part * taux
            reste -= part
    return round(impot, 2)


def _rabais_zh(annees_pleines: int) -> float:
    """Taux de rabais de longue duree pour ``annees_pleines`` de possession."""
    if annees_pleines >= 20:
        return RABAIS_ZH_PLAFOND
    return RABAIS_ZH_TABLE.get(annees_pleines, 0.0)


def impot_zh(gain_chf: float, annees_pleines: int) -> float:
    """Impot ZH sur les gains immobiliers, tarif complet.

    Ordre : franchise (< 5'000 → 0), puis tarif progressif par tranches, puis
    majoration de courte duree (× 1.5 si < 1 an, × 1.25 si < 2 ans), puis rabais
    de longue duree (table des annees pleines, plafonne a 50 % des 20 ans). La
    majoration et le rabais s'appliquent a l'impot déjà calcule.
    """
    if gain_chf < FRANCHISE_ZH:
        return 0.0

    impot = impot_base_zh(gain_chf)

    # Majoration de courte duree (mutuellement exclusive du rabais par la duree).
    if annees_pleines < 1:
        impot *= 1.0 + MAJORATION_ZH_MOINS_1_AN
    elif annees_pleines < 2:
        impot *= 1.0 + MAJORATION_ZH_MOINS_2_ANS

    # Rabais de longue duree (a partir de 5 annees pleines).
    rabais = _rabais_zh(annees_pleines)
    if rabais:
        impot *= 1.0 - rabais

    return round(impot, 2)


# ══════════════════════════════════════════════════════════════════════════════
# VD — Vaud : bareme degressif par duree de possession (LI art. 72)
# ══════════════════════════════════════════════════════════════════════════════

SOURCE_VD: str = (
    "Loi sur les impots directs cantonaux (LI), RSV 642.11, art. 72 — Etat de "
    "Vaud, version consolidee lexfind.ch (tolv/200645)."
)

# 25 lignes. Chaque entree = (de_annees_inclus, a_annees_exclu, taux). La
# derniere ligne (None) couvre 24 ans et plus.
BAREME_VD: List[Tuple[int, Optional[int], float]] = [
    (0, 1, 0.30), (1, 2, 0.27), (2, 3, 0.24), (3, 4, 0.22), (4, 5, 0.20),
    (5, 6, 0.18), (6, 7, 0.17), (7, 8, 0.16), (8, 9, 0.15), (9, 10, 0.15),
    (10, 11, 0.14), (11, 12, 0.14), (12, 13, 0.13), (13, 14, 0.13),
    (14, 15, 0.12), (15, 16, 0.12), (16, 17, 0.11), (17, 18, 0.11),
    (18, 19, 0.10), (19, 20, 0.10), (20, 21, 0.09), (21, 22, 0.09),
    (22, 23, 0.08), (23, 24, 0.08), (24, None, 0.07),
]


def duree_effective_vd(annees_possession: int, annees_occupation: int = 0) -> int:
    """Duree effective VD, art. 72 al. 4 : double comptage de l'occupation.

    Les annees d'occupation personnelle prouvees comptent double, plafonnees a
    la duree de possession reelle : ``possession + min(occupation, possession)``.
    """
    occupation_creditee = min(max(annees_occupation, 0), max(annees_possession, 0))
    return max(annees_possession, 0) + occupation_creditee


def taux_vd(duree_effective: int) -> float:
    """Taux VD pour une duree effective de possession (en annees)."""
    d = max(duree_effective, 0)
    for de, a_exclu, taux in BAREME_VD:
        if d >= de and (a_exclu is None or d < a_exclu):
            return taux
    return BAREME_VD[-1][2]


# ══════════════════════════════════════════════════════════════════════════════
# GE — Geneve : bareme degressif par duree de possession (LCP art. 84)
# ══════════════════════════════════════════════════════════════════════════════

SOURCE_GE: str = (
    "Loi generale sur les contributions publiques (LCP), rsGE D 3 05, art. 84 — "
    "Republique et canton de Geneve, silgeneve.ch, etat au 1.1.2026 (2 % des "
    "25 ans, revision en vigueur le 1.1.2025)."
)

# 7 lettres a..g. Chaque entree = (de_annees_inclus, a_annees_exclu, taux).
BAREME_GE: List[Tuple[int, Optional[int], float]] = [
    (0, 2, 0.50),    # a
    (2, 4, 0.40),    # b
    (4, 6, 0.30),    # c
    (6, 8, 0.20),    # d
    (8, 10, 0.15),   # e
    (10, 25, 0.10),  # f
    (25, None, 0.02),  # g — revision 1.1.2025
]


def taux_ge(annees: int) -> float:
    """Taux GE pour une duree de possession (en annees)."""
    d = max(annees, 0)
    for de, a_exclu, taux in BAREME_GE:
        if d >= de and (a_exclu is None or d < a_exclu):
            return taux
    return BAREME_GE[-1][2]


# ══════════════════════════════════════════════════════════════════════════════
# Cantons a mecanisme (impot reel, tarif non tabulable) et renvoi officiel
# ══════════════════════════════════════════════════════════════════════════════

CANTONS_CALIBRES: frozenset = frozenset({"ZH", "VD", "GE"})

# Cantons ou l'impot existe mais dont le tarif depend de quotites communales ou
# de baremes lies au revenu : on nomme l'administration fiscale cantonale, sans
# URL et sans chiffre. Valeurs = chaines uniquement (aucun taux).
MECANISME_CANTONS: Dict[str, Dict[str, str]] = {
    "BE": {
        "administration": (
            "l'administration fiscale du canton de Berne "
            "(Steuerverwaltung des Kantons Bern)"
        ),
    },
    "LU": {
        "administration": (
            "l'administration fiscale du canton de Lucerne "
            "(Dienststelle Steuern des Kantons Luzern)"
        ),
    },
    "BS": {
        "administration": (
            "l'administration fiscale du canton de Bale-Ville "
            "(Steuerverwaltung Basel-Stadt)"
        ),
    },
}

SOURCE_MECANISME: str = (
    "Impot cantonal sur les gains immobiliers (LHID art. 12 ; loi fiscale "
    "cantonale) — tarif non tabulable ici (quotites communales / bareme lie au "
    "revenu)."
)

SOURCE_INCONNU: str = (
    "Impot cantonal sur les gains immobiliers (LHID art. 12 ; loi fiscale "
    "cantonale) — bareme non encore calibre sur une source primaire."
)


def _mecanisme_message(administration: str) -> str:
    return (
        "L'impot sur les gains immobiliers existe dans ce canton, mais son tarif "
        "depend de quotites communales et de baremes lies au revenu qui ne se "
        "tabulent pas de facon fiable ici. Pour un montant chiffre, adresse-toi "
        f"au calculateur officiel de {administration}."
    )


def _inconnu_message() -> str:
    return (
        "Le bareme de l'impot sur les gains immobiliers de ce canton n'a pas "
        "encore ete calibre sur une source primaire. Aucun montant n'est estime "
        "ici : renseigne-toi aupres de l'administration fiscale de ton canton."
    )


# ══════════════════════════════════════════════════════════════════════════════
# Dispatcher verdict
# ══════════════════════════════════════════════════════════════════════════════

def verdict_gain_immobilier(
    canton: str,
    gain_chf: float,
    annees_possession: int,
    annees_occupation: int = 0,
) -> Dict[str, object]:
    """Verdict d'impot sur les gains immobiliers pour un canton donne.

    ZH / VD / GE : ``modele = "calibre"`` avec ``impot_chf`` chiffre.
    BE / LU / BS : ``modele = "mecanisme"``, ``impot_chf = None``, renvoi au
    calculateur cantonal officiel.
    Autres cantons : ``modele = "inconnu"``, ``impot_chf = None``.
    """
    canton = (canton or "").upper()
    gain = max(float(gain_chf), 0.0)

    if canton == "ZH":
        impot = impot_zh(gain, annees_possession)
        mecanismes: List[str] = ["franchise 5'000 CHF"]
        if annees_possession < 1:
            mecanismes.append("majoration de courte duree (< 1 an, +50 %)")
        elif annees_possession < 2:
            mecanismes.append("majoration de courte duree (< 2 ans, +25 %)")
        if _rabais_zh(annees_possession):
            mecanismes.append(
                f"rabais de longue duree ({int(_rabais_zh(annees_possession) * 100)} %)"
            )
        mecanismes.append("tarif progressif par montant de gain")
        return {
            "canton": canton,
            "modele": "calibre",
            "impot_chf": impot,
            "taux_effectif_pct": round(impot / gain * 100, 2) if gain > 0 else 0.0,
            "mecanismes": mecanismes,
            "source": SOURCE_ZH,
        }

    if canton == "VD":
        duree = duree_effective_vd(annees_possession, annees_occupation)
        taux = taux_vd(duree)
        impot = round(gain * taux, 2)
        mecanismes = ["bareme degressif par duree de possession"]
        if annees_occupation > 0:
            mecanismes.append(
                "double comptage des annees d'occupation personnelle "
                f"(art. 72 al. 4) : duree effective {duree} ans"
            )
        return {
            "canton": canton,
            "modele": "calibre",
            "impot_chf": impot,
            "taux_effectif_pct": round(taux * 100, 2),
            "mecanismes": mecanismes,
            "source": SOURCE_VD,
        }

    if canton == "GE":
        taux = taux_ge(annees_possession)
        impot = round(gain * taux, 2)
        return {
            "canton": canton,
            "modele": "calibre",
            "impot_chf": impot,
            "taux_effectif_pct": round(taux * 100, 2),
            "mecanismes": ["bareme degressif par duree de possession"],
            "source": SOURCE_GE,
        }

    if canton in MECANISME_CANTONS:
        administration = MECANISME_CANTONS[canton]["administration"]
        return {
            "canton": canton,
            "modele": "mecanisme",
            "impot_chf": None,
            "taux_effectif_pct": None,
            "mecanismes": [_mecanisme_message(administration)],
            "source": SOURCE_MECANISME,
        }

    return {
        "canton": canton,
        "modele": "inconnu",
        "impot_chf": None,
        "taux_effectif_pct": None,
        "mecanismes": [_inconnu_message()],
        "source": SOURCE_INCONNU,
    }
