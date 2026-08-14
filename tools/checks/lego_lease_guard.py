#!/usr/bin/env python3
"""Le bail du Lego — ce que le loop a le droit de faire, et rien d'autre.

POURQUOI CE FICHIER EXISTE

Le 14.08.2026, un loop autonome a tourné une journée sur un texte figé la
semaine précédente. Il a fidèlement répété un ordre du jour mort : le Lego
réellement en cours (bascule 4) n'a pas été touché, `product/mint_next/BRIEF.md`
— que la méthode déclare « lu au début de chaque session » — n'a jamais été
ouvert, et une PR de 159 fichiers hors cadence a notifié Julien d'échecs CI.

Un axe adverse a corrigé le diagnostic : le texte périmé n'était que la cause
immédiate. La cause profonde est qu'une prose ancienne gardait le pouvoir de
CHOISIR LE TRAVAIL, sans contrôle d'autorité, de périmètre ni de terminaison.
Et son verdict tient en une phrase :

    « La dérive ne devient mécaniquement impossible que si le wrapper et le
      pre-push imposent ce bail. Un meilleur prompt seul reste contournable. »

D'où ce garde. Il ne conseille pas, il REFUSE.

CE QU'IL VÉRIFIE
  1. le bail existe, est actif, et nomme un Lego ;
  2. le cadrage et le storyboard qu'il cite existent VRAIMENT sur disque ;
  3. chaque beat déclaré vert a une preuve, et cette preuve existe ;
  4. il reste au moins un beat ouvert — sinon le Lego est fini et le loop doit
     s'arrêter au lieu d'inventer la suite ;
  5. le travail en cours ne sort pas de `allowed_paths`.

Le point 4 est le plus important : c'est celui qui ARRÊTE. Un loop qui ne sait
pas s'arrêter réinvente du travail — c'est exactement ce qui s'est passé.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEASE = ROOT / "product" / "mint_next" / "lego_lease.json"


def _fail(msg: str) -> int:
    print(f"STOP lego_lease_guard : {msg}")
    print("  → aucune écriture, aucun commit, aucune PR. Rendre la main.")
    return 1


def _changed_paths() -> list[str]:
    """Ce que l'arbre courant modifie — index, arbre de travail, non suivis."""
    out: set[str] = set()
    for args in (
        ["git", "diff", "--name-only"],
        ["git", "diff", "--cached", "--name-only"],
        ["git", "ls-files", "--others", "--exclude-standard"],
    ):
        p = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
        if p.returncode:
            continue
        out.update(l for l in p.stdout.splitlines() if l)
    return sorted(out)


def main() -> int:
    if not LEASE.exists():
        return _fail(f"bail absent ({LEASE.relative_to(ROOT)})")

    try:
        bail = json.loads(LEASE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return _fail(f"bail illisible : {exc}")

    if not bail.get("active"):
        return _fail("bail inactif — aucun Lego n'est ouvert")

    lego = bail.get("lego")
    if not lego:
        return _fail("le bail ne nomme aucun Lego")

    # Le contrat doit exister sur disque. Un bail qui cite un cadrage absent
    # laisserait le loop travailler sans contrat — le trou d'origine.
    for cle in ("cadrage", "storyboard"):
        chemin = bail.get(cle)
        if not chemin or not (ROOT / chemin).exists():
            return _fail(f"le {cle} cité par le bail est introuvable : {chemin}")

    beats = bail.get("beats") or []
    if not beats:
        return _fail("le bail ne déclare aucun beat")

    # Un beat vert SANS preuve est un mensonge de tableau de bord.
    for b in beats:
        if b.get("etat") == "vert":
            preuve = b.get("preuve")
            if not preuve or not (ROOT / preuve).exists():
                return _fail(
                    f"beat « {b.get('id')} » déclaré vert mais sa preuve est "
                    f"absente : {preuve}"
                )

    ouverts = [b for b in beats if b.get("etat") != "vert"]
    if not ouverts:
        print(f"STOP lego_lease_guard : les {len(beats)} beats de « {lego} » sont verts.")
        print("  → le Lego est terminé. Rendre la main pour clôture et cadrage")
        print("    du suivant. Un beat terminé ne donne JAMAIS permission")
        print("    d'inventer le suivant.")
        return 1

    # Périmètre : ce qui est modifié doit être annoncé par le bail.
    autorises = bail.get("allowed_paths") or []
    hors = [
        c
        for c in _changed_paths()
        if not any(c.startswith(a) for a in autorises)
    ]
    if hors:
        print(f"STOP lego_lease_guard : {len(hors)} chemin(s) hors périmètre du bail.")
        for c in hors[:10]:
            print(f"  · {c}")
        if len(hors) > 10:
            print(f"  … et {len(hors) - 10} autre(s)")
        print("  → soit le bail les autorise explicitement, soit ce travail")
        print("    n'appartient pas à ce Lego et attend son propre cadrage.")
        return 1

    suivant = ouverts[0]
    print(f"OK lego_lease_guard — Lego « {lego} » ({bail.get('titre','')})")
    print(f"  beats verts   : {len(beats) - len(ouverts)}/{len(beats)}")
    print(f"  BEAT COURANT  : {suivant.get('id')}")
    print(f"  cadrage       : {bail['cadrage']}")
    print(f"  storyboard    : {bail['storyboard']}")
    print("  acceptation   :")
    for cmd in bail.get("acceptation", []):
        print(f"    $ {cmd}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
