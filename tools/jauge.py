#!/usr/bin/env python3
"""Où en est MINT — lu sur les sources, jamais saisi à la main.

POURQUOI CE FICHIER EXISTE

Julien, plusieurs fois : « je veux voir où on en est, sur le Lego en cours et
sur MINT en entier, sous la forme la plus visible possible ». L'information
existait — journal des Legos, bail, storyboard, faits du jumeau — mais éclatée
dans quatre endroits, dont un JSON.

UNE VERSION DE CETTE IDÉE A DÉJÀ ÉTÉ REJETÉE, LE 2026-08-15 AU MATIN.

`.planning/decisions/2026-08-15-tableau-de-bord-des-legos.md` — rejetée par un
axe Codex, pour deux raisons vérifiées : le BRIEF portait DEUX journaux
contradictoires, et `.planning/journeys/BOARD.md` était présenté comme une vue
générée qui couvrait déjà le besoin.

Les deux raisons sont tombées depuis, et c'est pour ça que ce fichier existe :

  · le double journal a été supprimé le jour même, et le garde du bail REFUSE
    désormais un BRIEF qui en porterait deux ;
  · BOARD.md a été ouvert : c'est un tableau d'ISSUES (6 lignes, 5 P0 et 1 P1),
    pas une vue des Legos. Il ne couvrait pas le besoin — l'ADR l'avait cru
    sans l'ouvrir.

CE QU'IL NE FAIT PAS, ET POURQUOI

Il n'affiche AUCUN pourcentage d'avancement global de MINT. Il n'existe nulle
part de liste des Legos restant à construire : le journal donne un numérateur
sans dénominateur. Inventer « MINT est à 60 % » serait le genre de chiffre
rassurant et faux que cette application entière existe pour bannir.

Ce qu'il affiche à la place, ce sont des fractions RÉELLES, chacune avec un
dénominateur qu'on peut compter dans le code ou le contrat.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

VERT, JAUNE, ROUGE, GRIS, GRAS, FIN = (
    "\033[32m", "\033[33m", "\033[31m", "\033[90m", "\033[1m", "\033[0m")


def barre(fait: int, total: int, largeur: int = 24) -> str:
    if total <= 0:
        return GRIS + "·" * largeur + FIN
    plein = round(largeur * fait / total)
    couleur = VERT if fait == total else (JAUNE if fait else ROUGE)
    return f"{couleur}{'█' * plein}{GRIS}{'·' * (largeur - plein)}{FIN}"


def ligne(titre: str, fait: int, total: int, note: str = "") -> str:
    return (f"  {titre:<26} {barre(fait, total)}  {fait}/{total}"
            + (f"  {GRIS}{note}{FIN}" if note else ""))


def lego_en_cours() -> tuple[str | None, list[tuple[str, str, int]]]:
    """Le Lego actif, ou (None, []) si aucun bail n'est ouvert.

    Trouvé en portant ce fichier sur une base sans bail : la jauge levait une
    exception au lieu de dire « aucun Lego en cours ». Un outil qui ne sait
    pas dire « rien » ne sait pas dire la vérité.
    """
    chemin = ROOT / "product/mint_next/lego_lease.json"
    if not chemin.exists():
        return None, []
    bail = json.loads(chemin.read_text(encoding="utf-8"))
    sb = json.loads((ROOT / bail["storyboard"]).read_text(encoding="utf-8"))
    par_id = {x["id"]: x for x in sb["beats"]}
    etats = []
    for x in bail["beats"]:
        c = par_id.get(x["id"], {})
        planifies, traces = c.get("tests_planned") or [], c.get("tests") or []
        if x["etat"] == "vert":
            etats.append((x["id"], "fermé", 3))
        elif traces and not planifies:
            etats.append((x["id"], f"{len(traces)} test(s) tracé(s)", 2))
        elif planifies:
            etats.append((x["id"], f"{len(planifies)} seulement planifié(s)", 1))
        else:
            etats.append((x["id"], "rien", 0))
    return bail["lego"], etats


def legos_livres() -> int:
    """Lignes du journal portant un résultat — 4 colonnes remplies."""
    chemin = ROOT / "product/mint_next/BRIEF.md"
    if not chemin.exists():
        return 0
    brief = chemin.read_text(encoding="utf-8")
    return sum(1 for l in brief.splitlines()
               if l.startswith("| 2026-") and l.count("|") >= 5
               and re.search(r"PROMU|MERG", l))


def faits_du_jumeau() -> tuple[int, int, list[str]]:
    """Faits canoniques modélisés, et ceux dont la LECTURE canonique existe.

    Le dénominateur est compté dans le code, pas déclaré dans une prose : un
    modèle `mint_next_*_fact.dart` par fait, une `readCanonical*` par fait
    réellement porté par le magasin scellé.
    """
    modeles = sorted(p.stem.replace("mint_next_", "").replace("_fact", "")
                     for p in (ROOT / "apps/mobile/lib/models").glob(
                         "mint_next_*_fact.dart"))
    magasin = (ROOT / "apps/mobile/lib/services/secure_wizard_store.dart"
               ).read_text(encoding="utf-8")
    lus = {m.group(1).lower() for m in
           re.finditer(r"readCanonical(\w+)\s*\(", magasin)}
    portes = [m for m in modeles if m.replace("_", "") in lus]
    return len(portes), len(modeles), [m for m in modeles if m not in portes]


def main() -> int:
    lego, beats = lego_en_cours()
    print(f"\n{GRAS}  MINT — où on en est{FIN}\n")

    if lego is None:
        print(f"{GRIS}  Aucun Lego en cours sur cette base (pas de bail).{FIN}")
    else:
        fermes = sum(1 for _, _, n in beats if n == 3)
        traces = sum(1 for _, _, n in beats if n >= 2)
        n = len(beats)
        print(f"{GRAS}  Lego en cours : {lego}{FIN}")
        for bid, etat, niveau in beats:
            puce = {3: f"{VERT}█{FIN}", 2: f"{JAUNE}▓{FIN}",
                    1: f"{ROUGE}▒{FIN}", 0: f"{GRIS}·{FIN}"}[niveau]
            print(f"    {puce}  {bid:<26} {GRIS}{etat}{FIN}")
        print()
        print(ligne("beats fermés", fermes, n,
                    "un beat ferme sur verdict Codex"))
        print(ligne("preuve tracée par nom", traces, n))

    portes, total, manquants = faits_du_jumeau()
    print(f"\n{GRAS}  Le jumeau financier{FIN}")
    print(ligne("faits canoniques portés", portes, total,
                "manque : " + ", ".join(manquants) if manquants else ""))

    print(f"\n{GRAS}  Construction{FIN}")
    print(f"  {'Legos livrés':<26} {VERT}{legos_livres()}{FIN}"
          f"  {GRIS}numérateur seul — aucune source ne dit combien il en{FIN}")
    print(f"  {'':<26}    {GRIS}reste, donc AUCUN pourcentage n'est honnête{FIN}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
