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

    # RIEN NE SE FERME SANS VERDICT CODEX. Idée de Julien, 2026-08-15.
    #
    # J'avais écrit avoir besoin de lui pour un « superviseur extérieur non
    # modifiable par l'agent ». Il a répondu : Codex est exactement cela. Il
    # avait raison — Codex est hors de moi, je ne peux pas le modifier, et il
    # juge seul. Ce qui lui manquait, c'est que son avis n'arrêtait rien : je
    # choisissais quand l'appeler, et je pouvais l'ignorer.
    #
    # Ici il cesse d'être un conseiller. Un beat déclaré vert doit citer un
    # verdict qui EXISTE sur disque. Je ne peux plus fermer sans l'avoir
    # consulté, et l'absence se voit.
    for b in beats:
        if b.get("etat") == "vert":
            verdict = b.get("verdict_codex")
            if not verdict or not (ROOT / verdict).exists():
                return _fail(
                    f"beat « {b.get('id')} » déclaré vert sans verdict Codex "
                    f"({verdict or 'aucun'}). Lancer `tools/codex_axes.sh` et "
                    "déposer sa sortie avant de fermer."
                )

    ouverts = [b for b in beats if b.get("etat") != "vert"]
    if not ouverts:
        print(f"STOP lego_lease_guard : les {len(beats)} beats de « {lego} » sont verts.")
        print("  → le Lego est terminé. Rendre la main pour clôture et cadrage")
        print("    du suivant. Un beat terminé ne donne JAMAIS permission")
        print("    d'inventer le suivant.")
        return 1

    # LE BAIL NE PEUT PAS S'ÉLARGIR PENDANT QU'IL TRAVAILLE.
    #
    # Défaut trouvé par un axe adverse le 2026-08-15 : le bail s'autorisait
    # LUI-MÊME et autorisait le GARDE dans ses `allowed_paths`. Un loop pouvait
    # donc étendre sa propre laisse au milieu d'une tâche — ce que j'ai fait
    # trois fois le 14, de bonne foi, sans m'en apercevoir.
    #
    # Le bail reste modifiable, sinon on ne pourrait jamais fermer un beat.
    # Mais SEUL : si le bail ou le garde bougent en même temps que du code, on
    # refuse. Une mise à jour de bail est son propre commit, jamais un
    # élargissement glissé dans un lot.
    meta_exact = {"product/mint_next/lego_lease.json", "tools/checks/lego_lease_guard.py"}
    # Les verdicts Codex appartiennent à la comptabilité du bail, pas au
    # produit : les déposer n'est pas « du code qui bouge ».
    meta_prefixes = (".planning/phases/mint-next-user-twin-foundation-20260808/verdicts/",)
    modifies = set(_changed_paths())
    meta = {c for c in modifies
            if c in meta_exact or c.startswith(meta_prefixes)}
    if meta & meta_exact and modifies - meta:
        print("STOP lego_lease_guard : le bail (ou son garde) bouge EN MÊME TEMPS que du code.")
        for c in sorted(modifies & meta):
            print(f"  bail   · {c}")
        for c in sorted(modifies - meta):
            print(f"  code   · {c}")
        print("  → une mise à jour de bail est son PROPRE commit. Autrement, on")
        print("    élargit sa laisse au milieu d'une tâche sans que personne le voie.")
        return 1

    # LA BRANCHE ET LA BASE SONT CELLES QUE LE BAIL DÉCLARE.
    #
    # Le garde ne les vérifiait pas : il aurait laissé travailler sur n'importe
    # quelle branche, y compris celle d'un autre écrivain.
    branche_attendue = bail.get("worktree", {}).get("branche") or bail.get("branche")
    if branche_attendue:
        actuelle = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=ROOT, text=True, capture_output=True,
        )
        if actuelle.returncode or actuelle.stdout.strip() != branche_attendue:
            return _fail(
                f"branche « {actuelle.stdout.strip() or '?'} » alors que le bail "
                f"déclare « {branche_attendue} »"
            )

    base = bail.get("base_sha")
    if base:
        anc = subprocess.run(
            ["git", "merge-base", "--is-ancestor", base, "HEAD"],
            cwd=ROOT, capture_output=True,
        )
        if anc.returncode != 0:
            return _fail(
                f"la base déclarée ({base[:9]}) n'est pas un ancêtre de HEAD — "
                "l'historique a bougé sous le bail"
            )

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
